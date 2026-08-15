<!--
Vendored from https://github.com/konstruktoid/agent-instructions-skills
instructions/bash_coding_instructions.md
Upstream commit: 4983695a16ac349dfcac90c4ab27c86d272c2d6e
Do not edit locally; re-vendor from upstream instead.
-->

# Bash Coding Instructions

## Objective

Produce shell code that passes `shellcheck` and the repository's formatter cleanly, fails loudly
rather than silently, and stays readable to whoever maintains it next. These instructions apply
whenever an agent authors or modifies a shell script in a repository that adopts them.

The target is Bash, not POSIX `sh`. Where a POSIX construct is less safe or less clear than the
Bash equivalent, use the Bash one: `[[ … ]]` over `[ … ]`, arrays over whitespace-delimited
strings, `$(…)` over backticks, `set -o pipefail` over an unchecked pipeline. Portability to
`dash` or `ash` is a requirement only where the repository states it, for example a Debian
maintainer script, an Alpine image, or an initramfs hook. Where that requirement is absent,
ShellCheck's `SC3xxx` POSIX-compatibility warnings do not apply and the file must declare Bash so
they are not raised. Where it is present, the script is not covered by this document: write it as
`#!/bin/sh` and hold it to POSIX.

Two skills build on this document and are worth applying alongside it:

- For the security and stability properties `shellcheck` does not verify on its own, such as
  strict-mode semantics, cleanup on failure, handling of untrusted input, environment and `PATH`
  control, temporary files, and credentials, apply the `bash-secure-scripting` skill
  (`.agents/skills/bash-secure-scripting/SKILL.md`).
- For adding or updating test coverage for a script, apply the `bash-testing` skill
  (`.agents/skills/bash-testing/SKILL.md`), which covers discovering the repository's existing test
  layout, deciding when a test is required, and running the suite in a bounded verify loop. Test
  files are source, so the tooling baseline below applies to them as well.

## Tooling

### Required

- Run checks through the repository's own entry point where one exists, for example `make lint`,
  `pre-commit run --all-files`, or the step in `.github/workflows/*.yml`, rather than a bare
  invocation that may use different options.
- Run `shellcheck` on every script touched, and fix what it reports. It is the baseline quality
  gate, in the same position `ruff` holds for Python.
- Run `bash -n` on every script touched. It parses without executing and catches the syntax errors
  that a script otherwise reaches only on the branch that runs them.
- Run the repository's formatter if one is configured. `shfmt -d` (diff mode) is the common choice;
  `shfmt -i 2 -ci -bn -d` matches the layout rules below. Do not reformat a file the repository
  does not already format.
- Declare the shell so the tools analyze the right dialect. An executable script starts with a
  shebang, `#!/usr/bin/env bash` or `#!/bin/bash`, matching whichever form the repository already
  uses. A sourced library has no shebang and no executable bit, so mark it with a
  `# shellcheck shell=bash` directive instead.
- Follow the repository's existing `.shellcheckrc`, `.editorconfig`, and formatter settings. Propose
  `enable=all` in `.shellcheckrc` only for a new project, or when the user asks for stricter
  checking. `shellcheck --list-optional` prints the optional checks and what each one adds;
  `require-variable-braces`, `check-extra-masked-returns`, `check-set-e-suppressed`, and
  `deprecate-which` are the ones that most often catch real defects.
- For a script that sources another file, run `shellcheck -x` and point it at the file with a
  `# shellcheck source=path/to/lib.sh` directive, or set `source-path=SCRIPTDIR` in `.shellcheckrc`.
  Resolving the source is preferable to silencing `SC1091`.
- State the Bash version the script requires when it uses a feature that is not in Bash 3.2, which
  is what macOS ships. `mapfile`/`readarray`, associative arrays (`declare -A`), and `globstar`
  need Bash 4.0 or later; `{fd}>file` descriptor allocation and `BASH_XTRACEFD` need 4.1; the
  `${var@Q}` family of parameter transformations and `shopt -s inherit_errexit` need 4.4. If the
  repository targets Linux only, that is an acceptable answer; record it rather than leaving it
  implicit, and add a version guard where a user could plausibly run the script on an older Bash.
  Guard on the version the feature actually needs, comparing the minor version too where it is not
  a `.0` release.

