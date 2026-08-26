<!--
Vendored from https://github.com/konstruktoid/agent-instructions-skills
skills/github/github-repository-security/references/access-and-secrets.md
Upstream ref: v0.1.0
Upstream commit: 994be479cf1d44d5ee69d0334da07e923d8dee2e
Do not edit locally; re-vendor with tools/vendor-agent-standards.sh instead.
-->

# Access, Environments, and Secrets

Read this when granting or reviewing access to a repository, configuring environments, scoping
secrets, or responding to a credential that has been exposed.

## Contents

- Roles and least privilege
- Teams rather than individuals
- Outside collaborators
- Machine identities
- Deploy keys
- Environments
- Secret scope
- Secret scanning and push protection
- Responding to a leaked credential
- Repository visibility
- Checklist

## Roles and least privilege

GitHub repository roles are cumulative, and each one grants everything the one below it does:

| Role | Grants | Appropriate for |
|---|---|---|
| `read` | Clone, pull, open issues and pull requests | Everyone who needs the code |
| `triage` | Manage issues and pull requests without write access | Issue triage without commit rights |
| `write` | Push to unprotected branches, manage some settings | Contributors |
| `maintain` | Repository settings short of destructive ones | People who run the repository |
| `admin` | Everything, including deletion, visibility, and rulesets | Administration as the job |

The role that grants the ability to change a control is the one to ration. `admin` on a repository
includes the ability to edit or delete its rulesets, so a control that must survive a compromised
account belongs at the organization level rather than in the repository.

## Teams rather than individuals

Grant access to a team and manage membership in the team. A direct collaborator grant produces
access that no membership review will find, because it is attached to the repository rather than
to a group anyone reviews.

```sh
gh api --paginate "repos/OWNER/REPO/collaborators?affiliation=direct&per_page=100" \
  --jq '.[] | {login, role_name}'
gh api --paginate "repos/OWNER/REPO/teams?per_page=100" --jq '.[] | {slug, name, permission}'
```

`affiliation=direct` is what makes the first command an audit of direct grants. The default,
`affiliation=all`, returns everyone who can reach the repository through a team or through the
organization as well, and `role_name` reports the effective permission without saying where it
came from, so the two are indistinguishable in the output. Do not filter `read` out either: a
direct `read` grant is still a grant no membership review will find, which is the whole finding.

The second command returns the teams and the permission each one holds, not the people in them,
so the two outputs cannot be compared as they stand. Take the `slug` of each team with a
permission at least equal to the direct grant and read its membership:

```sh
gh api --paginate "orgs/ORG/teams/TEAM_SLUG/members?per_page=100" \
  --jq '.[] | {login, role, inherited}'
```

`role` and `inherited` appear only where the organization has the feature enabled. Where they are
absent, read one membership at a time with `gh api orgs/ORG/teams/TEAM_SLUG/memberships/LOGIN`,
which returns `role` and `state` in every organization. A `state` of `pending` is an invitation
rather than access, and `inherited` set to `true` means the person is in a child team rather than
this one, which still grants the repository permission but is administered elsewhere.

Where the person already holds equivalent access through a team, the direct grant is redundant and
the fix is to remove it. Where no team gives that access, add the person to a team that does, or
create one, before removing the grant. Removing first leaves the person without access they were
using. An outside collaborator is not a candidate for either move: the account is outside the
organization and cannot hold team membership, so route it through the owner-and-expiry process
below instead.

## Outside collaborators

An outside collaborator is an account outside the organization with access to a repository. The
threat model treats them as a distinct actor for a reason: the organization's identity provider
does not govern the account, so offboarding at the employer does not remove the access.

- Prefer a fork and a pull request over a collaborator grant.
- Where a grant is necessary, make it `read` or `triage`, give it an owner and an expiry, and
  record both.
- Re-approve rather than renew silently. An annual review that confirms everything is a review
  that has stopped working.

## Machine identities

What the automation authenticates to decides what it should present, so OIDC and the four
credentials below answer different questions and do not belong in one ranking.

Use OIDC where a workflow authenticates to something outside GitHub, such as a cloud provider, a
registry, or a package index. The workload exchanges a short-lived GitHub-issued token for access
at the far end, and no credential is stored on either side. It authenticates nothing to GitHub
itself, so it replaces a stored cloud credential rather than any of the four below.

For access to GitHub, automation authenticates in one of four ways, in descending order of
preference:

1. **The workflow's `GITHUB_TOKEN`**, with `permissions` narrowed to what the job needs. It is
   minted per job, expires when the job ends, and reaches only the one repository.
