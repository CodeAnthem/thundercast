#!/usr/bin/env bash
# ==================================================================================================
# NDS - Settings session / recipe / secret-file tests
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-20 | Modified: 2026-08-20
# ==================================================================================================

suite_settings_sm() {
    local sid tmp recipe pwfile

    sid="$(nds_sm_create --name smtest --builtin disk,encryption)" || {
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ nds_sm_create"
        nds_sm_use default || true
        return 0
    }
    nds_sm_use "$sid" || true
    if [[ "$sid" == "smtest" && "$SM_CURRENT" == "smtest" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ nds_sm_create isolates a named session"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ nds_sm_create id/current ($sid / $SM_CURRENT)"
    fi

    nds_cfg_set DISK_TARGET "/dev/smtest"
    nds_sm_use default
    if [[ "$(nds_cfg_get DISK_TARGET)" != "/dev/smtest" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ default session did not receive smtest DISK_TARGET"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ session leak: default has smtest DISK_TARGET"
    fi
    nds_sm_use smtest
    if [[ "$(nds_sm_get DISK_TARGET)" == "/dev/smtest" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ nds_sm_get reads the active session"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ nds_sm_get after use smtest"
    fi

    nds_cfg_set INSTALL_KIND "classic"
    nds_cfg_set ENCRYPTION "true"
    nds_cfg_set ENCRYPTION_PASSWORD "true"
    tmp=$(mktemp -d)
    recipe="${tmp}/host.recipe"
    nds_sm_export --recipe "$recipe"
    if grep -q '^\[disk\]' "$recipe" && grep -q 'DISK_TARGET="/dev/smtest"' "$recipe" \
        && grep -q '^kind=classic' "$recipe"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ nds_sm_export writes sectioned recipe"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ nds_sm_export recipe contents"
    fi

    nds_cfg_set ACCESS_ADMIN_PASSWORD "super-secret-value"
    nds_sm_secret_register ACCESS_ADMIN_PASSWORD
    nds_sm_materialize_secrets
    pwfile="$(nds_cfg_get ACCESS_ADMIN_PASSWORD_FILE)"
    if [[ -n "$pwfile" && -f "$pwfile" ]] \
        && [[ "$(cat "$pwfile")" == "super-secret-value" ]] \
        && [[ -z "$(nds_cfg_get ACCESS_ADMIN_PASSWORD)" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ secret values move to *_FILE (0600)"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ nds_sm_materialize_secrets"
    fi
    nds_sm_export --recipe "${tmp}/redacted.recipe"
    if grep -q 'ACCESS_ADMIN_PASSWORD_FILE=' "${tmp}/redacted.recipe" \
        && ! grep -q 'super-secret-value' "${tmp}/redacted.recipe"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ recipe export never contains secret values"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ recipe leaked a secret value"
    fi

    if validate_secret_file "$pwfile"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ validate_secret_file accepts the materialized path"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ validate_secret_file rejected a valid secret file"
    fi
    if validate_secret_file "/tmp/nds-missing-secret"; then
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ validate_secret_file accepted a missing path"
    else
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ validate_secret_file rejects missing files"
    fi

    nds_sm_create --name smload --builtin disk,encryption >/dev/null || {
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ nds_sm_create smload"
        nds_sm_use default || true
        rm -rf "$tmp"
        return 0
    }
    nds_sm_load "$recipe"
    if [[ "$(nds_cfg_get DISK_TARGET)" == "/dev/smtest" ]] \
        && [[ "$(nds_cfg_get INSTALL_KIND)" == "classic" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ nds_sm_load restores sectioned keys"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ nds_sm_load"
    fi
    export NDS_DISK_TARGET="/dev/from-env"
    nds_sm_load_with_env "$recipe"
    if [[ "$(nds_cfg_get DISK_TARGET)" == "/dev/from-env" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ nds_sm_load_with_env: NDS_* overrides recipe"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ nds_sm_load_with_env override"
    fi
    unset NDS_DISK_TARGET
    if nds_sm_validate encryption; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ nds_sm_validate uses shared preset validators"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ nds_sm_validate encryption"
    fi

    nds_sm_use default
    rm -rf "$tmp"
}