### Avoid

- Adding a linter, formatter, or test framework without first checking whether the repository
  already has an equivalent configured.
- Weakening configuration to make a failing check pass. Fix the code instead, or add a narrowly
  scoped, justified suppression.
- Suppressing a finding as a first response. A `# shellcheck disable=SC2086` immediately above the
  offending line, with a one-line reason, is the most that should ever be needed. Never place a
  `disable` directive at file level, never disable a code without naming it, and never add a
  repository-wide `disable=` to `.shellcheckrc` to silence one instance.
- Writing `#!/bin/sh` and then using Bash features. The script runs under whatever `/bin/sh` is on
  the host, which is `dash` on Debian and Ubuntu.
- Parsing the output of `ls`, and iterating over `$(ls)` or an unquoted command substitution to
  produce a list of files. Use a glob, `find -print0` with `read -d ''`, or `mapfile`.

## Structure and Style

These rules follow Google's shell style guide, with the deviations noted.

- Two-space indentation, no tabs. Keep lines within 80 columns where the content allows it; a long
  path or URL on one line is preferable to a wrapped one that cannot be searched for.
- Put `; then` and `; do` on the same line as `if`, `for`, and `while`. Put `else`, `fi`, and `done`
  on their own lines.
- Split a pipeline that does not fit on one line, one segment per line, with the `|` leading the
  continuation line.
- Quote every expansion that could contain data: `"${var}"`, `"$@"`, `"$(command)"`. Braces alone
  do not quote. Do not quote literal integers.
- Use `"$@"`, never bare `$@` or `$*`, to forward arguments.
- Use arrays for lists of elements and for command arguments, expanded as `"${array[@]}"`. Never
  build a command in a string and run it by expanding the string: the quoting is lost.
- Use `[[ … ]]` for tests, `(( … ))` or `$(( … ))` for arithmetic, and `$(…)` for command
  substitution. Do not use `expr`, `let`, `$[ … ]`, or backticks.
- Test strings with explicit `-z` and `-n`. Compare numbers with `((…))` or `-lt`/`-gt`, never with
  `<` or `>` inside `[[ … ]]`, which compare lexicographically.
- Prefix a glob with an explicit path, `./*` rather than `*`, so a file whose name begins with a
  hyphen is not read as an option. Pass `--` before user-supplied operands for the same reason.
- Read input with `while IFS= read -r line`, and feed the loop by redirection or process
  substitution (`done < <(command)`) rather than piping into it. A piped `while` runs in a subshell,
  so variables it sets are lost. `mapfile -t lines < <(command)` is the alternative.
- Prefer builtins and parameter expansion over an external process: `"${var%.*}"` rather than a call
  to `sed`, `"${#var}"` rather than `wc -c`, `[[ $var == *pattern* ]]` rather than a call to `grep`.
- Use `printf '%s\n' "$value"` rather than `echo "$value"` for anything that holds data. `echo`
  interprets leading hyphens as options and, in some shells and configurations, backslash escapes.
- Send error and diagnostic messages to standard error, so callers can separate them from output:

  ```bash
  err() {
    printf '%s: %s\n' "${0##*/}" "$*" >&2
  }
  ```

- Declare function-local variables with `local`, and keep the declaration separate from an
  assignment that comes from a command substitution: `local output; output="$(command)"`. Combined,
  `local` supplies the exit status and the command's failure is lost, which `SC2155` reports.
- Name functions and variables in `lower_snake_case`. Name constants and exported variables in
  `UPPER_SNAKE_CASE` and mark them `readonly` or `declare -xr`.
- Group functions together after the constants, and give a script that has functions a `main`
  function, with `main "$@"` as the last non-comment line. Keep executable code out of the space
  between function definitions.
- Comment each function that is neither obvious nor short, and every function in a sourced library,
  stating what it does, which globals it reads or writes, what arguments it takes, what it writes to
  stdout, and any exit status beyond the default.
