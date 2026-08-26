<!--
Vendored from https://github.com/konstruktoid/agent-instructions-skills
skills/github/github-actions-security/references/supply-chain.md
Upstream ref: v0.1.0
Upstream commit: 994be479cf1d44d5ee69d0334da07e923d8dee2e
Do not edit locally; re-vendor with tools/vendor-agent-standards.sh instead.
-->

# Action Supply Chain

Read this when adding, upgrading, or pinning an action or reusable workflow, when configuring
Dependabot or an allowed-actions policy, or when a workflow caches or publishes artifacts.

## Contents

- Pin to a commit SHA
- Pin to the latest release
- Pinning does not stop at `uses:`
- Choosing an action at all
- Dependabot
- Policy enforcement
- Cache and artifact poisoning
- Provenance
- Checklist

## Pin to a commit SHA

`uses: some-org/some-action@v1` resolves a tag, and a tag is a pointer the action's maintainer, or
anyone who compromises their account, can move. The `tj-actions/changed-files` compromise in March
2025 worked exactly this way: existing tags were repointed at a malicious commit, and thousands of
repositories consumed it on their next run without changing a line.

```yaml
- uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
```

- Use the full 40-character SHA. An abbreviated SHA is rejected.
- Keep the version in a trailing comment. Without it the reference is unreadable, and Dependabot
  uses the comment to propose updates.
- Pin the SHA of a commit that a release tag pointed to, not an arbitrary commit from the default
  branch.
- Verify the commit belongs to the repository named in `uses:`. A SHA from a fork can be reachable
  through the upstream repository's object store, so a reference that looks upstream can resolve to
  fork code.

Actions published by GitHub itself (`actions/*`, `github/*`) carry lower risk than third-party ones,
but the reasoning is the same and the pinning rule is not worth making conditional.

Immutable releases prevent a published release's tag and assets from being changed, and generate a
signed attestation for each asset. They are generally available and configurable per repository or
per organization, applying to releases published after the setting is turned on. They narrow the
window but do not close it: the protection covers the release's own tag, so the moving major or
minor tags most workflows reference, `@v1` and `@v1.2`, stay mutable because they are separate tags
that no release owns, and a repository that has not enabled the setting is unaffected. SHA pinning
remains the guidance.

## Pin to the latest release

Pinning and currency are separate requirements, and satisfying only the first produces the worst
outcome: an action frozen at a version whose known vulnerabilities are never fixed, with the pin
providing the appearance of control. A SHA pin is not a reason to stay on an old version; it is the
reason updating has to be deliberate.

Whenever a `uses:` line is added or touched, resolve the action's current release rather than
carrying the version already in the file forward:

```sh
gh api repos/OWNER/REPO/releases/latest --jq .tag_name
gh api repos/OWNER/REPO/commits/<tag> --jq .sha
```

- Do not treat the version already in the workflow, or a version recalled from memory, as current.
  Look it up during the change.
- `releases/latest` excludes drafts and prereleases. Where a repository publishes tags without
  releases, take the newest tag from `gh api repos/OWNER/REPO/tags` and confirm against the
  repository that it is a release rather than a build or nightly marker.
- Read the release notes across every version being skipped, not only the newest. A major-version
  bump changes the runtime, inputs, or defaults often enough that it needs checking, and the
  reasoning belongs in the pull request description.
- Balance currency against the cooldown below. The newest release and a release old enough to be
  trusted are not always the same version; where they differ, prefer the newest release that clears
  the cooldown, and say which one was chosen.
- Where a version must stay behind, for example because a newer major drops a runner or an input the
  workflow depends on, state the reason in a comment on the line, so it is not read later as neglect.

`pinact run -update` and `ratchet update` re-resolve every pinned reference to the current release,
and are the practical way to apply this across a repository. Both rewrite the files in place, so run
them on a clean tree and review the resulting diff; do not merge it unread. `pinact run -check`
reports what is unpinned without editing anything, which is the form to use in CI or when a
confirmed write is not wanted.

## Pinning does not stop at `uses:`

A pinned action can still fetch mutable content at run time. Before trusting one, read its
`action.yml` and any Dockerfile or shell script it ships, and look for:

- `uses:` references inside a composite action that are themselves on a tag or branch
- `FROM ubuntu:latest` or any unpinned base image in a Docker action
- `curl ... | bash`, `wget`, or a download from a release URL that is not checksum-verified
- `npm install`, `pip install`, or `go install` without a lockfile or a pinned version
- Network calls to a host unrelated to the action's stated purpose

