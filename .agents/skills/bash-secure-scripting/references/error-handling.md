<!--
Vendored from https://github.com/konstruktoid/agent-instructions-skills
skills/bash/bash-secure-scripting/references/error-handling.md
Upstream commit: f4696ac18174422ba873bac1630628d49123c7c0
Do not edit locally; re-vendor from upstream instead.
-->

# Failure handling: traps, cleanup, exit codes, locking

A script that stops halfway is the normal case, not the exceptional one. What matters is what it
leaves behind and what it tells its caller.

## Cleanup with a trap

Install the trap immediately after creating the resource, never at the end of the script:

```bash
workdir=''      # script scope: the trap body runs after main has returned

# Removes the work directory. Safe to run more than once, and before it exists.
cleanup() {
  if [[ -n ${workdir} && -d ${workdir} ]]; then
    rm -rf -- "${workdir}"
  fi
  return 0
}

main() {
  workdir="$(mktemp -d)"
  trap cleanup EXIT
  ...
}
```

Rules that follow from how traps behave:

- **`EXIT` is the cleanup signal.** It runs when the script ends normally, when `errexit` aborts
  it, and when a caught signal terminates it.
- **`RETURN` is not a substitute inside a function.** When a command in a function fails under
  `errexit`, the shell exits without running that function's `RETURN` trap. Anything that must be
  removed belongs on `EXIT`.
- **The trap body is evaluated when it fires, not when it is installed.** It runs in the script's
  scope, so a variable that was `local` to the function that installed the trap is already gone.
  Under `nounset` the trap then fails and cleans up nothing, which is a leak that only appears on
  the failure path. Keep anything a trap names in a script-scope variable.
- **One trap per signal.** A second `trap … EXIT` replaces the first. Where several resources need
  releasing, extend one `cleanup` function rather than installing more traps. `trap -p EXIT` prints
  what is currently installed.
- **Cleanup must be idempotent and must not fail.** It can run at any point, including before the
  resource exists. Guard every removal with a test, and do not let a failure inside cleanup mask
  the original error.
- **Guard with `if`, not with `test && command`.** A `[[ -n ${workdir} ]] && rm …` line returns 1
  when the resource is absent, and that status is the function's status. As the last command in an
  `EXIT` trap it becomes the script's exit status, so a successful run reports failure because
  there was nothing to remove. Use an `if` block and `return 0`, as above.
- **`SIGKILL` and `SIGSTOP` cannot be trapped.** Anything that must survive a hard kill needs a
  location that is cleaned externally, such as a `mktemp -d` under a systemd `RuntimeDirectory`, or
  a startup sweep of the script's own stale files.

## Signals

`EXIT` alone leaves two gaps. A blocking command such as `sleep` or `curl` is not interrupted
promptly by a signal the script does not trap, and the exit status of a script terminated by
`SIGINT` does not necessarily report the signal. Both are fixed by trapping the signal, cleaning
up, and re-raising it with the default disposition:

```bash
on_signal() {
  local signal="$1"
  cleanup
  trap - "${signal}"        # restore the default handler for the signal received
  kill -s "${signal}" "$$"  # die of that signal: 130 for INT, 143 for TERM
}
trap 'on_signal INT' INT
trap 'on_signal TERM' TERM
```

Pass the signal name into the handler and re-raise the one that arrived. A handler shared between
`INT` and `TERM` that always sends `INT` reports every termination as 130, so a caller that
distinguishes a user interrupt from a scheduler timeout sees the wrong one.

For a script whose work is done by background children, kill the process group in the handler
(`kill -- -$$` from a script that is a process group leader) so children do not outlive it.

## Reporting the failure

An `ERR` trap turns a bare non-zero status into a located error message. It needs `set -E` to fire
inside functions:

```bash
set -Eeuo pipefail
trap 'err "failed at line ${LINENO}: ${BASH_COMMAND}"' ERR
```

`BASH_COMMAND` holds the command that failed, and `BASH_SOURCE`/`FUNCNAME`/`BASH_LINENO` give the
call stack. It holds the command *before* expansion, so `curl -H "Authorization: Bearer ${token}"`
reaches the trap with `${token}` unexpanded and the value is not disclosed. A secret written as a
literal argument is disclosed, because the literal is the command text; that is one more reason not
to put one in a command line. Do not print variable values from an `ERR` trap without knowing what
they hold; see [secrets.md](secrets.md).

Diagnostics go to standard error, always. Standard output is the script's data, and a caller
capturing it in `$(…)` receives every progress message mixed into the result. When the script runs
from `cron` or a systemd unit, `logger` sends its diagnostics to the journal instead of to a mail
spool nobody reads.

## Exit codes are an interface

| Status | Meaning |
|---|---|
| 0 | Success, and nothing else. |
| 1 | General failure. |
| 2 | Misuse of the script: bad arguments, missing required option. |
| 64 to 78 | The `sysexits.h` range, when a script wants to distinguish usage (64), data (65), no input (66), unavailable service (69), and configuration (78) errors. |
| 126 | Command found but not executable. |
| 127 | Command not found. |
| 128 + n | Terminated by signal n, so 130 for `SIGINT` and 143 for `SIGTERM`. |

