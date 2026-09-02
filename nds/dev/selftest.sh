#!/usr/bin/env bash
# ==================================================================================================
# NDS - Self-test runner (bashTestSuite + feature *_TEST.sh)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-29 | Modified: 2026-09-03
# ==================================================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
NDS_SRC="${ROOT}/nds/src"
SCRIPT_DIR="${NDS_SRC}"
APP_DIR="${NDS_SRC}/app"
FLEET_ACTIONS="${ROOT}/fleet/nds-actions"

# shellcheck disable=SC1091
source "${ROOT}/utilities/bashTestSuite/main.sh"

# shellcheck disable=SC1091
source "${APP_DIR}/main.sh"
nds_app_bootstrap "$SCRIPT_DIR"
nds_app_loadSettingsManager
nds_cfg_init
nds_app_loadFeatures

# NDS-only suite helpers (CONFIG_DATA isolation)
nds_test_reset_config() {
    local key
    CONFIG_DATA=()
    if [[ ${#NDS_TEST_CONFIG_SNAPSHOT[@]} -gt 0 ]]; then
        for key in "${!NDS_TEST_CONFIG_SNAPSHOT[@]}"; do
            CONFIG_DATA["$key"]="${NDS_TEST_CONFIG_SNAPSHOT[$key]}"
        done
    fi
}

nds_test_snapshot_config() {
    local key
    declare -gA NDS_TEST_CONFIG_SNAPSHOT=()
    for key in "${!CONFIG_DATA[@]}"; do
        NDS_TEST_CONFIG_SNAPSHOT["$key"]="${CONFIG_DATA[$key]}"
    done
}

bashTestSuite_title "Thunderboot - Nix Deploy System v${SCRIPT_VERSION} self-tests"
bashTestSuite_sourceTree "${NDS_SRC}" || exit 1
# Fleet birth wizards (toolkit / addFleetHost) live outside nds/src.
[[ -d "$FLEET_ACTIONS" ]] && bashTestSuite_sourceTree "$FLEET_ACTIONS"

# Stable order (catalog laziness asserts must run before action suites load presets)
TEST_PASSED=0
TEST_FAILED=0
run_named_suite "settingsManager" suite_settings_manager
run_named_suite "settings_sm" suite_settings_sm
run_named_suite "skip" suite_skip
run_named_suite "cfg" suite_cfg
run_named_suite "presets" suite_presets
run_named_suite "validators" suite_validators
run_named_suite "nixWriter" suite_nixwriter
run_named_suite "structure" suite_structure
run_named_suite "actions" suite_actions
run_named_suite "git" suite_git
run_named_suite "git_utility" suite_git_utility
run_named_suite "disk_utility" suite_disk_utility
run_named_suite "mode" suite_mode
run_named_suite "bundle" suite_bundle
run_named_suite "inputs" suite_inputs
run_named_suite "classicConfig" suite_classic_config
run_named_suite "classic_hardware" suite_classic_hardware
run_named_suite "nixos_store" suite_nixos_store
run_named_suite "flake_helpers" suite_flake_helpers
run_named_suite "cast_catalog" suite_cast_catalog
run_named_suite "toolkit_sops" suite_toolkit_sops
run_named_suite "facter" suite_facter

BASH_TESTSUITE_PASSED=$TEST_PASSED
BASH_TESTSUITE_FAILED=$TEST_FAILED
print_test_summary
