---
name: github-actions-security
description: Authors, reviews, and hardens GitHub Actions workflows, reusable workflows, and composite actions with least-privilege GITHUB_TOKEN permissions, action references pinned by commit SHA to the latest published release, injection-safe handling of untrusted event data, safe trigger and runner choices, and a structure that scales across many repositories, verified with actionlint and zizmor in a bounded loop. Use when creating or editing anything under .github/workflows/, an action.yml or action.yaml, or a dependabot.yml covering actions, and when reviewing workflow permissions, secrets, OIDC, action pinning or versions, triggers such as pull_request_target or workflow_run, self-hosted runners, caching, or organization-wide workflow governance.
---

<!--
Vendored from https://github.com/konstruktoid/agent-instructions-skills
skills/github/github-actions-security/SKILL.md
Upstream commit: 4983695a16ac349dfcac90c4ab27c86d272c2d6e
Do not edit locally; re-vendor from upstream instead.
-->

# github-actions-security

## Purpose

Produce GitHub Actions workflows and actions that grant the smallest permission set the job needs,
resist the attack patterns CI/CD systems are actually compromised through, and stay maintainable
when the same pattern is repeated across many repositories. This skill is a triage layer: it states
the baseline every workflow must meet, routes the change to the detail that applies, then holds the
result to a bounded verify loop built on `actionlint` and `zizmor`.

A workflow is remote code execution with access to repository credentials. Treat a workflow file as
production code, not configuration.

## When to use this

- Creating or editing any file under `.github/workflows/`.
- Creating or editing an `action.yml` or `action.yaml`, whether composite, Docker, or JavaScript.
- Creating or editing a reusable workflow, or a caller that invokes one.
- Reviewing or changing `permissions`, secrets, OIDC trust conditions, action versions, triggers,
  runner labels, caching, or concurrency in a workflow.
- Editing `.github/dependabot.yml` for the `github-actions` ecosystem.
- Designing workflow structure for an organization: shared workflows, action allowlists, rulesets.

## When NOT to use this

- CI systems other than GitHub Actions.
- Changes to application code that only happen to be built by a workflow, with no workflow file
  touched.

## Steps

1. Orient before changing anything. Read the workflows already in the repository, plus
   `.github/dependabot.yml`, `.github/CODEOWNERS`, and any `zizmor.yml` or `.actionlint.yaml`.
   Match the conventions already present: job naming, runner labels, how secrets are passed, whether
   actions are pinned by SHA or by tag. Check `CONTRIBUTING.md`, `CLAUDE.md`, or `AGENTS.md` for
   rules the repository sets for itself.
2. Apply the baseline below to every workflow touched. It does not depend on the change type.
3. Match the change against the triage table and read the reference files that apply. Read only what
   applies; the table is an index, not a reading list.
