#!/usr/bin/env bash
# ==================================================================================================
# NDS - App entry
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-12 | Modified: 2026-09-27
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

_nds_load_features() {
    local app_dir=$1
    local src_dir="${app_dir%/*}"
    local wizard="${src_dir}/wizard"

    # shellcheck source=../lib/lib_rand.sh
    source "${src_dir}/lib/lib_rand.sh" || return 1

    import_dir "${app_dir}/session" --depth 0 || return 1
    import_dir "${app_dir}/utility" --depth 0 || return 1
    local _nds_util
    for _nds_util in pkg age disk flake git hwconfig facter nixcfg nixos qr sops targetSeed; do
        nds_requireUtility "$_nds_util" || return 1
    done
    eventRun utility.load || return 1
    import_dir "${app_dir}/actionSelect" --depth 0 || return 1
    # shellcheck source=pipeline/confirm.sh
    source "${app_dir}/pipeline/confirm.sh" || return 1
    # shellcheck source=pipeline/finish.sh
    source "${app_dir}/pipeline/finish.sh" || return 1
    # shellcheck source=pipeline/pipeline.sh
    source "${app_dir}/pipeline/pipeline.sh" || return 1
    import_dir "${src_dir}/recipe" --depth 0 || return 1
    import_dir "${src_dir}/recipe/schema" --depth 0 || return 1
    import_dir "${src_dir}/cook" --depth 0 || return 1
    if [[ -d "$wizard" ]]; then
        import_dir "$wizard" --depth 0 || return 1
        [[ -d "${wizard}/askers" ]] && import_dir "${wizard}/askers" --depth 0
        [[ -d "${wizard}/git" ]] && import_dir "${wizard}/git" --depth 0
    fi
}

_nds_setup_chrome() {
    _nds_chrome_subtitleIdle() {
        chrome_setHeader 1 -b 238 -f 250
    }
    _nds_chrome_subtitleWait() {
        chrome_setHeader 1 -b 24 -f 255
    }
    chrome_setHeader 0 -b 236 -f 255
    _nds_chrome_subtitleIdle
    eventRegister prompt.pre _nds_chrome_subtitleWait || return 1
    eventRegister prompt.post _nds_chrome_subtitleIdle || return 1

    # Temporary. The frame is the alternate screen, so it vanishes on exit.
    # NDS_CHROME_HOLD=true waits for Enter before chrome_end. Remove after the visual check.
    _nds_chrome_hold() {
        [[ ${NDS_CHROME_HOLD:-} == true ]] || return 0
        chrome_isOn || return 0
        printf '\n%s\n' "Chrome held open. Press Enter to close." >/dev/tty
        read -r _nds_hold </dev/tty || true
    }
    eventRegister exit _nds_chrome_hold 1 || return 1
}

main() {
    local app_dir rc=0
    app_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

    _nds_load_essentials "$app_dir" "$@"
    logger_scopeExists nixos || logger_scopeCreate "NixOS install" nixos
    logger_scopeExists session || logger_scopeCreate "NDS session" session
    logger_scopeSet session

    _nds_setup_chrome || return 1
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
    prompt --type pause "Press Enter to continue" || true
}

# Run main only when this file is the program that was started, not when another file sources it.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
