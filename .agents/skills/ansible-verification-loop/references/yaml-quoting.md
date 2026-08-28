<!--
Vendored from https://github.com/konstruktoid/agent-instructions-skills
skills/ansible/ansible-verification-loop/references/yaml-quoting.md
Upstream ref: v0.1.0
Upstream commit: 994be479cf1d44d5ee69d0334da07e923d8dee2e
Do not edit locally; re-vendor with tools/vendor-agent-standards.sh instead.
-->

# YAML Quoting and Scalar Resolution

Read this when a change adds, removes, or argues about quoting in a YAML file, or when
explaining to a reviewer why a particular value must stay quoted.

## Authoritative source

The [YAML 1.2.2 Specification](https://yaml.org/spec/1.2.2/) is the authoritative
reference for scalar resolution, quoting, and tag semantics.

## Why values need quoting

Use the specification to explain *why* a value needs quoting, and be precise about which
YAML version resolves what. The difference is the whole reason quoting is needed: a value
whose type depends on the loader is a value that must be quoted.

- YAML 1.2.2's core schema resolves exactly six spellings as booleans: `true`, `True`,
  `TRUE`, `false`, `False`, and `FALSE`. Not every capitalization, so `tRue` is a string.
  The rest of the "Norway problem" family, unquoted `yes`, `no`, `on`, `off`, `y`, and `n`,
  is YAML 1.1 behavior that many loaders still implement.
- Ansible reads YAML through PyYAML, which follows YAML 1.1, so those spellings do become
  booleans in a playbook even though YAML 1.2.2 leaves them as strings. Quote them
  wherever the string is what is wanted.
- YAML 1.1 resolves two numeric forms that YAML 1.2.2 drops, and both are narrower than
  "anything with a leading zero or a colon":
  - Octal is `0` followed by digits `0` to `7`, so `012` is 10 under YAML 1.1 and the
    integer 12 under YAML 1.2.2. A leading zero alone does not do it: `08` and `09` are
    not valid octal and stay strings, and `0x1f` is hexadecimal in both.
  - Sexagesimal is two or more colon-separated groups of digits, the groups after the
    first being `00` to `59`, so `12:30` is 750 under YAML 1.1 and a string under
    YAML 1.2.2. A colon in ordinary text does not do it: `note: 12:ab` stays a string, and
    a mapping's own `key: value` colon is structure rather than a scalar.
  Quote a value in either form so it does not change meaning with the loader.

## Auditing quoting across a repository

A sweep that adds or removes quoting across many files mixes two kinds of change, and a reviewer
cannot judge the risk unless they are reported separately.

**Correctness.** A value whose type depends on the loader changes meaning when its quoting changes.
Check explicitly for the YAML 1.1 and 1.2 divergence set: `yes`, `no`, `on`, `off`, `y`, `n`, a
leading `0` followed by digits `0` to `7`, and sexagesimal `NN:NN`. Each one found unquoted is a
behavior change waiting to happen, and quoting it is a fix.

**Consistency.** Everything else is cosmetic. When the divergence set turns out to be quoted already,
which is the usual result in a repository that lints with `yaml[truthy]`, say plainly that the sweep
changed no behavior rather than presenting it as a fix.

Do not over-quote. Quoting is for values that are meant to be strings:

- A default backing a `type: "int"` or `type: "bool"` entry in `meta/argument_specs.yml` must stay
  unquoted. The `type:` value is itself a string and may be quoted; the `default:` under it has to
  match the type it declares. A quoted `"5"` is a string, and it remains one everywhere the
  argument spec's coercion has not been applied, which breaks any comparison or arithmetic that
  treats it as a number.
- A sweep must skip any value whose declared type is not a string, and must not quote a value that
  is already a real boolean or integer.

For measuring the current ratio before deciding what the convention is, and for the parser
configuration an audit needs to see quoting at all, read
[style-sweeps.md](style-sweeps.md).

## Relationship to the repository's linters

Ansible's YAML loader accepts unquoted `yes`, `no`, `on`, and `off` rather than rejecting
them, which is exactly why the lint rule exists: `ansible-lint`'s default `yaml`/`truthy`
rule requires `true`/`false` and flags the other spellings. The specification explains why
that rule is there; it does not replace it.

Never use the specification to justify removing existing quoting, the `---`
document-start marker, or any other convention that `ansible-lint` or `yamllint`
already enforces in the target repository. The repository's configured linters win.
