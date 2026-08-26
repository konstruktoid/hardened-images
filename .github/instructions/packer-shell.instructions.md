---
applyTo: "*.pkr.hcl,scripts/**/*.sh,tools/**/*.sh,build_box.sh,run_qemu.sh,azure_vars_export"
---

# Packer and Shell Provisioning Instructions

Apply these rules to Packer templates and the shell scripts that build and
provision the hardened images.

## Shell scripting requirements
- Start scripts with `set -euo pipefail` (or equivalent explicit error
  handling) so failures during a build stop the pipeline rather than
  continuing silently.
- Must pass `shellcheck` (enforced via `.pre-commit-config.yaml`, the `shell`
  job in `.github/workflows/lint.yml`, and `build_box.sh` itself); fix findings
  rather than disabling checks. When a suppression is genuinely correct, use a
  targeted `# shellcheck disable=SCxxxx` with a comment saying why.
- `azure_vars_export` is sourced, not executed. It must not use `set -e`, which
  would terminate the caller's interactive shell; it handles errors explicitly
  and `return`s instead.
- Quote variables and paths; avoid word-splitting/glob bugs on user-supplied
  input (e.g. `-var` overrides passed to `build_box.sh`).
- Never persist Azure `ARM_*` credentials or other secrets to disk; only
  export them into the current shell's environment.

## Packer template requirements
- Keep `*.pkr.hcl` declarative — provisioning logic belongs in `scripts/` or
  `config/local.yml`, not inline shell embedded in HCL.
- Pin `required_version` for Packer core and every entry in
  `required_plugins` to an exact minor series (`~> 1.1.6`), mirroring the
  existing templates. A floating `>=` constraint is not a pin.
- Templates must be `packer fmt` clean and must `packer validate`. Both are
  enforced by the `packer` job in `.github/workflows/lint.yml`, and
  `build_box.sh` runs `packer validate` before `packer build`.
- Mark credential variables `sensitive = true` unless the value is a short
  common word, which Packer would then redact from unrelated build output.
  State the reason in a comment when leaving one unmarked.
- Use `variable ... validation` blocks for values whose absence would otherwise
  produce a silently wrong build, such as the IP address that scopes the Azure
  build VM's inbound SSH rule.
- Provisioner scripts are `#!/bin/bash` and rely on bash-only behaviour, so
  `execute_command` must invoke `bash`, not `sh`.

## Build lifecycle and secrets
- The ephemeral SSH keypair Packer uses to provision an image must always be
  stripped by `scripts/cleanup.sh` before the build finishes — do not
  remove, weaken, or make this step conditional.
- Do not bake permanent SSH keys, passwords, or cloud credentials into the
  built image; `ssh_authorized_keys` should remain an explicit opt-in
  variable, not a default.
- SBOM generation (`scripts/sbom.sh`, Syft) and checksum output for built
  artifacts should not be skipped or weakened.
- Anything fetched during a build must come from a pinned tag and be verified.
  Do not pipe a remote installer into a shell, and do not fetch from a moving
  branch: download the release asset plus its checksum file and verify one
  against the other, as `scripts/sbom.sh` does.
- A pinned version belongs in exactly one place. The hardening role tag and the
  Syft version are declared as Packer variables and passed to the scripts
  through `environment_vars`; do not re-hardcode them in a script.

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
