<!--
Vendored from https://github.com/konstruktoid/agent-instructions-skills
skills/github/github-organization-governance/references/identity-and-access.md
Upstream ref: v0.1.0
Upstream commit: 994be479cf1d44d5ee69d0334da07e923d8dee2e
Do not edit locally; re-vendor with tools/vendor-agent-standards.sh instead.
-->

# Identity and Access

Read this when configuring authentication requirements, provisioning, teams and roles, service
accounts, access reviews, or offboarding.

## Contents

- Identity is the perimeter
- Two-factor authentication
- Single sign-on
- Automated provisioning and deprovisioning
- Teams and roles
- Custom roles
- Outside collaborators
- Service accounts and machine identities
- Access reviews
- Offboarding
- Checklist

## Identity is the perimeter

Most of the threat model's actors are not attackers who broke a control. They are attackers
holding a credential: a stolen session, a leaked token, an account that was never removed, an app
that outlived its purpose. The controls in this file decide how much a held credential is worth
and how quickly it stops working.

## Two-factor authentication

Require it for every member, and confirm by listing the accounts that do not have it rather than
by reading the setting:

```sh
gh api --paginate "orgs/ORG/members?filter=2fa_disabled&per_page=100" --jq '.[].login'
```

Requiring it removes members who do not comply, which is why the requirement is often deferred.
Announce a date, publish the list, and enforce on the date. Deferring it indefinitely leaves the
weakest accounts in place precisely because they are the least responsive.

Phishing-resistant methods, meaning security keys and passkeys, are worth requiring for owners and
for anyone who can change a control, since the attacks that matter defeat one-time codes.

## Single sign-on

Enforcing single sign-on puts membership under the identity provider, so a suspended employee
loses access without a GitHub action. Two details decide whether the enforcement holds:

- Sessions and tokens created before enforcement need authorization against the identity provider,
  and unauthorized ones must be revoked rather than left.
- Accounts that bypass single sign-on, such as owners kept for recovery, are the exception list.
  Keep it short, name each account's purpose, and review it.

## Automated provisioning and deprovisioning

Provisioning from the identity provider means a person's access is a consequence of their record
there. The property that matters is the reverse one: removal from the directory removes the
access, without anyone remembering.

Test the removal path rather than the creation path. Creation failures are noticed immediately;
removal failures are noticed at the next audit, or never.

## Teams and roles

- Map teams to how the organization works, and grant repository access to teams only.
- Nest teams where access is genuinely hierarchical, and keep the nesting shallow enough that a
  reviewer can tell what a grant implies.
- Give every team an owner and a stated purpose. A team with neither accumulates members.
- Keep the owner role scarce. Owners can change every control in this file, and the audit log is
  the only thing that records it.

## Custom roles

A custom repository role grants a specific set of permissions rather than the next role up. The
case worth using it for is the recurring one: someone needs a single administrative capability,
such as editing repository rules or managing webhooks, and the alternative is `admin`.

Define the role once, name it for the capability rather than the team, and review its holders on
the access review cadence.

## Outside collaborators

An outside collaborator is outside the identity provider, so none of the automation above applies
to them. List them, give each an owner and an expiry, and prefer a fork and a pull request where
the work allows it:

```sh
gh api --paginate "orgs/ORG/outside_collaborators?per_page=100" --jq '.[].login'
```

## Service accounts and machine identities

A service account with a password in a shared vault produces an audit trail naming a role rather
than a person. Replace it where the platform allows:

- A GitHub App for automation acting on repositories, scoped to selected repositories.
- OIDC for a workload authenticating to a cloud provider or a registry.
- A fine-grained token with an expiry where neither is possible, owned by a named person.

Where a service account must remain, require two-factor on it, restrict its access to the
repositories it needs, and record who holds its credential.

## Access reviews

A review that confirms everything is a review that has stopped working. Make each one produce a
decision per grant:

- Set a cadence per population: members and teams periodically, owners and administrators more
  often, outside collaborators and tokens at least as often as their expiry.
- Give the reviewer the data rather than asking them to gather it: the grant, its age, its last
  use where the platform reports it, and its owner.
- Record the outcome, including what was revoked. The list of revocations is the evidence that the
  review happened.
- Revoke by default when nobody claims a grant. An unclaimed grant with a claimed owner is the
  normal case for the access that outlives its purpose.

## Offboarding

Removal from the identity provider is the start rather than the end:

- Confirm the account lost organization membership and every repository grant.
- Revoke tokens, SSH keys, and authorized apps tied to the account.
- Reassign or remove the machine identities the person owned, since an unowned automation
  credential is the one nobody will notice.
- Transfer ownership of repositories held in a personal account that the organization depends on.

## Checklist

- [ ] Two-factor required, with the non-compliant accounts listed rather than assumed empty
- [ ] Phishing-resistant methods required for owners and for anyone who can change a control
- [ ] Single sign-on enforced, with pre-existing sessions and tokens reauthorized or revoked
- [ ] The bypass account list is short, named, purposeful, and reviewed
- [ ] Provisioning automated, and the removal path tested rather than assumed
- [ ] Repository access granted through teams only, with every team owned and purposeful
- [ ] Owner role scarce, and its holders reviewed most often
- [ ] Custom roles used in place of `admin` where a single capability is needed
- [ ] Outside collaborators listed, each with an owner and an expiry
- [ ] Machine identities are apps or OIDC where possible, and every remaining token is
      fine-grained, expiring, and owned
- [ ] Access reviews produce a decision per grant and record what was revoked
- [ ] Offboarding covers tokens, keys, authorized apps, owned automation, and personal-account
      repositories the organization depends on
