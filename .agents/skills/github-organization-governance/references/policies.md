<!--
Vendored from https://github.com/konstruktoid/agent-instructions-skills
skills/github/github-organization-governance/references/policies.md
Upstream ref: v0.1.0
Upstream commit: 994be479cf1d44d5ee69d0334da07e923d8dee2e
Do not edit locally; re-vendor with tools/vendor-agent-standards.sh instead.
-->

# Organization Policies

Read this when setting member privileges, base permissions, the actions and runner policy, or the
rules that decide which apps and tokens can act on repositories.

## Contents

- Where a policy belongs
- Member privileges
- Base permission
- Repository creation, visibility, and deletion
- Forking policy
- Actions policy
- Runner groups
- GitHub Apps
- OAuth apps
- Personal access token policy
- Checklist

## Where a policy belongs

The same rule can be set at three levels, and the level decides who can undo it:

- **Enterprise**: applies to every organization, and an organization owner cannot relax it. The
  place for controls that must survive an organization owner.
- **Organization**: applies to every repository, and a repository administrator cannot relax it.
  The place for most security policy.
- **Repository**: local, and editable by anyone with `admin` on that repository. The place for
  controls that are the team's own choice.

Set a control one level above the role it is meant to constrain. A control set at the same level
as the people it governs is a suggestion.

## Member privileges

Every privilege granted to all members is granted to any account that becomes a member, including
a compromised one. The defaults worth holding:

- Members cannot create public repositories.
- Members cannot change repository visibility.
- Members cannot delete or transfer repositories.
- Members cannot invite outside collaborators without approval.

Where a privilege is granted broadly for convenience, name what it replaces. Restricting
repository creation without providing a fast path to a new repository produces work in personal
accounts, which is worse than the privilege.

## Base permission

The base permission is the access every member has to every repository. Set it to `none` or
`read`.

`write` as a base permission means every member can push to every repository the rulesets do not
protect, and the audit trail of who could have made a change becomes the member list. Where the
organization currently sets `write`, treat lowering it as a migration: find the teams that rely on
implicit access, grant it explicitly, then lower the base.

## Repository creation, visibility, and deletion

Visibility changes and deletions are the actions from the repository threat model with the largest
consequences and the least recovery. Restrict them to owners, and make sure they generate audit
events that are alerted on rather than merely recorded.

Repository creation is different: restricting it is defensible, but the reason to control it is
classification rather than scarcity. A repository created without its custom properties is a
repository outside every property-targeted ruleset. Where the platform supports required
properties at creation, use them; otherwise, run a scheduled check for unclassified repositories.

## Forking policy

Forking a private repository moves the code into a namespace the organization's rulesets do not
govern. Disable forking of private repositories by default, and allow it only where a named case
needs it. A fork made for convenience is a copy that stays behind and keeps its access.

## Actions policy

The organization-level actions policy is the control that decides what code every workflow may
call:

```sh
gh api orgs/ORG/actions/permissions
gh api orgs/ORG/actions/permissions/selected-actions
gh api orgs/ORG/actions/permissions/workflow
```

- Restrict to selected actions: those created by GitHub, those verified by a partner where that
  suits the risk appetite, and an explicit allowlist of everything else. Adding an action then
  becomes a policy change with a reviewer, which is the point.
- Require actions to be pinned to a SHA where the policy supports it, which closes the gap between
  an allowlisted repository and the code it serves today.
- Set the default workflow token to read-only for the organization, so a repository has to grant
  permissions deliberately.
- Require approval for workflows from all outside contributors rather than only first-time ones. A
  contributor who has been approved once is approved from then on.

## Runner groups

A self-hosted runner is a machine that runs whatever a workflow tells it to, with whatever access
that machine has:

- Place runners in groups, and scope each group to named repositories rather than to all.
- Never make a runner group available to a public repository. No configuration makes that safe,
  because anyone can open a pull request.
- Keep runners ephemeral, so a job cannot leave state for the next one.
- Separate the group that builds contributed code from the group with access to anything else.

## GitHub Apps

An app installation is a standing grant of permissions that survives the person who installed it:

```sh
gh api --paginate "orgs/ORG/installations?per_page=100" --jq '.installations[] |
  {app_slug, repository_selection, permissions}'
```

- Review installations on the same cadence as human access.
- Prefer selected repositories over all repositories, and remove permissions the app does not use.
- Record who requested each installation and why. An app nobody can explain is one to remove.
- Restrict who may install an app to owners, so an installation is a decision rather than a click.

## OAuth apps

An OAuth app acts as a user, with that user's access, and its authorization is not visible in the
repository. Restrict third-party application access at the organization level and approve
individual apps, rather than allowing every member to authorize whatever they sign in to.

## Personal access token policy

- Restrict access by fine-grained tokens to those the organization approves, so a token that can
  read a private repository is a decision somebody made.
- Deny access by classic tokens where the plan supports it. A classic token's scope is everything
  its owner can reach, which no review can narrow.
- Require an expiry, and treat a request to extend one as the moment to ask whether an app would
  do the job.
- Review approved tokens and pending requests on the access review cadence. Each is a separate
  endpoint, and a review that reads only the first says nothing about the access waiting on a
  decision:

  ```sh
  # Approved tokens holding access now.
  gh api --paginate "orgs/ORG/personal-access-tokens?per_page=100" --jq '.[] |
    {owner: .owner.login, repository_selection, token_expired, token_expires_at}'

  # Requests awaiting approval or denial.
  gh api --paginate "orgs/ORG/personal-access-token-requests?per_page=100" --jq '.[] |
    {owner: .owner.login, repository_selection, reason, created_at}'
  ```

  Only a GitHub App can call either endpoint. An owner's own credential, whether a personal
  access token or an OAuth token, is refused, so both commands run as an installation holding
  the organization permission for personal access tokens. An organization that has no such app
  reviews these two lists in the settings interface, and the absence of an app is itself the
  finding: the token policy has no automated evidence behind it.

## Checklist

- [ ] Each control set one level above the role it constrains
- [ ] Members cannot create public repositories, change visibility, delete, or transfer
- [ ] Base permission is `none` or `read`, with implicit access replaced by explicit team grants
- [ ] Forking of private repositories disabled except for named cases
- [ ] Actions restricted to an allowlist, with SHA pinning required where supported
- [ ] Default workflow token read-only across the organization
- [ ] Approval required for workflows from all outside contributors
- [ ] Runner groups scoped to named repositories, ephemeral, and never reachable from a public
      repository
- [ ] App installations reviewed, scoped to selected repositories, with unused permissions removed
- [ ] Third-party OAuth application access restricted and approved individually
- [ ] Fine-grained tokens approved and expiring, classic tokens denied where the plan allows
- [ ] Approved tokens and pending requests both reviewed, each from its own endpoint
- [ ] Repositories created without classifying properties detected by a scheduled check
