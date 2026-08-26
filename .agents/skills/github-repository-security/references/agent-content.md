<!--
Vendored from https://github.com/konstruktoid/agent-instructions-skills
skills/github/github-repository-security/references/agent-content.md
Upstream ref: v0.1.0
Upstream commit: 994be479cf1d44d5ee69d0334da07e923d8dee2e
Do not edit locally; re-vendor with tools/vendor-agent-standards.sh instead.
-->

# Agent-Facing Content in a Repository

Read this when a repository ships content that an AI agent loads: skills, instructions documents,
slash commands, hooks, plugin manifests, or MCP server definitions. It covers both directions:
the repository controls that protect what is published, and the review that content receives
before it is trusted.

## Contents

- Why this content is different
- The five components that execute or steer
- Repository controls for a repository that publishes agent content
- Reviewing an instruction file for injection
- Reviewing hooks, commands, and scripts
- Reviewing MCP server configuration
- Publishing and installation
- The data-access statement
- Checklist

## Why this content is different

Ordinary source code is executed by a machine that does exactly what the code says. Agent-facing
content is loaded into a model's context, where natural language becomes instructions with the
authority of the surrounding session. No linter, type checker, or scanner reads it for intent, so
the review is human and the repository controls around it are the only enforced protection.

The consequence for repository configuration: the paths holding this content need the same
protection as build and release configuration, because a change to them changes what every
consumer's agent does.

## The five components that execute or steer

| Component | What it can do | Review focus |
|---|---|---|
| Session hooks | Run shell commands automatically with the user's permissions | Any command that reads credentials or reaches the network |
| Scripts | Execute with the invoking user's access | Filesystem reach, network calls, argument handling |
| Slash commands | Trigger tool calls and file operations from a prompt | Whether the prompt widens scope beyond what the name implies |
| MCP server configuration | Point at endpoints outside the repository's control | Which endpoint, what it receives, who controls it |
| Skill and instruction files | Enter the model's context as authoritative text | Reach, egress, and priority language, described below |

Skill and instruction files are the hardest case, because there is no automated defense at all and
they read as documentation.

## Repository controls for a repository that publishes agent content

- Protect the default branch: no direct pushes, no force pushes, a pull request required, and
  approval required before merging. A repository whose content becomes another user's agent
  behavior has no trivial change.
- Cover every agent-facing path in `CODEOWNERS`, alongside `.github/workflows/` and the packaging
  manifest, so a change is reviewed by someone accountable for it.
- Make `CODEOWNERS` own itself, as the last rule in the file, and assign it to a team that does
  not overlap with the owners of the paths above:

  ```text
  /.github/CODEOWNERS  @ORG/security-team
  ```

  GitHub evaluates `CODEOWNERS` from the base branch and the last matching pattern wins, so
  without that rule one pull request can delete the ownership of every path listed above and
  merge with no code owner having seen it. The rule is what makes the rest of the file hold.
- Require review from a second person for those paths where the project has the people for it, and
  hold the review to reading the diff rather than the description.
- Run the merge-blocking checks the content deserves: lint, the project's own authoring checks,
  secret scanning, and static analysis where the content includes code.
- Verify the project's own claims against itself in continuous integration, so guidance the
  repository publishes is guidance the repository passes.
- Publish from a protected tag with trusted publishing, as
  [releases-and-provenance.md](releases-and-provenance.md) describes. Consumers are told to pin to
  a tag, which requires the tag to be protected.
- Ship a `SECURITY.md` with a private reporting channel and an incident response plan that covers
  withdrawing a bad version and telling consumers.

## Reviewing an instruction file for injection

Read the file as a whole, then look specifically for four patterns. Each is a reason to ask a
question, not proof of malice, and each is invisible to every automated check the repository runs.

- **Reach.** Paths the content has no reason to want: credential directories, shell profiles,
  environment files, cloud configuration. Glob patterns wider than the task needs. Access to
  environment variables as a category rather than by name.
- **Egress.** A URL built from file contents. Instructions to report, log, or sync to a remote
  service. An encoding step, such as base64, with no local reason for the encoding.
- **Priority language.** Wording that outranks the user's own request: always, before responding,
  regardless of, even if not asked, first and silently. Framing that presents the text as a system
  instruction rather than as repository content.
- **Framing that lowers scrutiny.** A payload buried in a setup or troubleshooting section, an
  example that demonstrates reading credentials, or a block long enough that a reviewer tires
  before reaching the part that matters.

A disclosed vulnerability in a rule-file feature of another agent tool worked this way: files read
from a project directory were fed into a trusted channel, where injected instructions steered the
model toward leaking environment variables. The repository around it was reviewed. Natural
language was the gap.

## Reviewing hooks, commands, and scripts

- A session hook runs without the user asking. Read every command it runs, and treat any read of a
  credential path or any outbound connection as a finding to justify before merging.
- A script shipped with the content executes with the user's access. Apply the language skill that
  covers it, and check argument handling for the injection paths that skill names.
- A slash command is a prompt. Check that the operations it implies match the name and the
  documentation, since a command named for a narrow task can request a wide one.

## Reviewing MCP server configuration

An MCP server definition points at an endpoint outside the repository. Establish who controls the
endpoint, what data reaches it, and whether the definition pins a version or follows a moving
reference. A definition pointing at a host the project does not control is a dependency on that
host's security, and it belongs in the data-access statement.

## Publishing and installation

- Release from a tag, and make the tag protected and immutable. Consumers pinning to a default
  branch receive every change at the moment it merges.
- Tell consumers which reference to pin to, and honor that instruction with the tag controls that
  make it meaningful.
- On the installing side, the audit is short: check that the source repository requires review,
  that releases are tagged rather than deployed from a moving branch, that `SECURITY.md` and a
  data-access statement exist, that publishing uses short-lived credentials, that session hooks
  read no credentials and open no connections, and that each instruction file reaches only what
  its stated purpose needs.

## The data-access statement

State, in a file the repository publishes, what the content reads and what it sends anywhere. The
statement is what makes the review above cheap: a reader compares the claim against the files, and
any reach not covered by the claim is a question. Keep it specific, naming paths and endpoints
rather than categories.

## Checklist

- [ ] Default branch protected, direct and force pushes blocked, pull request and approval
      required
- [ ] `CODEOWNERS` covers every agent-facing path, the workflows, and the packaging manifest
- [ ] Merge-blocking checks cover lint, the project's own authoring rules, secret scanning, and
      static analysis of any shipped code
- [ ] The project verifies its own published claims in continuous integration
- [ ] Releases published from a protected, immutable tag using trusted publishing
- [ ] `SECURITY.md` names a private channel and an incident response plan covering withdrawal
- [ ] Every instruction file reviewed for reach, egress, priority language, and framing that
      lowers scrutiny
- [ ] Every session hook's commands read, with credential reads and outbound connections justified
- [ ] Every MCP server definition names a controlled endpoint, with the data it receives stated
- [ ] A data-access statement exists, naming paths and endpoints rather than categories
- [ ] Consumers are told which tag to pin to, and the tag controls make that instruction real
