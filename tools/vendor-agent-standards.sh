#!/usr/bin/env bash
set -euo pipefail

UPSTREAM_URL="https://github.com/konstruktoid/agent-instructions-skills"

DEFAULT_UPSTREAM_REF="v0.1.0"
DEFAULT_UPSTREAM_COMMIT="994be479cf1d44d5ee69d0334da07e923d8dee2e"

UPSTREAM_REF="${1:-${DEFAULT_UPSTREAM_REF}}"
UPSTREAM_COMMIT_EXPECTED="${2:-}"

if [ "${UPSTREAM_REF}" = "${DEFAULT_UPSTREAM_REF}" ] && [ -z "${UPSTREAM_COMMIT_EXPECTED}" ]; then
  UPSTREAM_COMMIT_EXPECTED="${DEFAULT_UPSTREAM_COMMIT}"
fi

if [ -z "${UPSTREAM_COMMIT_EXPECTED}" ]; then
  printf 'error: %s is not the pinned ref (%s), so the expected commit must be given as the second argument\n' \
    "${UPSTREAM_REF}" "${DEFAULT_UPSTREAM_REF}" >&2
  printf 'usage: %s [ref] [expected-commit]\n' "${0##*/}" >&2
  exit 1
fi

SKILLS=(
  "ansible/ansible-verification-loop"
  "bash/bash-secure-scripting"
  "bash/bash-testing"
  "github/github-actions-security"
  "github/github-organization-governance"
  "github/github-repository-security"
)

INSTRUCTIONS=(
  "bash_coding_instructions.md"
  "github_governance_instructions.md"
  "written_language_instructions.md"
)

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS_DIR="${REPO_ROOT}/.agents/skills"
CLAUDE_SKILLS_DIR="${REPO_ROOT}/.claude/skills"
INSTRUCTIONS_DIR="${REPO_ROOT}/instructions"

for cmd in git sed; do
  command -v "${cmd}" > /dev/null 2>&1 || {
    printf 'error: %s is required but was not found in PATH\n' "${cmd}" >&2
    exit 1
  }
done

WORK_DIR="$(mktemp --directory -t vendor-agent-standards.XXXXXX)"
trap 'rm -rf -- "${WORK_DIR}"' EXIT

git clone --quiet --depth 1 --branch "${UPSTREAM_REF}" \
  "${UPSTREAM_URL}" "${WORK_DIR}/upstream"

UPSTREAM_COMMIT="$(git -C "${WORK_DIR}/upstream" rev-parse HEAD)"

if [ -n "${UPSTREAM_COMMIT_EXPECTED}" ] \
  && [ "${UPSTREAM_COMMIT}" != "${UPSTREAM_COMMIT_EXPECTED}" ]; then
  printf 'error: %s resolved to %s but %s was expected; refusing to vendor\n' \
    "${UPSTREAM_REF}" "${UPSTREAM_COMMIT}" "${UPSTREAM_COMMIT_EXPECTED}" >&2
  exit 1
fi

rewrite_paths() {
  sed \
    -e 's#skills/\(ansible\|bash\|github\|python\)/#.agents/skills/#g' \
    -e "s#[$]{CLAUDE_PLUGIN_ROOT}/instructions/#instructions/#g"
}

vendor_file() {
  local src_rel="$1" dest="$2"
  local src="${WORK_DIR}/upstream/${src_rel}"
  local header body_start=1

  [ -f "${src}" ] || {
    printf 'error: upstream file not found: %s\n' "${src_rel}" >&2
    exit 1
  }

  header="$(
    printf '<!--\nVendored from %s\n%s\nUpstream ref: %s\nUpstream commit: %s\nDo not edit locally; re-vendor with tools/vendor-agent-standards.sh instead.\n-->\n' \
      "${UPSTREAM_URL}" "${src_rel}" "${UPSTREAM_REF}" "${UPSTREAM_COMMIT}"
  )"

  if [ "$(head -n 1 "${src}")" = "---" ]; then
    body_start="$(awk 'NR > 1 && $0 == "---" { print NR + 1; exit }' "${src}")"
    [ -n "${body_start}" ] || {
      printf 'error: unterminated frontmatter in %s\n' "${src_rel}" >&2
      exit 1
    }
  fi

  mkdir -p -- "$(dirname -- "${dest}")"
  {
    if [ "${body_start}" -gt 1 ]; then
      head -n "$((body_start - 1))" "${src}" | rewrite_paths
    fi
    printf '%s\n\n' "${header}"
    tail -n "+${body_start}" "${src}" | rewrite_paths
  } > "${dest}"
}

MANIFEST="${WORK_DIR}/skill-manifest"
: > "${MANIFEST}"

for skill in "${SKILLS[@]}"; do
  src_dir="${WORK_DIR}/upstream/skills/${skill}"

  [ -d "${src_dir}" ] || {
    printf 'error: upstream skill directory not found: skills/%s\n' "${skill}" >&2
    exit 1
  }

  skill_files="$(cd "${src_dir}" && find . -type f -name '*.md' -printf '%P\n' | sort)"

  [ -n "${skill_files}" ] || {
    printf 'error: no Markdown files found in skills/%s\n' "${skill}" >&2
    exit 1
  }

  while IFS= read -r rel; do
    printf '%s\t%s\n' "${skill}" "${rel}" >> "${MANIFEST}"
  done <<< "${skill_files}"
done

printf 'Vendoring from %s at %s (%s)\n' "${UPSTREAM_URL}" "${UPSTREAM_REF}" "${UPSTREAM_COMMIT}"

rm -rf -- "${SKILLS_DIR}" "${CLAUDE_SKILLS_DIR}"
mkdir -p -- "${SKILLS_DIR}" "${CLAUDE_SKILLS_DIR}"

while IFS=$'\t' read -r skill rel; do
  name="${skill##*/}"
  vendor_file "skills/${skill}/${rel}" "${SKILLS_DIR}/${name}/${rel}"
done < "${MANIFEST}"

for skill in "${SKILLS[@]}"; do
  name="${skill##*/}"
  ln -sfn "../../.agents/skills/${name}" "${CLAUDE_SKILLS_DIR}/${name}"
  printf '  skill        %s\n' "${name}"
done

for doc in "${INSTRUCTIONS[@]}"; do
  vendor_file "instructions/${doc}" "${INSTRUCTIONS_DIR}/${doc}"
  printf '  instructions %s\n' "${doc}"
done

printf 'Done.\n'
