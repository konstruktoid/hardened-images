<!--
Vendored from https://github.com/konstruktoid/agent-instructions-skills
instructions/github_governance_instructions.md
Upstream ref: v0.1.0
Upstream commit: 994be479cf1d44d5ee69d0334da07e923d8dee2e
Do not edit locally; re-vendor with tools/vendor-agent-standards.sh instead.
-->

# GitHub Governance Instructions

## Objective

Produce GitHub repository and organization configuration that grants the least access the work
requires, enforces every rule through a mechanism rather than a convention, and leaves evidence a
reviewer can read without asking the person who made the change. These instructions apply whenever
an agent creates or modifies repository settings, organization or enterprise policy, rulesets,
access grants, or the security files a repository ships, in a project that adopts them.

Configuration is code without a compiler. A rule that no mechanism enforces is a statement of
intent, and the audit log records what the mechanism did rather than what the policy said.

Two skills build on this document and are worth applying alongside it:

- For one repository, apply the `github-repository-security` skill
  (`.agents/skills/github-repository-security/SKILL.md`), which covers rulesets, review
  requirements, scanning, access, release protection, and the agent-facing content a repository
  ships, verified by reading the applied state back.
- For settings that span repositories, apply the `github-organization-governance` skill
  (`.agents/skills/github-organization-governance/SKILL.md`), which covers organization and
  enterprise policy, identity, custom properties, ruleset rollout, and audit evidence.

Prose written into a repository under these instructions, including `SECURITY.md`, a policy page,
and a pull request description recording an exception, follows
`instructions/written_language_instructions.md`.

## Scope

These instructions govern platform configuration and the security files that sit beside the code.

Covered:

- Repository settings, rulesets, branch and tag protection, and merge requirements.
- Access: teams, roles, outside collaborators, deploy keys, GitHub Apps, and tokens.
- Secret scanning, code scanning, dependency alerts, and the response to what they report.
- `SECURITY.md`, `CODEOWNERS`, private vulnerability reporting, and advisories.
- Organization and enterprise policy, custom properties, audit logging, and access reviews.
- Release and tag protection, and the identity a publishing job authenticates with.

Not covered:

- The content of workflow files, which `.agents/skills/github-actions-security/SKILL.md` covers.
- Application code, which the language-specific instructions and skills cover.
- Provisioning of infrastructure outside GitHub, including the cloud roles a workflow assumes.

## The Repository Baseline

Every repository, whatever else the change touches:

- The default branch is protected by a ruleset in active mode: force pushes blocked, deletion
  blocked, a pull request required before merging, and the required status checks named rather
  than assumed, each bound to the app that reports it with `integration_id` so the check cannot
  be satisfied by anyone with write access.
- Review is enforced rather than requested. At least one approving review, stale approvals
  dismissed on a new push, approval of the most recent reviewable push, and review from code
  owners on the paths that carry risk.
- `CODEOWNERS` covers `.github/workflows/`, dependency manifests and lockfiles, release
  configuration, and any agent-facing content the repository ships, such as skills, hooks, or
  MCP server definitions.
- Secret scanning and push protection are enabled, with a response that rotates the credential
  before it removes the commit.
- Dependency alerts are enabled, a lockfile is committed, and version updates run on a schedule
  with a cooldown that keeps a release from being adopted the hour it is published.
- Code scanning runs on pull requests, with a severity threshold that blocks the merge rather than
  filing an advisory nobody reads.
- `SECURITY.md` names a private reporting channel and a response time, and private vulnerability
  reporting is enabled so the channel exists.
- The default workflow token is read-only, and the actions a workflow may call are restricted to
  an allowlist.
- Releases are published from a protected tag by a workflow that authenticates with OIDC, not from
  a moving branch and not with a long-lived token held as a secret.
- Deploy keys are read-only, or the write access is stated and time-bounded.
- A repository that is no longer maintained is archived rather than deleted, so its history stays
  auditable.

## The Organization Baseline

- Two-factor authentication is required for every member, and single sign-on is enforced where the
  plan supports it.
- Membership and access are provisioned and deprovisioned automatically, so an account that leaves
  the identity provider loses repository access without a manual step.
- The base permission is `none` or `read`. Access is granted through teams. A direct collaborator
  grant is an exception that carries a reason and an expiry.
- Members cannot create public repositories, change repository visibility, delete a repository, or
  transfer one out. Those actions belong to owners and appear in the audit log.
- Controls that must not be editable by a repository administrator are set as organization
  rulesets. A repository ruleset may add to them and may not weaken them.
- Every repository carries custom properties that classify it: data classification, business
  criticality, owning team, and the compliance frameworks that apply. Rulesets target those
  properties rather than a list of repository names, so a new repository inherits its tier on
  creation.
