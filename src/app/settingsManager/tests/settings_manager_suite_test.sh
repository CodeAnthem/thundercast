#!/usr/bin/env bash
# ==================================================================================================
# NDS - Settings manager tests
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-06 | Modified: 2026-07-06
# ==================================================================================================

suite_settings_manager() {
    local tmpdir count

    nds_mode_resolve || true
    if [[ -n "${NDS_MODE:-}" ]] && declare -f nds_cfg_aa_from_store &>/dev/null; then
        local -A cfg=()
        nds_cfg_aa_from_store cfg
        cfg[_NDS_MODE_PROBE]="1"
        nds_cfg_aa_to_store cfg
        if [[ "$(nds_cfg_get _NDS_MODE_PROBE)" == "1" ]]; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ config AA bridge round-trip"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ config AA bridge round-trip"
        fi
        unset 'CONFIG_DATA[_NDS_MODE_PROBE]'
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ mode/AA bridge missing"
    fi

    if [[ "${PRESET_LOADED[installFlake]:-}" == "1" ]]; then
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ lazy catalog: installFlake hooks loaded at init"
    else
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ lazy catalog: installFlake hooks not loaded at init"
    fi

    if [[ "${PRESET_LOADED[remoteAction]:-}" == "1" ]]; then
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ lazy catalog: remoteAction hooks loaded at init"
    else
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ lazy catalog: remoteAction hooks not loaded at init"
    fi

    if [[ "${PRESET_REGISTRY[installFlake]:-}" == "disabled" ]] \
       && [[ "${PRESET_REGISTRY[remoteAction]:-}" == "disabled" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ catalog: action-only presets registered disabled"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ catalog: installFlake/remoteAction should be disabled"
    fi

    nds_cfg_preset_disable "neverRegistered"
    if [[ -z "${PRESET_REGISTRY[neverRegistered]:-}" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ disable: no ghost entry for unknown preset"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ disable: ghost entry for unknown preset"
    fi

    nds_cfg_preset_disable disk
    if [[ "${PRESET_REGISTRY[disk]:-}" == "disabled" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ disable: catalog preset can be disabled"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ disable: catalog preset should disable"
    fi
    nds_cfg_preset_enable disk

    tmpdir=$(mktemp -d)
    mkdir -p "${tmpdir}/.nds/presets"
    cp "${TEST_ROOT}/fixtures/nds-remote-preset.sh" "${tmpdir}/.nds/presets/custom.sh"

    NDS_PRESET_INJECT_COUNT=0
    nds_preset_inject_from_flake "$tmpdir"
    if [[ "$NDS_PRESET_INJECT_COUNT" -eq 1 ]] && declare -f custom_defaults &>/dev/null; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ inject_from_flake: sets global count and registers hooks"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ inject_from_flake: count/hooks missing after direct call"
    fi

    rm -rf "$tmpdir"

    export NDS_NETWORK_HOSTNAME="envhost"
    nds_cfg_apply_env_all
    if [[ "${CONFIG_DATA[NETWORK_HOSTNAME]:-}" == "envhost" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ nds_cfg_apply_env_all: maps NDS_* to CONFIG_DATA"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ nds_cfg_apply_env_all"
    fi
    unset NDS_NETWORK_HOSTNAME
}
