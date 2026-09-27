#!/usr/bin/env bash
# ==================================================================================================
# NDS - App entry
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-12 | Modified: 2026-09-24
# ==================================================================================================
set -euo pipefail

_nds_load_essentials() {
    local app_dir="$1"
    shift
    local script_source="${app_dir%/*}"

    declare -gA essentials_config=(
        [BASHVERSION_MAJOR]="5"
        [BASHVERSION_MINOR]="3"
        [LOG_ROOT]="/tmp/nds/logs"
        [LOG_PURGE]="true"
        [LOG_MINLEVEL]="verbose"
        [LOG_STDERRLEVEL]="warn"
        [LOG_INDENT]="2"
        [LOG_COLOR]="true"
        [LOG_COMPOSE_FILENAME]="nds.log"
        [ROOTREEXEC_ROOT]="true"
        [ROOTREEXEC_SCRIPT]="${app_dir}/main.sh"
        [ROOTREEXEC_PURPOSE]="NixOS deployment"
        [ROOTREEXEC_KEEP_ENV_PREFIX]="NDS_"
        [TRAP_PRESETS]="true"
        [SCRIPTINFO_DIR]="${script_source}"
        [SCRIPTINFO_NAME]="Thundercast - Nix Deploy System"
        [SCRIPTINFO_VERSION]="$(< "${script_source}/VERSION")"
        [TTY_EXIT_PRIORITY]="10"
        [RUNTIME_PREFIX]="nds"
        [RUNTIME_SUBDIRS]="recipe secrets config seed work logs"
        [RUNTIME_PURGE_STALE]="true"
        [UI_MODE]="auto"
    )

    # shellcheck source=../../../utilities/essentials/essentials.sh
    source "${app_dir}/../../../utilities/essentials/essentials.sh"
    essentials_init "$@"
}

main() {
    local app_dir rc=0
    app_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

    _nds_load_essentials "$app_dir" "$@"
    logger_scopeExists nixos || logger_scopeCreate "NixOS install" nixos
    logger_scopeExists session || logger_scopeCreate "NDS session" session
    logger_scopeSet session

    # shellcheck source=chrome.sh
    source "${app_dir}/chrome.sh"
    # shellcheck source=features.sh
    source "${app_dir}/features.sh"
    _nds_load_features "$app_dir" || return 1

    nds_cli_parse "$@" || rc=$?
    if [[ "$rc" -eq 2 ]]; then
        return 0
    fi
    [[ "$rc" -eq 0 ]] || return "$rc"

    tty_guardEnable
    chrome_begin
    nds_mode_resolve || return 1
    info "NDS ${ scriptInfo_get_version; } mode=${NDS_MODE}"
    chrome_setSubtitle "$NDS_MODE"
    nds_pipeline_run || return 1
    chrome_setSubtitle "${NDS_CURRENT_ACTION:-}"
}

# Run main only when this file is the program that was started, not when another file sources it.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