2. **A GitHub App**, scoped to the permissions the automation needs and installed on named
   repositories, where the work crosses repositories or outlives a run. The token is short-lived
   and the app is visible in the organization's installations.
3. **A fine-grained personal access token**, scoped to named repositories and permissions, with an
   expiry, owned by a named person who answers for it.
4. **A classic personal access token**, which is scoped to everything the owner can reach. Treat
   an existing one as a finding rather than a configuration.

Every machine identity needs an owner, a purpose, and a review date. An identity nobody can
explain is one nobody will notice being used.

## Deploy keys

A deploy key is an SSH key granting access to one repository. Read-only is the default worth
holding to, since a write-capable deploy key is a credential that can push to the repository and
carries no user identity in the audit trail.

```sh
gh api --paginate "repos/OWNER/REPO/keys?per_page=100" --jq '.[] |
  {id, title, read_only, created_at, last_used}'
```

A key with a title nobody recognizes, or one that has never been used, is a finding. Removing it
is reversible; leaving it is not.

## Environments

An environment is where a deployment credential belongs, because it adds the two controls a
repository secret has no equivalent of:

- **Required reviewers**, which stop a job from proceeding until a named person or team approves.
- **Deployment branch and tag policies**, which stop a job on an arbitrary branch from claiming
  the environment's secrets.

Add a wait timer where an incorrect deployment is expensive to reverse, and restrict the
environment to the branch or tag pattern that releases are cut from.

## Secret scope

Store a secret at the narrowest scope that works:

- An environment secret, reachable only by a job that names the environment and passes its
  protection rules.
- A repository secret, reachable by any workflow in the repository, including one added by a
  contributor with write access.
- An organization secret, which needs an explicit repository list rather than being available to
  all repositories.

A secret reachable by a job that runs untrusted code is exposed, whatever its scope. Keep the job
that builds or tests contributed code separate from the job that holds a credential.

## Secret scanning and push protection

Secret scanning finds credentials already committed. Push protection stops the commit that would
add one. Both are worth enabling, and push protection is the one that changes outcomes, since it
acts before the credential is exposed.

- Enable both, and confirm through a read that both are enabled rather than trusting the update.
- Where a bypass is available to committers, review the bypass events. A bypass is a credential
  that reached the repository with a reason attached.
- Some scanning options are configurable only through the web interface. Where an update is
  accepted and a read shows the field unchanged, report that rather than retrying.

## Responding to a leaked credential

Order matters, and the common instinct is the wrong one. Removing the commit changes what a reader
sees without changing what the credential can do.

1. **Rotate or revoke the credential.** Until this is done, nothing else has reduced the risk.
2. **Determine exposure.** How long it was reachable, whether the repository is public, and
   whether the credential was used in a way the provider's logs can show.
3. **Record the incident**, including the rotation time, in whatever place the organization keeps
   that record.
4. **Then clean the history**, if it is still worth doing. Rewriting history invalidates every
   clone and every commit reference, so it is a decision with its own cost.
5. **Close the path.** Add push protection if it was absent, and add the pattern to the scanner if
   it is a credential format the scanner does not know.

## Repository visibility

Making a private repository public publishes every commit in its history, every branch, and every
issue and pull request, not the current tree. Before proposing the change:

- Scan the full history for credentials, not just the working tree.
- Check for internal hostnames, addresses, customer names, and identifiers in commit messages,
  issue titles, and code comments.
- Confirm that anything found is rotated rather than only removed.
- State that the change is irreversible in effect: history that has been public may have been
  cloned, and making the repository private again does not retract it.

## Checklist

- [ ] Every access grant is the smallest role that allows the work
- [ ] Access is held through teams, with any direct collaborator grant migrated or justified
- [ ] Outside collaborators have `read` or `triage`, an owner, and an expiry
- [ ] Every machine identity has an owner, a purpose, and a review date, and uses OIDC or a
      GitHub App where possible
- [ ] No classic personal access token in use where a fine-grained token or an app would work
- [ ] Deploy keys are read-only unless the write need is stated, and none is unrecognized or unused
- [ ] Deployment credentials live in environments with required reviewers and a branch or tag
      policy
- [ ] No secret is reachable by a job that runs untrusted code
- [ ] Secret scanning and push protection confirmed enabled by a read, not by an update response
- [ ] A leaked credential was rotated before the history was touched, and the incident recorded
- [ ] A visibility change was preceded by a history scan and an explicit approval
