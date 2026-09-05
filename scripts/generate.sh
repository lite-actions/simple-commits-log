#!/usr/bin/env bash
set -euo pipefail

: "${GITHUB_OUTPUT:=/dev/stdout}"
emit() { printf '%s=%s\n' "$1" "$2" >> "${GITHUB_OUTPUT}"; }
tmp=""
cleanup() {
  if [ -n "${tmp}" ]; then
    rm -f "${tmp}"
  fi
}
trap cleanup EXIT

TITLE="${INPUT_TITLE:-Changelog}"
OUT="${INPUT_OUTPUT_FILE:-CHANGELOG.md}"
commit_ref="${INPUT_COMMIT:-}"

if [ -z "${commit_ref}" ] && [ -n "${GITHUB_EVENT_PATH:-}" ] && [ -f "${GITHUB_EVENT_PATH}" ] \
   && command -v jq >/dev/null 2>&1; then
  commit_ref="$(jq -r '.after // empty' "${GITHUB_EVENT_PATH}")"
fi
commit_ref="${commit_ref:-HEAD}"
sha="$(git rev-parse "${commit_ref}")"
short_sha="$(git rev-parse --short "${sha}")"
date="$(git log -1 --format=%cs "${sha}")"
subject="$(git log -1 --format=%s "${sha}")"
body="$(git log -1 --format=%b "${sha}")"

render_ref() {
  if [ -n "${GITHUB_REPOSITORY:-}" ]; then
    printf '[%s](%s/%s/commit/%s)' \
      "${short_sha}" "${GITHUB_SERVER_URL:-https://github.com}" "${GITHUB_REPOSITORY}" "${sha}"
  else
    printf '%s' "${short_sha}"
  fi
}

merge_body_line="$(printf '%s\n' "${body}" | sed -n '/./{p;q;}')"
source_line="${subject}"
if printf '%s' "${subject}" | grep -Eq '^Merge pull request #[0-9]+' && [ -n "${merge_body_line}" ]; then
  source_line="${merge_body_line}"
fi

type="other"
message="${source_line}"
parsed="$(printf '%s\n' "${source_line}" | sed -nE 's/^([a-z]+)(\([^)]+\))?(!)?:[[:space:]]*(.*)$/\1\t\4/p')"
if [ -n "${parsed}" ]; then
  type="${parsed%%	*}"
  message="${parsed#*	}"
elif printf '%s' "${subject}" | grep -Eq '^Merge '; then
  type="merge"
fi

ref="$(render_ref)"
header="${date} ${type} ${ref}"
marker="<!-- simple-commits-log:${sha} -->"
entry="${header} ${marker}\n${message}\n\n"

if [ -f "${OUT}" ] && grep -Fq "${marker}" "${OUT}"; then
  echo "Entry for ${short_sha} already present in ${OUT}; nothing to do."
  emit changed false
  emit file "${OUT}"
  exit 0
fi

if [ ! -f "${OUT}" ]; then
  printf '# %s\n\n%b' "${TITLE}" "${entry}" > "${OUT}"
  echo "Created ${OUT}."
else
  tmp="$(mktemp)"
  if head -n 1 "${OUT}" | grep -Eq '^# '; then
    {
      sed -n '1p' "${OUT}"
      printf '\n%b' "${entry}"
      tail -n +2 "${OUT}" | sed '/./,$!d'
    } > "${tmp}"
  else
    {
      printf '%b' "${entry}"
      cat "${OUT}"
    } > "${tmp}"
  fi
  mv "${tmp}" "${OUT}"
  echo "Updated ${OUT}."
fi

emit changed true
emit file "${OUT}"
