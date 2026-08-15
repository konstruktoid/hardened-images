<!--
Vendored from https://github.com/konstruktoid/agent-instructions-skills
skills/github/github-actions-security/references/permissions-and-secrets.md
Upstream commit: f4696ac18174422ba873bac1630628d49123c7c0
Do not edit locally; re-vendor from upstream instead.
-->

# Permissions, Secrets, and OIDC

Read this when the change touches `permissions`, `GITHUB_TOKEN` scopes, secrets, environments, or
cloud authentication.

## The permission model

`GITHUB_TOKEN` is minted per job, expires when the job ends, and carries whatever scopes the
`permissions` key resolved to for that job. There are three levels, each overriding the one above:

1. The organization or repository default, set in Settings, Actions, General. Set this to
   **read-only**. It is the only control that protects workflows nobody has reviewed yet.
2. The workflow-level `permissions` key.
3. The job-level `permissions` key.

Declaring any scope discards the defaults for that level, so a block listing one scope grants
exactly that scope and nothing else.

Write `permissions: {}` at workflow level and grant per job. Workflow-level grants leak: a
three-job workflow where only the release job needs `contents: write` hands that token to the test
job too, which is where untrusted code runs.

```yaml
permissions: {}

jobs:
  test:
    permissions:
      contents: read
  release:
    needs: test
    permissions:
      contents: write
      id-token: write
```

Splitting the write scope into its own job is the point of the pattern, not a formality. Keep any
job that executes code from a pull request on `contents: read`.

### Scopes worth knowing

- `contents: write` allows pushing to any branch not protected by a ruleset, and creating releases.
  It is the scope an attacker wants. Treat any workflow holding it as a release workflow.
- `actions: write` allows cancelling and re-running workflows, and deleting artifacts. Rarely needed.
- `id-token: write` requests an OIDC token. Grant it only in the job that authenticates.
- `attestations: write` publishes build provenance and needs `id-token: write` with it.
- `packages: write` on a public repository package is effectively a publish credential.

Events caused by `GITHUB_TOKEN` do not start another workflow run, with two exceptions:
`workflow_dispatch` and `repository_dispatch` do fire when dispatched with it. This is a loop
guard, not a security boundary, and it is also why a push made by `GITHUB_TOKEN` never runs the
`push` workflows. Reach for a credential other than `GITHUB_TOKEN` only when the downstream event
is one it cannot raise, and prefer a GitHub App installation token to a personal access token: it
is short-lived and scoped to the repositories the app is installed on.

## Secrets

Anyone with write access to a repository can read every repository secret, and every organization
secret shared with it, because they can write a workflow that prints one. Environment secrets are
the exception worth knowing: a job reaches them only by naming that `environment:`, and if the
environment has required reviewers, a wait timer, or a branch restriction, the job does not start
and the secret is never injected until those pass. That protection is the deployment gate, not the
secret store, so it holds only while the rules stay on the environment. Scope accordingly.

- **Prefer environment secrets to repository secrets, and repository to organization.** An
  environment secret is reachable only from a job that declares `environment:`, which can require
  reviewer approval and restrict the branches allowed to deploy.
- **Pass a secret at step level, not job level**, so it is not in the environment of every step:

  ```yaml
  - name: Publish
    env:
      API_TOKEN: ${{ secrets.API_TOKEN }}
    run: ./publish.sh
  ```

- **Do not use `secrets: inherit`** when calling a reusable workflow. It passes every secret the
  caller can see, including ones the callee has no business holding. Name each secret:

  ```yaml
  jobs:
    call:
      uses: octo-org/shared/.github/workflows/publish.yml@<sha>
      secrets:
        REGISTRY_TOKEN: ${{ secrets.REGISTRY_TOKEN }}
  ```

- **Store one value per secret.** A JSON or YAML blob containing a credential is unlikely to be
  redacted from logs, because masking matches whole values.
