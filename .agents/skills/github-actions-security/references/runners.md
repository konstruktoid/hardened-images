<!--
Vendored from https://github.com/konstruktoid/agent-instructions-skills
skills/github/github-actions-security/references/runners.md
Upstream commit: a05445ea232a635d1803138a365d7a6868d693d2
Do not edit locally; re-vendor from upstream instead.
-->

# Runners and Egress Control

Read this when the change sets `runs-on`, introduces a container or service container, or touches
runner infrastructure or network policy.

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
    uses: step-security/harden-runner@bf7454d06d71f1098171f2acdf0cd4708d7b5920 # v2.20.0
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
- [ ] Container and service container images pinned by digest
- [ ] No Docker socket mounted into a job container
