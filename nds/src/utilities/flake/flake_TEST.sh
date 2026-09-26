#!/usr/bin/env bash
# ==================================================================================================
# Flake utility - probe reuses an existing clone
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# ==================================================================================================

# shellcheck source=../../setup_TEST.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../setup_TEST.sh"
import_dir "$(dirname "${BASH_SOURCE[0]}")" --depth 0

_flake_clones=0
git_clone() { _flake_clones=$((_flake_clones + 1)); }

suite_flake() {
    local dest
    dest=$(mktemp -d)
    mkdir -p "${dest}/.git"
    _flake_clones=0
    if flake_probe /keys 'https://example.com/a/b.git' "$dest" && [[ "$_flake_clones" -eq 0 ]]; then
        bts_pass "flake_probe reuses an existing clone"
    else
        bts_fail "flake_probe cloned ${_flake_clones} times"
    fi
    rm -rf "${dest}/.git"
    if flake_probe /keys 'https://example.com/a/b.git' "$dest" && [[ "$_flake_clones" -eq 1 ]]; then
        bts_pass "flake_probe clones when the destination is empty"
    else
        bts_fail "empty probe clone count was ${_flake_clones}"
    fi
    rm -rf "$dest"
}
