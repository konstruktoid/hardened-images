<!--
Vendored from https://github.com/konstruktoid/agent-instructions-skills
skills/bash/bash-secure-scripting/references/strict-mode.md
Upstream commit: f4696ac18174422ba873bac1630628d49123c7c0
Do not edit locally; re-vendor from upstream instead.
-->

# Strict mode, and what it does not cover

`set -Eeuo pipefail` is the starting line of a Bash script, not a guarantee. It removes the most
common ways a script continues after a failure, and it has documented exceptions that hide the
rest. Knowing the exceptions is the point of this file.

## What each option does

| Option | Name | Effect |
|---|---|---|
| `-e` | `errexit` | Exit when a pipeline, list, or compound command returns non-zero, subject to the exceptions below. |
| `-u` | `nounset` | Treat expansion of an unset variable or parameter as an error. |
| `-o pipefail` | `pipefail` | A pipeline returns the status of the last command that exited non-zero, instead of only the rightmost one. |
| `-E` | `errtrace` | An `ERR` trap is inherited by shell functions, command substitutions, and subshells. Without it, a trap set at the top level never fires inside a function. |
| `-T` | `functrace` | The same inheritance for `DEBUG` and `RETURN` traps. Needed only when tracing or profiling. |
| `-x` | `xtrace` | Print each command before running it. A debugging aid that prints expanded arguments, including credentials. See [secrets.md](secrets.md). |
| `-C` | `noclobber` | Refuse to truncate an existing file with `>`. Useful in a script that writes results; `>\|` overrides it deliberately. |

`shopt -s inherit_errexit` extends `errexit` into command substitutions. Without it, the subshell
in `out=$(step_one; step_two)` continues after `step_one` fails and the assignment succeeds:

```bash
set -euo pipefail
out=$(false; echo "this still runs")   # assignment succeeds, out="this still runs"

shopt -s inherit_errexit
out=$(false; echo "never reached")     # the script exits here
```

It requires Bash 4.4 or later. Where the target may be older, check the command substitution's
status explicitly instead.

## Where errexit is ignored

The manual lists the cases. The shell does not exit when the failing command is:

- part of the condition of `while`, `until`, or `if`;
- any command in a `&&` or `||` list except the last one;
- any command in a pipeline except the last, subject to `pipefail`;
- a command whose status is inverted with `!`.

The consequence people miss is that these contexts disable `errexit` for everything they call,
including the whole body of a function:

```bash
process() {
  false           # under errexit this would abort
  echo "reached"  # but it prints, because of how process is called below
}

process || echo "failed"   # errexit is ignored inside process
```

The function runs to completion and reports success. `shellcheck -o check-set-e-suppressed` reports
this as `SC2310`. When a function must fail on its first error, call it plainly and let
`errexit` work, or check statuses inside it explicitly.

## Capturing a status without losing errexit

Three patterns cover nearly everything:

```bash
# 1. Failure is expected: accept the one status that means it, not every failure.
#    `grep -q pattern file || true` also swallows status 2, which is a missing or
#    unreadable file or an invalid pattern, and reports it as a clean no-match.
status=0
grep -q pattern file || status=$?
case "${status}" in
  0) found=1 ;;
  1) found=0 ;;   # documented: no match
  *) err "grep failed on file with status ${status}"; return 1 ;;
esac

# 2. Failure needs a branch.
if ! systemctl is-active --quiet "${unit}"; then
  err "unit ${unit} is not running"
  return 1
fi

# 3. The status itself is needed.
rc=0
run_migration || rc=$?
case "${rc}" in
  0) ;;
  3) err "migration already applied" ;;
  *) err "migration failed with status ${rc}"; return "${rc}" ;;
esac
```

Never write a bare `|| true` on a command whose failure matters. It is the single most common way a
strict-mode script becomes a silent-failure script.

## pipefail and PIPESTATUS

`pipefail` makes a pipeline fail when any element fails, which is almost always what a script
means. It also makes `cmd | head -1` fail when `head` closes the pipe early and `cmd` dies of
`SIGPIPE`, so a pipeline that ends in `head`, `grep -q`, or `tee` to a closing reader needs
thought rather than a reflexive `|| true`.

