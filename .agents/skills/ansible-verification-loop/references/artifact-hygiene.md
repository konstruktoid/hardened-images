<!--
Vendored from https://github.com/konstruktoid/agent-instructions-skills
skills/ansible/ansible-verification-loop/references/artifact-hygiene.md
Upstream ref: v0.1.0
Upstream commit: 994be479cf1d44d5ee69d0334da07e923d8dee2e
Do not edit locally; re-vendor with tools/vendor-agent-standards.sh instead.
-->

# Repository and Collection Artifact Hygiene

Read this when a change touches `.gitignore` or `galaxy.yml` in a collection, when a built
artifact is larger than the source it was built from, or before a collection is published to
Galaxy or Automation Hub.

## Contents

- Two lists, and neither implies the other
- How `build_ignore` patterns are matched
- What the build ignores without being told
- What belongs in each list
- Why the local state is the part that matters
- Verify the artifact, not the configuration
- A standalone role has only one list

## Two lists, and neither implies the other

`.gitignore` decides what enters the repository. `build_ignore` in `galaxy.yml` decides what
enters the tarball that `ansible-galaxy collection build` writes. The build never reads
`.gitignore`. It walks the collection directory as it stands on disk and includes every untracked
file no `build_ignore` pattern excludes, so a working copy that has run molecule once ships the
dependencies it downloaded, the logs it wrote, and whatever local configuration sits beside them.
None of that appears in `git status`, and the build reports no warning.

The relationship between the two lists is not equality:

- Every `.gitignore` entry needs a `build_ignore` counterpart. It names local state, which belongs
  in neither the repository nor the artifact.
- `build_ignore` carries more than that. Tracked development files, such as `.github`,
  `ansible.cfg`, agent instructions and linter configuration, belong in the repository and are of
  no use to whoever installs the collection.

`build_ignore` and the `manifest` key are mutually exclusive, and setting both fails the build
with that message. A collection that uses `manifest` states the same exclusions as `MANIFEST.in`
directives instead.

## How `build_ignore` patterns are matched

Each pattern is an `fnmatch` glob compared against the entry's path relative to the collection
root. Four consequences decide whether an entry takes effect at all:

- A trailing slash matches nothing. The path a pattern is compared against never ends in a
  separator, so `.ansible/` excludes nothing while `.ansible` excludes the directory. This is the
  most common reason a `build_ignore` list that reads correctly does nothing at all.
- A bare name is anchored at the collection root. `molecule-logs` excludes the top-level directory
  of that name and no other; `*/molecule-logs` reaches it at any depth.
- `*` crosses directory separators, because `fnmatch` is not path-aware. `*.gz` excludes
  `logs/run.gz` as well as `run.gz`, which makes an extension pattern the reliable form for
  output files whose location is not fixed.
- A directory that matches is not walked into, so one entry covers everything beneath it. A
  directory whose contents were all excluded individually still ships as an empty directory.

Gitignore syntax does not carry over. There is no `!` negation, no `**`, and no comments.

## What the build ignores without being told

These need no entry: `MANIFEST.json`, `FILES.json`, `galaxy.yml`, `galaxy.yaml`, `.git`, `*.pyc`,
`*.retry`, `tests/output`, and a previously built `<namespace>-<name>-*.tar.gz` in the root.
Directories named `CVS`, `.bzr`, `.hg`, `.git`, `.svn`, `__pycache__` and `.tox` are skipped by
name at any depth.

Two gaps in that list are worth stating, because both look covered and are not. `.tox` is skipped
but `.nox` and `.venv` are not, and `tests/output` is anchored at the root, so an `output`
directory under a nested tests directory still ships.

## What belongs in each list

| Category | Examples | `.gitignore` | `build_ignore` |
|----------|----------|--------------|----------------|
| Dependencies and caches | `.ansible`, `ansible_collections`, `.cache`, `.venv`, `.nox` | Yes | Yes |
| Test and lint output | `molecule-logs`, `*.log`, `*.gz`, the detached run log and sentinel, coverage output | Yes | Yes |
| Local configuration and credentials | `.env`, `.env.yml`, vault password files, private keys, an inventory written for a real environment | Yes | Yes |
| Tracked development files | `.github`, `ansible.cfg`, `CLAUDE.md`, `AGENTS.md`, `.agents`, `.ansible-lint`, `.ansible-lint-ignore`, `.yamllint` | No | Yes |

## Why the local state is the part that matters

The first three rows are where user and system information leaves the machine. A downloaded
dependency tree and a molecule log carry the hostname, username, home directory paths and internal
addresses of whatever ran the tests; `.env` files and vault password files carry credentials; an
inventory written against a real environment carries both. This is the same exposure the skill's
reporting step describes for pasted output, with a wider audience and no way to take it back:
removing a version from Galaxy does not recall the copies already downloaded, and content
committed to the repository stays in the history after the file is deleted.

## Verify the artifact, not the configuration

A `build_ignore` list is not evidence. Build the collection and read what the tarball holds:

```sh
ansible-galaxy collection build --force
out="$(mktemp -d)"
tar -tzf <namespace>-<name>-<version>.tar.gz | grep -v '/$' | sort > "${out}/artifact"
git ls-files | sort > "${out}/tracked"
comm -23 "${out}/artifact" "${out}/tracked"
```

`comm -23` prints what the artifact holds and git does not track. `MANIFEST.json` and `FILES.json`
are generated by the build and belong there; every other line is local state that a `build_ignore`
pattern failed to exclude. Read the full file list as well, for the other direction: a tracked
development file that reached the artifact fails no comparison, since git does track it.

Keep the comparison files outside the collection root, so the check does not create the next thing
that needs excluding, and remove the tarball afterwards or exclude `*.tar.gz` in both lists.

Two smaller signals:

- `ansible-galaxy collection build --force -vvv` prints one line per skipped entry, which shows
  whether a pattern took effect at all.
- Artifact size against source size. Syncing the two lists in
  [konstruktoid/ansible-collection-hardening#91](https://github.com/konstruktoid/ansible-collection-hardening/pull/91)
  took the built collection from 26M to 950K, all of it downloaded dependencies under an
  `.ansible/` entry that had never matched anything.

## A standalone role has only one list

A standalone role has no `galaxy.yml` and no `build_ignore`. Galaxy imports the repository
contents, so `.gitignore` is the only control and anything committed is published. The categories
above still apply; there is one place to put them rather than two.
