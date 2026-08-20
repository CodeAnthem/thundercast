#!/usr/bin/env bash
# ==================================================================================================
# NDS - Self-test runner
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-24 | Modified: 2026-08-16
# Description:   Cross-feature entry — sources feature-colocated suites
# ==================================================================================================

set -euo pipefail

TEST_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TEST_ROOT
SCRIPT_DIR="$(cd "${TEST_ROOT}/.." && pwd)"
readonly SCRIPT_DIR

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/app/main.sh"
nds_app_bootstrap "$SCRIPT_DIR"
nds_app_loadSettingsManager
nds_cfg_init
nds_app_loadFeatures

# shellcheck disable=SC1091
source "${TEST_ROOT}/framework.sh"

# Feature-colocated suites
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/app/settingsManager/tests/settings_manager_suite_test.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/app/settingsManager/tests/settings_cfg_suite_test.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/app/settingsManager/tests/settings_presets_suite_test.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/app/settingsManager/tests/settings_validators_test.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/app/settingsManager/tests/settings_inputs_suite_test.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/app/settingsManager/tests/settings_sm_suite_test.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/app/tests/app_skip_suite_test.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/app/tests/app_mode_suite_test.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/app/tests/app_helpers_suite_test.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/app/tests/app_structure_suite_test.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/app/tests/app_actions_suite_test.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/git/tests/git_suite_test.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/tools/tests/tools_suite_test.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/tools/tests/tools_facter_suite_test.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/app/bundle/tests/bundle_suite_test.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/install/tests/install_nixwriter_suite_test.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/install/tests/install_classic_config_suite_test.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/install/tests/install_suite_test.sh"

nds_run_self_tests() {
    TEST_PASSED=0
    TEST_FAILED=0

    nds_ui_section_title "NDS self-tests"

    run_named_suite "settingsManager" suite_settings_manager
    run_named_suite "settings_sm" suite_settings_sm
    run_named_suite "skip" suite_skip
    run_named_suite "cfg" suite_cfg
    run_named_suite "presets" suite_presets
    run_named_suite "validators" suite_validators
    run_named_suite "nixWriter" suite_nixwriter
    run_named_suite "standalone" suite_standalone
    run_named_suite "structure" suite_structure
    run_named_suite "actions" suite_actions
    run_named_suite "git" suite_git
    run_named_suite "mode" suite_mode
    run_named_suite "tools_lib" suite_tools_lib
    run_named_suite "bundle" suite_bundle
    run_named_suite "inputs" suite_inputs
    run_named_suite "classicConfig" suite_classic_config
    run_named_suite "install" suite_install
    run_named_suite "facter" suite_facter

    print_test_summary
}

# Only auto-run when executed as a script (CI / bash src/tests/run.sh).
# Sourced by the live `test` action — caller invokes nds_run_self_tests.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    nds_run_self_tests
fi
