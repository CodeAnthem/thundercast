#!/usr/bin/env bash
# ==================================================================================================
# NDS - Menu skip env tests
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-06 | Modified: 2026-08-30
# ==================================================================================================

suite_skip() {
    unset NDS_AUTO_CONFIRM NDS_INSTALL_CONFIRM_SKIP

    if nds_env_is_true true && nds_env_is_true 1; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ nds_env_is_true: true and 1"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ nds_env_is_true: true and 1"
    fi

    if ! nds_env_is_true false && ! nds_env_is_true ""; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ nds_env_is_true: false and empty"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ nds_env_is_true: false and empty"
    fi

    export NDS_INSTALL_CONFIRM_SKIP=true
    if nds_skip_menu NDS_INSTALL_CONFIRM_SKIP; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ nds_skip_menu: specific flag"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ nds_skip_menu: specific flag"
    fi
    unset NDS_INSTALL_CONFIRM_SKIP

    export NDS_CAST_WARN_SKIP=true
    if nds_skip_menu NDS_CAST_WARN_SKIP; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ nds_skip_menu: NDS_CAST_WARN_SKIP"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ nds_skip_menu: NDS_CAST_WARN_SKIP"
    fi
    unset NDS_CAST_WARN_SKIP

    if declare -f nds_skip_register &>/dev/null \
        && [[ " ${_NDS_SKIP_REGISTRY[*]} " == *" NDS_CAST_WARN_SKIP "* ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ skip_register: NDS_CAST_WARN_SKIP"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ skip_register: NDS_CAST_WARN_SKIP missing"
    fi

    export NDS_AUTO_CONFIRM=true
    if nds_skip_menu NDS_INSTALL_CONFIRM_SKIP; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ nds_skip_menu: NDS_AUTO_CONFIRM umbrella"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ nds_skip_menu: NDS_AUTO_CONFIRM umbrella"
    fi
    unset NDS_AUTO_CONFIRM

    nds_skip_all
    if [[ "${NDS_GIT_AUTH_SKIP:-false}" != "true" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ skip_all: does not set NDS_GIT_AUTH_SKIP"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ skip_all: must not skip git auth wizard"
    fi
    if grep -q 'nds_skip_menu NDS_INSTALL_CONFIRM_SKIP' \
            "${SCRIPT_DIR}/install/disk/ui/install_disk_prompts.sh" \
        && grep -q 'nds_skip_menu NDS_INSTALL_CONFIRM_SKIP' \
            "${SCRIPT_DIR}/install/verify/ui/install_confirm.sh"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ NDS_INSTALL_CONFIRM_SKIP covers format + remote confirm"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ NDS_INSTALL_CONFIRM_SKIP does not cover format/remote"
    fi
    local _skip_var
    for _skip_var in "${_NDS_SKIP_REGISTRY[@]}"; do
        unset "$_skip_var"
    done
    unset NDS_AUTO_CONFIRM

    nds_app_actionHandler_logic_discover "${SCRIPT_DIR}/actions" || return 1
    export NDS_ACTION=installFlake
    NDS_CURRENT_ACTION=""
    if nds_app_actionHandler_logic_selectFromEnv && [[ "$NDS_CURRENT_ACTION" == "installFlake" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ nds_app_actionHandler_logic_selectFromEnv: installFlake"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ nds_app_actionHandler_logic_selectFromEnv: installFlake"
    fi

    export NDS_ACTION=not_a_real_action
    NDS_CURRENT_ACTION=""
    if ! nds_app_actionHandler_logic_selectFromEnv 2>/dev/null; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ nds_app_actionHandler_logic_selectFromEnv: rejects invalid action"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ nds_app_actionHandler_logic_selectFromEnv: rejects invalid action"
    fi
    unset NDS_ACTION NDS_CURRENT_ACTION

    if declare -f nds_settings_catalog_init &>/dev/null \
        && declare -f nds_app_prepareAction &>/dev/null; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ staged load: catalog + prepare helpers present"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ staged load: catalog/prepare helpers missing"
    fi

    if declare -f nds_git_cfg_owner_slug &>/dev/null \
        && declare -f nds_git_clone_with_key &>/dev/null \
        && declare -f nds_install_ctx_get &>/dev/null \
        && declare -f nds_cfg_apply_env_all &>/dev/null; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ module boundaries: validators/settings helpers loaded"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ module boundaries: expected helpers missing"
    fi

    # Fresh process mimics main.sh: backbone only — no pre-sourced git/install.
    local prepare_out=""
    if prepare_out=$(
        env SCRIPT_DIR="$SCRIPT_DIR" "$BASH" -euo pipefail -c '
            source "${SCRIPT_DIR}/app/main.sh"
            nds_app_bootstrap "$SCRIPT_DIR" || exit 1
            nds_app_prepareAction || exit 1
            declare -f nds_git_owner_slug >/dev/null
            declare -f nds_install_disk_part >/dev/null
            declare -f nds_nixos_install >/dev/null
        ' 2>&1
    ); then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ prepare_action_runtime: loads standalone deps without pre-source"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ prepare_action_runtime: loads standalone deps without pre-source"
        console "    ${prepare_out}"
    fi
}
