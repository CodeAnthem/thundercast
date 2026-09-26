#!/usr/bin/env bash
# ==================================================================================================
# NDS - Shared test boot
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-24 | Modified: 2026-09-26
# Description:   Loads essentials for NDS tests and points scriptInfo at nds/src.
# ==================================================================================================

_NDS_SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

# shellcheck source=../../utilities/essentials/testEnvironment/testEnvironment.sh
source "${_NDS_SRC_DIR}/../../utilities/essentials/testEnvironment/testEnvironment.sh"

nds_test_boot() {
    essentials_test_load logger eventBus importer ui chrome prompt scriptInfo task sessionDir || return 1
    __ESSENTIALS_SCRIPTINFO[script_dir]="$_NDS_SRC_DIR"
    __ESSENTIALS_SCRIPTINFO[script_name]="NDS Test"
    __ESSENTIALS_SCRIPTINFO[script_version]="0.0.0"
}

nds_test_session() {
    _NDS_TEST_SESSION=$(mktemp -d)
    mkdir -p \
        "${_NDS_TEST_SESSION}/recipe" \
        "${_NDS_TEST_SESSION}/secrets" \
        "${_NDS_TEST_SESSION}/config" \
        "${_NDS_TEST_SESSION}/seed" \
        "${_NDS_TEST_SESSION}/work" \
        "${_NDS_TEST_SESSION}/logs"
}

nds_session_dir() {
    local name=$1
    if [[ -z "${_NDS_TEST_SESSION:-}" ]]; then
        printf '%s\n' "nds_session_dir: no test session" >&2
        return 1
    fi
    printf '%s\n' "${_NDS_TEST_SESSION}/${name}"
}

nds_test_session_drop() {
    if [[ -n "${_NDS_TEST_SESSION:-}" && -d "${_NDS_TEST_SESSION}" ]]; then
        rm -rf "${_NDS_TEST_SESSION}"
    fi
    unset _NDS_TEST_SESSION
}

nds_test_boot
