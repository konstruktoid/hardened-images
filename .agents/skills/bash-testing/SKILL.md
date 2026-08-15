---
name: bash-testing
description: Adds or updates bats-core, shunit2, or plain-script test coverage for a Bash change by first discovering the repository's existing test layout and conventions, matching them rather than imposing a new framework, deciding whether the change requires a test at all, making a script testable by separating logic into functions from the entry point, and running the suite in a bounded verify loop. Use when a shell script's behavior changes and that change should be locked in, including fixing a bug so it cannot regress, pinning an exit code or output that is currently wrong, adding behavior, or covering input validation, cleanup, privilege, or destructive paths, and when deciding where a new shell test belongs in an unfamiliar repository. Not for test work in other languages, and not for documenting, explaining, or tuning CI for a script whose behavior is unchanged.
---

<!--
Vendored from https://github.com/konstruktoid/agent-instructions-skills
skills/bash/bash-testing/SKILL.md
Upstream commit: 4983695a16ac349dfcac90c4ab27c86d272c2d6e
Do not edit locally; re-vendor from upstream instead.
-->

# bash-testing

## Purpose

Add test coverage that fits the repository a shell change lands in, and that exercises the paths
shell scripts actually fail on: bad arguments, a missing dependency, a command that returns
non-zero, a filename with a space in it, a second run after a partial first one.

## When to use this

- A shell change adds behavior, fixes a bug, or changes a script's interface: its arguments, its
  output, or its exit codes.
- A change touches input validation, cleanup, locking, privilege, or a destructive operation.
- Deciding where a shell test belongs in a repository whose layout is unfamiliar.

## When NOT to use this

- Non-shell changes.
- A repository whose shell is covered by a test framework in another language, for example a
  pytest suite that invokes the scripts. Extend that suite instead of introducing a shell one
  beside it.

## Steps

1. **Discover what the repository already does.** Do not assume a framework.
   - Look for `test/`, `tests/`, `spec/`, `*.bats`, `*_test.sh`, `test_*.sh`, a `test` target in a
     `Makefile` or `justfile`, and the test step in `.github/workflows/*.yml`.
   - Identify the framework: `bats-core` (`@test` blocks, `bats-support` and `bats-assert` helpers,
     often vendored in `test/test_helper/` or as git submodules), `shunit2` (`testX` functions and
     a trailing `. shunit2`), or plain scripts that exit non-zero on failure.
   - Read two or three existing tests near the code being changed. Note how the script under test
     is located and loaded, how fixtures and temporary directories are created, and how external
     commands are stubbed.
2. **Decide whether a test is required.** See the table below. If a test is not required, say so
   and why, rather than silently skipping it.
3. **Make the script testable if it is not.** The change is small and worth making: move the logic
   into functions, keep the entry point to `main "$@"`, and guard it so the file can be sourced
   without running:

   ```bash
   if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
     main "$@"
   fi
   ```

   A test then sources the script and calls one function, instead of running the whole program and
   parsing its output. Do not restructure a script beyond what the change needs.
4. **Write the test in the discovered style**, covering the paths below.
5. **Run the suite in the bounded verify loop.**
6. Follow `instructions/bash_coding_instructions.md` for the test code itself. Test files are
   source, and `shellcheck` applies to them. It analyzes a `.bats` file through the
   `#!/usr/bin/env bats` shebang; a helper file without one needs `-s bats` or a
   `# shellcheck shell=bats` directive.

## When a test is required versus optional

| Change | Test |
|---|---|
| New script, or a new function in a sourced library | Required |
| Bug fix | Required, and it must fail without the fix |
| Changed arguments, output format, or exit codes | Required, updating the existing test rather than adding a parallel one |
| Input validation, path handling, or anything that parses untrusted data | Required, including the rejection paths |
| A destructive operation, cleanup, or locking | Required, against a temporary directory, including the failure path |
| Refactor with no behavior change | Not required; existing tests must pass unchanged, and that is the evidence |
| Comments, formatting, help text wording | Not required |
| A wrapper that only calls one external command | Not required if the repository does not test its other wrappers |

## What a shell test should cover

Beyond the happy path, which is usually the least interesting case:

- **Exit codes.** Assert the status, not only the output. A script that prints an error and exits 0
  is broken in a way output assertions miss.
- **Standard error.** Assert that diagnostics go to stderr and that stdout carries only data.
- **Argument validation.** No arguments, too many, an empty string, a value that fails the
  allowlist pattern, and a value beginning with a hyphen.
