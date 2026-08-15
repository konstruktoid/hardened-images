---
name: bash-secure-scripting
description: Authors, reviews, and hardens Bash scripts for the stability and security properties a linter cannot verify on its own, including strict-mode semantics and the cases errexit ignores, cleanup and locking on every exit path, injection-safe handling of untrusted input and filenames, PATH and environment control, temporary files and permissions, and credential handling, verified with shellcheck, bash -n, and the repository's formatter in a bounded loop. Use when creating or editing a shell script, a sourced shell library, or shell embedded in CI steps, container entrypoints, systemd units, cron jobs, or git hooks, and when reviewing quoting, eval, set -euo pipefail, traps, temporary files, privilege or sudo use, or secrets in shell code.
---

<!--
Vendored from https://github.com/konstruktoid/agent-instructions-skills
skills/bash/bash-secure-scripting/SKILL.md
Upstream commit: a05445ea232a635d1803138a365d7a6868d693d2
Do not edit locally; re-vendor from upstream instead.
-->

# bash-secure-scripting

## Purpose

Produce Bash that fails loudly instead of silently, cannot be steered by the data it processes, and
leaves nothing behind when it exits early. This skill is a triage layer: it states the baseline
every script must meet, routes the change to the detail that applies, then holds the result to a
bounded verify loop built on `shellcheck` and `bash -n`.

A shell script is a program that runs with its caller's privileges and passes its inputs to other
programs as code. Treat one as production software, not as a note to the operating system.

## When to use this

- Creating or editing any script with a Bash shebang, a `.sh` or `.bash` file, or a sourced shell
  library.
- Writing shell that runs somewhere other than a file: a `run:` step in CI, a container
  `ENTRYPOINT`, `ExecStart=` in a systemd unit, a crontab entry, a git hook, a package
  post-install script.
- Reviewing or changing quoting, `eval`, `set` options, traps, temporary files, `PATH`, `sudo` or
  other privilege changes, file permissions, or credential handling in shell code.
- Auditing an existing script before it is given more privilege, more input, or a schedule.

## When NOT to use this

- Scripts that must run under POSIX `sh` (`dash`, `ash`, a Debian maintainer script, an initramfs
  hook). The guidance here assumes Bash features that those shells do not have. Hold such a script
  to POSIX and to ShellCheck's `SC3xxx` checks instead.
- Shell code in another language's string, such as a Python `subprocess` call. That is the calling
  language's problem first; use its own security skill.
- One-off interactive commands that are not being written into a file or a pipeline.

## Steps

1. Orient before changing anything. Read the scripts already in the repository, plus
   `.shellcheckrc`, `.editorconfig`, `.pre-commit-config.yaml`, and any `Makefile` or CI step that
   lints or runs them. Match what is there: shebang form, whether functions are used, how errors
   are reported, where helpers are sourced from. Check `CONTRIBUTING.md`, `CLAUDE.md`, or
   `AGENTS.md` for rules the repository sets for itself.
2. Read `instructions/bash_coding_instructions.md` and follow it. It is the single source of truth
   for the `shellcheck`, `bash -n`, and formatter workflow, and for the layout and naming rules.
3. Apply the baseline below to every script touched. It does not depend on the change type.
4. Match the change against the triage table and read the reference files that apply. Read only
   what applies; the table is an index, not a reading list.
5. Write or modify the script, then run the verify loop until it is clean or the bound is reached.
6. State the reason for any deliberate exception, such as an `eval`, a `|| true`, or a
   `# shellcheck disable`, in a comment on the line it applies to and in the pull request
   description.

## The baseline

Every script, without exception:

- **Start in strict mode.** `set -Eeuo pipefail` on the line after the header comment. `-E` makes
  an `ERR` trap apply inside functions, subshells, and command substitutions, which plain `-e`
  does not. Add `shopt -s inherit_errexit` where the target is Bash 4.4 or later.
- **A sourced library sets nothing.** Strict mode belongs to the entrypoint that runs. A library
  runs in the caller's shell, so `set`, `shopt`, `trap`, and `IFS` at its top level silently
  rewrite the behavior of every script that sources it, including ones written to run without
  `errexit`. A library defines functions and constants, returns a status, and leaves the caller's
  options and traps as it found them. Where a function needs an option, set it inside that
  function and restore the previous value before returning.
- **Know what strict mode does not catch.** `errexit` is ignored for commands in a condition, in
  `&&` or `||` chains other than the final command, in a pipeline other than the last element, and
  under `!`. Strict mode is a backstop, not a substitute for checking the commands whose failure
  matters. See [references/strict-mode.md](references/strict-mode.md).
- **Quote every expansion that can hold data**, and hold lists in arrays expanded as
  `"${array[@]}"`. Never assemble a command in a string and run it by expanding the string.
