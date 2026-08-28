<!--
Vendored from https://github.com/konstruktoid/agent-instructions-skills
skills/github/github-repository-security/references/rulesets.md
Upstream ref: v0.1.0
Upstream commit: 994be479cf1d44d5ee69d0334da07e923d8dee2e
Do not edit locally; re-vendor with tools/vendor-agent-standards.sh instead.
-->

# Rulesets and Branch Protection

Read this when creating or changing a ruleset, branch protection, tag protection, required status
checks, merge requirements, or a bypass grant.

## Contents

- Why rulesets rather than branch protection
- Anatomy of a ruleset
- The baseline tier
- The production tier
- The regulated tier
- Push rules
- Tag rules
- Bypass and break-glass
- Evaluate mode and rollout
- Migrating from branch protection
- Troubleshooting a rule that blocks legitimate work
- Checklist

## Why rulesets rather than branch protection

Branch protection is a per-branch setting owned by the repository. A ruleset is a named policy
object that targets branches or tags by pattern, can be defined at the organization level, layers
with other rulesets, keeps a change history, and on the plans that offer it can run in evaluate
mode before it blocks anything. Layering is the property that matters for governance: an
organization ruleset and a repository ruleset both apply, and the result is the union of their
restrictions. A repository administrator can add to an organization ruleset and cannot subtract
from it.

Prefer a ruleset for every new control. Migrate an existing branch protection rule when the branch
it protects is touched for another reason, rather than leaving two overlapping mechanisms in place
where a reader cannot tell which one produced a block.

## Anatomy of a ruleset

A ruleset has four parts, and a review that skips any of them is incomplete:

- **Target**: `branch`, `tag`, or `push`, plus the patterns it applies to. `~DEFAULT_BRANCH` and
  `~ALL` are the two named targets worth knowing, since a pattern written as `main` misses a
  repository whose default branch is named something else.
- **Enforcement**: `active`, `evaluate`, or `disabled`. Evaluate reports what would have been
  blocked without blocking it. A ruleset left in evaluate is a measurement, not a control.
- **Rules**: the individual requirements, listed below by tier.
- **Bypass actors**: the roles, teams, or apps that may ignore the rules, and whether they may do
  so always or only for a pull request.

Keep the definition in a JSON file in the repository and apply it from there, so the policy is
reviewable and reproducible:

```sh
gh api --method POST repos/OWNER/REPO/rulesets --input ruleset.json
gh api repos/OWNER/REPO/rulesets/RULESET_ID --jq '{enforcement, rules, bypass_actors}'
```

Ruleset history is retained, and an earlier iteration can be restored. That history is the
evidence that a control was in force on a given date, so a ruleset deleted and recreated loses
what an audit asks for. Update rather than replace.

## The baseline tier

Applies to every repository, including a proof of concept. The intent is a floor that costs a
single developer almost nothing:

- Block force pushes on the default branch. Force pushes overwrite history, break commit
  references other systems depend on, and destroy the record a review is evidenced by.
- Block deletion of the default branch.
- Require a pull request before merging, even where no approval is required, so every change has a
  reviewable record and automated checks have somewhere to report.
- Require the status checks that already run, named explicitly, and bind each one to the app that
  reports it with `integration_id`. A check that is not named is not required, whatever the
  workflow does; a check named without an `integration_id` accepts a status from any person or
  app with write access, so it records agreement rather than requiring a passing run. Re-read the
  ruleset after applying it and confirm each check kept its `integration_id`, since the interface
  falls back to "any source" without saying so.

## The production tier

Applies where the repository supports a running service or ships to users. Add:

- Required approvals of at least one, so nobody merges unreviewed code.
- Dismiss stale approvals when new commits are pushed, so an approval covers the code that merges
  rather than the code that was reviewed.
- Require review from code owners, which puts the change in front of the people accountable for
  the paths it touches.
- Require approval of the most recent reviewable push, which stops a reviewer who pushed a
  suggestion from approving their own change.
- Require conversation resolution before merging.
- Require code scanning results with a severity threshold, tuned so the block is credible rather
  than routinely bypassed.
- Require the branch to be up to date before merging, where the test suite is sensitive to
  interleaved changes.

## The regulated tier

Applies where the repository holds regulated data or supports a system in scope for a framework
such as SOC 2, PCI DSS, HIPAA, or FedRAMP. Add:

- Require signed commits, once signing is set up widely enough that the rule does not simply
  generate exceptions.
- Require deployments to succeed before merging, through the required status check for the
  environment.
- Restrict commit metadata, for example requiring an author email in the organization's domain, so
  a change cannot be attributed to an account outside the identity provider.