- **Hostile filenames.** At least one fixture path containing a space; a newline or a quote where
  the script handles filenames from `find` or a glob.
- **Failure of a called command.** Stub it, or point the script at a path that does not exist, and
  confirm the script stops rather than continuing with an empty value.
- **Cleanup.** Assert that the temporary directory is gone after both a successful and a failed
  run.
- **Reruns.** Run the script twice and assert the second run is a success and changes nothing, for
  anything meant to be idempotent.

Stub an external command by putting a directory first in `PATH` inside the test, with an
executable of that name, rather than by editing the script for testability:

```bash
setup() {
  TEST_TMPDIR="$(mktemp -d)"
  mkdir -p "${TEST_TMPDIR}/bin"
  cat > "${TEST_TMPDIR}/bin/curl" <<'STUB'
#!/usr/bin/env bash
printf 'stubbed response\n'
STUB
  chmod +x "${TEST_TMPDIR}/bin/curl"
  PATH="${TEST_TMPDIR}/bin:${PATH}"
}

teardown() {
  rm -rf -- "${TEST_TMPDIR}"
}
```

Keep every test independent: its own temporary directory, no shared mutable state, no ordering
assumptions, no network access, no dependence on wall-clock time, and nothing written outside the
temporary directory. Never test a destructive script against real paths; give it a scratch
directory and assert on what is left.

Keep the machine out of the test. A home-directory path, username, hostname, or real email address
in a fixture or an expected value is both a test that passes on one machine and information the
repository has no reason to publish.

## Verify

Run the repository's own entry point, not a bare framework invocation, when one exists: `make
test`, the CI step, or `bats test/`. Where the repository has no shell tests and adding a framework
is out of scope for the change, say so and verify by running the script directly against a scratch
directory, including one failure path, then report what was covered.

- The full suite passes, not only the new test.
- The new test fails against the unfixed or unchanged code, for a bug fix or a behavior change.
- `shellcheck` and `bash -n` are clean on the test files as well as the script.

### The bounded loop

One **attempt** is one full fix-and-rerun cycle: apply fixes for the failures from the previous
run, then rerun the suite to completion. Reading output, or re-reading a file without changing
anything, is not an attempt.

- Baseline the loop at 3 attempts.
- Continue past 3 only while making measurable progress, meaning each cycle ends with strictly
  fewer failures than the one before it.
- Stop early, before 3 attempts, if the loop is oscillating: the same failures recur, the count
  stops dropping, or a fix for one failure reintroduces another.
- When stopping for either reason, report to the user rather than proceeding or silently giving
  up. Name the failing test, include its output, and state what was tried.

Never weaken a test, skip it, or delete an assertion to get a green run. If a test is wrong, fix
the test and say why it was wrong.

## Verification checklist

- [ ] Existing test layout, framework, and conventions read before writing, and matched
- [ ] No second test framework introduced alongside an existing one
- [ ] Test required by the table above was written, or its absence explained
- [ ] For a bug fix, the test was confirmed to fail without the fix
- [ ] Exit status asserted, not only output, and stderr checked where the script reports errors
- [ ] Rejection paths covered for any input validation the change touches
- [ ] At least one fixture path containing a space, where the script handles filenames
- [ ] Cleanup asserted after a failed run, for any script that creates temporary files
- [ ] Full suite run through the repository's own entry point, to a clean result or to a stop
      under the loop rules above, with failures reported
- [ ] `shellcheck` and `bash -n` clean on the test files too
- [ ] Tests are independent of ordering, network access, wall-clock time, and anything outside
      their own temporary directory
- [ ] No home-directory path, username, hostname, or real email address in test code, fixtures, or
      committed output

## References

Paths starting `instructions/` are relative to this library's root. When this skill is installed as
a Claude Code plugin, read them at `${CLAUDE_PLUGIN_ROOT}/instructions/`, which resolves to the
installed copy.

- `instructions/bash_coding_instructions.md`: the `shellcheck`, `bash -n`, and formatter baseline,
  which applies to test code as well.
- `.agents/skills/bash-secure-scripting/SKILL.md`: for security-relevant changes, whose rejection,
  cleanup, and failure paths need coverage.
- bats-core, [documentation](https://bats-core.readthedocs.io/) and the
  [bats-assert](https://github.com/bats-core/bats-assert) helper library.
- shunit2, [documentation](https://github.com/kward/shunit2), for repositories already using it.
