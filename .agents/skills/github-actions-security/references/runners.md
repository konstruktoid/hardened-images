<!--
Vendored from https://github.com/konstruktoid/agent-instructions-skills
skills/github/github-actions-security/references/runners.md
Upstream ref: v0.1.0
Upstream commit: 994be479cf1d44d5ee69d0334da07e923d8dee2e
Do not edit locally; re-vendor with tools/vendor-agent-standards.sh instead.
-->

# Runners and Egress Control

Read this when the change sets `runs-on`, introduces a container or service container, or touches
runner infrastructure or network policy.

## Contents

- Choosing a runner
- Hardening a self-hosted runner
- Egress control
- Granting a job access to a device
- Containers and service containers
- Checklist

## Choosing a runner

GitHub-hosted runners are ephemeral virtual machines, destroyed after one job, with no access to
other runners or to an internal network. Compromise is bounded by the job. Use them unless a
specific requirement rules them out.

Self-hosted runners persist state between jobs by default, usually sit inside a network with
something worth reaching, and often run as a user with more access than the job needs.

**A self-hosted runner must never serve a public repository.** Anyone can fork it, open a pull
request, and execute code on the machine. There is no configuration that makes this safe, so this is
a rule rather than a recommendation.

Private repositories are not exempt from the underlying problem. Anyone with write access, and
anyone who compromises an account with write access, gets code execution on the runner host.

## Hardening a self-hosted runner

When one is genuinely required:

- **Make it ephemeral.** Register with `--ephemeral`, or use just-in-time runners created through
  the REST API, which accept at most one job before removing themselves. Rebuild the host or
  container from an image each time; do not reuse a workspace.
- **Prefer Actions Runner Controller** on Kubernetes, or an equivalent that destroys the pod after
  each job, over long-lived VMs.
- **Run as an unprivileged dedicated user** with no sudo, no Docker socket access unless the job
  requires it, and write access only to the runner's own workspace.
- **Use runner groups** to limit which organizations and repositories can target a given runner, and
  segregate groups by privilege. A runner with production network access should not be reachable
  from a repository that accepts community contributions.
- **Keep credentials off the host.** No SSH keys, no cloud CLI profiles, no long-lived tokens in the
  runner user's home directory. Block or restrict access to the cloud instance metadata service,
  which is otherwise a credential source for any job.
- **Do not rely on label naming for isolation.** A workflow in any repository allowed to use the
  runner group can request the label. Isolation comes from the group, not the label.
- **Log and monitor.** Ship process, file, and network telemetry to the security team, and alert on
  a job reaching an unexpected destination.

## Egress control

A compromised job's first act is usually to send credentials somewhere. Restricting outbound network
access from the runner turns exfiltration into a blocked connection and an alert.