When the status of a specific element matters, read `PIPESTATUS` immediately and copy it, because
the next command overwrites it, including `[`:

```bash
set -o pipefail
producer | consumer
statuses=("${PIPESTATUS[@]}")   # copy first, inspect afterwards
if ((statuses[0] != 0)); then
  err "producer failed with status ${statuses[0]}"
fi
```

## nounset details

- Reference an optional positional parameter as `"${1:-}"`, and an optional variable as
  `"${VAR:-default}"`. A bare `"$1"` aborts the script when the argument is absent, which is
  correct only when the argument is mandatory.
- `"${array[@]}"` on an empty array is safe from Bash 4.4 onward. On older versions it triggers
  `nounset`, so a script targeting Bash 3.2 needs `${array[@]+"${array[@]}"}`.
- `nounset` catches a typo in a variable name, which is its main value. It does not catch a
  variable that is set but empty. Use `"${VAR:?message}"` where an empty value is also invalid.

## Globbing options

| Option | Effect | When to set it |
|---|---|---|
| `shopt -s nullglob` | A pattern matching nothing expands to nothing instead of to itself | Before looping over a glob that may match nothing. |
| `shopt -s failglob` | A pattern matching nothing is an error | When a missing match means the script's assumptions are wrong. |
| `shopt -s globstar` | `**` matches across directory levels | Recursive traversal, Bash 4.0 or later. Note that it follows symlinked directories. |
| `shopt -s extglob` | Extended patterns such as `!(…)` and `+(…)` | Pattern matching that would otherwise need an external tool. |
| `shopt -s dotglob` | Globs match dotfiles | Copy or cleanup loops that must not skip hidden files. |
| `shopt -s lastpipe` | The last element of a pipeline runs in the current shell | Rarely. It works only with job control off, and process substitution is clearer. |

Without `nullglob`, `for f in ./*.log` iterates once with `f` set to the literal `./*.log` when no
file matches, and the body then operates on a non-existent path. Set the option, or test with
`[[ -e ${f} ]]` inside the loop.

`set -f` (`noglob`) disables filename expansion entirely. It is a blunt fix for unquoted expansion;
quote the expansion instead.

## IFS

`IFS` controls word splitting of unquoted expansions and how `read` splits a line. Its default is
space, tab, newline.

The "unofficial strict mode" advises `IFS=$'\n\t'` at the top of a script. It reduces the damage
from an unquoted expansion containing spaces, but it is a global change that surprises later
readers, breaks code that relies on splitting on spaces, and does nothing about globbing. Prefer
the two habits that make it unnecessary:

- Quote every expansion, and hold lists in arrays.
- Set `IFS` per command, where it is visible, rather than globally:

  ```bash
  while IFS= read -r line; do        # IFS= keeps leading and trailing whitespace
    printf 'line: %s\n' "${line}"
  done < "${input_file}"

  IFS=':' read -r -a path_entries <<< "${PATH}"   # scoped to this one read
  ```

If a repository already sets `IFS=$'\n\t'` at the top of its scripts, follow the convention rather
than changing it as a side effect of an unrelated edit.

## Subshells swallow state and failures

- A pipeline runs each element in a subshell, so `count=0; find … | while read -r f; do
  ((count++)); done` leaves `count` at zero. Feed the loop with `done < <(find …)` or read into an
  array with `mapfile -t`.
- `local var="$(command)"` masks the command's exit status, because the status reported is
  `local`'s. Declare first, assign second: `local var; var="$(command)"`. ShellCheck reports this
  as `SC2155`.
- The same applies to `declare`, `export`, and `readonly` combined with a command substitution.
- Changes to variables, the working directory, and traps inside `( … )` are discarded when it
  exits.

## Verify strict-mode assumptions by running the failure path

Strict mode is only demonstrated by a failing run. Run the script once with a step forced to fail,
for example by pointing it at a missing file, and confirm that it stops where expected and exits
non-zero. A script that has only ever been run on the happy path has untested error handling.
