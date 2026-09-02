#!/usr/bin/env bash
# ==================================================================================================
# remoteAction - cast catalog units (no network)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-03 | Modified: 2026-09-03
# ==================================================================================================

suite_cast_catalog() {
    local root out

    _cc_ok() {
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ cast_catalog: $1"
    }
    _cc_fail() {
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ cast_catalog: $1"
    }
    _cc_eq() {
        local name="$1" got="$2" want="$3"
        if [[ "$got" == "$want" ]]; then _cc_ok "$name"
        else _cc_fail "$name ($got != $want)"; fi
    }

    if declare -f _nds_cast_url_is_http &>/dev/null; then
        if _nds_cast_url_is_http "https://github.com/a/b.git" \
            && ! _nds_cast_url_is_http "git@github.com:a/b.git"; then
            _cc_ok "url classifies HTTPS vs SSH"
        else
            _cc_fail "url HTTPS/SSH classification"
        fi
    else
        _cc_fail "cast_url_is_http missing"
    fi

    if ! declare -f nds_cast_list_actions &>/dev/null; then
        _cc_fail "cast_list_actions missing"
        return 0
    fi

    root=$(mktemp -d "${TMPDIR:-/tmp}/nds_cast.XXXXXX")
    mkdir -p "${root}/.nds/actions"
    : >"${root}/.nds/actions/addFleetHost.sh"
    : >"${root}/.nds/actions/toolkit.sh"
    : >"${root}/.nds/actions/manifest.sh"
    : >"${root}/.nds/actions/myDeploy.sh"

    out=${ nds_cast_list_actions "$root"; }
    _cc_eq "list skips stubs + manifest" "$out" "myDeploy"

    if nds_cast_require_user_actions "$root" >/dev/null; then
        _cc_ok "require_user_actions with user action"
    else
        _cc_fail "require_user_actions should pass"
    fi

    rm -f "${root}/.nds/actions/myDeploy.sh"
    if nds_cast_require_user_actions "$root" >/dev/null 2>&1; then
        _cc_fail "empty catalog (stubs only) must fail closed"
    else
        _cc_ok "empty catalog (stubs only) fails closed"
    fi

    : >"${root}/.nds/actions/myDeploy.sh"
    out=${ nds_cast_action_script "$root" myDeploy; }
    _cc_eq "action_script resolves user action" "$out" "${root}/.nds/actions/myDeploy.sh"
    if nds_cast_action_script "$root" addFleetHost >/dev/null 2>&1; then
        _cc_fail "action_script must skip addFleetHost stub"
    else
        _cc_ok "action_script skips addFleetHost stub"
    fi

    unset NDS_CAST_ACTION
    nds_cfg_set CAST_ACTION ""
    # select_action requires CAST_ACTION / NDS_CAST_ACTION (unattended contract).
    if nds_cast_select_action "$root" >/dev/null 2>&1; then
        _cc_fail "select without CAST_ACTION must fail"
    else
        _cc_ok "select without CAST_ACTION fails"
    fi

    NDS_CAST_ACTION=myDeploy
    if nds_cast_select_action "$root" >/dev/null 2>&1; then
        out=$(nds_cfg_get CAST_ACTION)
        _cc_eq "select binds NDS_CAST_ACTION" "$out" "myDeploy"
    else
        _cc_fail "select with NDS_CAST_ACTION should pass"
    fi
    unset NDS_CAST_ACTION

    rm -rf "$root"
}
