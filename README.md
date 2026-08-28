# Hardened Ubuntu server templates

This is a repository containing [Packer](https://www.packer.io/)
templates to create a hardened [Ubuntu](https://releases.ubuntu.com) server.

There are templates available for creating a
- [Azure virtual machine image](https://learn.microsoft.com/en-us/azure/virtual-machines/linux/build-image-with-packer)
- [QEMU](https://www.qemu.org/) `.qcow2` disk image

[Ubuntu 26.04 LTS (Resolute Raccoon)](https://releases.ubuntu.com/resolute/)
is supported.

The Ansible role used to make the server a bit more secure is available in the
[konstruktoid/ansible-role-hardening](https://github.com/konstruktoid/ansible-role-hardening)
repository.

The role is installed and configured using [config/local.yml](./config/local.yml).

See the Packer
[builders](https://developer.hashicorp.com/packer/docs/builders) and
[post-processors](https://developer.hashicorp.com/packer/docs/post-processors)
documentation on how to rewrite the templates for another platform.

## Usage

### Azure

Requires [Packer](https://www.packer.io/), the Azure CLI (`az`), `jq`,
`curl` and a [Microsoft Azure](https://portal.azure.com/) account.

Ensure the correct values are set in `ubuntu-azure-vars.json` before
validating the configuration and building the image.

[azure_vars_export](azure_vars_export) creates or resets the service
principal, exports the `ARM_*` variables needed to authenticate with Azure,
and detects the caller's public IP address as `MY_IP_ADDRESS` so the build
VM's network security group only allows inbound SSH from that address. It
must be sourced rather than executed, and it expects an existing `az` login.
The credentials are exported into the current shell only; never write them to
disk.

It also creates the resource group named in `ubuntu-azure-vars.json` if it
does not already exist, and assigns the principal the `Contributor` role
scoped to that group. `ARM_LOCATION` (default `northeurope`),
`ARM_SUBSCRIPTION_ID`, `ARM_RESOURCE_GROUP_NAME`, `ARM_PRINCIPAL_NAME` and
`MY_IP_ADDRESS` override the detected or file-derived values.

```json
{
  "image_offer": "ubuntu-26_04-lts",
  "image_sku": "server",
  "principal_name": "PackerPrincipal",
  "resource_group": "PackerGroup",
  "vm_size": "Standard_D2s_v3"
}
```

```sh
az login --use-device-code --tenant <tenant_id>
source azure_vars_export

packer init -upgrade ubuntu-hardened-azure.pkr.hcl
packer validate -var-file ubuntu-azure-vars.json ubuntu-hardened-azure.pkr.hcl
packer build -timestamp-ui -var-file ubuntu-azure-vars.json ubuntu-hardened-azure.pkr.hcl
```

The Azure build generates the same SPDX (`.spdx.json`) and CycloneDX
(`.cdx.json`) SBOMs as the local build and downloads them to a timestamped
subdirectory under `output`, named after the managed image.

### Local qcow2 image

Requires [Packer](https://www.packer.io/), [QEMU](https://www.qemu.org/) and
OVMF, the [EDK II](https://github.com/tianocore/edk2) UEFI firmware, which is
the `ovmf` package on Debian and Ubuntu.

`build_box.sh` also checks that `shellcheck`, `ssh-keygen` and `sha256sum`
are on `PATH`, and runs `shellcheck` over the repository's shell scripts
before it builds anything.

To build the image, run `bash build_box.sh`. The script generates a throwaway
SSH keypair, then builds [ubuntu-hardened-qemu.pkr.hcl](./ubuntu-hardened-qemu.pkr.hcl):
Packer boots the official Ubuntu 26.04 live-server ISO in QEMU and installs it
unattended using the
[autoinstall](https://canonical-subiquity.readthedocs-hosted.com/en/latest/intro-to-autoinstall.html)
configuration in [http/user-data.pkrtpl.hcl](./http/user-data.pkrtpl.hcl). No
base image or box is needed, but the build does fetch the Ubuntu ISO, the
pinned `konstruktoid.hardening` tag and the pinned Syft release.

A build takes roughly half an hour on a host with a usable `/dev/kvm`, and
writes an image of about 8 GB, backed by a 20 GB virtual disk (`var.disk_size`).

Near the end of the build, an SBOM of the image is generated with
[Syft](https://github.com/anchore/syft) using
[scripts/sbom.sh](./scripts/sbom.sh). It runs before
[scripts/cleanup.sh](./scripts/cleanup.sh), which has to stay last so the
ephemeral provisioning keypair is always stripped, so the SBOM is a pre-cleanup
snapshot and still lists packages and files that cleanup then purges.

Both templates also declare `scripts/cleanup.sh` as an
`error-cleanup-provisioner`, so the keypair is stripped even when an earlier
provisioner fails and the build is run with `-on-error=run-cleanup-provisioner`.

The generated `.qcow2` disk image, its SPDX (`.spdx.json`) and CycloneDX
(`.cdx.json`) SBOM files, and a `CHECKSUMS` file covering those three are
stored in a timestamped subdirectory under `output`. The build's serial
console log (`serial.log`) and the guest's UEFI variable store
(`efivars.fd`) are left there as well.

By default the image ships with a single `ubuntu` account (password
`ubuntu`, see `var.password`/`var.password_hash`) and no persisted SSH keys.

> **Note**
> That password is a published default and it survives into the built image,
> which also has `sshd_password_authentication` enabled. It is meant for local
> testing. For anything else, override `var.password` and `var.password_hash`
> together, generating the hash with `openssl passwd -6`.

Pass your own public keys to keep them installed in the built image:

```sh
bash build_box.sh -var 'ssh_authorized_keys=["ssh-ed25519 AAAA... you@example.com"]'
```

Extra arguments given to `build_box.sh` are passed through to `packer build`.
The ephemeral keypair Packer itself uses to provision the image is always
stripped by [scripts/cleanup.sh](./scripts/cleanup.sh) before the build
finishes.

### Verification

Images are built locally rather than in CI, so a `.qcow2` file carries no
provenance of its own; verify it against the `CHECKSUMS` file written beside
it.

What is attested is the build definition.
[.github/workflows/slsa.yml](./.github/workflows/slsa.yml) runs on a push to
`main` or `master`, on a `v*` tag, and on a published release. It checksums
the templates, `build_box.sh`, `run_qemu.sh`, `azure_vars_export`, `scripts/`,
`tools/`, `config/`, `http/` and `ubuntu-azure-vars.json` into a single
`hardened-images.sha256` file, and that file is the subject of the
[SLSA](https://slsa.dev/) build level 3 provenance generated by
[slsa-github-generator](https://github.com/slsa-framework/slsa-github-generator).

Both appear on the
[SLSA workflow runs](https://github.com/konstruktoid/hardened-images/actions/workflows/slsa.yml),
where the `hardened-images.sha256` artifact is kept for five days. For a tag,
the provenance is uploaded as a release asset by the generator, and the
`hardened-images.sha256` file is attached to the same release by the
workflow's `release` job.

## Using the qcow2 image

[run_qemu.sh](./run_qemu.sh) boots a built image with the same OVMF UEFI
firmware the build used and forwards a local port to the guest's SSH server.
With no argument it picks the most recently modified image under `output`:

```sh
bash run_qemu.sh
bash run_qemu.sh ./output/<build>/<build>.qcow2
```

`OVMF_CODE`, `OVMF_VARS_TEMPLATE`, `SSH_PORT` and `VM_MEMORY` can be set in the
environment to override the defaults. The script falls back to software
emulation, with a warning, when `/dev/kvm` is not usable.

Once booted, connect over SSH as the `ubuntu` user, either with a key you
passed via `ssh_authorized_keys` or with the password `ubuntu`
(see [Local qcow2 image](#local-qcow2-image)):

```sh
ssh -p 2222 ubuntu@localhost
```

## Repository structure

```sh
.
├── .agents
│   └── skills            # Agent skills, vendored from agent-instructions-skills
├── .claude
│   └── skills            # Symlinks to .agents/skills, for Claude Code discovery
├── .github
│   ├── copilot-instructions.md  # Authoritative security and quality rules
│   ├── instructions      # Path-scoped review rules
│   └── workflows         # Lint, SLSA provenance, Scorecard, dependency review,
│                         # issue assignment
├── .pre-commit-config.yaml  # gitleaks, shellcheck, ansible-lint, packer fmt
├── azure_vars_export     # Sourced: exports ARM_* credentials and MY_IP_ADDRESS
├── build_box.sh          # Builds the local .qcow2 image
├── CLAUDE.md             # Repository guidance for coding agents
├── config
│   ├── ansible.cfg
│   ├── local.yml         # Installs and configures konstruktoid.hardening
│   └── requirements.yml  # Collections konstruktoid.hardening needs
├── http
│   ├── meta-data
│   └── user-data.pkrtpl.hcl  # autoinstall configuration
├── instructions          # Coding, writing and governance standards, vendored
│                         # from agent-instructions-skills
├── LICENSE
├── run_qemu.sh           # Boots a built image locally
├── scripts
│   ├── azure.sh          # Azure-specific image preparation
│   ├── cleanup.sh        # Strips build leftovers; must always run last
│   ├── hardening.sh      # Runs the Ansible provisioning step
│   └── sbom.sh           # Generates SPDX and CycloneDX SBOMs with Syft
├── SECURITY.md
├── tools
│   └── vendor-agent-standards.sh  # Re-vendors instructions/ and .agents/skills
├── ubuntu-azure-vars.json
├── ubuntu-hardened-azure.pkr.hcl
└── ubuntu-hardened-qemu.pkr.hcl
```

## Development

Both templates are formatted with `packer fmt` and must validate before they
are built; `build_box.sh` runs `packer validate` itself. The same checks run in
CI via [.github/workflows/lint.yml](./.github/workflows/lint.yml), which covers
`packer fmt`/`validate`, `shellcheck`, `bash -n` syntax checks, `actionlint`,
`zizmor` and `ansible-lint`.

Locally, install the hooks with `pre-commit install`, or run the whole set with
`pre-commit run --all-files`.

The pinned versions that a build depends on are set in the templates:

| Pinned thing | Where |
|---|---|
| Packer core and plugins | `packer` block in each `*.pkr.hcl` |
| `konstruktoid.hardening` role tag | `var.hardening_role_version` |
| Collections the role needs | `config/requirements.yml` |
| Syft | `var.syft_version` |
| Ubuntu ISO and its checksum | `var.iso_url` / `var.iso_checksum` (QEMU only) |
| Agent skills and instructions | `DEFAULT_UPSTREAM_REF` / `DEFAULT_UPSTREAM_COMMIT` in `tools/vendor-agent-standards.sh` |

The templates hand these to the provisioning scripts as environment
variables: both pass `HARDENING_ROLE_VERSION`, `SYFT_VERSION` and
`BUILD_USERNAME`, and the Azure template also passes `ANSIBLE_CONFIG`. The
password sudo authenticates with is passed the same way, as `SUDO_PASSWORD` in
the provisioner environment file (`use_env_var_file`), so it never appears in
the command Packer logs or in the guest's process list, and `--preserve-env`
omits it so sudo drops it before the script runs.
`scripts/hardening.sh` and `config/local.yml` (role tag), `scripts/sbom.sh` (Syft) and
`scripts/cleanup.sh` (username) each carry a matching fallback default so they
still run standalone. Change the version in the template variable, then keep
those defaults in sync with it.

`config/requirements.yml` is a copy of the `requirements.yml` shipped by
`konstruktoid.hardening` at the pinned tag. The templates upload it and
`scripts/hardening.sh` installs from it, so `ansible-galaxy` never installs
collections fetched from a mutable tag at build time. Bumping the role version
means checking that file against the upstream one for the new tag.

The contents of `instructions/` and `.agents/skills/` are vendored copies of
[konstruktoid/agent-instructions-skills](https://github.com/konstruktoid/agent-instructions-skills)
and carry the upstream commit in a header comment. The script verifies that the
ref still resolves to the pinned commit before it replaces anything. Do not edit
them in place; bump `DEFAULT_UPSTREAM_REF` and `DEFAULT_UPSTREAM_COMMIT` and
re-run (the script also takes a ref as its first argument and the commit it must
resolve to as its second, for a one-off run):

```sh
bash tools/vendor-agent-standards.sh
```

## Contributing

Do you want to contribute? Great! Contributions are always welcome,
no matter how large or small. If you found something odd, feel free to submit a
issue, improve the code by creating a pull request, or by
[sponsoring this project](https://github.com/sponsors/konstruktoid).

## License

Apache License Version 2.0

## Author Information

[https://github.com/konstruktoid](https://github.com/konstruktoid "github.com/konstruktoid")