Reusable workflows are third-party dependencies with the same properties. Pin
`uses: org/repo/.github/workflows/x.yml@<sha>` the same way.

## Choosing an action at all

The safest action is the one not added. A three-line `run:` step often replaces a dependency that
brings an unaudited JavaScript bundle into a job holding the repository token.

When one is warranted, check: whether the source is readable and small, whether it is actively
maintained, whether the publisher is a verified creator or a known organization, and whether the
name is a near-match for a more popular action, which is how typosquatting works. Prefer forking a
critical action into the organization and pinning that, so an upstream compromise does not propagate
automatically.

## Dependabot

```yaml
version: 2
updates:
  - package-ecosystem: github-actions
    directory: /
    schedule:
      interval: weekly
    cooldown:
      default-days: 7
```

- Dependabot updates SHA pins and rewrites the version comment, so pinning does not freeze a
  repository at an old version. It is what keeps the latest-release rule true between changes, rather
  than only at the moment someone edits the file, so configure it in any repository that pins.
- A cooldown, `cooldown` for Dependabot or `minimumReleaseAge` for Renovate, delays adoption of a
  brand-new release. Most malicious releases are found and yanked within days, so a delay of about a
  week absorbs a large share of the risk at little cost.
- Security alerts for actions are generated from semantic versions. A SHA-pinned action receives
  version-update pull requests but may not raise an alert, so the update pull requests must actually
  be reviewed and merged rather than left open.
- Review a Dependabot action bump by reading the upstream diff between the two SHAs, not by trusting
  the version number.

## Policy enforcement

Set these at the organization or enterprise level, in Settings, Actions, Policies. They apply to
every repository regardless of what a workflow file says:

- **Allowed actions.** Choose the most restrictive level the organization can work with: enterprise
  actions only; enterprise plus verified creators; or an explicit allowlist. Entries prefixed with
  `!` block an action or version, and the blocklist is evaluated last, overriding any allow rule.
- **Require actions to be pinned to a full-length commit SHA.** Available since August 2025 as a
  checkbox alongside the allowed-actions policy. Workflows referencing an unpinned action fail
  validation. This is the control that makes SHA pinning an invariant rather than a review comment.
- Keep the policy in version control and apply it through the API, so changes are auditable and can
  be reverted quickly during an incident.

## Cache and artifact poisoning

Caches are shared across a repository, and a pull request from a branch can write a cache entry that
a later privileged run on the default branch restores.

- **Disable caching in release and publishing workflows.** A poisoned cache entry restored into a
  release build is a direct path into the published artifact. This includes the implicit caching in
  setup actions, such as `actions/setup-node` with `cache: npm`.
- Do not cache anything derived from a pull request build into a key that a default-branch run will
  match.
- Treat an artifact downloaded from another workflow run as untrusted input. See
  [untrusted-input.md](untrusted-input.md) for the `workflow_run` rules.

## Provenance

For anything published to consumers, generate an attestation in the same job that produced the
artifact:

```yaml
permissions:
  contents: read
  id-token: write
  attestations: write

steps:
  - uses: actions/attest-build-provenance@<full-sha> # v4.x
    with:
      subject-path: dist/*.tar.gz
```

Verify with `gh attestation verify <file> --repo <owner>/<repo>`. An attestation is only meaningful
if consumers verify it, so document the verification command alongside the release.

## Checklist

- [ ] Every `uses:` reference pinned to a full 40-character SHA with a version comment
- [ ] The SHA was resolved from the source repository, not written from memory
- [ ] Each version is the newest release that clears the cooldown, looked up during this change, or
      the reason for staying further behind is stated in a comment on the line
- [ ] Release notes read for every version skipped by an upgrade, with major-version implications
      recorded in the pull request description
- [ ] Composite actions, Docker base images, and install scripts inside a pinned action checked for
      mutable references
- [ ] New actions justified: readable source, maintained, correct name, minimal alternative
      considered
- [ ] Dependabot configured for `github-actions` with a cooldown, and its pull requests reviewed
      against the upstream diff
- [ ] Organization policy restricts allowed actions and requires SHA pinning
- [ ] No caching in release or publishing workflows, including implicit setup-action caches
- [ ] Published artifacts carry a build provenance attestation, with a documented verify command
