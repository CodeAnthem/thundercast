#!/usr/bin/env bash
# ==================================================================================================
# NDS - Bundle core feature selfchecks
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-05 | Modified: 2026-08-27
# ==================================================================================================

suite_bundle() {
    if declare -f nds_bundle_register_file &>/dev/null \
        && declare -f nds_bundle_create &>/dev/null \
        && declare -f nds_bundle_path &>/dev/null \
        && declare -f nds_bundle_finish &>/dev/null \
        && declare -f nds_bundle_print_reboot_hint &>/dev/null; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ bundle: register/create/path/finish API loaded"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ bundle: core API missing"
    fi

    if declare -f nds_install_bundle_create &>/dev/null \
        || declare -f nds_install_bundle_path &>/dev/null; then
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ bundle: leftover nds_install_bundle_* alias"
    else
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ bundle: no nds_install_bundle_* aliases"
    fi

    if nds_import_file "${SCRIPT_DIR}/app/bundle/tests/bundle_register_test.sh" 2>/dev/null \
        && nds_test_bundle_register_api; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ bundle: register hooks materialize files"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ bundle: register hooks materialize"
    fi

    if declare -f _nds_bundle_quickstart &>/dev/null; then
        local dest ver
        dest=$(mktemp)
        ver="${SCRIPT_VERSION:-}"
        [[ -n "$ver" ]] || ver=$(<"${SCRIPT_DIR}/app/VERSION")
        NDS_CTX_HOSTNAME=testhost _nds_bundle_quickstart "$dest"
        if grep -q "\*\*NDS version:\*\* ${ver}" "$dest" \
            && grep -q '\*\*NixOS version:\*\* ' "$dest" \
            && grep -q 'nds-restore.recipe' "$dest" \
            && ! grep -q $'\u2014' "$dest"; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ bundle: QUICK_START.md records versions, nds-restore.recipe, no em dash"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ bundle: QUICK_START.md missing versions, nds-restore.recipe, or has em dash"
        fi
        rm -f "$dest"

        dest=$(mktemp)
        local qs_stage
        qs_stage=$(mktemp -d)
        mkdir -p "${qs_stage}/secrets/git"
        printf 'dummy-key\n' >"${qs_stage}/secrets/git/nds_deploy_test_repo"
        NDS_CTX_HOSTNAME=testhost _nds_bundle_quickstart "${qs_stage}/QUICK_START.md"
        if grep -q 'secrets/git' "${qs_stage}/QUICK_START.md" \
            && grep -q 'Recreate this install' "${qs_stage}/QUICK_START.md"; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ bundle: QUICK_START.md documents secrets/git keys"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ bundle: QUICK_START.md missing secrets/git section"
        fi
        rm -rf "$qs_stage"
        rm -f "$dest"

        dest=$(mktemp)
        qs_stage=$(mktemp -d)
        mkdir -p "${qs_stage}/secrets/toolkit"
        printf 'dummy-age\n' >"${qs_stage}/secrets/toolkit/operator_age.txt"
        NDS_CTX_HOSTNAME=testhost _nds_bundle_quickstart "${qs_stage}/QUICK_START.md"
        if grep -q 'secrets/toolkit' "${qs_stage}/QUICK_START.md" \
            && grep -q 'Operator keys (keep this zip)' "${qs_stage}/QUICK_START.md" \
            && grep -q 'CAST_TOOLKIT_BUNDLE' "${qs_stage}/QUICK_START.md" \
            && ! grep -q $'\u2014' "${qs_stage}/QUICK_START.md"; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ bundle: QUICK_START.md documents toolkit operator keys"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ bundle: QUICK_START.md missing toolkit operator-key warning"
        fi
        rm -rf "$qs_stage"
        rm -f "$dest"

        dest=$(mktemp)
        NDS_CTX_HOSTNAME=testhost \
            NDS_CTX_ENCRYPTION=true \
            NDS_CTX_ENCRYPTION_PASSWORD=true \
            NDS_CTX_REMOTE_UNLOCK=true \
            NDS_CTX_REMOTE_PORT=2222 \
            NDS_CTX_REMOTE_NETWORK=dhcp \
            _nds_bundle_quickstart "$dest"
        local ru_line fl_line
        ru_line=$(grep -n '^## Remote unlock' "$dest" | head -n1 | cut -d: -f1)
        fl_line=$(grep -n '^## First login' "$dest" | head -n1 | cut -d: -f1)
        if [[ -n "$ru_line" && -n "$fl_line" && "$ru_line" -lt "$fl_line" ]] \
            && grep -q 'Initrd host key vs your unlock key' "$dest" \
            && grep -q 'IdentitiesOnly=yes' "$dest" \
            && ! grep -q 'Need to create that key first' "$dest"; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ bundle: QUICK_START.md remote unlock before first login"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ bundle: QUICK_START.md remote unlock order/content"
        fi
        rm -f "$dest"
    fi
}
