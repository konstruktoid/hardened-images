---
applyTo: "config/**/*.yml,config/**/*.yaml,**/*.pkrtpl,**/*.pkrtpl.hcl"
---

# Enterprise Ansible Hardening Instructions

Apply these rules to `config/local.yml`, `config/ansible.cfg`, and any
provisioning templates that configure the `konstruktoid.hardening` role.

## Authoring priorities
- Module-first implementation; avoid `shell`/`command` unless no safe module exists.
- Always use the fully-qualified collection name (FQCN, for example `ansible.builtin.git`) for every module call.
- Declarative, idempotent tasks with descriptive names.
- Double-quoted YAML strings.
- Pin `konstruktoid.hardening` to an explicit tagged version, never a floating branch.

## Conservative security handling
Treat these `konstruktoid.hardening` variables and domains as high sensitivity
and change conservatively:
- SSH (`sshd_*`), sudo, PAM, and user/group management
- audit/logging (`auditd_*`) and systemd service behavior
- mounts, sysctl/kernel tuning, firewall rules (`manage_ufw`, `ufw_*`)
- crypto policy, protocol hardening, and service exposure

Do not flip a hardening variable to a less restrictive value (e.g.
`sshd_permit_root_login: true`, `manage_ufw: false`,
`auditd_apply_audit_rules: false`, `suid_sgid_permissions: false`) without an
explicit request and a documented reason in the commit/PR description.

## Compliance-aware behavior
- Favor patterns aligned with CIS and STIG hardening intent and CMMC-oriented objectives.
- Improve auditability, traceability, and enforcement consistency.
- Reference exact benchmark/control IDs only when verified in repository context; otherwise cite likely control areas and rationale.

## Review priorities
1. Security regression or weakening of existing hardening intent
2. Over-privileged execution (`become`, root scope, broad permissions)
3. Non-idempotent logic or risky shell pipelines
4. Missing explicit ownership/mode on managed files
5. Operational reliability issues (unsafe restarts, brittle conditions)

## Risk levels
- Critical: clear security bypass, credential exposure, or severe privilege expansion
- High: significant hardening regression or broad exposure
- Medium: moderate hardening gap or reliability risk
- Low: maintainability/readability issue with minimal security impact

## Second opinions
- Regardless of finding severity, ask `@claude` for a second opinion in the PR before finalizing the review.
