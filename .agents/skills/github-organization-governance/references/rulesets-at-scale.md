<!--
Vendored from https://github.com/konstruktoid/agent-instructions-skills
skills/github/github-organization-governance/references/rulesets-at-scale.md
Upstream ref: v0.1.0
Upstream commit: 994be479cf1d44d5ee69d0334da07e923d8dee2e
Do not edit locally; re-vendor with tools/vendor-agent-standards.sh instead.
-->

# Rulesets and Classification at Scale

Read this when designing a custom property schema, targeting rulesets across many repositories,
staging a rollout, or detecting drift between the intended configuration and the live one.

## Contents

- Classify before enforcing
- Designing the property schema
- Populating and keeping properties current
- Targeting a ruleset by property
- Tiering
- Staged rollout
- Reading rule insights
- Bypass at scale
- Drift detection
- Managing the configuration as code
- Checklist

## Classify before enforcing

A ruleset targeted at a list of repository names is correct on the day it is written and stale on
the day the next repository is created. A ruleset targeted at a custom property is correct
continuously, because a repository joins the tier by carrying the property.

The order is therefore fixed: define the schema, populate it, confirm coverage, then target
rulesets at property values. Enforcing first produces a control with a coverage gap nobody
measures.

## Designing the property schema

Start with the properties that drive a decision, not the ones that would be nice to report on. A
property that no ruleset, workflow, or review consults is metadata that will drift:

| Property | Type | Drives |
|---|---|---|
| `data-classification` | Single select: public, internal, confidential, restricted | Which protection tier applies |
| `business-criticality` | Single select: critical, high, medium, low | Review depth and response targets |
| `owner-team` | String | Who answers for the repository and its alerts |
| `compliance-frameworks` | Multi select: SOC2, PCI-DSS, HIPAA, FedRAMP | Additional required checks and evidence |
| `environment` | Single select: production, staging, development | Whether the production tier applies |

Keep the vocabulary closed where the value drives enforcement. A free-text field that a ruleset
targets will eventually hold a spelling nothing matches.

For a public repository, avoid a property whose value reveals something about the organization
that the repository does not: an internal project name, or a security posture that tells a reader
where the weak controls are.

## Populating and keeping properties current

- Set the properties at creation, through the creation workflow or a scheduled job that finds
  unclassified repositories.
- Where the platform supports required properties, use them, so the classification cannot be
  skipped.
- Report coverage as a number, and treat the uncovered repositories as the finding:

  ```sh
  gh api --paginate orgs/ORG/properties/values --jq '.[] |
    {repo: .repository_name, props: [.properties[] | .property_name]}'
  ```

- Re-derive properties that can be computed, such as whether a repository has a deployment
  workflow, rather than relying on a person to keep them accurate.

## Targeting a ruleset by property

An organization ruleset can target repositories by property value, by name pattern, or by an
explicit list. Prefer the property, keep the name pattern for cases where naming is the
classification, and treat an explicit list as a temporary measure with an end date.

Include archived repositories in the audit even though they cannot receive pushes, since an
archived repository that is unarchived returns without the tier if the targeting was a list.

## Tiering

Three tiers cover most organizations, and each adds to the one before it:

- **Baseline**, every repository: force pushes and deletion blocked, a pull request required,
  the shared security checks required and each bound to its reporting app with `integration_id`.
  Status checks are not indexed above the repository level, so the name is entered by hand and a
  typo produces a check that is never required; verify the applied ruleset rather than the draft.
- **Production**, where the repository supports a running service: approvals, code owner review,
  stale approval dismissal, approval of the most recent reviewable push, conversation resolution,
  and code scanning results required.
- **Regulated**, where a framework applies: signed commits, restricted commit metadata, deployment
  success required, additional scanning, and push rules covering sensitive paths, file types, and
  file size.

Keep each tier a separate ruleset rather than one ruleset with conditions. Separate rulesets can be
rolled out, evaluated, and reverted independently, and rule insights then attribute a block to a
tier.

## Staged rollout

Move a new control through four stages, and let the reported violations decide when to advance:

1. **Test**: evaluate mode on repositories nobody depends on.
2. **Pilot**: evaluate mode on a few named repositories with willing teams.
3. **Expand**: evaluate mode across the whole target set.
4. **Enforce**: active mode, with violations and bypasses still being read.

Tell developers before a rule becomes blocking, and publish a page naming the rules per tier, how
to request an exception, and how to read a failed push. A rule that arrives unannounced is
reverted rather than followed.

Stage the rules as well as the repositories. Enabling several restrictive rules at once makes the
resulting friction impossible to attribute, and push rules are the ones most likely to break
automation that nobody remembered.

## Reading rule insights

Rule insights report what the rulesets did: which rule blocked what, and which bypass was used.
Use them for three questions:

- Which rule fires most, which usually means the rule encodes an assumption the fleet does not
  hold.
- Which repositories bypass most, which is either a tier applied wrongly or a team without the
  capability the rule requires.
- Whether the block rate falls after a rollout, which is the measurement that says enablement
  worked.

## Bypass at scale

- Grant bypass to roles and teams, not to individuals, so the grant survives an individual leaving.
- Prefer `pull_request` scope over `always`.
- Review bypass events on a stated cadence, and treat a recurring bypass as a rule to change.
- Avoid the impossible merge: a required workflow that cannot run, an external check that never
  reports, or a review requirement in a single-maintainer repository. Each produces either a
  standing bypass or a stalled team.

## Drift detection

Live configuration diverges from the intended one through manual changes, exceptions, and
repositories created outside the process. Run a scheduled comparison of the live state against the
committed definition, and report differences rather than reapplying them silently: a difference is
either an unrecorded change or an exception nobody wrote down, and both need a person.

Report at least the rulesets whose rules differ from the definition, the repositories missing
required properties, the repositories matched by no tier, and bypass actors not in the definition.

## Managing the configuration as code

Keep the property schema, the ruleset definitions, and the policy settings in a repository, and
apply them from there. The benefits are the ones any reviewed change has: a diff, a reviewer, a
history, and the ability to reapply after drift. Whether the mechanism is a script over the API or
an infrastructure-as-code provider matters less than the definitions being reviewable.

The repository holding that configuration is itself a high-value target, since a change to it
changes every repository's controls. Apply the production tier to it at minimum, restrict who may
merge, and require code owner review.

## Checklist

- [ ] Property schema defined, with every property driving a decision
- [ ] Vocabulary closed for every property a ruleset targets
- [ ] No property on a public repository reveals internal information
- [ ] Properties set at creation, with coverage measured and uncovered repositories listed
- [ ] Rulesets target properties rather than name lists, with any list carrying an end date
- [ ] Tiers kept as separate rulesets, each rollable and revertible on its own
- [ ] Rollout staged through test, pilot, expand, and enforce, with violations read at each stage
- [ ] Developers told before a rule became blocking, with a page naming rules and the exception
      path
- [ ] Rule insights reviewed for the most-fired rule and the most-bypassing repositories
- [ ] Bypass granted to roles or teams, scoped narrowly, and reviewed on a cadence
- [ ] No tier creates an impossible merge
- [ ] Drift detection scheduled, reporting rather than silently reapplying
- [ ] Configuration kept in a reviewed repository, and that repository protected at least at the
      production tier
