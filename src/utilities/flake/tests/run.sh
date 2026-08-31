#!/usr/bin/env bash
# ==================================================================================================
# Flake utility - standalone tests (no NDS)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-31 | Modified: 2026-08-31
# ==================================================================================================

set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../main.sh
source "${ROOT}/main.sh"

PASS=0
FAIL=0

ok() { PASS=$((PASS + 1)); printf '  ok  %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf '  FAIL %s\n' "$1"; }

assert_eq() {
    local name="$1" got="$2" want="$3"
    if [[ "$got" == "$want" ]]; then
        ok "$name"
    else
        fail "$name ($got != $want)"
    fi
}

assert() {
    local name="$1"
    shift
    if "$@"; then
        ok "$name"
    else
        fail "$name"
    fi
}

TMP="$(mktemp -d "${TMPDIR:-/tmp}/flake_test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "${TMP}/flake"
cat >"${TMP}/flake/flake.nix" <<'EOF'
{
  inputs.core.url = "git+ssh://git@github.com/CodeAnthem/thundercore.git";
  inputs.other.url = "git@github.com:CodeAnthem/dp_cluster.git";
}
EOF
cat >"${TMP}/flake/flake.lock" <<'EOF'
{
  "nodes": {
    "core": {
      "locked": {
        "type": "git",
        "url": "ssh://git@github.com/CodeAnthem/thundercore.git",
        "rev": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        "narHash": "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
      }
    },
    "root": { "inputs": { "core": "core" } }
  },
  "root": "root",
  "version": 7
}
EOF

mapfile -t urls < <(flake_listGitUrls "${TMP}/flake" "git@github.com:CodeAnthem/leaf.git")
joined="$(printf '%s|' "${urls[@]}")"
assert "lists root url" bash -c "printf '%s' '$joined' | grep -q 'git@github.com:CodeAnthem/leaf.git'"
assert "lists lock ssh url" bash -c "printf '%s' '$joined' | grep -q 'git@github.com:CodeAnthem/thundercore.git'"
assert "lists flake.nix git@ url" bash -c "printf '%s' '$joined' | grep -q 'git@github.com:CodeAnthem/dp_cluster.git'"

assert_eq "toSsh scp" "$(_flake_url_toSsh 'git@github.com:A/B.git')" "git@github.com:A/B.git"
assert_eq "toSsh git+ssh" "$(_flake_url_toSsh 'git+ssh://git@github.com/A/B.git')" "git@github.com:A/B.git"
assert_eq "fetchTree ssh" "$(flake_fetchTreeUrl 'git+ssh://git@github.com/A/B.git')" "ssh://git@github.com/A/B.git"

if command -v jq &>/dev/null; then
    mapfile -t entries < <(flake_listLockGitEntries "${TMP}/flake/flake.lock")
    assert_eq "lock entry count" "${#entries[@]}" "1"
    assert "lock entry has rev" bash -c "printf '%s' '${entries[0]}' | grep -q $'\taaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\t'"
else
    ok "skip lock entries (no jq)"
fi

assert_false() {
    local name="$1"
    shift
    if "$@"; then
        fail "$name"
    else
        ok "$name"
    fi
}
assert_false "reject missing root" flake_listGitUrls "${TMP}/missing"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
