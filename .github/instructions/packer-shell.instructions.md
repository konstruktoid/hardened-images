---
applyTo: "*.pkr.hcl,scripts/**/*.sh,build_box.sh,azure_vars_export"
---

# Packer and Shell Provisioning Instructions

Apply these rules to Packer templates and the shell scripts that build and
provision the hardened images.

## Shell scripting requirements
- Start scripts with `set -euo pipefail` (or equivalent explicit error
  handling) so failures during a build stop the pipeline rather than
  continuing silently.
- Must pass `shellcheck` (enforced via `.pre-commit-config.yaml`); fix
  findings rather than disabling checks.
- Quote variables and paths; avoid word-splitting/glob bugs on user-supplied
  input (e.g. `-var` overrides passed to `build_box.sh`).
- Never persist Azure `ARM_*` credentials or other secrets to disk; only
  export them into the current shell's environment.

## Packer template requirements
- Keep `*.pkr.hcl` declarative — provisioning logic belongs in `scripts/` or
  `config/local.yml`, not inline shell embedded in HCL.
- Any new `required_plugins`/provisioner should be pinned to a specific
  version, mirroring the existing templates.
- Validate changes with `packer init -upgrade` and `packer validate` before
  `packer build`.

## Build lifecycle and secrets
- The ephemeral SSH keypair Packer uses to provision an image must always be
  stripped by `scripts/cleanup.sh` before the build finishes — do not
  remove, weaken, or make this step conditional.
- Do not bake permanent SSH keys, passwords, or cloud credentials into the
  built image; `ssh_authorized_keys` should remain an explicit opt-in
  variable, not a default.
- SBOM generation (`scripts/sbom.sh`, Syft) and checksum output for built
  artifacts should not be skipped or weakened.

## Review priorities
1. Secret/credential handling (Azure vars, SSH keys, passwords)
2. Build reproducibility (pinned plugins/role versions, no hidden network fetches)
3. Shell safety (`set -euo pipefail`, quoting, shellcheck cleanliness)
4. Cleanup correctness (ephemeral keys, temp files stripped from the image)
5. Provenance/SBOM completeness for produced artifacts

## Risk levels
- Critical: secret/credential leakage into the image, repo, or logs
- High: missing key/credential cleanup, unpinned dependency introducing supply-chain risk
- Medium: reliability issue (unsafe script logic, missing validation step)
- Low: style/maintainability issue with minimal security impact

## Second opinions
- Regardless of finding severity, ask `@claude` for a second opinion in the PR before finalizing the review.
