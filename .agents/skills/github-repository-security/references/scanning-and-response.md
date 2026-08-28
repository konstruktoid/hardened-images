<!--
Vendored from https://github.com/konstruktoid/agent-instructions-skills
skills/github/github-repository-security/references/scanning-and-response.md
Upstream ref: v0.1.0
Upstream commit: 994be479cf1d44d5ee69d0334da07e923d8dee2e
Do not edit locally; re-vendor with tools/vendor-agent-standards.sh instead.
-->

# Scanning, Alerts, and Response

Read this when enabling or tuning code scanning, dependency alerts, or secret scanning, when
deciding what an alert obliges the repository to do, or when writing the security policy and
disclosure process.

## Contents

- The three scanners answer different questions
- Code scanning
- Dependency alerts and updates
- Dependency review at merge time
- Triage and remediation targets
- Suppressing a finding
- SECURITY.md
- Private vulnerability reporting and advisories
- Incident response for a repository
- Checklist

## The three scanners answer different questions

- **Secret scanning** asks whether a credential is present. A hit is an incident, since the
  credential is valid until rotated.
- **Dependency alerts** ask whether a component with a known vulnerability is in use. A hit is a
  triage item whose urgency depends on reachability and exposure.
- **Code scanning** asks whether the repository's own code contains a vulnerable pattern. A hit is
  a defect to fix or to dismiss with a reason.

Enabling all three and triaging none produces a repository that looks governed and is not. Decide
the response before enabling the scanner.

## Code scanning

- Run it on pull requests, so a finding arrives while the change is still cheap to alter, and on a
  schedule, so a rule added after the merge still finds old code.
- Set a severity threshold that blocks the merge. A threshold set so high that nothing blocks is a
  report, not a control; one set so low that everything blocks trains developers to bypass.
- Scan the workflow files too. CodeQL analyzes GitHub Actions definitions, which catches the
  injection and permission patterns `github-actions-security` covers, from a second direction.
- Read the results through the API when auditing, since the count in the interface excludes
  dismissed alerts:

  ```sh
  gh api --paginate --slurp "repos/OWNER/REPO/code-scanning/alerts?per_page=100" |
    jq 'add | group_by(.rule.security_severity_level) |
      map({severity: .[0].rule.security_severity_level, count: length})'
  ```

  `--jq` runs once per page, so an aggregate written that way counts each page separately and
  reports a total for the first 30 alerts. `--slurp` collects the pages into one array instead,
  and it cannot be combined with `--jq`, so the aggregation moves into a piped `jq`.

## Dependency alerts and updates

- Enable alerts and automated security updates, and commit a lockfile so the versions in use are
  the versions scanned.
- Configure version updates on a schedule, grouped so the pull requests are reviewable rather than
  one per package.
- Set a cooldown so a release published an hour ago is not adopted automatically. Several supply
  chain compromises have been caught within days of publication, and a cooldown converts that
  detection window into protection.
- Keep the ecosystem list complete. An ecosystem that is not configured is not monitored, and
  GitHub Actions is the one most often missing.

## Dependency review at merge time

Alerts report what is already in the repository. Dependency review reports what a pull request
would add, before it is merged, and can fail the check on a vulnerability severity or a license
that policy does not allow. It is the cheapest control in this file to add and the one most often
absent, because it requires only a required status check.

## Triage and remediation targets

A finding without a stated target is a finding that stays open. Set targets by severity, state
them where developers see them, and measure against them:

| Severity | Target | Behavior when the target is missed |
|---|---|---|
| Critical | Days, single digits | Escalate to the owning team's manager |
| High | Weeks, single digits | Reviewed at the next security review |
| Medium | The next planned release | Tracked, no escalation |
| Low | Backlog with an owner | Reviewed quarterly for accumulation |

Prioritize on exposure rather than severity alone: a critical finding in a dependency that no code
path reaches ranks below a high finding on an internet-facing entry point. Where exploitation
probability data is available, use it to order work within a severity band rather than to override
the band.

## Suppressing a finding

A dismissal is a decision that outlives the person who made it, so it carries the same burden as a
fix:

- Dismiss with a reason the next reader can evaluate: why the code path is unreachable, or which
  compensating control makes the finding moot.
- Never dismiss to reach a clean run before a deadline.
- Re-examine dismissals when the surrounding code changes, since a path that was unreachable is
  the thing a refactor most often makes reachable.

## SECURITY.md

`SECURITY.md` is read by someone who has found a vulnerability and is deciding whether to report
it privately. Write it for that reader:

- The private channel to use, and the fact that issues are not it.
- The response time the project commits to, and what happens after the report is acknowledged.
- Which versions receive fixes.
- Whether coordinated disclosure is expected, and the timeline.

A project that ships agent-facing content, such as skills, hooks, or MCP servers, states in the
same file what the content reads and what it sends anywhere, so the reader can audit the claim
against the files. That statement is the thing an installer checks before trusting the repository.

## Private vulnerability reporting and advisories

Enable private vulnerability reporting so the channel named in `SECURITY.md` exists inside the
repository rather than in someone's mailbox. Use a draft advisory to coordinate the fix, and
publish it when the fix ships, so downstream consumers receive the alert through the same
mechanism they already watch.

## Incident response for a repository

Write the plan before it is needed, and keep it to steps that can be followed under pressure:
contain, assess, revoke or yank, notify, remediate, and review afterwards. Name who decides, and
what evidence gets preserved before anything is deleted. For a published package or plugin, state
how a bad version is withdrawn and how consumers are told.

## Checklist

- [ ] Code scanning runs on pull requests and on a schedule, with a threshold that blocks a merge
- [ ] Workflow definitions are in scope for code scanning
- [ ] Dependency alerts and automated security updates enabled, with a lockfile committed
- [ ] Version updates scheduled, grouped, with a cooldown, and covering every ecosystem in use,
      including GitHub Actions
- [ ] Dependency review required as a status check on pull requests
- [ ] Remediation targets stated by severity, with exposure used to order work inside a band
- [ ] Every dismissal carries a reason a later reader can evaluate
- [ ] `SECURITY.md` names a private channel, a response time, and the supported versions
- [ ] Private vulnerability reporting enabled
- [ ] A repository shipping agent-facing content states what that content reads and sends
- [ ] An incident response plan exists, naming the decision maker and the evidence to preserve