- Additional required checks: infrastructure-as-code scanning, dependency review with a license
  policy, and a check that reports attempts to circumvent secret scanning.

## Push rules

Push rules apply before a commit reaches the repository rather than at merge time, which makes
them the only control that stops a file from ever landing. They are also the rules most likely to
break automation, so pilot them:

- Restrict file paths, for the paths a change must never take without review: security policy
  configuration, release configuration, and any file that changes what the repository trusts.
- Restrict file extensions, to keep binaries and archives out of a source repository.
- Restrict file size, which prevents both repository bloat and a large-file exfiltration path.

## Tag rules

A release tag is a supply chain artifact. Protect the tag pattern releases are cut from:

- Block deletion and force update of tags matching the release pattern, so a published version
  cannot be repointed at different code.
- Restrict who may create a tag matching that pattern to the roles that publish releases.

Tag protection through the older per-repository setting is superseded by tag rulesets. Where both
exist, consolidate on the ruleset and say so in the change.

## Bypass and break-glass

Every bypass actor is a documented hole in the control. Grant one only where its absence creates
an impossible merge, such as a single-maintainer repository with a review requirement, or a
required check that cannot run during an incident.

- Prefer a role or a team over a named person, so the grant survives an individual leaving.
- Prefer `pull_request` scope over `always`, which keeps the record of what was merged.
- Write the procedure down: who may use it, under what conditions, and what they record afterwards.
- Review bypass events on a stated cadence. A recurring bypass is a rule that needs changing, not
  a person who needs reminding.

## Evaluate mode and rollout

Evaluate mode requires GitHub Enterprise Cloud, or GitHub Enterprise Server after 3.10. On Free,
Pro, and Team the enforcement status does not exist, so check the plan before planning a rollout
around it. Where it is unavailable, run the first three stages below in active mode against a
target narrow enough to absorb a mistake, and widen the targeting rather than changing the
enforcement.

Enforcement that arrives without warning gets bypassed or reverted. Roll a new control out in
four stages, and let the reported violations decide when to advance:

1. **Test.** Evaluate mode on a repository nobody depends on, to confirm the rule matches what it
   was meant to match.
2. **Pilot.** Evaluate mode on a few named repositories with willing teams. Read the violations
   and fix the rule rather than the repositories.
3. **Expand.** Evaluate mode across the whole target set, whether that is a list or a property
   value. Look for the rule that fires constantly, which is usually a rule written against an
   assumption the fleet does not hold.
4. **Enforce.** Active mode. Keep reading violations and bypasses, since the useful signal starts
   rather than ends here.

Tell the affected developers before a rule becomes blocking, and give them a page that says which
rules apply, how to request an exception, and how to read a failed push.

## Migrating from branch protection

Read the existing protection before writing the ruleset, because the two models name things
differently and a silent gap is easy to create:

```sh
gh api repos/OWNER/REPO/branches/main/protection
```

Map each protection setting to its ruleset rule, create the ruleset in evaluate mode, compare what
it reports against what protection blocks, and only then remove the branch protection rule.
Removing protection first leaves the branch unprotected for the length of the migration. Where
evaluate mode is unavailable, run the ruleset in active mode alongside the branch protection rule
instead: both apply, the result is the union, and the comparison is what the developers report
rather than what the insights page does.

## Troubleshooting a rule that blocks legitimate work

The failure a developer reports is usually the last rule in the chain rather than the one that
matters. Before changing anything, ask the repository which rules apply to the branch:

```sh
gh ruleset check main --repo OWNER/REPO
```

Then read the ruleset that owns the rule, and check whether it is a repository ruleset or an
inherited organization one. A rule inherited from the organization cannot be relaxed in the
repository, and the correct response is an exception request rather than a local edit.

Where the block is correct and the work is legitimate, the fix is usually a missing status check
that never reports, an automation account that is not a bypass actor, or a required check that
runs only on some events. Confirm which before proposing that a rule be dropped.

## Checklist

- [ ] Every control expressed as a ruleset, with branch protection migrated or explicitly retained
- [ ] Target uses `~DEFAULT_BRANCH` or an explicit pattern that matches the branch it protects
- [ ] Enforcement is `active`, or `evaluate` with the stage of the rollout stated
- [ ] Tier applied matches the repository's classification, and the classification is stated
- [ ] Required status checks named explicitly, and each one actually reports on the event
- [ ] Push rules piloted before enforcement, with the automation they affect identified
- [ ] Release tag pattern protected against deletion and force update
- [ ] Every bypass actor is a role or team, scoped as narrowly as the case allows, with a written
      procedure and a review cadence
- [ ] Ruleset definition kept in a reviewable file, and updated rather than deleted and recreated
- [ ] Applied state read back and compared against the definition
