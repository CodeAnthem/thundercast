#!/usr/bin/env bash
# ==================================================================================================
# toolkit action - sops policy units
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-03 | Modified: 2026-09-03
# ==================================================================================================

suite_toolkit_sops() {
    local root body

    _ts_ok() {
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ toolkit_sops: $1"
    }
    _ts_fail() {
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ toolkit_sops: $1"
    }

    if ! declare -f nds_toolkit_write_sops_policy &>/dev/null; then
        _ts_fail "write_sops_policy missing (fleet toolkit logic not loaded?)"
        return 0
    fi

    root=$(mktemp -d "${TMPDIR:-/tmp}/nds_toolkit.XXXXXX")
    nds_toolkit_write_sops_policy "$root" "unused-pubkey"
    if [[ -f "${root}/.sops.yaml" ]] \
        && grep -q 'creation_rules: \[\]' "${root}/.sops.yaml" \
        && [[ -d "${root}/secrets/swarm" && -d "${root}/secrets/hosts" ]]; then
        _ts_ok "new file is empty rules; dirs created"
    else
        _ts_fail "new .sops.yaml shape"
    fi

    printf '%s\n' 'creation_rules: [{path_regex: secrets/.*, key_groups: []}]' >"${root}/.sops.yaml"
    body=$(cat "${root}/.sops.yaml")
    nds_toolkit_write_sops_policy "$root" "age1operator"
    if [[ "$(cat "${root}/.sops.yaml")" == "$body" ]]; then
        _ts_ok "leaves existing yaml (no placeholder swap)"
    else
        _ts_fail "clobbered existing .sops.yaml"
    fi

    if ! grep -q 'age1operator' "${root}/.sops.yaml"; then
        _ts_ok "does not append operator (Init owns recipients)"
    else
        _ts_fail "appended operator pubkey"
    fi

    rm -rf "$root"
}
