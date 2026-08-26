<!--
Vendored from https://github.com/konstruktoid/agent-instructions-skills
skills/bash/bash-secure-scripting/references/untrusted-input.md
Upstream ref: v0.1.0
Upstream commit: 994be479cf1d44d5ee69d0334da07e923d8dee2e
Do not edit locally; re-vendor with tools/vendor-agent-standards.sh instead.
-->

# Untrusted input and injection

Shell passes its inputs to other programs as text that those programs parse. Every place a value
crosses into something that parses it, including back into the shell itself, is an injection point.

## Contents

- What counts as untrusted
- Never re-parse data as code
- Arithmetic evaluation is code execution
- Validate at the boundary, with an allowlist
- Paths and traversal
- Hostile filenames
- Other interpreters
- Reading input safely
- Exposure through the command line

## What counts as untrusted

Everything the script did not write itself:

- Positional parameters and options, including from a CI job, a hook, or a systemd unit.
- Environment variables, which the caller controls.
- Filenames, whether from a glob, `find`, or an argument. A filename may contain spaces, newlines,
  quotes, backslashes, globbing characters, and a leading hyphen.
- File contents, including configuration the script reads.
- Anything from the network: an API response, a webhook payload, a downloaded artifact.
- Anything from a version control system: a branch name, a tag, a commit message, a pull request
  title.

## Never re-parse data as code

This is the rule the rest of the file supports. A value must reach the program that uses it as one
argument, never as a fragment of a command line that something parses again.

```bash
eval "backup_${target}"                 # eval on any data is an injection
bash -c "process ${file}"               # the string is re-parsed by the new shell
ssh host "rm -rf ${remote_dir}"         # parsed by the remote login shell
sudo sh -c "install ${package}"         # parsed by sh, running as root
awk "BEGIN { print ${expr} }"           # awk is a programming language
sed "s/${pattern}/x/" file              # / or & in the value changes the command
find . -exec sh -c "convert {} ${opts}" \;   # {} interpolated into a shell string
```

The safe forms pass data through the argument vector, so no second parser sees it:

```bash
"${command_array[@]}"                                    # a command built as an array
bash -c 'process "$1"' _ "${file}"                       # $1 inside single quotes
ssh host rm -rf -- "$(printf '%q' "${remote_dir}")"      # only if the remote shell is bash
awk -v expr="${expr}" 'BEGIN { print expr }'             # -v passes a value, not code
find . -exec convert {} "${opts}" \;                     # no intermediate shell
```

`printf '%q'` and `${var@Q}` (Bash 4.4 or later) produce a value that is safe to re-parse by
another Bash. They do not make a value safe for `sh`, `awk`, SQL, or a URL, and they are not a
substitute for avoiding the second parser.

The `ssh` line above is the case where that matters most, because the parser is on the other
machine and is outside the script's control. `ssh` joins its arguments into one string and hands
it to the remote account's login shell, so `%q` output is only safe if that shell is Bash: under `dash`,
`csh`, or a restricted shell the quoting can be wrong, and a `ForceCommand` or an
`authorized_keys` `command=` ignores the argument entirely and runs something else. Confirm the
remote shell, or use a transport that never builds a remote command line, such as `scp`, `rsync`,
or piping the value in on standard input for the remote program to read.

## Arithmetic evaluation is code execution

`(( … ))`, `$(( … ))`, `let`, and an assignment to a variable declared with `declare -i` all
evaluate their operand, and array subscripts inside that operand are expanded:

```bash
count="a[$(id >&2)]"
((count))            # runs id
```

Validate anything that reaches arithmetic before it gets there:

```bash
if [[ ! ${count} =~ ^[0-9]+$ ]]; then
  die 65 "not a number: ${count}"
fi
```

## Validate at the boundary, with an allowlist

Reject values that do not match a pattern of permitted characters. Do not strip characters and
continue: a sanitizer that removes `;` still passes `$(…)`, backticks, newlines, and `-`-prefixed
options.

