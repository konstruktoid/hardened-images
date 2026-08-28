<!--
Vendored from https://github.com/konstruktoid/agent-instructions-skills
skills/bash/bash-secure-scripting/references/environment.md
Upstream ref: v0.1.0
Upstream commit: 994be479cf1d44d5ee69d0334da07e923d8dee2e
Do not edit locally; re-vendor with tools/vendor-agent-standards.sh instead.
-->

# Environment, PATH, and privilege

A script inherits its environment from whoever started it. Where the script has more privilege than
that caller, or runs unattended, the environment is input and needs the same treatment as any other
input.

## Contents

- PATH
- Variables the caller controls
- Privilege
- umask and file modes
- Dependencies
- The contexts a script actually runs in

## PATH

`PATH` decides which program each unqualified command name runs. A script that runs privileged,
from `cron`, from a systemd unit, from a hook, or through `sudo` sets its own:

```bash
PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
export PATH
```

- Never include `.`, an empty element (a leading, trailing, or doubled `:`), or any directory
  writable by a user with less privilege than the script.
- Order matters: the first match wins, so a writable directory early in `PATH` is a complete
  compromise of the script.
- For a small number of critical calls in a privileged script, an absolute path
  (`/usr/sbin/iptables`) removes the question entirely. For everything else, a controlled `PATH`
  plus `command -v` checks is more maintainable than absolute paths throughout.
- `hash -r` clears the remembered command locations if `PATH` changes mid-script.

## Variables the caller controls

Bash and the programs a script calls change behavior based on variables an attacker may set:

| Variable | Effect |
|---|---|
| `BASH_ENV` | A file Bash sources before running a non-interactive script. Arbitrary code, before line 1. |
| `ENV` | The same for POSIX-mode shells and `sh`. |
| `SHELLOPTS`, `BASHOPTS` | Options applied at startup, including `xtrace`. |
| `IFS` | Changes how unquoted expansions and `read` split. |
| `CDPATH` | Makes `cd relative_dir` land somewhere else and print the resolved path to stdout. |
| `GLOBIGNORE` | Removes entries from glob results, so a cleanup loop can be made to skip a file. |
| `LD_PRELOAD`, `LD_LIBRARY_PATH` | Change what code every dynamically linked program runs. |
| `PYTHONPATH`, `PERL5LIB`, `NODE_OPTIONS`, `GEM_PATH` | The same for interpreters the script calls. |
| `TMPDIR` | Redirects `mktemp` and many tools to a directory the caller chose. |
| `LC_ALL`, `LANG`, `TZ` | Change sort order, character classes, and date parsing. |
| `PAGER`, `EDITOR`, `VISUAL`, `GIT_*`, `SSH_*` | Turn a called tool into an execution vector. |

Two defenses, used together:

- Set what the script depends on, explicitly, at the top: `PATH`, `LC_ALL=C` where output is
  parsed, `TMPDIR` where it matters, and `umask`.
- Clear the rest when crossing a privilege boundary. `env -i` starts a child with an empty
  environment, and `sudo` with `env_reset` (the default) and a minimal `env_keep` does the same:

  ```bash
  env -i PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin' LC_ALL=C \
    /usr/local/sbin/privileged-helper -- "${arg}"
  ```

  Set each variable to a literal the script controls. `PATH="${PATH}"` and `HOME="${HOME}"` copy
  the caller's values straight back into the child, which is the thing `env -i` was there to
  prevent. Pass `HOME`, `TMPDIR`, or anything else only when the helper needs it and only as a
  fixed path.

Bash's privileged mode (`bash -p`, `set -p`) ignores `BASH_ENV`, `ENV`, `SHELLOPTS`, `CDPATH`, and
`GLOBIGNORE`, and does not inherit shell functions from the environment. It is worth knowing, but
it is not a substitute for controlling the environment deliberately.

Exported shell functions cross process boundaries in the environment. Do not rely on one being
present, and do not export one into a program running at a different privilege level.

## Privilege

- **Never set the setuid or setgid bit on a shell script.** Linux ignores it for interpreted
  scripts, and where a system honors it the interpreter start-up is a race. Use `sudo` with a
  specific rule instead.
- **A privileged script must not be writable by anyone who cannot already gain that privilege.**
  Root-owned, mode `0755`, or `0700` where its contents are sensitive. The same applies to every
  file it sources and every directory in the path to it.
- **Grant `sudo` access to a command, not to a shell.** A sudoers rule permitting `ALL`, an editor,
  a package manager, or any program with a shell escape is equivalent to full root. Constrain the
  arguments in the rule where the tool allows it, and remember that a rule wildcard is not a
  security boundary.