- **Never pass untrusted data to `eval`**, to `bash -c`, to an `ssh` remote command, or to any
  other construct that re-parses it as shell. Validate input against an allowlist pattern at the
  boundary, and reject rather than sanitize.
- **Clean up on every exit path.** Create temporary files and directories with `mktemp`, and remove
  them from a `trap … EXIT` installed *before* the `mktemp` that creates them, not at the end of
  the script. A trap installed on the next line still leaves a window in which a signal loses the
  path; a cleanup guarded on an empty variable is safe to install first.
- **Fail closed.** A check that cannot be completed is a failure, not a pass. Give each failure
  path a deliberate exit status.
- **Control the environment where it matters.** A script that runs privileged, from `cron`, from a
  systemd unit, or through `sudo` sets its own `PATH` and does not inherit behavior-changing
  variables from its caller.
- **Keep secrets out of the process table and the logs.** Never pass a credential as a command-line
  argument, never `set -x` around one, and never write one to a file the repository tracks.
- **Never make a shell script setuid or setgid.** No configuration makes this safe. Use `sudo` with
  a specific, argument-constrained rule instead.
- **Never pipe a downloaded artifact into a shell.** `curl … | bash` executes whatever the server
  returns, on redirect, on compromise, and on a truncated response.

A script meeting the baseline:

```bash
#!/usr/bin/env bash
#
# Archive yesterday's logs for one service into the retention directory.

set -Eeuo pipefail
shopt -s inherit_errexit

# Runs from cron as root: the environment is the caller's, so set what matters.
PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
export PATH
export LC_ALL=C
export TMPDIR=/var/tmp        # not a caller-chosen directory
umask 077

readonly PROGNAME="${0##*/}"
readonly RETENTION_DIR="/var/backups/logs"

# Script scope, not local to main: the EXIT trap runs after main has returned.
workdir=''

err() {
  printf '%s: %s\n' "${PROGNAME}" "$*" >&2
}

cleanup() {
  if [[ -n ${workdir} && -d ${workdir} ]]; then
    rm -rf -- "${workdir}"
  fi
  return 0
}

# Clean up, then die of the signal rather than reporting a status of our own, so a
# caller and a supervisor see the 128+n they are waiting for.
on_signal() {
  local sig="$1"
  cleanup
  trap - EXIT "${sig}"
  kill -s "${sig}" -- "$$"
}

# Archives the log directory of one service into a caller-provided directory.
# Globals: RETENTION_DIR
# Arguments: service name matching ^[a-z][a-z0-9_-]*$, work directory
# Returns: 0 on success, 2 on invalid input
archive_service() {
  local service="$1"
  local workdir="$2"
  local archive

  if [[ ! ${service} =~ ^[a-z][a-z0-9_-]*$ ]]; then
    err "invalid service name: ${service}"
    return 2
  fi

  archive="${RETENTION_DIR}/${service}-$(date -u +%Y%m%d).tar.gz"
  tar --create --gzip --file "${workdir}/archive.tar.gz" -- "/var/log/${service}"
  mv -- "${workdir}/archive.tar.gz" "${archive}"
}

main() {
  if (($# != 1)); then
    err "usage: ${PROGNAME} SERVICE"
    return 64
  fi

  # Traps first: a signal arriving between mktemp and the trap would leave the
  # directory behind. cleanup tolerates the empty workdir until mktemp assigns it.
  trap cleanup EXIT
  trap 'on_signal INT' INT
  trap 'on_signal TERM' TERM
  workdir="$(mktemp -d)"

  archive_service "$1" "${workdir}"
}

main "$@"
```

Five properties of that skeleton are easy to get wrong:

- Cleanup belongs on `EXIT`, which runs when `errexit` aborts the script. A `RETURN` trap does not:
  when a command inside a function fails under `errexit`, the shell exits without running that
  function's `RETURN` trap.
- `EXIT` alone is not enough for a signal. An interrupted script should die of the signal it
  received, so a caller or a supervisor reads the 128+n status it is waiting for. Trapping `INT`
  and `TERM`, cleaning up, restoring the default disposition with `trap - EXIT "${sig}"`, and
  re-raising with `kill -s` does that. Handling the signal without re-raising is worse than not
  trapping it: `cleanup` returns 0 as the trap's last command, so a script killed mid-run reports
  success.
- The trap body is evaluated when the trap fires, in the script's scope. A trap naming a variable
  that was `local` to a function runs after that function has returned, so the name is unset and,
  under `nounset`, the cleanup itself fails and removes nothing. Keep the path in a script-scope
  variable, as above.
