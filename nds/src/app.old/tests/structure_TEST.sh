#!/usr/bin/env bash
# ==================================================================================================
# NDS - Structure / layout selfchecks (high-signal only)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-07 | Modified: 2026-09-03
# Description:   Post-drain layout + public API contracts — no migration archaeology
# ==================================================================================================

suite_structure() {
    local f missing=0
    local fleet_actions="${SCRIPT_DIR}/../../fleet/nds-actions"

    for f in \
        "${SCRIPT_DIR}/utilities/git/main.sh" \
        "${SCRIPT_DIR}/utilities/flake/main.sh" \
        "${SCRIPT_DIR}/utilities/disk/main.sh" \
        "${SCRIPT_DIR}/utilities/nixos/main.sh" \
        "${SCRIPT_DIR}/utilities/nixcfg/main.sh" \
        "${SCRIPT_DIR}/utilities/hwconfig/main.sh" \
        "${SCRIPT_DIR}/utilities/sops/main.sh" \
        "${SCRIPT_DIR}/utilities/targetSeed/main.sh" \
        "${SCRIPT_DIR}/utilities/facter/main.sh" \
        "${SCRIPT_DIR}/utilities/git/providers/git_github_bin.sh" \
        "${SCRIPT_DIR}/wizard/git/lib/git_warm.sh" \
        "${SCRIPT_DIR}/wizard/git/access/logic" \
        "${SCRIPT_DIR}/wizard/install/ui" \
        "${SCRIPT_DIR}/realize/main.sh" \
        "${SCRIPT_DIR}/realize/plan_classic.sh" \
        "${SCRIPT_DIR}/realize/plan_flake.sh" \
        "${SCRIPT_DIR}/wizard/install/logic/install_leaf_open.sh" \
        "${SCRIPT_DIR}/actions/classicInstall/setup.sh" \
        "${SCRIPT_DIR}/actions/installFlake/logic" \
        "${SCRIPT_DIR}/actions/remoteAction/logic" \
        "${SCRIPT_DIR}/app/bundleManager/logic" \
        "${SCRIPT_DIR}/app/sessionControl" \
        "${fleet_actions}/toolkit/logic" \
        "${fleet_actions}/toolkit/setup.sh" \
        "${fleet_actions}/addFleetHost/setup.sh"
    do
        if [[ ! -e "$f" ]]; then
            missing=1
            console "  ✗ missing: ${f#"$SCRIPT_DIR"/}"
        fi
    done
    if [[ -d "${SCRIPT_DIR}/install" || -d "${SCRIPT_DIR}/tools" || -d "${SCRIPT_DIR}/app/ensure" \
        || -d "${SCRIPT_DIR}/actions/apply/logic" || -d "${SCRIPT_DIR}/actions/classicInstall/logic" ]]; then
        missing=1
        console "  ✗ leftover install/, tools/, app/ensure/, or action-local realize logic"
    fi
    if [[ "$missing" -eq 0 ]]; then
        bts_pass "ok"
        console "  ✓ post-drain feature roots present"
    else
        bts_fail "fail"
    fi

    missing=0
    for f in \
        "${SCRIPT_DIR}/actions/classicInstall/setup.sh" \
        "${SCRIPT_DIR}/actions/installFlake/setup.sh" \
        "${SCRIPT_DIR}/actions/remoteAction/setup.sh" \
        "${SCRIPT_DIR}/actions/apply/setup.sh" \
        "${SCRIPT_DIR}/actions/test/setup.sh" \
        "${SCRIPT_DIR}/actions/uiSmoke/setup.sh"
    do
        [[ -f "$f" ]] || { missing=1; console "  ✗ missing action setup: ${f#"$SCRIPT_DIR"/}"; }
    done
    if [[ "$missing" -eq 0 ]]; then
        bts_pass "ok"
        console "  ✓ core action setup.sh files present"
    else
        bts_fail "fail"
    fi

    if declare -f _nds_app_warmupGitGh &>/dev/null \
        && ! declare -f _nds_app_warmupGitGh | grep -qE 'nds_ensure_gh|git_gh_prefetch|git_gh_ensure'; then
        bts_pass "ok"
        console "  ✓ warmup does not prefetch gh"
    else
        bts_fail "fail"
        console "  ✗ warmup still prefetches gh"
    fi

    if declare -f git_gh_ensure &>/dev/null \
        && declare -f nds_bundle_create &>/dev/null \
        && declare -f nds_import_tree &>/dev/null \
        && declare -f nds_realize_run &>/dev/null \
        && declare -f disk_prepare &>/dev/null \
        && declare -f nds_lib_getHostIP &>/dev/null; then
        bts_pass "ok"
        console "  ✓ key public APIs present"
    else
        bts_fail "fail"
        console "  ✗ missing key public APIs"
    fi

    if command -v rg &>/dev/null; then
        local hits
        hits=$(rg -n '^\s*(nds_ui_|nds_ask_user)' \
            "${SCRIPT_DIR}/wizard/git/access/logic" \
            "${SCRIPT_DIR}/wizard/git/keys/logic" \
            "${SCRIPT_DIR}/utilities/nixos/ops" \
            "${SCRIPT_DIR}/utilities/nixcfg/logic" \
            "${SCRIPT_DIR}/utilities/disk" \
            "${SCRIPT_DIR}/app/bundleManager/logic" \
            "${SCRIPT_DIR}/app/settingsManager/logic" \
            --glob '*.sh' 2>/dev/null || true)
        if [[ -n "$hits" ]]; then
            bts_fail "fail"
            console "  ✗ UI calls still in non-UI logic:"
            while IFS= read -r line; do
                console "      $line"
            done <<< "$hits"
        else
            bts_pass "ok"
            console "  ✓ no prompt UI calls in utility/settings/bundle logic"
        fi
    else
        bts_pass "ok"
        console "  ✓ (skip UI-in-logic grep — rg not installed)"
    fi

    # Layering: nobody reads a NDS_CTX_* snapshot anymore; utilities never call realize or
    # install prompts — they receive arguments.
    if command -v rg &>/dev/null; then
        local ctx_hits util_hits
        ctx_hits=$(rg -n 'NDS_CTX_|nds_install_ctx_' "${SCRIPT_DIR}" "${fleet_actions}" \
            --glob '*.sh' --glob '!**/tests/**' 2>/dev/null || true)
        util_hits=$(rg -n 'nds_realize_|_nds_realize_|nds_install_ui_' "${SCRIPT_DIR}/utilities" \
            --glob '*.sh' --glob '!**/tests/**' 2>/dev/null || true)
        if [[ -z "$ctx_hits" && -z "$util_hits" ]]; then
            bts_pass "ok"
            console "  ✓ no NDS_CTX_* snapshot; no utility → realize/prompt callbacks"
        else
            bts_fail "fail"
            console "  ✗ layering violations:"
            while IFS= read -r line; do
                [[ -n "$line" ]] && console "      $line"
            done <<< "${ctx_hits}"$'\n'"${util_hits}"
        fi
    fi
}
