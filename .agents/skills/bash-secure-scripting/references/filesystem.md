<!--
Vendored from https://github.com/konstruktoid/agent-instructions-skills
skills/bash/bash-secure-scripting/references/filesystem.md
Upstream commit: a05445ea232a635d1803138a365d7a6868d693d2
Do not edit locally; re-vendor from upstream instead.
-->

# Files, temporary directories, and destructive commands

Most of what a script does is create, move, and delete files, usually in directories other users
can also write to. The failure modes are predictable names, races, and expansions that produce a
path nobody intended.

## Temporary files

```bash
workdir=''                                   # script scope, so the trap can name it
cleanup() { [[ -n ${workdir} ]] && rm -rf -- "${workdir}"; return 0; }
trap cleanup EXIT                            # installed before anything it removes exists
workdir="$(mktemp -d)"                       # honors TMPDIR, mode 0700
tmpfile="$(mktemp)"                          # mode 0600
tmpfile="$(mktemp -t myscript.XXXXXXXX)"     # named template, at least six X characters
```

- Always `mktemp`. A hand-built name such as `/tmp/build.$$` is predictable, so another user can
  pre-create it, or point it at a file the script then truncates with root privileges.
- `mktemp` creates the file or directory atomically, with a mode no other user can read. That
  atomicity is the security property; the random name alone is not.
- Install the cleanup trap *before* the `mktemp` it cleans up after, not on the line following it.
  Between the two lines the path exists with no trap naming it, and a signal there leaks the
  directory. Declaring the variable empty at script scope first lets the trap be installed early
  and do nothing until there is something to remove. See [error-handling.md](error-handling.md).
- Where the script runs under systemd, prefer the unit's `RuntimeDirectory` or `PrivateTmp`, which
  the service manager creates and removes.
- Create the temporary file in the same filesystem as its destination when the result will be moved
  into place, so the move is atomic rather than a copy.

## Races in shared directories

A test followed by an action is two operations, and anything can change between them:

```bash
[[ -e ${target} ]] || printf '%s\n' "${data}" > "${target}"   # racy
```

Prefer operations that are atomic in the kernel and report failure:

```bash
mkdir -- "${lock_dir}"            # fails if it already exists
set -C; printf '%s\n' "${data}" > "${target}"; set +C   # noclobber: fails if it exists
ln -s -- "${new}" "${link}.tmp" && mv -T -- "${link}.tmp" "${link}"   # atomic replace
mv -n -- "${src}" "${dest}"       # no overwrite
```

Do not follow a path in a directory writable by others without knowing what it points at. Where the
script must act on such a path as a privileged user, open it once and work on that descriptor, or
copy it into the script's own directory first. `rm -rf` on a directory another user can write to
can be redirected by a symlink placed mid-traversal; GNU `rm` guards the common cases, but the
safer answer is not to work in a shared directory at all.

## Destructive commands

```bash
# Two separate checks: :? rejects the empty value, the resolved-path test rejects
# everything else that must not be deleted.
target="$(realpath -- "${build_dir:?build_dir is unset}")"
[[ ${target} == "${BUILD_ROOT}"/?* ]] || die 78 "refusing to remove ${target}"
rm -rf -- "${target}"
```

- Use `${var:?message}` in any `rm`, `mv`, `chown`, `chmod -R`, or `find -delete` path built from a
  variable. Under `set -u` an unset variable already aborts, but `:?` also catches the empty
  string, which is the case that produces `rm -rf /`.
- **`${var:?}` is not a destructive-operation guard on its own.** It rejects unset and empty, and
  nothing else: `/`, `//`, `.`, `..`, `${HOME}`, and `/tmp/..` all pass it and all resolve
  somewhere the script has no business deleting. The guard is the second check — resolve the path
  and confirm it sits under a directory the script owns, either an allowlisted parent as above or
  a directory the script created itself with `mktemp -d`. Delete only paths the script created or
  was configured to manage.
- `rm -rf "${dir}/"*` deletes the contents of `/` when `dir` is empty. ShellCheck reports this as
  `SC2115`; write `"${dir:?}/"*`, and still bound `dir` to an allowlisted parent.
- Pass `--` before every path operand, and prefix globs with `./`, so a filename beginning with a
  hyphen is not read as an option.
- Prefer a narrow `find` over a broad `rm -rf`: `find "${dir:?}" -xdev -mindepth 1 -maxdepth 1
  -name 'build-*' -exec rm -rf -- {} +`. `-xdev` keeps it from crossing into a mounted filesystem.
- Offer a dry-run mode for anything that deletes or overwrites in bulk, and verify against a
  scratch copy before the real data.
- `cd` can fail, and the commands after it then run somewhere else entirely. Write
  `cd -- "${dir}" || die 66 "cannot enter ${dir}"` (`SC2164`), or keep the change scoped in a
  subshell: `( cd -- "${dir}" && make )`.

## Writing files

- Write through a temporary file and `mv` into place, so a reader never sees a partial file and a
  failed run does not destroy the previous version:

  ```bash
  tmp="$(mktemp -- "${dest}.XXXXXX")"
  generate > "${tmp}"
  mv -- "${tmp}" "${dest}"
  ```

- `set -C` (`noclobber`) prevents `>` from truncating an existing file; `>|` overrides it where
  truncation is intended.
- Set the mode with the umask before creation, or use `install -D -m 0600 -- "${tmp}" "${dest}"`,
  rather than creating a file and fixing its mode afterwards. The window between the two is when
  the secret is readable.
- Append with `>>` for logs, and remember that concurrent writers are only safe for small writes on
  a file opened in append mode.

## Trusting a file before reading it

Before a privileged script sources, executes, or reads a file that decides its behavior, confirm
ownership and that it is not writable by others:

```bash
require_secure_file() {
  local path="$1" owner mode
  owner="$(stat -c '%U' -- "${path}")"     # GNU; BSD stat uses -f '%Su'
  mode="$(stat -c '%a' -- "${path}")"
  [[ ${owner} == "$(id -un)" || ${owner} == root ]] || die 77 "${path} is owned by ${owner}"
  [[ ${mode} == 600 || ${mode} == 400 ]] || die 77 "${path} has mode ${mode}, expected 600"
}
```

The check is only as good as the directory holding the file: a file with mode `0600` inside a
world-writable directory can be replaced wholesale. Check the parent directory too where it
matters.

## Downloaded artifacts

```bash
# Under errexit any of these four exits the script, so the temporary needs an owner
# that outlives them. Set the trap before creating anything it removes.
tmp="$(mktemp -- "${dest}.XXXXXX")"
trap 'rm -f -- "${tmp}" "${tmp}.asc"' EXIT

curl --proto '=https' --tlsv1.2 -fsSL --max-time 60 -o "${tmp}" -- "${url}"
printf '%s  %s\n' "${expected_sha256}" "${tmp}" | sha256sum -c -
gpg --verify -- "${tmp}.asc" "${tmp}"      # where the project publishes signatures
mv -- "${tmp}" "${dest}"                   # after this the trap removes nothing
```

- Never `curl … | bash`, `wget -O - … | sh`, or any variant. The shell executes whatever arrives,
  including a truncated response and whatever a compromised or redirected host returns.
- Never disable certificate verification (`curl -k`, `--insecure`, `wget --no-check-certificate`).
  A verification failure is a result, not an obstacle.
- Verify before use, and use `-f` so an HTTP error status is a failure rather than an error page
  written to the output file.
- Download to a temporary file, verify it, then move it into place. A partially downloaded artifact
  must never be reachable under its final name.
