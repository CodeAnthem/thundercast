#!/usr/bin/env bash
# ==================================================================================================
# NDS - Action discovery selfcheck
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-07 | Modified: 2026-08-27
# ==================================================================================================

_nds_test_import_action() {
    local name="$1"
    local setup="${SCRIPT_DIR}/actions/${name}/setup.sh"

    unset -f action_setup action_preview action_config action_presets \
        action_on_accept action_extend_settings_manager 2>/dev/null || true

    if ! nds_import_file "$setup"; then
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ import ${name}/setup.sh"
        return 0
    fi
    if declare -f action_setup &>/dev/null && declare -f action_preview &>/dev/null; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ import ${name}: action_setup + action_preview"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ import ${name}: missing action_setup/action_preview"
    fi
}

suite_actions() {
    local -a names=()
    local n

    NDS_ACTION_NAMES=()
    unset NDS_ACTION_DATA
    declare -gA NDS_ACTION_DATA=()

    if ! nds_app_actionHandler_logic_discover "${SCRIPT_DIR}/actions"; then
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ nds_app_actionHandler_logic_discover failed"
        return 0
    fi

    for n in "${NDS_ACTION_NAMES[@]}"; do
        names+=("$n")
    done

    local have_classic=0 have_flake=0 have_remote=0 have_test=0 have_smoke=0
    local have_addrole=0 have_toolkit=0 have_apply=0
    for n in "${names[@]}"; do
        [[ "$n" == "classicInstall" ]] && have_classic=1
        [[ "$n" == "installFlake" ]] && have_flake=1
        [[ "$n" == "remoteAction" ]] && have_remote=1
        [[ "$n" == "addRole" ]] && have_addrole=1
        [[ "$n" == "toolkit" ]] && have_toolkit=1
        [[ "$n" == "apply" ]] && have_apply=1
        [[ "$n" == "test" ]] && have_test=1
        [[ "$n" == "uiSmoke" ]] && have_smoke=1
    done

    if [[ "$have_classic" -eq 1 && "$have_flake" -eq 1 && "$have_remote" -eq 1 \
        && "$have_addrole" -eq 1 && "$have_toolkit" -eq 1 && "$have_apply" -eq 1 ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ discover: classicInstall / installFlake / remoteAction / addRole / toolkit / apply"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ discover: missing production actions (${names[*]})"
    fi

    if [[ "$have_test" -eq 0 && "$have_smoke" -eq 0 ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ discover: test/uiSmoke hidden without NDS_TEST"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ discover: debug actions visible without NDS_TEST"
    fi

    NDS_TEST=true
    NDS_ACTION_NAMES=()
    unset NDS_ACTION_DATA
    declare -gA NDS_ACTION_DATA=()
    nds_app_actionHandler_logic_discover "${SCRIPT_DIR}/actions" || true
    have_test=0 have_smoke=0
    for n in "${NDS_ACTION_NAMES[@]}"; do
        [[ "$n" == "test" ]] && have_test=1
        [[ "$n" == "uiSmoke" ]] && have_smoke=1
    done
    unset NDS_TEST

    if [[ "$have_test" -eq 1 && "$have_smoke" -eq 1 ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ discover: test + uiSmoke when NDS_TEST=true"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ discover: NDS_TEST did not surface test/uiSmoke"
    fi

    # Execute-as-script "validation" cannot load sourced libraries (`return`, NDS funcs).
    _NDS_IMPORT_FIXTURE_MARKER=""
    if nds_import_file "${SCRIPT_DIR}/app/tests/fixtures/app_sourced_return.sh" \
        && [[ "${_NDS_IMPORT_FIXTURE_MARKER}" == "sourced" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ import: sourced file with top-level return"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ import: sourced file with top-level return"
    fi

    _nds_test_import_action classicInstall
    _nds_test_import_action installFlake
    _nds_test_import_action remoteAction
    _nds_test_import_action addRole
    _nds_test_import_action toolkit
    _nds_test_import_action apply
    _nds_test_import_action test
    _nds_test_import_action uiSmoke

    if grep -q 'Do not use a repository you do not trust' \
        "${SCRIPT_DIR}/install/flake/ui/install_flake_cast.sh" \
        && grep -q 'NDS_CAST_WARN_SKIP' \
        "${SCRIPT_DIR}/install/flake/ui/install_flake_cast.sh" \
        && grep -q 'later run scripts from it' \
        "${SCRIPT_DIR}/install/flake/ui/install_flake_cast.sh" \
        && ! grep -q 'do not run unknown remote actions' \
            "${SCRIPT_DIR}/actions/remoteAction/setup.sh" \
        && ! grep -q 'nds_cast_ui_confirm_source' \
            "${SCRIPT_DIR}/install/flake/logic/install_flake_cast.sh" \
        && ! grep -q 'nds_cast_ui_confirm_source' \
            "${SCRIPT_DIR}/install/flake/ui/install_flake_cast.sh"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ remoteAction: one untrusted-repo warning, before first fetch"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ remoteAction: warning missing, duplicated, or still in preview"
    fi

    if grep -q 'nds_cast_ui_confirm_fetch' \
        "${SCRIPT_DIR}/install/flake/logic/install_flake_cast.sh" \
        && awk '
            /^nds_cast_gate\(\)/ { g=1 }
            g && /nds_cast_ui_confirm_fetch/ { f=1 }
            g && /nds_cast_clone "/ { c=1; if (!f) exit 1 }
            END { exit (f && c) ? 0 : 1 }
        ' "${SCRIPT_DIR}/install/flake/logic/install_flake_cast.sh"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ remoteAction: confirm fetch before cloning catalog"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ remoteAction: catalog cloned without confirm fetch"
    fi
    if grep -q 'remote_action_config || exit' \
        "${SCRIPT_DIR}/actions/remoteAction/setup.sh"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ remoteAction: remote_action_config failure aborts setup"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ remoteAction: remote_action_config failure is ignored"
    fi
    if awk '
            /nds_cfg_menu_or_skip/ { n++; if (!cfg) early=1 }
            /remote_action_config/ { cfg=1 }
            END { exit (n==1 && cfg && !early) ? 0 : 1 }
        ' "${SCRIPT_DIR}/actions/remoteAction/setup.sh" \
        && grep -q 'nds_install_open_leaf' \
            "${SCRIPT_DIR}/actions/remoteAction/setup.sh" \
        && grep -q 'nds_install_flake_probe_leaf_write' \
            "${SCRIPT_DIR}/install/apply/logic/install_apply.sh" \
        && ! grep -q 'nds_cfg_prompt_errors' \
            "${SCRIPT_DIR}/actions/remoteAction/setup.sh"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ remoteAction: one settings menu after compose config; open_leaf write probe"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ remoteAction: settings menu count, write probe, or early prompt_errors"
    fi

    if awk '
            /^action_setup\(\)/ { s=1 }
            s && /nds_install_confirm/ { conf=1 }
            s && /nds_addRole_compose \|\|/ { if (!conf) exit 1 }
            END { exit (s && conf) ? 0 : 1 }
        ' "${SCRIPT_DIR}/actions/addRole/setup.sh" \
        && awk '
            /^action_setup\(\)/ { s=1 }
            s && /nds_install_confirm/ { conf=1 }
            s && /nds_toolkit_compose \|\|/ { if (!conf) exit 1 }
            END { exit (s && conf) ? 0 : 1 }
        ' "${SCRIPT_DIR}/actions/toolkit/setup.sh" \
        && awk '
            /nds_install_confirm/ { conf=1 }
            /remote_action_run \|\|/ { if (!conf) exit 1 }
            END { exit conf ? 0 : 1 }
        ' "${SCRIPT_DIR}/actions/remoteAction/setup.sh" \
        && grep -q 'NDS_INSTALL_CONFIRMED' \
            "${SCRIPT_DIR}/install/apply/logic/install_apply.sh"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ composers confirm disk wipe before git-push compose"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ composers push/compose before disk confirm"
    fi

    if ! grep -q 'nds_cfg_set CAST_ACTION "addRole"' \
            "${SCRIPT_DIR}/install/flake/ui/install_flake_cast.sh" \
        && grep -q 'nds_cast_require_user_actions' \
            "${SCRIPT_DIR}/install/flake/logic/install_flake_cast.sh" \
        && grep -q 'addRole|toolkit) return 1' \
            "${SCRIPT_DIR}/install/flake/logic/install_flake_cast.sh"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ remoteAction: empty catalog does not default CAST_ACTION=addRole"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ remoteAction: empty catalog still defaults to addRole or stubs load"
    fi

    if grep -q '_nds_toolkit_refuse_remote' \
            "${SCRIPT_DIR}/actions/toolkit/setup.sh" \
        && grep -q 'toolkit is local-only' \
            "${SCRIPT_DIR}/actions/toolkit/setup.sh" \
        && grep -q 'nds_cfg_preset_set_menu installFlake false' \
            "${SCRIPT_DIR}/actions/toolkit/setup.sh"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ toolkit: INSTALL_MODE=remote is refused, installFlake hidden"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ toolkit: remote install is not hard-blocked or Your flake still listed"
    fi

    if grep -q 'nds_sm_validate' "${SCRIPT_DIR}/actions/classicInstall/setup.sh" \
        && grep -q 'nds_sm_menu' "${SCRIPT_DIR}/actions/classicInstall/setup.sh" \
        && grep -q 'nds_sm_validate' "${SCRIPT_DIR}/actions/installFlake/setup.sh" \
        && grep -q 'nds_sm_menu' "${SCRIPT_DIR}/actions/installFlake/setup.sh"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ classicInstall/installFlake use nds_sm_validate/menu"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ classicInstall/installFlake still call nds_cfg_validate_all directly"
    fi
}