- **Register derived values.** A base64-encoded or URL-encoded form of a secret is not masked
  automatically. Emit `::add-mask::VALUE` for it, and for any sensitive value that did not come from
  the secrets store. Masking is best-effort, not a guarantee.
- **Never write a secret to a file the workflow later uploads**, including an artifact, a coverage
  report, or a core dump.
- **Keep user and system detail out of logs and artifacts too.** Workflow logs are public on a
  public repository, and an uploaded artifact outlives the run. Runner paths
  (`/home/runner/work/...`), `whoami`/`hostname` output, `env` dumps, and full tracebacks are not
  secrets, so nothing masks them, but on a self-hosted runner they describe your infrastructure and
  the account the job runs as. Do not `set -x` or dump the environment as a debugging habit, and
  normalize captured output before a step commits it back to the repository.
- **Rotate on a schedule and after any incident.** Audit `org.update_actions_secret` and related
  events in the organization audit log.

## Environments and deployment gates

An environment is the control that turns a workflow into a reviewed deployment:

```yaml
jobs:
  deploy:
    environment:
      name: production
      url: ${{ steps.deploy.outputs.url }}
    permissions:
      id-token: write
      contents: read
```

Configure on the environment itself: required reviewers, a wait timer, and a deployment branch rule
limiting it to the release branch or tag pattern. These are enforced by GitHub, not by the workflow
file, so a workflow change alone cannot bypass them.

## OIDC instead of stored credentials

OIDC removes the long-lived cloud credential entirely. The workflow requests a short-lived token
that the cloud provider validates against a trust policy.

```yaml
jobs:
  deploy:
    permissions:
      id-token: write
      contents: read
    steps:
      - name: Authenticate to AWS
        uses: aws-actions/configure-aws-credentials@<full-sha> # v5.x
        with:
          role-to-assume: arn:aws:iam::123456789012:role/github-deploy
          aws-region: eu-north-1
```

The security of this depends entirely on the trust condition configured on the cloud side. Claims
worth constraining:

| Claim | Meaning | Example |
|---|---|---|
| `sub` | Composite subject | `repo:octo-org/octo-repo:environment:production` |
| `job_workflow_ref` | The exact workflow file and ref that ran | `octo-org/octo-repo/.github/workflows/deploy.yml@refs/heads/main` |
| `repository` | Repository identifier | `octo-org/octo-repo` |
| `environment` | Deployment environment | `production` |
| `repository_owner_id` | Numeric owner ID, stable across renames | `12345` |

Rules:

- Match `sub` exactly. A condition such as `repo:octo-org/*` trusts every repository in the
  organization, including one created later by anyone with permission to create repositories.
- Never match on `repo:octo-org/octo-repo:*`, which trusts every branch and every pull request in
  that repository.
- Prefer `job_workflow_ref` when the role is powerful, so only one reviewed workflow file can assume
  it.
- Constrain by `environment` so the trust is tied to the approval gate.
- Use `repository_owner_id` rather than the owner name where the provider supports custom claims,
  because names can be released and reclaimed. AWS does not support custom claims.

The same reasoning applies to package registries offering trusted publishing, such as PyPI, npm, and
crates.io. Use it in place of a stored publish token.

## Checklist

- [ ] Organization or repository default token permission is read-only
- [ ] `permissions: {}` at workflow level, scopes granted per job
- [ ] No job holds a write scope while running untrusted or unreviewed code
- [ ] Secrets passed at step level, one value per secret
- [ ] No `secrets: inherit`; each secret named explicitly in reusable workflow calls
- [ ] Sensitive non-secret values masked with `::add-mask::`
- [ ] No environment dumps, `set -x`, or self-hosted runner paths, hostnames, or account names left
      in logs or uploaded artifacts
- [ ] Deployments gated by an environment with required reviewers and a branch rule
- [ ] OIDC trust conditions match `sub` or `job_workflow_ref` exactly, with no wildcard