- **Drop privilege with a tool that does it completely.** `setpriv --reuid=… --regid=… --clear-groups`
  or `runuser -u user -- command`. Avoid `su - user -c "${command}"`, which re-parses the string as
  shell. Confirm supplementary groups are dropped, not only the uid.
- **Check for elevation rather than assuming it.** `((EUID == 0)) || die 77 "must run as root"`, or
  the reverse for a script that must not run as root.
- **Do not prompt for a password inside a loop of `sudo` calls.** Use `sudo -n` and fail with a
  clear message when credentials are absent, so the script does not hang unattended.

## umask and file modes

Set the mask before creating anything, rather than fixing modes afterwards:

```bash
umask 077     # new files 0600, new directories 0700: use for anything sensitive
umask 022     # world-readable output, the normal default
```

`mktemp` creates files as `0600` and directories as `0700` regardless of the mask, which is one
reason to use it. A redirection (`> file`) obeys the mask, so the mask is what protects it.

## Dependencies

Fail immediately with a clear message when a required program is missing, rather than partway
through:

```bash
# Defined before anything that can call it: a guard that aborts while resolving its
# own error helper reports "command not found" instead of the status it documents.
err() {
  printf '%s: %s\n' "${0##*/}" "$*" >&2
}

die() {
  local status="$1"
  shift
  err "$*"
  exit "${status}"
}

require_commands() {
  local cmd missing=()
  for cmd in "$@"; do
    command -v -- "${cmd}" > /dev/null 2>&1 || missing+=("${cmd}")
  done
  ((${#missing[@]} == 0)) || die 69 "missing required commands: ${missing[*]}"
}

require_commands curl jq tar
```

Use `command -v`, not `which`, which is an external program with inconsistent behavior and exit
status (`shellcheck -o deprecate-which` reports it). Where the script relies on GNU-specific
options (`sed -i`, `readlink -f`, `date -d`, `stat -c`, `sort -z`), either test for the GNU variant
or document that the script requires GNU coreutils.

For a Bash feature newer than 3.2, guard on the version rather than failing with a syntax error,
and guard on the version that feature actually needs. `mapfile`, `declare -A`, and `globstar`
arrived in 4.0, but `{fd}>file` and `BASH_XTRACEFD` need 4.1, and `${var@Q}` and
`shopt -s inherit_errexit` need 4.4, so a major-version-only test passes on a Bash that cannot run
the script:

```bash
# Bash 4.0 or later: mapfile, declare -A, globstar.
((BASH_VERSINFO[0] >= 4)) || die 69 'bash 4.0 or later is required'

# Bash 4.4 or later: ${var@Q}, shopt -s inherit_errexit. Compare the minor version too.
((BASH_VERSINFO[0] > 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] >= 4))) ||
  die 69 'bash 4.4 or later is required'
```

Both guards call `die`, so `die` and the `err` it uses must be defined above them, as in
`require_commands` earlier in this section. A guard placed before its helper aborts with
`die: command not found` on exactly the old Bash it was written to detect, and returns 127 rather
than the status it documents. Keep the helper definitions immediately after strict mode, before the
first check that can fail. `die` is the same helper described in
[error-handling.md](error-handling.md).

## The contexts a script actually runs in

- **`cron`**: almost no environment, `PATH` is typically `/usr/bin:/bin`, no TTY, and `%` in a
  crontab line is a newline. Set `PATH` in the script, never assume the working directory, and send
  diagnostics somewhere durable.
- **systemd units**: `ExecStart` needs an absolute path and is not parsed by a shell, so globs,
  pipes, and variable expansion do not work there. Put the logic in the script, not the unit, and
  use `Environment=` or `EnvironmentFile=` for values. `RuntimeDirectory=` gives a temporary
  directory the service manager cleans up.
- **CI steps**: the log is often public and the environment holds secrets. Do not enable `set -x`
  in a step that touches a credential, and do not print the environment.
- **Container entrypoints**: the script is PID 1, so it receives signals no other process handles
  and must `exec "$@"` to hand the process over rather than leaving a shell between the init system
  and the workload.
- **Git hooks**: the environment carries `GIT_DIR` and related variables that redirect git
  commands, and some hooks receive their input on stdin.
- **SSH forced commands**: `SSH_ORIGINAL_COMMAND` is entirely attacker-controlled and must be
  matched against an allowlist, never passed to `eval` or `bash -c`.

Non-interactive shells do not read `~/.bashrc` or `/etc/profile`. Source what the script needs
explicitly, from a path it controls, and do not rely on the user's shell configuration.

The restricted shell (`rbash`) is not a boundary for scripts: it lifts its own restrictions in the
shell it spawns to run a script, and the manual recommends containers, jails, or zones for a
genuinely restricted environment.