- Cleanup returns success even when there was nothing to clean. Written as
  `[[ -n ${workdir} ]] && rm -rf -- "${workdir}"`, the function returns 1 whenever the directory
  is absent, and as the last command in an `EXIT` trap that becomes the script's exit status: a
  run that succeeded reports failure.
- The environment is set before anything uses it. This script archives `/var/log` and writes under
  `/var/backups` as root, so an inherited `PATH` decides which `tar`, `date`, and `mktemp` run, and
  an inherited `TMPDIR` decides where `mktemp -d` puts the data. Set both, plus `umask`, at the top
  rather than trusting whoever invoked the script. See
  [references/environment.md](references/environment.md).

See [references/error-handling.md](references/error-handling.md) for the signal cases `EXIT` alone
misses.

## Triage: which reference to read

| The change touches | Read |
|---|---|
| `set` options, `shopt`, pipelines whose failure matters, `PIPESTATUS` | [references/strict-mode.md](references/strict-mode.md) |
| A command in a condition, a `&&`/`\|\|` chain, `local x=$(…)`, or a subshell | [references/strict-mode.md](references/strict-mode.md) |
| `IFS`, word splitting, globbing behavior, `read` loops | [references/strict-mode.md](references/strict-mode.md) |
| `trap`, cleanup, signals, `exit` codes, retries, timeouts | [references/error-handling.md](references/error-handling.md) |
| Concurrency, lock files, a script that can run twice at once | [references/error-handling.md](references/error-handling.md) |
| Logging, progress output, anything written to stdout or stderr | [references/error-handling.md](references/error-handling.md) |
| Command-line arguments, `read`, environment input, API or file data | [references/untrusted-input.md](references/untrusted-input.md) |
| `eval`, `bash -c`, `ssh host "$cmd"`, `xargs`, `find -exec`, `awk`/`sed` scripts built from data | [references/untrusted-input.md](references/untrusted-input.md) |
| Filenames from a glob, `find`, or user input; paths joined from data | [references/untrusted-input.md](references/untrusted-input.md) |
| SQL, `curl` URLs, JSON, or any string built for another interpreter | [references/untrusted-input.md](references/untrusted-input.md) |
| `PATH`, exported variables, `sudo`, `su`, `doas`, dropping privileges | [references/environment.md](references/environment.md) |
| `cron`, systemd units, container entrypoints, CI steps, git hooks | [references/environment.md](references/environment.md) |
| `source`ing a file, `BASH_ENV`, `ENV`, `LC_*`, `umask`, dependency checks | [references/environment.md](references/environment.md) |
| Temporary files, `mktemp`, `/tmp`, symlinks, `rm -rf`, file modes | [references/filesystem.md](references/filesystem.md) |
| `cd`, relative paths, `>` redirection over an existing file, atomic writes | [references/filesystem.md](references/filesystem.md) |
| Downloading an artifact, verifying a checksum or signature | [references/filesystem.md](references/filesystem.md) |
| Passwords, tokens, API keys, SSH keys, `.env` files, `curl` authentication | [references/secrets.md](references/secrets.md) |
| `set -x`, debug output, transcripts, anything committed that captured a run | [references/secrets.md](references/secrets.md) |
| Generating a password, token, or random identifier | [references/secrets.md](references/secrets.md) |

If the change matches nothing in the table, the baseline and the verification checklist still
apply.

## Verify

Never declare a shell change done from the edit alone. A script that parses is not a script that
runs, and a script that runs on the happy path is not a script that fails safely.

Run, in this order, through the repository's own entry point where one exists (`make lint`,
`pre-commit run --all-files`, the CI step) rather than a bare invocation:

1. **`shellcheck`** on every script touched, with `-x` where the script sources another file so the
   source is resolved rather than silenced. Fix findings; do not suppress them. Where the
   repository has no ShellCheck configuration, run it with defaults and report what it found.
2. **`bash -n`** on every script touched, which parses the whole file including branches a test run
   never reaches.
3. **The repository's formatter**, if one is configured, in diff mode (`shfmt -d`).
4. **The script itself**, on a representative input, in a disposable location. Confirm the exit
   status, not only the output. Then run at least one failure path: a missing file, an invalid
   argument, a command that returns non-zero. Confirm the script stops, reports to stderr, exits
   non-zero, and leaves no temporary files behind. For a destructive script, run it against a
   scratch directory or through its dry-run mode; never verify against real data.
5. **The repository's test suite**, if it has one for shell (`bats`, `shunit2`, a `make test`
   target). Adding coverage is the `bash-testing` skill's subject
   (`.agents/skills/bash-testing/SKILL.md`).

### The bounded loop

One **attempt** is one full fix-and-rerun cycle: apply fixes for the findings from the previous
run, then rerun every check above to completion. Reading output, or re-reading a file without
changing anything, is not an attempt.

