<!--
Vendored from https://github.com/konstruktoid/agent-instructions-skills
skills/github/github-actions-security/references/scalability.md
Upstream commit: f4696ac18174422ba873bac1630628d49123c7c0
Do not edit locally; re-vendor from upstream instead.
-->

# Scalability and Governance

Read this when a workflow is repeated across repositories, when creating a reusable workflow or
composite action, or when workflow runtime, cost, or organization-wide policy is in scope.

## Reusable workflow or composite action

Both remove duplication, and they are not interchangeable:

| | Reusable workflow | Composite action |
|---|---|---|
| Called with | `jobs.<id>.uses` | `steps[].uses` |
| Unit | One or more whole jobs | A sequence of steps inside a job |
| Runner | Declares its own `runs-on` | Runs on the caller's runner |
| Permissions | Own `permissions`, bounded by the caller's | Uses the caller's job token |
| Secrets | Passed explicitly per secret | Passed as inputs |
| Nesting | Up to 4 levels | Up to 10 levels |

Choose a reusable workflow when the unit is a job: a whole build, a whole deploy, a matrix. Choose a
composite action when the unit is a few steps that belong inside someone else's job.

A reusable workflow is the stronger security boundary, because it declares its own permissions and
receives only the secrets it is handed. Prefer it for anything that touches credentials.

```yaml
# .github/workflows/build.yml in octo-org/shared
on:
  workflow_call:
    inputs:
      python-version:
        required: true
        type: string
    secrets:
      REGISTRY_TOKEN:
        required: false

permissions: {}

jobs:
  build:
    runs-on: ubuntu-latest
    timeout-minutes: 15
    permissions:
      contents: read
    steps: []
```

Called with:

```yaml
jobs:
  build:
    uses: octo-org/shared/.github/workflows/build.yml@<full-sha> # v1.4.0
    with:
      python-version: "3.13"
    secrets:
      REGISTRY_TOKEN: ${{ secrets.REGISTRY_TOKEN }}
```

Pin the call to a SHA, like any other dependency. Type every input, mark required ones, and declare
secrets individually so `secrets: inherit` is never needed.

## A shared workflow repository

For an organization, a single reviewed repository of shared workflows and actions is the control
that makes every other recommendation here enforceable once instead of per repository.

- Put `.github/workflows/` under `CODEOWNERS` with a security or platform team as owner.
- Version the shared workflows with release tags, so callers pin a SHA and read a version comment.
  Communicate breaking changes through the version, not through a silent change to `main`.
- Keep the shared repository's own workflows under the same rules; it is the highest-value target in
  the organization.
- Resist a shared workflow that takes a script as an input. That inverts the trust model: the shared
  workflow becomes a way to run arbitrary code with whatever permissions it holds.

## Organization and enterprise controls

Controls a workflow file cannot bypass, in rough order of value:

| Control | Where | Effect |
|---|---|---|
| Default token permissions read-only | Org, repo | Protects every unreviewed workflow |
| Allowed actions policy, with SHA pinning required | Enterprise, org | Makes pinning an invariant |
| Fork pull request approval required | Org, repo | No fork code runs without a reviewer |
| Rulesets: required reviews, required status checks | Org, repo | Prevents self-merge of a workflow change |
| Required signed commits | Org, repo | Raises the cost of a pushed forgery |
| Runner group scoping | Org, enterprise | Bounds which repositories reach which runners |
| Environment reviewers and branch rules | Repo | Gates deployment behind a human |
| CODEOWNERS on `.github/` | Repo | Routes workflow changes to a reviewer who reads them |

Apply these through the API from version-controlled definitions, so the configuration is auditable
and can be restored quickly.

Enable code scanning with CodeQL's `actions` language, which analyzes workflow files themselves, and
make it a required status check that blocks high and critical findings. Add `zizmor` to CI for
defense in depth.

## Cost and runtime

Scalability is also about a workflow estate that stays affordable and fast as repositories multiply.

- **`timeout-minutes` on every job.** The 360-minute default is the failure mode where a hung job
  consumes six hours of runner time.
- **Concurrency groups** cancel superseded runs instead of paying for them:

  ```yaml
  concurrency:
    group: ${{ github.workflow }}-${{ github.ref }}
    cancel-in-progress: true
  ```

  Do not set `cancel-in-progress: true` on a deployment or publish workflow, where a cancelled run
  can leave partial state. Use a group without cancellation there, to serialize instead.

- **Path and branch filters** keep a workflow from running on changes it does not concern:

  ```yaml
  on:
    pull_request:
      paths:
        - "src/**"
        - ".github/workflows/build.yml"
  ```

  A workflow used as a required status check must still report a result on every pull request, so
  use a filter inside the job, or a skip-reporting job, rather than a top-level `paths` filter that
  leaves the check pending forever.

- **`fail-fast: false` only when the extra matrix results are worth their runtime.** The default
  cancels siblings on first failure, which is usually correct.
- **Keep the matrix as small as the risk allows.** Full operating system and version cross-products
  belong on a schedule, not on every pull request.
- **Cache deliberately.** A cache key that never hits costs storage and time; one that is too loose
  restores stale content. Keep caching out of release workflows entirely, per
  [supply-chain.md](supply-chain.md).
- **Split long jobs that need different permissions** rather than granting the union of both.
- **Prefer `schedule` over frequent polling**, and place scheduled workflows off the hour, because
  many workflows queue at `0 * * * *`.

## Checklist

- [ ] Shared logic lives in a versioned reusable workflow or composite action, not copied per
      repository
- [ ] Reusable workflows declare `permissions: {}` plus per-job scopes, typed inputs, and named
      secrets
- [ ] Callers pin shared workflows and actions to a SHA with a version comment
- [ ] Shared workflow repository owned through CODEOWNERS and held to the same rules
- [ ] Organization controls applied from version-controlled definitions
- [ ] CodeQL `actions` scanning enabled as a required check, with `zizmor` in CI
- [ ] Every job sets `timeout-minutes`
- [ ] Concurrency groups set, with cancellation off for deploy and publish workflows
- [ ] Path, branch, and matrix scope reviewed against runtime and cost
