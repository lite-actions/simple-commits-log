#!/usr/bin/env bash
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GEN="${ROOT}/scripts/generate.sh"

pass=0
fail=0
check() {
  if [ "$2" -eq 0 ]; then echo "  ok   - $1"; pass=$((pass + 1))
  else echo "  FAIL - $1"; fail=$((fail + 1)); fi
}
assert() {
  local desc="$1"; shift
  if "$@"; then echo "  ok   - ${desc}"; pass=$((pass + 1))
  else echo "  FAIL - ${desc}"; fail=$((fail + 1)); fi
}

unset GITHUB_REPOSITORY GITHUB_SERVER_URL GITHUB_EVENT_PATH

tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT
cd "${tmp}" || exit 1
git init -q
git config user.email test@example.com
git config user.name test

echo "== create a new changelog entry"
git commit -q --allow-empty -m "feat: add audit log"
sha1="$(git rev-parse HEAD)"
short1="$(git rev-parse --short HEAD)"
date1="$(git log -1 --format=%cs HEAD)"
export GITHUB_OUTPUT="${tmp}/out1"
INPUT_COMMIT=HEAD bash "${GEN}" >/dev/null 2>&1

grep -q '^# Changelog$' CHANGELOG.md; check "default heading created" $?
grep -q "^${date1} feat ${short1}$" CHANGELOG.md; check "entry header uses date type and short sha" $?
grep -q '^add audit log$' CHANGELOG.md; check "message written on following line" $?
grep -q '^changed=true$' "${GITHUB_OUTPUT}"; check "emits changed=true" $?

printf '\n== merge commit uses the PR title from the body\n'
git commit -q --allow-empty -F - <<'MSG'
Merge pull request #12 from lite-actions/fix-empty-payload

fix: handle empty payload
MSG
sha2="$(git rev-parse HEAD)"
date2="$(git log -1 --format=%cs HEAD)"
export GITHUB_OUTPUT="${tmp}/out2"
GITHUB_REPOSITORY="acme/widget" INPUT_COMMIT=HEAD bash "${GEN}" >/dev/null 2>&1

grep -qE "^${date2} fix \[[0-9a-f]{7,}\]\(https://github\.com/acme/widget/commit/${sha2}\)$" CHANGELOG.md
check "merge commit logs clickable short sha and parsed type" $?
grep -q '^handle empty payload$' CHANGELOG.md; check "merge body message used" $?
line_new="$(grep -n '^handle empty payload$' CHANGELOG.md | cut -d: -f1 | head -n1)"
line_old="$(grep -n '^add audit log$' CHANGELOG.md | cut -d: -f1 | head -n1)"
assert "latest entry prepended" test "${line_new}" -lt "${line_old}"

printf '\n== duplicate commit does not append twice\n'
before="$(cat CHANGELOG.md)"
export GITHUB_OUTPUT="${tmp}/out3"
GITHUB_REPOSITORY="acme/widget" INPUT_COMMIT=HEAD bash "${GEN}" >/dev/null 2>&1
assert "duplicate run leaves changelog unchanged" test "${before}" = "$(cat CHANGELOG.md)"
grep -q '^changed=false$' "${GITHUB_OUTPUT}"; check "emits changed=false for duplicate" $?

echo
printf 'passed: %s, failed: %s\n' "${pass}" "${fail}"
[ "${fail}" -eq 0 ]