Decide what each failure path returns rather than letting the last command decide for it. Status is
truncated modulo 256, so never `exit` a value above 255 or a negative one. Use `return` inside
functions and `exit` only from `main` or the top level, so a sourced library cannot terminate its
caller's shell. A common helper:

```bash
die() {
  local status="$1"
  shift
  err "$*"
  exit "${status}"
}
```

## Timeouts

Any command that talks to a network, a device, or another host needs a bound. Without one, a hung
call turns a scheduled script into a process that accumulates one copy per run.

```bash
timeout 30s remote_command          # exits 124 when the limit is reached
curl --max-time 30 --retry 0 -fsS   # -f so an HTTP error is a non-zero status
ssh -o ConnectTimeout=10 -o BatchMode=yes
```

`curl` without `-f` (or `--fail-with-body`) exits 0 on a 404 and writes the error page to the
output file, which is how a script ends up installing an HTML page as a binary.

## Retries

Retry only operations that are safe to repeat, and only transient failures. Bound the attempts and
back off. Where the tool distinguishes transient failures itself, let it: `curl --retry` retries
408, 429, and the 5xx statuses, honors `Retry-After`, and backs off exponentially, while a shell
loop around `curl -f` also retries 401, 403, and 404, which will never succeed.

```bash
fetch() {
  local url="$1" dest="$2" tmp

  # Same filesystem as the destination, so the move at the end is atomic and a
  # failed transfer never leaves a partial file under the final name.
  tmp="$(mktemp -- "${dest}.XXXXXX")"

  if ! curl --proto '=https' --tlsv1.2 -fsS --max-time 30 \
      --retry 3 --retry-delay 1 --retry-connrefused -o "${tmp}" -- "${url}"; then
    rm -f -- "${tmp}"
    err "download of ${dest} failed"   # not the URL: it can carry a token
    return 1
  fi

  # Every path out of here removes the temporary. errexit would abandon it on a
  # failing mv, leaving a stray `${dest}.XXXXXX` beside the real file.
  if ! mv -- "${tmp}" "${dest}"; then
    rm -f -- "${tmp}"
    err "install of ${dest} failed"
    return 1
  fi
}
```

Two things that example is doing deliberately:

- **The destination is written once, by `mv`.** `curl -o "${dest}"` leaves whatever arrived before
  the failure in place, so the next reader gets a truncated file with no indication that anything
  went wrong. `--remove-on-error` covers the same ground for `curl` specifically; the temporary
  file and `mv` work for any producer.
- **The diagnostic names the destination, not the URL.** A URL routinely carries basic-auth
  credentials, an access token, or a signed query string, and stderr from a `cron` job or a CI step
  is retained and often readable by more people than the credential is.

For a command with no retry logic of its own, wrap it in a bounded loop, and check the status
before backing off so a permanent failure fails immediately:

```bash
retry() {
  local attempts="$1" delay=1 attempt status=0
  shift
  for ((attempt = 1; attempt <= attempts; attempt++)); do
    status=0
    "$@" || status=$?
    if ((status == 0)); then
      return 0
    fi
    is_transient "${status}" || return "${status}"
    sleep "${delay}"
    delay=$((delay * 2))
  done
  return "${status}"
}
```

`is_transient` is the part that has to be written per command: it decides which exit statuses are
worth another attempt. Without it the loop turns a permanent error into the same error, several
attempts and several sleeps later. An unbounded `while ! command; do sleep 1; done` is not a retry,
it is a hang.

## Concurrency

A script that can be started twice, by `cron`, by a hook, or by two people, needs a lock. `flock`
holds it on a file descriptor, so the kernel releases it when the process dies, including on
`SIGKILL`:

```bash
readonly LOCK_FILE="/var/lock/${0##*/}.lock"

exec 9>"${LOCK_FILE}"
if ! flock -n 9; then
  err "another instance is running"
  exit 0     # or exit 1, depending on whether a skipped run is an error
fi
```

Decide deliberately whether a concurrent run should wait (`flock -w 60 9`), skip, or fail. Do not
build a lock out of a PID file plus `kill -0`: it races, and a stale file from a killed process
blocks every later run. Where `flock` is unavailable, `mkdir` is the portable atomic primitive,
with the same staleness problem to solve.

## Partial completion

Assume every run can stop between any two commands.

- Write to a temporary file in the destination filesystem and `mv` it into place. `mv` within a
  filesystem is atomic, so a reader sees either the old file or the new one, never a truncated one.
- Make operations conditional on their current state (`mkdir -p`, `id -u "${user}" >/dev/null ||
  useradd …`) so a rerun repairs rather than duplicates.
- Order the steps so the destructive one comes last, after everything it depends on has succeeded.
- Where a sequence cannot be made idempotent, record progress in a marker file and check it on
  entry.
