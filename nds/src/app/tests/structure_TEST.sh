#!/usr/bin/env bash
# ==================================================================================================
# NDS - Structure / layout selfchecks (high-signal only)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-07 | Modified: 2026-09-02
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
        "${SCRIPT_DIR}/actions/apply/logic" \
        "${SCRIPT_DIR}/actions/classicInstall/logic" \
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
    if [[ -d "${SCRIPT_DIR}/install" || -d "${SCRIPT_DIR}/tools" || -d "${SCRIPT_DIR}/app/ensure" ]]; then
        missing=1
        console "  ✗ leftover install/, tools/, or app/ensure/"
    fi
    if [[ "$missing" -eq 0 ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ post-drain feature roots present"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
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
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ core action setup.sh files present"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
    fi

    if declare -f _nds_app_warmupGitGh &>/dev/null \
        && ! declare -f _nds_app_warmupGitGh | grep -qE 'nds_ensure_gh|git_gh_prefetch|git_gh_ensure'; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ warmup does not prefetch gh"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ warmup still prefetches gh"
    fi

    if declare -f git_gh_ensure &>/dev/null \
        && declare -f nds_bundle_create &>/dev/null \
        && declare -f nds_import_tree &>/dev/null \
        && declare -f nds_install_apply &>/dev/null \
        && declare -f disk_prepare &>/dev/null \
        && declare -f nds_lib_getHostIP &>/dev/null; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ key public APIs present"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
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
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ UI calls still in non-UI logic:"
            while IFS= read -r line; do
                console "      $line"
            done <<< "$hits"
        else
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ no prompt UI calls in utility/settings/bundle logic"
        fi
    else
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ (skip UI-in-logic grep — rg not installed)"
    fi
}