- Baseline the loop at 3 attempts.
- Continue past 3 only while making measurable progress, meaning each cycle ends with strictly
  fewer findings than the one before it.
- Stop early, before 3 attempts, if the loop is oscillating: the same findings recur, the count
  stops dropping, or a fix for one finding reintroduces another.
- When stopping for either reason, report to the user rather than proceeding or silently giving up.
  Name the failing check, include its output, and state what was tried.

Suppress a ShellCheck finding only with a directive naming the specific code, on the line above the
one it applies to, with a reason. Never add a file-level or repository-wide `disable` to reach a
clean run.

## Verification checklist

- [ ] Verify loop run to a clean result, or stopped under the rules above with unresolved issues
      reported, naming the failing check and its output
- [ ] `shellcheck` clean on every script touched, with `-x` where files are sourced, and no new
      suppression that lacks a code and a reason
- [ ] `bash -n` clean on every script touched
- [ ] Formatter reports no diff, where the repository configures one
- [ ] The script was executed on a representative input and on at least one failure path, with the
      exit status checked and no temporary files left behind
- [ ] `set -Eeuo pipefail` present in every entrypoint, absent from every sourced library along with
      any other change to the caller's options or traps, and every command whose failure matters in
      a condition, a `&&`/`||` chain, or a pipeline is checked explicitly rather than left to
      `errexit`
- [ ] Every expansion that can hold data is quoted, lists are arrays, and no command is built by
      concatenating a string
- [ ] No untrusted data reaches `eval`, `bash -c`, an `ssh` remote command, or a string interpreted
      by another language, and every input is validated against an allowlist at the boundary
- [ ] Temporary files created with `mktemp` and removed by a trap installed at creation time
- [ ] Privileged, scheduled, or hook-invoked scripts set their own `PATH` and do not trust inherited
      environment variables
- [ ] No credential in a command-line argument, in `set -x` output, in a log, or in a tracked file
- [ ] File modes are least-privilege, and no shell script is setuid or setgid
- [ ] Destructive operations are guarded by an allowlisted parent or a `mktemp -d` directory, not by
      `${dir:?}` alone, and the script is safe to rerun after a partial failure
- [ ] Nothing committed carries user or system information: no home-directory paths, usernames,
      uids, hostnames, internal IPs, or real email addresses in scripts, fixtures, or captured output
- [ ] Every reference file matched in the triage table was read and applied

## References

Paths starting `instructions/` are relative to this library's root. When this skill is installed as
a Claude Code plugin, read them at `${CLAUDE_PLUGIN_ROOT}/instructions/`, which resolves to the
installed copy.

- `instructions/bash_coding_instructions.md`: the `shellcheck`, `bash -n`, and formatter baseline,
  plus the layout, naming, and style rules this skill assumes.
- [references/strict-mode.md](references/strict-mode.md): what `set -Eeuo pipefail` does and does
  not cover, `shopt` options, `PIPESTATUS`, `IFS`, and the subshell cases that swallow failures.
- [references/error-handling.md](references/error-handling.md): traps, cleanup, signals, exit
  codes, retries, timeouts, locking, and diagnostics.
- [references/untrusted-input.md](references/untrusted-input.md): injection through `eval` and
  other interpreters, argument validation, and hostile filenames.
- [references/environment.md](references/environment.md): `PATH`, inherited variables, privilege,
  `umask`, locale, dependency checks, and the non-interactive contexts a script runs in.
- [references/filesystem.md](references/filesystem.md): temporary files, TOCTOU and symlink
  attacks, destructive commands, permissions, atomic writes, and artifact verification.
- [references/secrets.md](references/secrets.md): where credentials leak in shell, how to pass them
  safely, and generating them.

### Normative

Cite these as standards.

- GNU, [Bash Reference Manual](https://www.gnu.org/software/bash/manual/bash.html)
- Google, [Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
- ShellCheck, [wiki and check index](https://www.shellcheck.net/wiki/)
- OWASP, [OS Command Injection Defense Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/OS_Command_Injection_Defense_Cheat_Sheet.html)

### Background

Useful orientation, but not authoritative. Do not cite these as standards; where they conflict with
a normative source, the normative source wins.

- Greg's Wiki, [BashPitfalls](https://mywiki.wooledge.org/BashPitfalls) and
  [BashFAQ](https://mywiki.wooledge.org/BashFAQ)
- FOSS Linux, [Hardening Bash Scripts](https://www.fosslinux.com/101589/bash-security-tips-securing-your-scripts-and-preventing-vulnerabilities.htm)
- Aaron Maxwell, [Unofficial Bash Strict Mode](http://redsymbol.net/articles/unofficial-bash-strict-mode/)
