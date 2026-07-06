---
applyTo: ".github/workflows/**/*.yml,.github/workflows/**/*.yaml,action.yml,action.yaml,.github/actions/**/*.yml,.github/actions/**/*.yaml"
---

# Enterprise GitHub Actions Security Instructions

Apply these rules to workflow and action definitions.

## Security-first workflow design
- Use least-privilege `permissions` at workflow/job scope; avoid implicit broad defaults.
- Keep triggers narrow (`branches`, `paths`, event types) and avoid unnecessary execution scope.
- Pin third-party actions to commit SHA (with a version comment), as already done in this repo's workflows.
- Treat all PR metadata, artifact contents, and external inputs as untrusted.
- Use `step-security/harden-runner` (or equivalent) at the start of jobs that build/release artifacts.

## Secrets and token handling
- Never hardcode secrets or tokens.
- Use GitHub secrets/variables and mask sensitive output.
- Avoid printing env/context objects that may contain credentials.
- Minimize `GITHUB_TOKEN` privileges and step exposure.
- Azure service principal credentials (`ARM_*`) must never appear in workflow logs or be persisted as artifacts.

## High-risk event and runner handling
- Use extreme caution with `pull_request_target` and `workflow_run`; never execute untrusted code with elevated context.
- For self-hosted runners, enforce strict trust boundaries, labeling, and job scoping.
- Validate artifact provenance before reuse; avoid cross-trust artifact promotion.
- Treat caches as potentially attacker-influenced; scope keys defensively.
- SLSA provenance generation (`slsa.yml`) and its `permissions`/`id-token` scoping must not be broadened beyond what the release job needs.

## Reliability and safety defaults
- Set explicit `timeout-minutes`.
- Use `concurrency` to prevent unsafe overlap when deployments/stateful steps exist.
- Keep scripts short, fail-fast, and explicit (`set -euo pipefail` for bash steps where appropriate).
- Avoid curl-pipe-to-shell patterns; download, verify, then execute.

## Review priorities
1. Privilege model (`permissions`, token use, OIDC scope)
2. Trigger safety and untrusted input handling
3. Third-party dependency trust (pinning, provenance)
4. Secret exposure risks in logs, outputs, artifacts, and caches
5. Runner isolation and escalation paths

## Risk levels
- Critical: direct secret exfiltration path or untrusted-code execution in privileged context
- High: broad token permissions, unsafe event usage, or unpinned high-trust action usage
- Medium: missing safety controls (`timeout-minutes`, `concurrency`, validation gaps)
- Low: style/maintainability issues with limited security impact

## Second opinions
- Regardless of finding severity, ask `@claude` for a second opinion in the PR before finalizing the review.
