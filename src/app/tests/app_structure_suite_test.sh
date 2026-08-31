#!/usr/bin/env bash
# ==================================================================================================
# NDS - Structure / layout selfchecks (CI-safe)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-07 | Modified: 2026-08-31
# Description:   Post-refactor layout invariants — no TTY, no disk wipe
# ==================================================================================================

suite_structure() {
    local f missing=0

    if [[ -d "${SCRIPT_DIR}/../TC-Tools/bin" && -f "${SCRIPT_DIR}/../TC-Tools/bin/tcast" \
        && -d "${SCRIPT_DIR}/../TC-Tools/commands" && -d "${SCRIPT_DIR}/../TC-Tools/lib" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ TC-Tools/ host CLI present (bin + commands + lib)"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ missing TC-Tools/ host CLI layout"
    fi

    if [[ -d "${SCRIPT_DIR}/scripts" ]]; then
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ leftover src/scripts (moved to TC-Tools/)"
    else
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ no src/scripts"
    fi

    if [[ -d "${SCRIPT_DIR}/utilities/git" && -f "${SCRIPT_DIR}/utilities/git/main.sh" \
        && -d "${SCRIPT_DIR}/utilities/flake" && -f "${SCRIPT_DIR}/utilities/flake/main.sh" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ utilities/git + utilities/flake present"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ missing utilities/git or utilities/flake"
    fi

    if [[ -d "${SCRIPT_DIR}/git" ]]; then
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ leftover src/git (must be gitAccess/)"
    else
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ no src/git (gitAccess/ + utilities/)"
    fi

    if [[ -d "${SCRIPT_DIR}/gitAccess/github" ]]; then
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ gitAccess/github still present"
    else
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ no gitAccess/github (GH lives in tools/)"
    fi

    if [[ -d "${SCRIPT_DIR}/app/core" || -d "${SCRIPT_DIR}/app/lifecycle" || -d "${SCRIPT_DIR}/app/runtime" ]]; then
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ leftover app/core, app/lifecycle, or app/runtime"
    else
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ no leftover app/core|lifecycle|runtime (feature folders instead)"
    fi

    if [[ -d "${SCRIPT_DIR}/settingsManager" ]]; then
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ leftover top-level src/settingsManager (must live under app/)"
    else
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ settingsManager lives under app/"
    fi

    if [[ -e "${SCRIPT_DIR}/app/framework.sh" || -e "${SCRIPT_DIR}/app/cli.sh" \
        || -e "${SCRIPT_DIR}/app/exit.sh" || -e "${SCRIPT_DIR}/app/session.sh" \
        || -d "${SCRIPT_DIR}/app/ui" ]]; then
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ leftover app root files (framework/cli/exit/session.sh or app/ui)"
    else
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ session/ holds runtime+cli+exit; no app/framework.sh"
    fi

    if [[ -f "${SCRIPT_DIR}/app/actionHandler/logic/preview.sh" ]]; then
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ leftover actionHandler/logic/preview.sh (preview is UI-only)"
    else
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ action preview is a single UI file"
    fi

    if [[ -f "${SCRIPT_DIR}/app/settingsManager/logic/state/git-maps.sh" ]]; then
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ git URL maps still in settingsManager state"
    elif declare -f nds_git_export_maps &>/dev/null; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ git owns URL map export (nds_git_export_maps)"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ nds_git_export_maps missing"
    fi

    if [[ -d "${SCRIPT_DIR}/app/mode" ]]; then
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ leftover empty app/mode/"
    else
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ no leftover app/mode/"
    fi

    if find "${SCRIPT_DIR}" -type f -name 'load.sh' ! -path '*/tests/*' 2>/dev/null | grep -q .; then
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ nested load.sh still present under src/"
    else
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ no nested load.sh under src/"
    fi

    if declare -f nds_git_gh_cmd &>/dev/null || declare -f nds_git_gh_ensure &>/dev/null; then
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ nds_git_gh_* aliases still defined"
    else
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ no nds_git_gh_* aliases"
    fi

    if declare -f nds_install_bundle_create &>/dev/null; then
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ nds_install_bundle_* alias still defined"
    else
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ no nds_install_bundle_* aliases"
    fi

    if [[ -d "${SCRIPT_DIR}/bundle" ]]; then
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ leftover top-level src/bundle (must live under app/)"
    else
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ bundle lives under app/"
    fi

    if [[ -d "${SCRIPT_DIR}/install/logic" || -d "${SCRIPT_DIR}/install/ui" ]]; then
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ leftover install/logic or install/ui (must be disk/flake/classic/nix/verify)"
    else
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ install nested like git (disk/flake/classic/nix/verify)"
    fi

    if [[ -d "${SCRIPT_DIR}/gitAccess/logic" || -d "${SCRIPT_DIR}/gitAccess/ui" ]]; then
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ leftover gitAccess/logic or gitAccess/ui (must be access/keys/wizard)"
    else
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ gitAccess uses access/keys/wizard (no flat logic/ui)"
    fi

    if find "${SCRIPT_DIR}" -type f \( -name 'hosts.sh' -o -name 'key.sh' -o -name 'store.sh' \
        -o -name 'init.sh' -o -name 'ask.sh' -o -name 'handler.sh' \) \
        ! -path '*/actions/*' 2>/dev/null | grep -q .; then
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ generic basename still present (hosts.sh/key.sh/store.sh/…)"
    else
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ no generic featureless basenames"
    fi

    # NDS feature trees use _nds_*; utilities/ may use _git_ / _flake_ (NDS-free libs).
    if rg -n --glob '*.sh' \
        '^(_git_|_bundle_|_install_|_nixcfg_|_flake_|_sops_|_settings_|_switch_|_clean_)' \
        "${SCRIPT_DIR}" 2>/dev/null | grep -v '/utilities/' | grep -q .; then
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ private helpers still use _git_/_install_/… (must be _nds_…)"
    else
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ private helpers use _nds_ prefix"
    fi

    for f in \
        "${SCRIPT_DIR}/lib" \
        "${SCRIPT_DIR}/gitAccess/lib" \
        "${SCRIPT_DIR}/gitAccess/access/logic" \
        "${SCRIPT_DIR}/gitAccess/access/ui" \
        "${SCRIPT_DIR}/gitAccess/keys/logic" \
        "${SCRIPT_DIR}/gitAccess/keys/ui" \
        "${SCRIPT_DIR}/gitAccess/wizard/ui" \
        "${SCRIPT_DIR}/install/lib" \
        "${SCRIPT_DIR}/install/disk/logic" \
        "${SCRIPT_DIR}/install/disk/ui" \
        "${SCRIPT_DIR}/install/flake/logic" \
        "${SCRIPT_DIR}/install/flake/ui" \
        "${SCRIPT_DIR}/install/classic/logic" \
        "${SCRIPT_DIR}/install/nix/logic" \
        "${SCRIPT_DIR}/install/verify/logic" \
        "${SCRIPT_DIR}/install/verify/ui" \
        "${SCRIPT_DIR}/install/nixcfg/logic" \
        "${SCRIPT_DIR}/app/bundle/logic" \
        "${SCRIPT_DIR}/app/bundle/ui" \
        "${SCRIPT_DIR}/app/actionHandler/logic" \
        "${SCRIPT_DIR}/app/actionHandler/ui" \
        "${SCRIPT_DIR}/app/session" \
        "${SCRIPT_DIR}/app/settingsManager/logic" \
        "${SCRIPT_DIR}/app/settingsManager/ui"
    do
        if [[ ! -d "$f" ]]; then
            missing=1
            console "  ✗ missing layout dir: ${f#"$SCRIPT_DIR"/}"
        fi
    done
    if [[ "$missing" -eq 0 ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ feature layout dirs present (logic/ui)"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
    fi

    missing=0
    for f in \
        "${SCRIPT_DIR}/actions/classicInstall/setup.sh" \
        "${SCRIPT_DIR}/actions/installFlake/setup.sh" \
        "${SCRIPT_DIR}/actions/remoteAction/setup.sh" \
        "${SCRIPT_DIR}/actions/addRole/setup.sh" \
        "${SCRIPT_DIR}/actions/toolkit/setup.sh" \
        "${SCRIPT_DIR}/actions/apply/setup.sh" \
        "${SCRIPT_DIR}/actions/test/setup.sh" \
        "${SCRIPT_DIR}/actions/uiSmoke/setup.sh"
    do
        if [[ ! -f "$f" ]]; then
            missing=1
            console "  ✗ missing action: ${f#"$SCRIPT_DIR"/}"
        fi
    done
    if find "${SCRIPT_DIR}/actions" -mindepth 2 -type d \( -name logic -o -name ui \) 2>/dev/null | grep -q .; then
        missing=1
        console "  ✗ actions still have logic/ or ui/ (must be single setup.sh)"
    fi
    if [[ "$missing" -eq 0 ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ actions are single setup.sh (no logic/ui split)"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
    fi

    if declare -f _nds_app_warmupGitGh &>/dev/null \
        && ! declare -f _nds_app_warmupGitGh | grep -q 'nds_gh_ensure'; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ warmup does not prefetch gh"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ warmup still calls nds_gh_ensure (classicInstall must not nix-fetch gh)"
    fi

    if declare -f nds_gh_ensure &>/dev/null \
        && declare -f nds_bundle_create &>/dev/null \
        && declare -f nds_import_tree &>/dev/null \
        && declare -f nds_cfg_print_backup &>/dev/null \
        && declare -f nds_git_bundle_contrib &>/dev/null \
        && declare -f nds_lib_getHostIP &>/dev/null \
        && declare -f nds_lib_key_bodyLooksValid &>/dev/null \
        && declare -f nds_lib_env_is_true &>/dev/null \
        && declare -f nds_hook_register &>/dev/null \
        && declare -f nds_ui_indent_push &>/dev/null \
        && declare -f nds_ui_warn &>/dev/null; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ key public APIs present (gh/bundle/import/cfg UI/git keys/warn/lib)"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ missing key public APIs"
    fi

    if declare -f nds_bundle_host_ip &>/dev/null || declare -f nds_install_ssh_user &>/dev/null; then
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ leftover nds_bundle_host_ip / nds_install_ssh_user (use nds_lib_*)"
    else
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ host IP / SSH user live in lib/"
    fi

    # Soft: UI call sites must not live in feature logic (comments OK).
    if command -v rg &>/dev/null; then
        local hits
        hits=$(rg -n '^\s*(nds_ui_|nds_ask_user)' \
            "${SCRIPT_DIR}/gitAccess/access/logic" \
            "${SCRIPT_DIR}/gitAccess/keys/logic" \
            "${SCRIPT_DIR}/install/classic/logic" \
            "${SCRIPT_DIR}/install/disk/logic" \
            "${SCRIPT_DIR}/install/flake/logic" \
            "${SCRIPT_DIR}/install/nix/logic" \
            "${SCRIPT_DIR}/install/nixcfg/logic" \
            "${SCRIPT_DIR}/install/verify/logic" \
            "${SCRIPT_DIR}/app/bundle/logic" \
            "${SCRIPT_DIR}/app/settingsManager/logic" \
            "${SCRIPT_DIR}/app/actionHandler/logic" \
            --glob '*.sh' 2>/dev/null || true)
        if [[ -n "$hits" ]]; then
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ UI calls still in feature logic:"
            while IFS= read -r line; do
                console "      $line"
            done <<< "$hits"
        else
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ no prompt UI calls in feature logic"
        fi
    else
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ (skip logic/UI grep — rg not installed)"
    fi
}