4. Write or modify the workflow, resolving every action reference to a real commit SHA (see
   [Resolving a SHA](#resolving-a-sha)). Never write a SHA from memory.
5. Run the verify loop until it is clean or the bound is reached.
6. State the reason for any deliberate exception, such as a permission above `read` or a
   `pull_request_target` trigger, in a YAML comment on the line it applies to and in the pull
   request description.

## The baseline

Every workflow, without exception:

- **Deny by default.** `permissions: {}` at workflow level. Grant permissions per job, never at
  workflow level, so one compromised job cannot reach another job's token scope.
- **Pin every third-party action to a full 40-character commit SHA**, with the version in a trailing
  comment. Tags and branches are mutable. This includes actions used inside composite actions and
  reusable workflows.
- **Pin to the latest published release of the action**, not to whatever version the file already
  used. Look the current release up at the time of the change; do not assume the version in the file,
  or the one you remember, is current. Staying on an older release needs a stated reason, in a
  comment on the line and in the pull request description.
- **Never interpolate untrusted event data into a `run:` block.** `${{ }}` is substituted into the
  script before the shell sees it. Pass the value through `env:` and reference the environment
  variable, quoted.
- **Set `persist-credentials: false` on `actions/checkout`** unless the job must push using the
  checkout credential, so the token is not left in `.git/config` for later steps.
- **Set `timeout-minutes` on every job.** The default is 360 minutes, which is both a cost exposure
  and a long window for a compromised job.
- **Do not use self-hosted runners in a public repository.** No configuration makes this safe.
- **Prefer OIDC over stored cloud credentials**, with the trust condition matched on an exact `sub`
  or `job_workflow_ref` claim, never a wildcard.

A workflow meeting the baseline:

```yaml
name: Example

on:
  pull_request:

permissions: {}

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  example:
    name: Example
    runs-on: ubuntu-latest
    timeout-minutes: 10
    permissions:
      contents: read
    steps:
      - name: Checkout repository
        uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false

      - name: Report the pull request title
        env:
          PR_TITLE: ${{ github.event.pull_request.title }}
        run: printf '%s\n' "$PR_TITLE"
```

### Resolving a SHA

An invented SHA either fails the workflow or resolves to something unintended, and a version recalled
from memory is stale by definition. Ask the source repository for both, in that order:

```sh
gh api repos/actions/checkout/releases/latest --jq .tag_name       # the current release
gh api repos/actions/checkout/commits/v7.0.1 --jq .sha             # its commit SHA
```

`releases/latest` skips drafts and prereleases. Some repositories publish only tags, in which case
use `gh api repos/OWNER/REPO/tags --jq '.[0].name'` and confirm against the repository's own release
notes that the tag is a real release rather than a build marker.

Before adopting a brand-new release, check that it has been available long enough to have been
noticed if it were malicious, and read its release notes for breaking changes. Record a major-version
bump and its behavior implications in the pull request description.

To pin or re-pin a whole repository, use a tool rather than editing by hand:
[pinact](https://github.com/suzuki-shunsuke/pinact) or
[ratchet](https://github.com/sethvargo/ratchet). Both rewrite `uses:` references to SHAs and keep
the version comment. Do not add either tool to a repository's configuration without asking; run it
and report the diff.

## Minimal permissions

Start from nothing and add only what a step actually calls. The common cases:

| The job does | Needs |
|---|---|
| Nothing but evaluate inputs or run a check against them | keep `permissions: {}` |
| Checkout, build, test | `contents: read` |
| Push a commit, tag, or branch | `contents: write` |
| Create a release | `contents: write` |
| Comment on or label a pull request | `pull-requests: write` |
| Comment on or label an issue | `issues: write` |
| Set a commit status or a check run | `statuses: write`, or `checks: write` |
| Upload SARIF from a scanner | `security-events: write` |
| Push to GitHub Packages or GHCR | `packages: write` |
| Request an OIDC token for a cloud provider | `id-token: write` |
| Deploy a GitHub Pages site | `pages: write` and `id-token: write` |
| Publish an artifact attestation | `attestations: write` and `id-token: write` |

No scope implies another. List every scope the job uses, including `contents: read` alongside a
write scope when the job also checks out code. Keep a job that needs a write scope separate from the
job that builds or tests untrusted code, so the write token is never present while that code runs.

For secrets, environments, and OIDC claims, read
[references/permissions-and-secrets.md](references/permissions-and-secrets.md).

## Triage: which reference to read

| The change touches | Read |
|---|---|
| `permissions`, `GITHUB_TOKEN` scopes, any token above `read` | [references/permissions-and-secrets.md](references/permissions-and-secrets.md) |
| Secrets, `secrets: inherit`, environments, deployment approval | [references/permissions-and-secrets.md](references/permissions-and-secrets.md) |
| OIDC, cloud credentials, trusted publishing | [references/permissions-and-secrets.md](references/permissions-and-secrets.md) |
| Debug logging, environment dumps, or a step that commits captured output back | [references/permissions-and-secrets.md](references/permissions-and-secrets.md) |
| A `run:` or `script:` block referencing any `github.event` value | [references/untrusted-input.md](references/untrusted-input.md) |
| `pull_request_target`, `workflow_run`, `issue_comment`, fork pull requests | [references/untrusted-input.md](references/untrusted-input.md) |
| A branch name, title, body, or label used in an expression or a file path | [references/untrusted-input.md](references/untrusted-input.md) |
| Adding, upgrading, or pinning an action or a reusable workflow | [references/supply-chain.md](references/supply-chain.md) |
| Dependabot configuration, action allowlists, immutable releases | [references/supply-chain.md](references/supply-chain.md) |
| `actions/cache`, artifact upload or download between workflows | [references/supply-chain.md](references/supply-chain.md) |
| Build provenance, artifact attestations, release publishing | [references/supply-chain.md](references/supply-chain.md) |
| `runs-on` with a self-hosted or custom label, runner groups | [references/runners.md](references/runners.md) |
| Container jobs, service containers, egress control, network policy | [references/runners.md](references/runners.md) |
| A workflow repeated across repositories, or a new reusable workflow | [references/scalability.md](references/scalability.md) |
| Matrices, concurrency, path filters, job graphs, runtime or cost | [references/scalability.md](references/scalability.md) |
| Organization or enterprise policy, rulesets, CODEOWNERS | [references/scalability.md](references/scalability.md) |

If the change matches nothing in the table, the baseline and the verification checklist still apply.

## Verify

Never declare a workflow change done from the edit alone. A workflow that parses is not a workflow
that is safe, and a workflow that is safe is not a workflow that runs.

Run, in this order:

1. **`actionlint`**, over every workflow in the repository. It catches schema errors, invalid
   expressions, unknown runner labels, and shellcheck findings inside `run:` blocks. Install it, or
   run the container:

   ```sh
   docker run --rm -v "$PWD:/repo" -w /repo rhysd/actionlint:latest -color
   ```

2. **`zizmor`**, over workflows and action definitions. This is the security audit: template
   injection, unpinned actions, excessive permissions, credential persistence, artifact poisoning,
   and dangerous triggers.

   ```sh
   uvx zizmor --persona=pedantic .
   ```

   Exit code 0 means no findings, and 11 through 14 mean findings by ascending severity. Codes 1
   through 3 mean the run itself failed, which is not a pass. Set `GH_TOKEN` to enable the audits
   that need the API, or accept the reduced offline coverage and say so. `--fix` applies mechanical
   fixes such as SHA pinning; review its diff rather than trusting it.

3. **The repository's own configured checks**, if it already runs a workflow linter, a YAML linter,
   or `pre-commit`. Run what is configured rather than a parallel tool of your own choosing.

4. **The workflow itself**, when the change alters behavior rather than only structure. Push to a
   branch and read the run, or use `gh workflow run` for a `workflow_dispatch` workflow. Confirm the
   run passed and that no step logged a secret. A syntactically valid workflow that never ran is
   unverified.

If the repository has no workflow linting configured, run these as one-off checks and report the
findings. Do not add a linter to the repository's configuration as part of an unrelated change.

### The bounded loop

One **attempt** is one full fix-and-rerun cycle: apply fixes for the findings from the previous run,
then rerun every check above to completion. Reading output, or re-reading a file without changing
anything, is not an attempt.

- Baseline the loop at 3 attempts.
- Continue past 3 only while making measurable progress, meaning each cycle ends with strictly fewer
  findings than the one before it.
- Stop early, before 3 attempts, if the loop is oscillating: the same findings recur, the count
  stops dropping, or a fix for one finding reintroduces another.
- When stopping for either reason, report to the user rather than proceeding or silently giving up.
  Name the failing check, include its output, and state what was tried.

Suppress a `zizmor` finding only in `zizmor.yml`, with a comment giving the reason. Never add a
suppression to reach a clean run.

## Verification checklist

- [ ] Verify loop run to a clean result, or stopped under the rules above with unresolved issues
      reported, naming the failing check and its output
- [ ] `actionlint` clean
- [ ] `zizmor` clean, with no new suppression that lacks a stated reason
- [ ] The workflow ran successfully, or the change is structural only and this is stated
- [ ] `permissions: {}` at workflow level, with every job granting only the scopes its steps use
- [ ] Every third-party action pinned to a full commit SHA that was resolved, not recalled, with a
      version comment
- [ ] Each pinned version is the latest published release, looked up during this change, or the
      reason for staying on an older one is stated
- [ ] No `${{ }}` interpolation of event data inside a `run:` block, a `script:` block, or a shell
      argument
- [ ] `actions/checkout` uses `persist-credentials: false`, or the job's need for the credential is
      stated
- [ ] Every job sets `timeout-minutes`
- [ ] No `pull_request_target` or `workflow_run` job checks out or executes fork-controlled code
- [ ] No secret reaches a job that runs untrusted code, and no `secrets: inherit`
- [ ] No self-hosted runner in a public repository
- [ ] Cloud access uses OIDC with an exact-match trust condition, or the reason for a static
      credential is stated
- [ ] No user or system information published: no environment dumps or `set -x`, and no runner
      path, hostname, or account name left in logs, artifacts, or output a step commits back
- [ ] Every reference file matched in the triage table was read and applied

## References

- [references/permissions-and-secrets.md](references/permissions-and-secrets.md): the
  `GITHUB_TOKEN` permission model, secret scoping, environments, and OIDC trust conditions.
- [references/untrusted-input.md](references/untrusted-input.md): script injection, the untrusted
  context inventory, and the dangerous triggers.
- [references/supply-chain.md](references/supply-chain.md): pinning, Dependabot, allowed-actions
  policy, cache and artifact poisoning, and attestations.
- [references/runners.md](references/runners.md): runner selection, self-hosted hardening, and
  egress control.
- [references/scalability.md](references/scalability.md): reusable workflows, composite actions,
  cost and runtime controls, and organization-wide governance.

Prose in this skill and its reference files follows
`instructions/written_language_instructions.md`. That path is relative to this library's root; when
the skill is installed as a Claude Code plugin, read it at `${CLAUDE_PLUGIN_ROOT}/instructions/`.

### Normative

Cite these as standards.

- GitHub, [Security hardening for GitHub Actions](https://docs.github.com/en/actions/reference/security/secure-use)
- GitHub, [Security in GitHub Actions](https://docs.github.com/en/actions/concepts/security)
- GitHub, [Secure your work](https://docs.github.com/en/actions/how-tos/secure-your-work)
- OWASP, [GitHub Actions Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/GitHub_Actions_Security_Cheat_Sheet.html)
- GitHub, [Well-Architected: GitHub Actions security](https://learn.github.com/well-architected/application-security/recommendations/actions-security/)

### Background

Useful orientation, but not authoritative. Do not cite these as standards; where they conflict with
a normative source, the normative source wins.

- GitGuardian, [GitHub Actions Security Cheat Sheet](https://blog.gitguardian.com/github-actions-security-cheat-sheet/)
- StepSecurity, [Community tier quickstart](https://docs.stepsecurity.io/workspace/getting-started/quickstart-community-tier)
- zizmor, [Usage](https://docs.zizmor.sh/usage/) and [Audit rules](https://docs.zizmor.sh/audits/)
- rhysd, [actionlint checks](https://github.com/rhysd/actionlint/blob/main/docs/checks.md)