- Automation authenticates as a GitHub App with scoped permissions rather than as a personal
  access token on a human account. Where a token is unavoidable, it is fine-grained, expiring,
  approved, and recorded.
- Self-hosted runners are placed in runner groups scoped to named repositories, and never made
  available to a public repository.
- Audit log events are streamed to storage the organization controls, with retention at least as
  long as the longest applicable framework requires.
- Access is reviewed on a stated cadence, and the review records what was revoked rather than only
  that it happened.

## Access and Identity

### Required

- Grant the smallest role that allows the work: `read` by default, `write` for contributors,
  `maintain` for people who run the repository, `admin` only where administration is the job.
- Grant access to a team, and manage membership in the team.
- Give every non-human identity an owner, a purpose, and a review date.
- Time-bound outside collaborator access and re-approve it rather than letting it lapse into
  permanence.
- Treat the ability to change a control as a privilege separate from the ability to use it. A
  break-glass bypass belongs to a named role with a written procedure, and every use is reviewed.

### Avoid

- A shared account with a password in a vault, which produces an audit trail naming nobody.
- A personal access token with organization-wide scope used by a pipeline.
- An access grant with no expiry made for a task that has one.
- Widening a role to unblock a single action, in place of performing that action through the
  mechanism that authorizes it.

## Secrets and Tokens

### Required

- Store a secret in the narrowest scope that works: an environment secret over a repository
  secret, a repository secret over an organization secret.
- Gate an environment that holds a deployment credential behind required reviewers.
- Prefer short-lived credentials issued through OIDC to any stored credential.
- Rotate a credential that has been exposed before removing the exposure, and record the rotation.
- Keep the identity a release publishes with distinct from the identity that builds and tests
  untrusted code.

### Avoid

- Making an organization secret available to all repositories when a subset needs it.
- Reusing one credential across environments, which makes a compromise unbounded.
- Removing a leaked secret from history as the first action, which changes what a reader sees
  without changing what the credential can do.

## Change Management and Evidence

### Required

- Read the current state before changing it, and state what the change alters.
- Obtain explicit approval before applying an outward-facing or irreversible change: repository
  visibility, transfer, deletion, ruleset deletion, a widened base permission, or a new bypass
  actor.
- Roll enforcement out in evaluate mode first where the mechanism supports it, and read the
  reported violations before switching to active.
- Read the state back after every write. An accepted API request is not an applied setting: some
  fields are accepted and ignored, and only a read shows which.
- Record, for every control, the mechanism that enforces it, the read that shows its current
  state, the audit event that records a change to it, and the owner who answers for it.
- Give every exception a reason, an owner, and an expiry, in a place a reviewer will find without
  being told where to look.

### Avoid

- Disabling a control to make a check pass.
- A control whose only evidence is that somebody remembers configuring it.
- A rollout that enables many restrictive rules at once, which makes the friction impossible to
  attribute to a rule.
- An exception granted verbally, or one whose expiry is the next audit.

## Compliance Mapping

A framework requires an outcome. The configuration is the control, and the audit log is the
evidence that the control held. Map each requirement to a mechanism that produces evidence without
anyone collecting it.

| Requirement | Mechanism | Evidence |
|---|---|---|
| Changes are reviewed before release | Ruleset requiring a pull request and approvals | Pull request record, ruleset history |
| Authors cannot approve their own change | Required approvals with code owner review | Review record on each merge |
| Only authorized people change production code | Team-based access, restricted bypass actors | Access review record, bypass events in the audit log |
| Credentials are managed and rotated | Environment secrets, OIDC, secret scanning | Rotation record, secret scanning alert history |
| Vulnerabilities are found and remediated | Code scanning, dependency alerts, stated thresholds | Alert history with time to remediation |
| Configuration changes are traceable | Organization rulesets, audit log streaming | Audit log entries retained for the required period |

State which framework a control is claimed against. A control that satisfies an internal standard
and no external one is still worth having, and saying so keeps the mapping honest.

## Quality Checklist

Before finalizing a configuration change, verify that:

- The current state was read before the change, and read back after it.
- The applied state matches the intent, field by field, rather than matching the request that was
  accepted.
- Every rule that the change relies on is enforced by a mechanism, and the mechanism is named.
- No control was weakened to make something pass, and no bypass actor was added without a stated
  reason and an owner.
- An outward-facing or irreversible change was approved explicitly before it was applied.
- Access granted is the smallest role that allows the work, held through a team, with an expiry
  where the need has one.
- Every credential involved is scoped to the narrowest level that works, and short-lived where
  the platform can issue one.
- The change leaves evidence: an audit event, a ruleset history entry, or a record naming the
  owner and the expiry of an exception.
- Any exception carries a reason, an owner, and an expiry.
- No example in the resulting documentation contains a real username, hostname, internal address,
  token, or organization-specific identifier that is not required to understand it.
