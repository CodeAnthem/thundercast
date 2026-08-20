#!/usr/bin/env bash
# ==================================================================================================
# NDS - Preset injection tests
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-06 | Modified: 2026-07-06
# ==================================================================================================

suite_presets() {
    local tmpdir count

    tmpdir=$(mktemp -d)
    mkdir -p "${tmpdir}/.nds/presets"
    cp "${TEST_ROOT}/fixtures/nds-remote-preset.sh" "${tmpdir}/.nds/presets/custom.sh"

    nds_preset_inject_from_flake "$tmpdir"
    count=$NDS_PRESET_INJECT_COUNT
    if [[ "$count" -eq 1 ]] && [[ "${PRESET_REGISTRY[custom]:-}" == "enabled" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ inject_from_flake: loads and enables custom preset"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ inject_from_flake: expected 1 preset enabled"
    fi

    if declare -f custom_defaults &>/dev/null && declare -f custom_configure &>/dev/null \
        && [[ "${PRESET_HOOKS[custom__validate]:-}" == "custom_validate" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ inject_from_flake: hooks registered"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ inject_from_flake: missing custom_* hooks / PRESET_HOOKS"
    fi

    rm -rf "$tmpdir"

    if validate_git_remote "git@github.com:org/repo.git" \
       && validate_git_url_classify "https://github.com/a/b" | grep -q https; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ validators/git: remote URL helpers"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ validators/git: remote URL helpers"
    fi

    if validate_toggle_normalize "yes" | grep -q true && validate_toggle_normalize "no" | grep -q false; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ validators/toggle: normalize yes/no"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ validators/toggle: normalize"
    fi
}
