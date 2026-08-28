<!--
Vendored from https://github.com/konstruktoid/agent-instructions-skills
skills/ansible/ansible-verification-loop/references/style-sweeps.md
Upstream ref: v0.1.0
Upstream commit: 994be479cf1d44d5ee69d0334da07e923d8dee2e
Do not edit locally; re-vendor with tools/vendor-agent-standards.sh instead.
-->

# Auto-Fix Output and Repository-Wide Style Sweeps

Read this before running a formatter or an auto-fixer over files, and before any change that makes
an existing convention consistent across many files. Both operations edit code the change was never
asked to touch, and both are able to pass every check while doing damage.

## Contents

- Auto-fix is a reformatter, not only a rule fixer
- A clean lint summary can hide a finding the change introduced
- Measure before a sweep, and let the measurement decide

## Auto-fix is a reformatter, not only a rule fixer

`ansible-lint --fix` loads each file through a round-tripping YAML library and writes it back out.
Anything the library normalises is rewritten, whether or not a rule ever flagged it. Running it on a
repository that already lints clean therefore still produces a diff.

The reproducible case is a blank line following a flow-style value. Given this input, which lints
clean:

```yaml
---
# A flow-style list.
flow_list: ["a", "b"]

# The next variable.
plain_value: "x"

# An empty flow list.
empty_list: []

# Final variable.
final_value: true
```

`ansible-lint --fix` reports `Passed: 0 failure(s), 0 warning(s)` and deletes both blank lines,
joining each comment block to the value above it. Blank lines after block-style and plain scalar
values are left alone; only the flow-style ones lose theirs. No rule was violated before the run and
none is violated after, so the quality gate cannot see the change. The cause is the library's
round-trip rather than a rule, so no lint setting suppresses it.

The consequences follow from that:

- Review `git diff` after every `--fix` or auto-format run, and treat any hunk the change does not
  explain as a regression to revert. Auto-fix output needs the same review as a hand edit.
- Never conclude that `--fix` changed nothing important from a clean lint result. The only signal
  the tool gives is a line such as `Modified 1 file.`; what it modified is only visible in the diff.
- Run an auto-fixer on a clean working tree, so its diff is separable from the change's own.

## A clean lint summary can hide a finding the change introduced

A repository with a lint-ignore file or inline skips downgrades a matching violation to an ignored
warning rather than a failure. A change that introduces such a violation in an already-listed file
therefore leaves the exit status and the pass/fail summary untouched.

The case that showed this: adding quotes to a value pushed a line from 160 to 162 characters,
crossing the line-length limit. The file already had a `yaml[line-length]` entry in the repository's
lint-ignore file, so the run still reported zero failures. Only the warning count moved, by one.

To know whether a change introduced a finding, capture the linter's full output, including the lines
it marks as ignored or warned, before touching anything, and diff it against the output from the
same command afterwards:

```sh
ansible-lint > lint-before.txt 2>&1      # before the first edit
ansible-lint > lint-after.txt 2>&1       # after the change
diff lint-before.txt lint-after.txt
```

Write both files outside the repository, or delete them before reporting, so neither is committed.
At minimum, compare the warning counts in the two summary lines. Pass or fail alone is not evidence
in any repository that carries a lint-ignore file.

This is the corollary of the rule against adding a suppression: an existing suppression must not be
silently inherited either. Fix the finding. For a line pushed over the limit, fold it with `>-`
rather than widening the ignore.

## Measure before a sweep, and let the measurement decide

When the task is to make something consistent, the current ratio is the evidence for what the
convention already is. Measure it, report it, and let it choose the target. Do not assume.

### Distinguishing a quoted scalar from a plain one needs a parser

`grep` cannot tell a quoted scalar from a plain one reliably, and neither can a YAML parser that has
not been told to keep the distinction. `ruamel.yaml` in round-trip mode discards quoting style
unless `preserve_quotes` is set, and then reports every scalar as plain:

```python
from ruamel.yaml import YAML
from ruamel.yaml.scalarstring import ScalarString

yaml = YAML(typ="rt")
yaml.preserve_quotes = True  # without this every scalar looks plain
# a scalar is quoted iff isinstance(value, ScalarString)
```

Over one collection's `defaults/main.yml` files, the same script reported 0 of 427 string scalars
quoted without `preserve_quotes` and 415 of 427 with it. The first answer would have justified a
sweep in the wrong direction across the whole repository.

### The same construct can be correct in one file and an artifact in another

A comment sitting directly above the key it documents is correct in a configuration block and in a
task file. In a `defaults/main.yml` whose convention is a blank line between variables, the same
comment block introducing the next variable wants that blank line. An automated sweep that cannot
tell the two apart damages the first kind while fixing the second.

- Count both forms per file or per directory, let the dominant one decide, and state the ratio when
  justifying the edit. One file measured here had 59 comment blocks separated by a blank line
  against 15 that were not, which settles what the file's convention is.
- Inspect a sample of the matches by hand before applying the edit. A scan run for this produced
  true positives in `defaults/` files and false positives in playbooks, including one match on a `#`
  inside a literal block scalar that was not a YAML comment at all.
- Report a sweep as consistency work when nothing it changed alters behavior, rather than implying
  a fix. See [yaml-quoting.md](yaml-quoting.md) for separating the correctness cases from the
  cosmetic ones in a quoting sweep.
