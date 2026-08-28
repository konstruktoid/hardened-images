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
Ansible role. The role code is external; it is installed and configured by the Ansible playbook in `config/local.yml`
(with settings from `config/ansible.cfg`).

## Commands

- `bash build_box.sh` — builds the local `.qcow2` image: generates a
  throwaway SSH keypair, boots the official Ubuntu 26.04 live-server ISO in
  QEMU, installs it unattended via the autoinstall config in
  `http/user-data.pkrtpl.hcl`, provisions with `konstruktoid.hardening`,
  generates an SBOM (`scripts/sbom.sh`, Syft) and then strips the ephemeral
  keypair (`scripts/cleanup.sh`, always last). Extra args are passed through
  to `packer build`, e.g.
  `bash build_box.sh -var 'ssh_authorized_keys=["ssh-ed25519 ..."]'`.
  Output (`.qcow2`, `.spdx.json`, `.cdx.json`, `CHECKSUMS`) lands under a
  timestamped subdirectory of `output/`.
- `packer init -upgrade ubuntu-hardened-azure.pkr.hcl`
  / `packer validate ...` / `packer build ...` — Azure image build. Requires
  Azure credentials; see `azure_vars_export` and `scripts/azure.sh`.
- `shellcheck -x -s bash -f gcc build_box.sh run_qemu.sh azure_vars_export scripts/*.sh tools/*.sh`
  — required to pass; `build_box.sh` runs exactly this list itself.
- `packer fmt -check -diff .` and `packer validate` must both pass for any
  `.pkr.hcl` change. `build_box.sh` runs `packer validate` before `packer build`.
- `pre-commit run --all-files` — `gitleaks`, `shellcheck`, `ansible-lint`,
  `packer fmt`, `detect-private-key`, and the pre-commit-hooks hygiene set.
- `.github/workflows/lint.yml` runs `shellcheck`, `bash -n`, `packer
  fmt`/`validate` and `ansible-lint` in CI, plus `actionlint` and `zizmor` over
  the workflows. `gitleaks`, `detect-private-key` and the hygiene hooks run in
  `pre-commit` only.
- `bash tools/vendor-agent-standards.sh` — re-vendors `instructions/` and
  `.agents/skills/` from the pinned upstream ref, verifying that the ref still
  resolves to the pinned commit before it replaces anything.

## Architecture

- `ubuntu-hardened-qemu.pkr.hcl` / `ubuntu-hardened-azure.pkr.hcl` — Packer
  templates for the two build targets. Provisioning logic is kept out of the
  HCL and lives in `scripts/` and `config/local.yml` instead.
- `config/local.yml` — the playbook that clones a pinned version of
  `ansible-role-hardening` and includes it with this repo's variable
  overrides (SSH, sudo, ufw, auditd, etc.). `config/ansible.cfg` configures
  the Ansible run. `config/requirements.yml` is a checked-in copy of the
  collections `ansible-role-hardening` requires at the pinned tag; both
  templates upload it and `scripts/hardening.sh` installs from it, so nothing
  is fetched from a mutable ref at build time. Keep it in sync when bumping
  the role version.
- `http/user-data.pkrtpl.hcl` (+ `http/meta-data`) — cloud-init/autoinstall
  template used to unattended-install Ubuntu inside QEMU.
- `scripts/hardening.sh` — invokes the Ansible provisioning step.
  `scripts/cleanup.sh` — strips the ephemeral Packer SSH keypair before the
  build finishes; must always run, and must run last. `scripts/sbom.sh` —
  generates SPDX/CycloneDX SBOMs with Syft, downloading and checksum-verifying
  the pinned release rather than piping an installer into a shell. Both
  templates run it, and because `scripts/cleanup.sh` has to stay last, the SBOM
  is a pre-cleanup snapshot: it still lists packages and files that cleanup
  subsequently purges from the shipped image. Both templates also declare
  `scripts/cleanup.sh` as an `error-cleanup-provisioner`, so a failing
  provisioner still strips the keypair when the build runs with
  `-on-error=run-cleanup-provisioner`. `scripts/azure.sh` — Azure-specific
  provisioning helper.
- The scripts take their pinned versions and the build username from
  `environment_vars` set by the templates (`HARDENING_ROLE_VERSION`,
  `SYFT_VERSION`, `BUILD_USERNAME`), each with a matching default so the script
  still runs standalone. Change the version in the template variable, not in
  the script. The sudo password travels the same way, as `SUDO_PASSWORD` in
  the provisioner environment file (`use_env_var_file = true`); never
  interpolate `var.password` into `execute_command`, and keep it out of
  `--preserve-env` so sudo drops it before the script runs.
- `tools/vendor-agent-standards.sh` — repository tooling, not provisioning.
  Nothing under `tools/` is uploaded into an image.
- `build_box.sh` — orchestrates the full local QEMU build lifecycle
  (keypair generation, `packer build`, cleanup, SBOM, checksums).
- `azure_vars_export` — creates/resets the Azure service principal, exports
  `ARM_*` credentials into the current shell, and detects the caller's public
  IP so the build VM's NSG only allows inbound SSH from that address. Never
  persist these credentials to disk.
- `.github/workflows/lint.yml` — `packer fmt`/`validate`, `shellcheck`,
  `actionlint`, `zizmor` and `ansible-lint`. `slsa.yml` — builds artifact
  checksums and generates SLSA provenance on push/release.
  `dependency-review.yml`, `scorecards.yml`, `issues.yml` are supporting
  supply-chain/repo-hygiene workflows.
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

## Agent skills and instructions

Skills live in `.agents/skills/`, with `.claude/skills/<name>` symlinked to
each so Claude Code still discovers them. Both these and `instructions/` are
vendored from
[konstruktoid/agent-instructions-skills](https://github.com/konstruktoid/agent-instructions-skills)
and carry the upstream ref and commit in a header comment. Never edit them
locally: bump `DEFAULT_UPSTREAM_REF` and `DEFAULT_UPSTREAM_COMMIT` in
`tools/vendor-agent-standards.sh` and re-run it.
The script also rewrites upstream-only paths (`skills/<category>/<name>/` and
`${CLAUDE_PLUGIN_ROOT}/instructions/`) to this repository's layout.

- `bash-secure-scripting` / `bash-testing` — extend the shellcheck/strict-mode
  baseline in `instructions/bash_coding_instructions.md`, which is the source
  of truth for it. Consult them before changing `build_box.sh`, `run_qemu.sh`,
  `azure_vars_export`, or anything under `scripts/`. They complement
  `.github/instructions/packer-shell.instructions.md`, which stays
  authoritative for Packer template and SBOM/provenance concerns.
- `github-actions-security` — applies to `.github/workflows/**`, alongside
  `.github/instructions/github-actions.instructions.md`.
- `github-repository-security` — applies to repository-level configuration:
  rulesets, scanning, `SECURITY.md`, `CODEOWNERS`, release and tag protection.
- `github-organization-governance` — applies to settings that span repositories:
  organization and enterprise policy, org-wide rulesets, member, team, app and
  token access. Referenced by `instructions/github_governance_instructions.md`.
- `ansible-verification-loop` — applies to `config/*.yml`, alongside
  `.github/instructions/ansible.instructions.md`.
