# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

`hardened-images` builds hardened Ubuntu server images using
[Packer](https://www.packer.io/) templates. Targets are an
[Azure virtual machine image](https://learn.microsoft.com/en-us/azure/virtual-machines/linux/build-image-with-packer)
and a local [QEMU](https://www.qemu.org/) `.qcow2` disk image (a former `.ova`
target is documented in git history only). Ubuntu 26.04 LTS (Resolute
Raccoon) is the supported release. Hardening is applied by the external
[konstruktoid/ansible-role-hardening](https://github.com/konstruktoid/ansible-role-hardening)
Ansible role, installed and configured via `config/local.yml` /
`config/ansible.cfg`, not by Ansible code that lives in this repo.

## Commands

- `bash build_box.sh` — builds the local `.qcow2` image: generates a
  throwaway SSH keypair, boots the official Ubuntu 26.04 live-server ISO in
  QEMU, installs it unattended via the autoinstall config in
  `http/user-data.pkrtpl.hcl`, provisions with `konstruktoid.hardening`, then
  strips the ephemeral keypair (`scripts/cleanup.sh`) and generates an SBOM
  (`scripts/sbom.sh`, Syft). Extra args are passed through to `packer build`,
  e.g. `bash build_box.sh -var 'ssh_authorized_keys=["ssh-ed25519 ..."]'`.
  Output (`.qcow2`, `.spdx.json`, `.cdx.json`, `CHECKSUMS`) lands under a
  timestamped subdirectory of `output/`.
- `packer init -upgrade -var-file ubuntu-azure-vars.json ubuntu-hardened-azure.pkr.hcl`
  / `packer validate ...` / `packer build ...` — Azure image build. Requires
  Azure credentials; see `azure_vars_export` and `scripts/azure.sh`.
- `shellcheck` — required to pass on all shell scripts (`.pre-commit-config.yaml`
  also runs `gitleaks`, `end-of-file-fixer`, `trailing-whitespace`).
- `packer validate` should be run before `packer build` for any `.pkr.hcl` change.

## Architecture

- `ubuntu-hardened-qemu.pkr.hcl` / `ubuntu-hardened-azure.pkr.hcl` — Packer
  templates for the two build targets. Provisioning logic is kept out of the
  HCL and lives in `scripts/` and `config/local.yml` instead.
- `config/local.yml` — the playbook that clones a pinned version of
  `ansible-role-hardening` and includes it with this repo's variable
  overrides (SSH, sudo, ufw, auditd, etc.). `config/ansible.cfg` configures
  the Ansible run.
- `http/user-data.pkrtpl.hcl` (+ `http/meta-data`) — cloud-init/autoinstall
  template used to unattended-install Ubuntu inside QEMU.
- `scripts/hardening.sh` — invokes the Ansible provisioning step.
  `scripts/cleanup.sh` — strips the ephemeral Packer SSH keypair before the
  build finishes; must always run. `scripts/sbom.sh` — generates SPDX/CycloneDX
  SBOMs with Syft. `scripts/azure.sh` — Azure-specific provisioning helper.
- `build_box.sh` — orchestrates the full local QEMU build lifecycle
  (keypair generation, `packer build`, cleanup, SBOM, checksums).
- `azure_vars_export` — creates/resets the Azure service principal, exports
  `ARM_*` credentials into the current shell, and detects the caller's public
  IP so the build VM's NSG only allows inbound SSH from that address. Never
  persist these credentials to disk.
- `.github/workflows/slsa.yml` — builds artifact checksums and generates SLSA
  provenance on push/release. `dependency-review.yml`, `scorecards.yml`,
  `issues.yml` are supporting supply-chain/repo-hygiene workflows.
- `.github/copilot-instructions.md` and `.github/instructions/*.instructions.md`
  are the authoritative security/quality rules for this repo — follow them
  for any change here too:
  - Treat SSH access, the default `ubuntu` account, sudo, PAM, audit/logging,
    firewall, mounts, sysctl, and authentication settings (all configured via
    `config/local.yml` hardening variables) as high-sensitivity: preserve
    existing hardening intent, don't silently weaken or broaden access.
  - Never persist Azure `ARM_*` secrets or SSH keys to disk or the repo; the
    ephemeral provisioning keypair must always be stripped by
    `scripts/cleanup.sh`.
  - Shell scripts must use `set -euo pipefail` and pass `shellcheck`.
  - `.github/instructions/github-actions.instructions.md` applies to
    `.github/workflows/**` (least-privilege `permissions`, pinned third-party
    actions by SHA, no curl-pipe-to-shell, explicit `timeout-minutes`/`concurrency`).
  - `.github/instructions/ansible.instructions.md` applies to `config/*.yml`
    (module-first, FQCN, pinned role version, conservative hardening changes).
  - `.github/instructions/packer-shell.instructions.md` applies to `*.pkr.hcl`
    and scripts (declarative templates, pinned plugin versions, secret/key
    hygiene, SBOM/provenance completeness).
