<!--
Vendored from https://github.com/konstruktoid/agent-instructions-skills
skills/bash/bash-secure-scripting/references/secrets.md
Upstream commit: a05445ea232a635d1803138a365d7a6868d693d2
Do not edit locally; re-vendor from upstream instead.
-->

# Credentials in shell scripts

Shell makes secrets visible in more places than most languages: the process table, the trace
output, the shell history, the log the scheduler mails, and the transcript someone pastes into an
issue.

## Where a secret must never appear

- **A command-line argument.** Every user on the host can read it from `ps` and `/proc/<pid>/cmdline`
  while the command runs. This includes `mysql -p"${pass}"`, `curl -u "user:${pass}"`,
  `docker login -p`, and any tool taking `--token`.
- **A script, a repository file, or a container image layer.** A credential in git history is
  compromised for as long as the history exists.
- **A log, a CI transcript, or an error message.** Including through `set -x` and through an `ERR`
  trap that prints variables.
- **A world-readable or group-readable file.** Mode `0600`, owned by the account that uses it.

## Getting a secret into a command safely

Ordered from best to acceptable:

1. **A secret manager or the platform's credential mechanism**: `systemd` `LoadCredential=`, the CI
   system's masked secrets, `vault read`, `aws secretsmanager get-secret-value`, `pass`, `gpg -d`.
2. **Standard input**: `docker login --password-stdin`, `gpg --passphrase-fd 0`,
   `openssl … -passin stdin`, `ssh-add` reading from a prompt.
3. **A file with mode 0600, referenced by path**: `curl --netrc-file`, `curl -H @headerfile`,
   `mysql --defaults-extra-file`, `restic --password-file`, `borg BORG_PASSCOMMAND`.
4. **An environment variable**, where the tool supports one and the alternatives do not apply. It
   stays out of `ps`, but it is inherited by every child process, appears in
   `/proc/<pid>/environ`, and is captured by crash handlers and by `docker inspect`.

Reading one interactively:

```bash
read -r -s -p 'Passphrase: ' passphrase
printf '\n' >&2
```

`-s` suppresses echo; the explicit newline keeps the prompt from running into the next output. If
the script can be interrupted while echo is off, restore it from the trap: `stty echo`.

Loading one from a file, with the permission check from
[filesystem.md](filesystem.md):

```bash
require_secure_file "${credentials_file}"
# shellcheck source=/dev/null
source "${credentials_file}"        # the file is code: it must be trusted and mode 0600
```

Sourcing is convenient and executes the file. Where the file comes from anywhere less trusted than
the script itself, parse the values instead of sourcing them.

## Tracing and debugging

`set -x` prints every command with its arguments expanded, so it prints secrets. In CI, where the
log may be public, this is the most common way a credential escapes.

Turn it off around the sensitive section, and restore the state that was actually there rather than
assuming it was on:

```bash
xtrace_was_on=0
case $- in
  *x*) xtrace_was_on=1 ;;
esac
set +x

status=0
authenticate "${token}" || status=$?

if ((xtrace_was_on)); then
  set -x
fi
((status == 0)) || die "${status}" 'authentication failed'
```

An unconditional `set -x` after the section enables tracing in a script that never had it on, which
is how the credentials in the *next* section reach the log. Capturing the status separately matters
for the same reason: under `errexit` a bare `authenticate "${token}"` that fails exits the script
with tracing still disabled, or, in the naive version, leaves the restore unreached.

Sending the trace elsewhere reduces the audience but does not make tracing safe:

```bash
readonly TRACE_FILE='/var/log/script.trace'   # a root-owned directory, not /tmp

umask 077
rm -f -- "${TRACE_FILE}"        # drops a leftover file or a planted symlink
set -C                          # noclobber: the create fails if it reappeared
: > "${TRACE_FILE}"
set +C

exec {BASH_XTRACEFD}>"${TRACE_FILE}"   # Bash 4.1 or later
set -x
...
set +x
exec {BASH_XTRACEFD}>&-         # close it once tracing is no longer needed
```

`umask` applies only when the file is created. Opening an existing path with `>>` keeps whatever
mode that file already had and follows a symlink to its target, so a pre-created `0644` file, a
symlink into a world-readable location, or a path under a directory someone else can write to
receives the expanded credentials instead. Create the file fresh under `noclobber`, or validate
ownership, file type, and mode `0600` before opening it with the `require_secure_file` check from
[filesystem.md](filesystem.md).

The file receives the same fully expanded commands, secrets included, so it needs a trusted path
that only root can write to, mode `0600`, and a retention policy — it is now a credential store.
Keep tracing disabled around credential handling regardless of where the output goes. `PS4` is
expanded on every traced command, so never build it from data.

An `ERR` or `DEBUG` trap that prints `BASH_COMMAND` prints the expanded command, secrets included.
Print the line number and the function name instead.

Redact deliberately when a value must be logged at all:

```bash
printf 'authenticating with token %s…\n' "${token:0:4}" >&2
```

## Generating secrets

```bash
openssl rand -base64 32
head -c 32 /dev/urandom | base64

# Restricted to an alphabet, from a bounded input.
secret="$(LC_ALL=C tr -dc 'A-Za-z0-9' < <(head -c 512 /dev/urandom))"
secret="${secret:0:32}"
((${#secret} == 32)) || die 70 'could not generate a secret'
```

Use `/dev/urandom` or `openssl rand`. Never `$RANDOM`, which is a 15-bit value from a predictable
generator, and never a value derived from the time, the PID, or a hash of a hostname. Where a
password policy requires a character class, generate more entropy and filter, rather than
constructing the value from small pieces.

Filter from a bounded input, not through `head` at the end of a pipeline. `tr -dc … < /dev/urandom
| head -c 32` reads an endless stream, so `head` exits after 32 bytes and `tr` dies of `SIGPIPE`.
The pipeline then reports 141, and under `set -o pipefail` that aborts the script after the value
was generated correctly. Reading a fixed 512 bytes and truncating with
`${secret:0:32}` leaves no reader to exit early; the length check catches the case where the
filtered result came up short.

Shell has no constant-time comparison. A script that compares a submitted token against a stored
one is doing authentication in the wrong place: move that to a program that can do it properly.

## Containing the damage

- Assume a secret that reached a log, a transcript, a `ps` listing, or git history is compromised.
  Rotate it. Removing the line afterwards does not undo the exposure.
- `shred` does not reliably erase a file on a journaling or copy-on-write filesystem, on flash
  storage, or on any snapshotted volume. Keep secrets out of files that outlive the run instead:
  `mktemp` with `umask 077`, removed by the `EXIT` trap.
- Interactive shells record commands in `HISTFILE`. Do not instruct a user to paste a secret onto a
  command line; have the script prompt for it, or read it from a file.
- Add credential filenames to `.gitignore` in the same change that introduces them, and never
  commit an example file containing a real value.

## Output the repository keeps

Anything a script captures and commits, such as a transcript, a fixture, or generated
documentation, must be normalized first: no tokens, no home-directory paths, no usernames, no
uids, no hostnames, no internal IP addresses, no real email addresses. Use placeholders
(`/path/to/project`, `user@example.com`, RFC 5737 addresses) and derive real values at runtime
(`$HOME`, `id -un`, `hostname`) instead of writing them into the file.