- Give the file a header comment stating what the script does, directly below the shebang.
- Say so when the script outgrows shell. Google's guide sets the threshold at roughly 100 lines, or
  earlier where the control flow is not straightforward. Anything needing structured data, precise
  numeric work, or non-trivial parsing belongs in another language. Recommend the move rather than
  building the shell version further.

## Beyond What the Tools Check

ShellCheck catches quoting, word splitting, most misuse of test and arithmetic syntax, many
subshell mistakes, and a long list of specific bug patterns. The following still require judgment
because no static check can settle them:

- **Whether shell is the right tool.** No linter reports that a 400-line script with nested
  associative arrays should have been Python.
- **Whether `set -e` covers the failure at hand.** `errexit` is ignored for any command in a
  condition, in a `&&` or `||` chain other than the last, in a pipeline other than the last element,
  and under `!`. A command whose failure matters in one of those positions must be checked
  explicitly. The `bash-secure-scripting` skill states the full list.
- **Whether `|| true` is hiding a real failure.** It is the correct tool for a command whose
  non-zero status is expected, such as `grep` finding no match, and a defect anywhere else.
- **Whether a comparison was meant to be a pattern match.** The right-hand side of `==` inside
  `[[ … ]]` is a glob pattern when unquoted and a literal string when quoted. Both are valid, so
  the tools cannot choose between them.
- **Whether an external command exists, and which implementation it is.** `sed -i`, `readlink -f`,
  `date -d`, `stat -c`, and `mktemp` differ between GNU coreutils and the BSD tools on macOS.
  Check for what the script calls (`command -v`) and fail with a clear message when it is absent.
- **Locale and environment dependence.** Sorting and character classes change with `LC_ALL`. Set
  `LC_ALL=C` for any parsing or sorting whose result the script depends on.
- **Exit codes as an interface.** Callers, `make`, CI, and systemd all read the exit status.
  Decide deliberately what each failure path returns rather than letting the last command decide.
- **Whether the script is safe to rerun.** Partial completion is the normal state of a script that
  failed. Whether rerunning it repairs or compounds the damage is a design question.
- **Secret flow through variables.** ShellCheck does not trace a credential from a variable into a
  command line visible in `ps`, a log line, or `set -x` output.
- **User and system information in committed files.** No rule flags a home directory path,
  username, uid, hostname, internal IP, or real email address that reached a script, a fixture, a
  captured transcript, or generated documentation. These identify the machine the change was made
  on rather than anything about the code, and they make the file non-portable as well as
  over-shared. Use placeholders (`/path/to/project`, `user@example.com`, RFC 5737 addresses),
  derive real values at runtime (`$HOME`, `id -un`, `hostname`), and normalize captured output
  before writing it anywhere that gets committed.
- **Suppression justification.** ShellCheck reports a `disable` directive with no code, but not
  whether the reason next to a scoped suppression is a real one.

## Quality Checklist

Before considering a shell change complete, verify that:

- `shellcheck` passes on every script touched, with no new suppressions.
- `bash -n` passes on every script touched.
- The repository's formatter reports no diff, where one is configured.
- Every suppression that remains, in a directive or in `.shellcheckrc`, names a specific code and
  carries a one-line justification.
- Each script declares its shell, through a shebang or a `# shellcheck shell=bash` directive, and
  any Bash 4 feature it uses is compatible with the version the repository targets.
- The script was run, not only linted, against a representative input, including at least one
  failure path. A script that parses is not a script that works.
- Every expansion that can hold data is quoted, lists are held in arrays, and no command is built
  by concatenating a string.
- Error messages go to standard error, and the exit status distinguishes success from each failure
  mode the caller needs to tell apart.
- The judgment items above have been considered, since the tools cannot check them.
- Nothing being committed carries a home-directory path, username, uid, hostname, internal IP, or
  real email address, including in test fixtures, captured output, and generated documentation.
- Test coverage was added or updated if the change adds behavior, fixes a bug, or changes the
  script's interface, following the `bash-testing` skill. If no test was added, the reason was
  stated rather than left implicit.
- The checks above were run, not merely described, and their output was seen. A change is not
  complete because the edit looks right.