[step-security/harden-runner](https://github.com/step-security/harden-runner) implements this as a
first step in the job, on GitHub-hosted and self-hosted runners:

```yaml
steps:
  - name: Harden the runner
    uses: step-security/harden-runner@05e31511f85b41b11d1cf0ef85d0992719546e2c # v2.21.0
    with:
      egress-policy: audit
```

Run it in `audit` mode first to learn the destinations a workflow actually contacts, then move to
`block` with an explicit `allowed-endpoints` list. Applying `block` without the audit phase breaks
builds. The community tier is free for public repositories, with a weekly run quota; private
repositories require a paid tier.

Detection capability varies by runner operating system, so verify the specific checks are supported
on the platform in use rather than assuming parity.

The same principle applies without a third-party action: an organization running self-hosted runners
can restrict egress at the network layer, allowing the GitHub endpoints, the package registries in
use, and nothing else.

### An allowlist is only as complete as the events the audit observed

The audit phase records the destinations the audited runs reached, and a run only reaches the code
paths its event took. A workflow's destination set is conditional on the event rather than fixed per
workflow, so an allowlist derived from an audit is silently incomplete for any event that did not
occur while auditing.

A dependency review action shows the shape. It contacts `api.deps.dev` only when the pull request
actually changes a dependency manifest, because that is what triggers its OpenSSF Scorecard lookup.
Where every audited pull request happened to touch no manifest, the endpoint is never observed and
never listed, and the first pull request that changes a manifest is blocked. An adjacent endpoint
being present, `api.securityscorecards.dev` in that case, is not evidence that the feature's
destinations are covered.

Two consequences:

- When building an allowlist, reason about each tool's conditional network calls from its
  documentation and source, not only about the destinations the audit observed.
- When a job with `egress-policy: block` starts failing after a long green streak, with no change to
  the allowlist, suspect a newly reached code path in a tool that was already present before
  suspecting the workflow.

This failure mode is the cost of `block`, and it is worth paying. Expect it and diagnose it rather
than retreating to `audit`.

### Diagnosing a blocked connection

A blocked connection surfaces as whatever generic error the tool raises. A failing step can log one
line, such as `##[error]fetch failed`, with no host, URL, or errno, and the check annotation carries
the same text and nothing more. Nothing in the failing step identifies the cause.

The hardening action's post-step in the same job log does identify it:

```text
domain not allowed: api.deps.dev.
```

That section also prints a `domain resolved:` entry for every lookup and an `endpoint called ...`
line for every successful connection, which together show how far the tool got before it was
blocked.

Treat a generic network error from inside a job that blocks egress as a blocked-egress suspect by
default, including `fetch failed`, `ECONNREFUSED`, `getaddrinfo`, and bare timeouts. Read the
post-step output before touching the workflow:

```sh
gh run view --job <job-id> --log | grep -i "not allowed"
```

When the same pull request also bumps the hardening action's own version, the bump is the obvious
hypothesis and is usually the wrong one. Settle it by comparing what the two runs did rather than
reasoning from the version delta: the `endpoint called` lines and the steps each run reached. A
passing run that never emitted the endpoint at all did not exercise the code path, which shows the
bump was coincident rather than causal and prevents a wrong revert.

## Granting a job access to a device

A job needing a device node, `/dev/kvm` for nested virtualization being the common case, is
routinely handled by a widely copied udev rule with `MODE="0666"`, which makes the device
world-writable. The reason that snippet spread is that the obvious alternative does not work: adding
the runner user to the owning group has no effect on the already authenticated runner session, so
group membership alone leaves the device inaccessible for the rest of the job.

Taking ownership in the rule works immediately and grants nothing to anyone else, because
`static_node` applies the ownership and mode to the device node directly:

```bash
printf 'KERNEL=="kvm", OWNER="%s", GROUP="kvm", MODE="0660", OPTIONS+="static_node=kvm"\n' \
  "$(id -un)" | sudo tee /etc/udev/rules.d/99-kvm.rules > /dev/null
sudo udevadm control --reload-rules
sudo udevadm trigger --name-match=kvm
sudo udevadm settle
```

Two points generalize past this device:

- `udevadm trigger` is asynchronous. Follow it with `udevadm settle` before anything depends on the
  result.
- Assert the outcome rather than assuming it. A permission change that fails here raises no error:
  the job degrades to software emulation and burns its full timeout instead. An explicit
  readable and writable check that fails the step with `::error::` converts a silent multi-hour
  degradation into an immediate, legible failure.

  ```bash
  if [ ! -r /dev/kvm ] || [ ! -w /dev/kvm ]; then
    echo "::error::/dev/kvm is not accessible, the guests would fall back to emulation"
    exit 1
  fi
  ```

  The general rule: when a setup step's failure mode is silent degradation rather than an error,
  verify the postcondition inside the step.

## Containers and service containers

- Pin container images by digest, not tag: `image: ghcr.io/org/img@sha256:...`. A tag on a container
  image is as mutable as a tag on an action.
- A `container:` job runs steps inside the image, so the image is as trusted as the workflow. Apply
  the same review standard as for an action.
- Service containers are reachable from the job. Do not expose a service holding real data to a job
  that runs untrusted code.
- Do not mount the Docker socket into a job container. It grants root on the host.

## Checklist

- [ ] No self-hosted runner used by a public repository
- [ ] Self-hosted runners are ephemeral, unprivileged, and scoped by runner group
- [ ] No credentials, SSH keys, or cloud profiles present on the runner host; metadata service
      access restricted
- [ ] Egress is audited, and blocked to an allowlist where the workflow's destinations are known
- [ ] The allowlist covers the destinations of events the audit did not observe, reasoned from each
      tool's conditional network calls rather than from observed traffic alone
- [ ] Any generic network failure in a job that blocks egress was checked against the hardening
      action's post-step log before the workflow was changed
- [ ] A device made accessible to the job is owned by the runner user rather than world-writable,
      and the step asserts the access it just granted
- [ ] Container and service container images pinned by digest
- [ ] No Docker socket mounted into a job container
- [ ] Any change to an egress allowlist or to runner device permissions is named as unverified
      until a run exercises it, together with the event that would exercise it
