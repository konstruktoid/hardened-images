<!--
Vendored from https://github.com/konstruktoid/agent-instructions-skills
skills/github/github-organization-governance/references/audit-and-compliance.md
Upstream ref: v0.1.0
Upstream commit: 994be479cf1d44d5ee69d0334da07e923d8dee2e
Do not edit locally; re-vendor with tools/vendor-agent-standards.sh instead.
-->

# Audit Logging and Compliance Evidence

Read this when configuring audit log retention or streaming, deciding which events to alert on,
mapping controls to a compliance framework, or handling an exception.

## Contents

- Evidence is a property of the control
- The audit log
- Events worth alerting on
- Streaming and retention
- What an auditor asks for
- Mapping controls to frameworks
- Exceptions
- Reporting a control that cannot be evidenced
- Checklist

## Evidence is a property of the control

A control that works and leaves no record fails an audit exactly as a missing control does. Design
each control so its evidence is a by-product: a ruleset produces a history entry and a blocked
push, a pull request requirement produces a review record, an app installation produces an audit
event. Evidence assembled by hand at audit time is evidence of the assembly.

For each control, name four things: the mechanism that enforces it, the read that shows its
current state, the audit event that records a change to it, and the owner who answers for it. A
control missing any of the four is incomplete, and saying which one is missing is more useful than
a summary that omits it.

## The audit log

The audit log records what happened, including the things no settings read will show: a setting
that was changed and changed back, a bypass that was used, an app that was installed for a day.

```sh
gh api --paginate "orgs/ORG/audit-log?phrase=action:repo.access&per_page=100"
gh api --paginate "orgs/ORG/audit-log?phrase=action:repository_ruleset.update&per_page=100"
```

Availability depends on the plan, and the API needs an owner token. Where the log cannot be read
with the available credentials, say so rather than reporting that the events are absent. An audit
that cannot see the audit log has not verified anything about the past.

## Events worth alerting on

Recording an event is not detecting it. Alert on the small set where a legitimate occurrence is
rare enough that a false alarm is cheap:

- Repository visibility changed to public.
- Repository transferred or deleted.
- A ruleset created, updated, or deleted, and a bypass used.
- Branch protection disabled or deleted.
- Organization owner role granted.
- Two-factor requirement or single sign-on enforcement disabled.
- An app installed, or its permissions changed.
- A self-hosted runner or runner group made available more widely.
- Secret scanning or push protection disabled, and push protection bypassed.

Route each alert to an owner rather than to a shared inbox, and state the expected response. An
alert with no named responder is a log line with extra steps.

## Streaming and retention

Stream the audit log to storage the organization controls, and set retention to at least the
longest period any applicable framework requires. Two properties matter beyond retention:

- The destination is outside the control of the accounts being audited, so an attacker with
  organization access cannot remove the record of what they did.
- The stream is monitored for interruption. A stream that stopped silently is worse than none,
  because the gap will be discovered when the record is needed.

## What an auditor asks for

Anticipate the questions, because each maps to a mechanism rather than to a document:

- Show that every change to production code was reviewed by someone other than the author.
- Show who could have merged without review, and whether anyone did.
- Show that access is granted through a process, and removed when someone leaves.
- Show which credentials exist, when they were last rotated, and who owns them.
- Show that vulnerabilities are found, prioritized, and remediated within a stated target.
- Show that the controls were in force for the whole period, not only today.

The last is the one configuration alone cannot answer. Ruleset history, audit log retention, and
the alert record are what cover the period rather than the moment.

## Mapping controls to frameworks

Map requirements to mechanisms, and keep the mapping in the repository holding the configuration
so it changes with the controls:

| Requirement | Mechanism | Evidence |
|---|---|---|
| Segregation of duties | Required approvals, code owner review, restricted bypass | Review records, bypass events |
| Change management | Pull request required, status checks, ruleset history | Pull request and check history |
| Least privilege | Base permission, team-based access, custom roles | Access review records |
| Credential management | Environment secrets, OIDC, token policy, secret scanning | Rotation records, alert history |
| Vulnerability management | Code scanning, dependency alerts, stated targets | Alert history with remediation times |
| Logging and monitoring | Audit log streaming, alerting on named events | Retained log, alert and response record |

Name the framework each control is claimed against. A control that satisfies an internal standard
and no external one is worth keeping, and saying so keeps the rest of the mapping credible.

## Exceptions

An exception is a control that does not apply to a case, recorded so it is visible. Every one
needs a reason, an owner, an expiry, and a compensating control where one exists. Review them on
the same cadence as access, and let them expire rather than renewing silently.

An exception with no expiry is a policy change made without review. An exception granted verbally
is a control that was removed and left no record.

## Reporting a control that cannot be evidenced

Some controls will be unverifiable in a given engagement: the plan does not include the audit log,
the credentials lack owner scope, or the enterprise level is not visible. Report each one
explicitly, name what could not be read, and state what would be needed to verify it. A report
that omits the gaps reads as coverage the work does not have.

## Checklist

- [ ] Every control names its mechanism, its state read, its audit event, and its owner
- [ ] Audit log readable, or the inability to read it stated with the reason
- [ ] Alerts configured for visibility changes, transfers, deletions, ruleset changes, bypasses,
      owner grants, authentication policy changes, app changes, runner exposure, and scanning
      being disabled
- [ ] Each alert routed to a named owner with an expected response
- [ ] Audit log streamed to storage outside the control of the audited accounts
- [ ] Retention at least as long as the longest applicable framework requires
- [ ] Stream interruption monitored
- [ ] Control-to-framework mapping kept with the configuration and current with it
- [ ] Evidence covers the period rather than the moment, through ruleset history and retained logs
- [ ] Every exception carries a reason, an owner, an expiry, and a compensating control where one
      exists
- [ ] Controls that could not be evidenced reported by name, with what verification would require
