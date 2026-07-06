# Repository Instructions for GitHub Copilot

This repository builds hardened Ubuntu server images (Azure VM image, QEMU
`.qcow2`, and formerly `.ova`) using [Packer](https://www.packer.io/) and the
[konstruktoid/ansible-role-hardening](https://github.com/konstruktoid/ansible-role-hardening)
Ansible role. Prefer secure-by-default, operationally reliable, maintainable,
and auditable changes.

## Mission and baseline
- Preserve existing hardening intent unless an explicit deviation is requested.
- Bias recommendations toward CIS Benchmarks, DISA STIG guidance, and
  CMMC-oriented practices.
- Prefer minimal, reviewable, reversible diffs.
- The build must remain reproducible without external dependencies beyond the
  official Ubuntu ISO, Packer, QEMU/OVMF, and the pinned hardening role
  version — do not introduce hidden network fetches or unpinned tooling.

## Engineering expectations
- Packer templates (`*.pkr.hcl`) should stay declarative; keep provisioning
  logic in `scripts/` or `config/local.yml` rather than inline in HCL.
- Shell scripts (`build_box.sh`, `azure_vars_export`, `scripts/*.sh`) must
  pass `shellcheck` (enforced via `.pre-commit-config.yaml`) and use
  `set -euo pipefail` (or equivalent explicit error handling).
- Favor maintainability over clever one-liners.
- Ansible usage in `config/local.yml` should stay module-first and use FQCN
  (`ansible.builtin.*`) — see `.github/instructions/ansible.instructions.md`.

## Security requirements
- Never hardcode secrets, credentials, keys, tokens, or passwords. Azure
  credentials (`ARM_*`) must never be persisted to disk or committed.
- Treat SSH access, the `ubuntu` account/password, sudo, PAM, audit/logging,
  firewall (ufw), mounts, sysctl, services, and authentication settings as
  high-sensitivity areas — these are set via `config/local.yml` vars passed
  to `konstruktoid.hardening`.
- The ephemeral Packer provisioning SSH keypair must always be stripped by
  `scripts/cleanup.sh` before a build finishes; do not weaken or bypass that
  cleanup step.
- Avoid security relaxations (e.g. `sshd_password_authentication`,
  `manage_ufw: false`, disabling audit rules) unless explicitly requested and
  documented with rationale.

## Preferred patterns
- Pin the `konstruktoid.hardening` role to an explicit version/tag (as done
  in `config/local.yml` / workflow provisioning), not a floating branch.
- Explicit `owner`, `group`, and quoted octal string `mode` values for any
  managed files touched via Ansible.
- Double-quoted YAML strings in `config/local.yml` and workflow YAML.
- Generate and validate SBOMs (`scripts/sbom.sh`, Syft) for built images
  rather than skipping provenance/attestation steps.

## Discouraged patterns
- `shell`/`command` Ansible modules when a built-in module exists.
- Non-idempotent logic without proper guards.
- Broad network exposure, permissive firewall rules, or world-writable modes
  in the resulting image.
- curl-pipe-to-shell patterns in build/provisioning scripts.
- Persisting SSH keys, passwords, or cloud credentials into the built image
  or repository.

## Linux security posture guidance
- Prefer restrictive defaults, reduced attack surface, and least
  functionality in the built image.
- Keep access control, logging/auditing, and configuration enforcement
  explicit in `config/local.yml`.
- Do not weaken hardening controls silently.

## Testing and validation
- Validate Packer templates with `packer init -upgrade` and
  `packer validate` before `packer build`.
- Run `shellcheck` on changed shell scripts.
- For local QEMU builds, `bash build_box.sh` should complete and produce a
  bootable `.qcow2` plus SBOM/checksum output under `output/`.
- Prefer fixing lint/validation failures over suppressing them; treat
  suppression as a last resort requiring justification.

## Documentation guidance
- Explain security rationale and operational impact for sensitive changes.
- Note compatibility tradeoffs and any intentional deviation from hardening
  intent (e.g. why a control was relaxed for a given image target).

## Review expectations
Prioritize findings on:
- security misconfiguration in `config/local.yml` hardening variables,
- credential/secret exposure (Azure vars, SSH keys, passwords),
- unpinned or unverified third-party dependencies (roles, actions, ISOs),
- file ownership/mode and idempotency in provisioning steps,
- exposure in network/service/authentication paths of the built image.

For meaningful findings, provide: Finding, Risk (Critical/High/Medium/Low),
Location, Recommendation, and a safer example as a short code snippet.

## Change safety rules
- Do not remove or weaken hardening behavior without explicit instruction.
- Do not silently broaden access or reduce enforcement.
- Flag high-impact changes affecting remote access, boot behavior,
  authentication, or audit posture.

## Second opinions
- Regardless of finding severity, ask `@claude` for a second opinion in the
  PR before finalizing the review.
