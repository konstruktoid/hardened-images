#!/usr/bin/env bash
set -euo pipefail

UPSTREAM_URL="https://github.com/konstruktoid/agent-instructions-skills"
UPSTREAM_REF="${1:-v0.1.0}"

SKILLS=(
  "ansible/ansible-verification-loop"
  "bash/bash-secure-scripting"
  "bash/bash-testing"
  "github/github-actions-security"
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

printf 'Vendoring from %s at %s (%s)\n' "${UPSTREAM_URL}" "${UPSTREAM_REF}" "${UPSTREAM_COMMIT}"

rm -rf -- "${SKILLS_DIR}" "${CLAUDE_SKILLS_DIR}"
mkdir -p -- "${SKILLS_DIR}" "${CLAUDE_SKILLS_DIR}"

for skill in "${SKILLS[@]}"; do
  name="${skill##*/}"
  while IFS= read -r rel; do
    vendor_file "skills/${skill}/${rel}" "${SKILLS_DIR}/${name}/${rel}"
  done < <(cd "${WORK_DIR}/upstream/skills/${skill}" && find . -type f -name '*.md' -printf '%P\n' | sort)

  ln -sfn "../../.agents/skills/${name}" "${CLAUDE_SKILLS_DIR}/${name}"
  printf '  skill        %s\n' "${name}"
done

for doc in "${INSTRUCTIONS[@]}"; do
  vendor_file "instructions/${doc}" "${INSTRUCTIONS_DIR}/${doc}"
  printf '  instructions %s\n' "${doc}"
done

printf 'Done.\n'