```bash
# Anchored, explicit, and stated in the function's comment header.
readonly SERVICE_PATTERN='^[a-z][a-z0-9_-]{0,63}$'

validate_service() {
  local service="$1"
  [[ ${service} =~ ${SERVICE_PATTERN} ]] || die 65 "invalid service name: ${service}"
}
```

Details that matter:

- Anchor with `^` and `$`. An unanchored pattern matches a substring, so `id` matches
  `id; rm -rf /`.
- Keep the pattern in a variable and use it unquoted on the right of `=~`. A quoted right-hand side
  is matched literally, which silently turns the check into a string comparison.
- The right-hand side of `==` inside `[[ … ]]` is a glob when unquoted and a literal when quoted.
  Decide which is meant, every time.
- `case` is often clearer than a regex for a fixed set of alternatives, and it cannot be
  accidentally quoted into a literal.
- Validate length as well as character class, so an input cannot be used to build an oversized
  argument list or path.
- Validate once, at the point the value enters the script, and pass the validated value onward.
  Re-validating in every function hides where the boundary is.

## Paths and traversal

A validated name is not a validated path. Where the script joins input into a path, resolve the
result and confirm it is inside the directory it should be:

```bash
resolve_within() {
  local base="$1" candidate="$2" resolved
  resolved="$(realpath -m -- "${base}/${candidate}")"
  [[ ${resolved} == "${base}/"* ]] || die 65 "path escapes ${base}: ${candidate}"
  printf '%s\n' "${resolved}"
}
```

Reject `..` components and absolute paths explicitly when the input is meant to be a single name.
`realpath` follows symlinks, which is what makes it the right check: a symlink pointing outside the
base is caught. `realpath -m` is GNU coreutils; on a host that may not have it, `cd` into the base
in a subshell and compare `$PWD`, or require the path to exist and use `readlink -f`. See
[filesystem.md](filesystem.md) for the races around acting on a resolved path.

## Hostile filenames

Assume filenames contain anything but `/` and NUL.

```bash
# Correct: NUL-delimited, no word splitting, no interpretation of backslashes.
while IFS= read -r -d '' file; do
  process -- "${file}"
done < <(find "${dir}" -type f -print0)

find "${dir}" -type f -exec process -- {} +     # no shell in the middle
mapfile -d '' files < <(find "${dir}" -type f -print0)   # Bash 4.4 or later
```

Never iterate over `$(ls)`, `$(find …)` unquoted, or a command substitution split on whitespace.
Always pass `--` before operands that come from data, and prefix globs with `./`, so a file named
`-rf` or `--checkpoint-action=exec=…` is treated as an operand rather than an option.

`read -r` is not optional: without `-r`, backslashes in the input are interpreted and lost.

## Other interpreters

| Destination | Safe form |
|---|---|
| JSON | `jq --arg value "${input}" '{key: $value}'`, never string concatenation |
| A URL query | `curl --data-urlencode "q=${input}"`, or `jq -rn --arg v "${input}" '$v\|@uri'` |
| SQL | The client's parameter binding. Where a client has none, do not build the statement in shell |
| `grep` patterns | `grep -F -- "${input}"` for a literal, or `grep -e "${input}"` when a pattern is intended |
| A `printf` format | `printf '%s\n' "${input}"`. A value must never be the format string (`SC2059`) |
| YAML, XML, HTML | A parser or template tool, not `sed` |

## Reading input safely

- `read -r -p 'prompt: ' answer` for a line, `read -r -s` for a secret (see
  [secrets.md](secrets.md)), and validate the answer before use.
- Do not `source` a data file. `source` executes it, so a configuration file becomes arbitrary code
  running with the script's privileges. Parse it instead, or accept that it is code and control its
  ownership and permissions accordingly.
- Treat a file the script wrote itself in a shared directory as untrusted on the way back in.
- Bound what is read. A `while read` loop over an unbounded stream, or `mapfile` on an arbitrarily
  large file, is a memory limit waiting to be found.

## Exposure through the command line

Arguments are visible to every user on the host through `ps` and `/proc`. Anything sensitive is
passed by file, by environment variable, or on standard input. See [secrets.md](secrets.md).
