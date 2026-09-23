#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - App entry point
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-12 | Modified: 2026-09-23
# ==================================================================================================
# shellcheck disable=SC2162
set -euo pipefail


_nds_setup_essentials() {
    # Get path to script source
    local current_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)" || exit 1
    local script_source="${current_dir%/*}"

    # Essentials Configuration
    local -A essentials_config=(
        # BashVersion
        [BASHVERSION_MAJOR]="5"
        [BASHVERSION_MINOR]="3"
        # Logger
        [LOG_ROOT]="${script_source}/logs"
        # [LOG_ROOT]="/tmp/logs"
        [LOG_PURGE]="true"
        [LOG_MINLEVEL]="verbose"
        [LOG_STDERRLEVEL]="warn"
        [LOG_INDENT]="2"
        [LOG_COLOR]="true"
        [LOG_COMPOSE_FILENAME]="nds.log"
        # rootReexec
        [ROOTREEXEC_ROOT]="true"
        [ROOTREEXEC_SCRIPT]="${current_dir}/main.sh"
        [ROOTREEXEC_PURPOSE]="NixOS deployment"
        [ROOTREEXEC_KEEP_ENV_PREFIX]="NDS_"
        # [ROOTREEXEC_KEEP_ENV_VARS]="DEBUG"
        # TrapHandler
        [TRAP_PRESETS]="true"
        # ScriptInfo
        [SCRIPTINFO_DIR]="${script_source}"
        [SCRIPTINFO_NAME]="Thundercast - Nix Deploy System"
        [SCRIPTINFO_VERSION]="$(< "${script_source}/VERSION")"
        # TTY
        [TTY_EXIT_PRIORITY]="10"
        # Runtime
        [RUNTIME_PREFIX]="nds"
        [RUNTIME_SUBDIRS]="config secrets"
        [RUNTIME_PURGE_STALE]="true"
        # UI
        [UI_MODE]="auto"
    )

    # Load Essentials
    source "${current_dir}/../../../utilities/essentials/essentials.sh" || {
        echo "Failed to source essentials.sh" >&2
        exit 1
    }

    _essentials_loadModules "$@" || {
        echo "Failed to load modules" >&2
        exit 1
    }
}
_nds_setup_essentials "$@"












# Test
logger_scopeCreate "NixOS Deployment System" "default"
verbose "This is a verbose message"
debug "This is a debug message"
info "This is a info message"
warn "This is a warn message"
error "This is a error message"

logger_compose "Thundercast NDS Log" "default"
logger_composeRead 5
fatal "This is a fatal message"


declare -gA NDS_HOOK_FUNCTIONS=(
    ["exit_msg"]="hook_exit_msg"
    ["exit_cleanup"]="nds_git_access_onExit"
)
declare -g NDS_FEATURES_LOADED=false
declare -g NDS_SETTINGS_LOADED=false

# shellcheck disable=SC1091
source "${APP_DIR}/moduleLoader/moduleLoader.sh"

# Description: Leftover gh session probe only — do not nix-prefetch gh.
_nds_app_warmupGitGh() {
    nds_requireUtility git || return 0
    if git_gh_host_logged_in; then
        NDS_GIT_GH_LEFTOVER=true
        export NDS_GIT_GH_LEFTOVER
        info "Leftover GitHub CLI login detected on this ISO (offered on exit)"
        nds_install_log "git: leftover gh session detected at warmup"
    else
        unset NDS_GIT_GH_LEFTOVER 2>/dev/null || true
        nds_install_log "git: no leftover gh session at warmup"
    fi
    return 0
}

# Description: Load settingsManager once.
nds_app_loadSettingsManager() {
    [[ "${NDS_SETTINGS_LOADED}" == "true" ]] && return 0
    nds_import_tree "${SCRIPT_DIR}/app/settingsManager" || return 1
    NDS_SETTINGS_LOADED=true
    return 0
}

# Description: Load utilities, wizard, bundleManager, and action-local trees after an action is chosen.
nds_app_loadFeatures() {
    [[ "${NDS_FEATURES_LOADED}" == "true" ]] && return 0
    local fleet_actions

    # Standalone utilities first (hooks via nds_requireUtility; sourcing does no work).
    nds_requireUtility git || return 1
    nds_requireUtility flake || return 1
    nds_requireUtility disk || return 1
    nds_requireUtility nixos || return 1
    nds_requireUtility nixcfg || return 1
    nds_requireUtility hwconfig || return 1
    nds_requireUtility sops || return 1
    nds_requireUtility targetSeed || return 1
    nds_requireUtility facter || return 1
    # Utility never prompts under NDS — actions use wizard/git (nds_git_access_run) for IO.
    export GIT_INTERACTIVE=0
    # NDS git orchestration (wizard/keys/maps) — calls store/flake APIs.
    nds_import_tree "${SCRIPT_DIR}/wizard/git" || return 1
    nds_import_tree "${SCRIPT_DIR}/wizard/install" || return 1
    nds_import_tree "${SCRIPT_DIR}/app/bundleManager" || return 1
    # Realize engine (Part A): the only code that partitions / installs. Actions compose, then call it.
    nds_import_tree "${SCRIPT_DIR}/realize" || return 1
    if [[ -d "${SCRIPT_DIR}/actions/installFlake/logic" ]]; then
        nds_import_tree "${SCRIPT_DIR}/actions/installFlake/logic" || return 1
    fi
    if [[ -d "${SCRIPT_DIR}/actions/remoteAction/logic" ]]; then
        nds_import_tree "${SCRIPT_DIR}/actions/remoteAction/logic" || return 1
    fi
    fleet_actions="$(cd "${SCRIPT_DIR}/../.." && pwd)/fleet/nds-actions"
    if [[ -d "${fleet_actions}/toolkit/logic" ]]; then
        nds_import_tree "${fleet_actions}/toolkit/logic" || return 1
    fi
    if [[ -d "${fleet_actions}/addFleetHost/logic" ]]; then
        nds_import_tree "${fleet_actions}/addFleetHost/logic" || return 1
    fi
    if declare -f nds_install_logs_init &>/dev/null; then
        nds_install_logs_init || true
    fi
    nds_utilities_runLoadHooks || return 1
    NDS_FEATURES_LOADED=true
    return 0
}

# Description: After action import: settingsManager extension, catalog, then git/bundle/install.
nds_app_prepareAction() {
    nds_app_loadSettingsManager || return 1
    if declare -f action_extend_settings_manager &>/dev/null; then
        action_extend_settings_manager || return 1
    fi
    nds_settings_catalog_init || return 1
    nds_app_loadFeatures || return 1
    return 0
}

# Description: Load backbone modules. Callers: main() and selftests (source this file first).
nds_app_bootstrap() {
    local script_dir="${1:-${SCRIPT_DIR}}"

    nds_import_tree "${script_dir}/lib" || return 1
    nds_import_tree "${script_dir}/app/utilityManager" || return 1
    nds_import_tree "${script_dir}/app/sessionControl" || return 1

    nds_import_file "${script_dir}/ui/terminal.sh" || return 1
    nds_import_file "${script_dir}/ui/input.sh" || return 1
    nds_import_file "${script_dir}/logger/logger.sh" || return 1
    nds_import_file "${script_dir}/ui/section.sh" || return 1
    nds_import_file "${script_dir}/ui/prompts.sh" || return 1
    nds_import_file "${script_dir}/ui/stepAnimation.sh" || return 1
    nds_ui_init

    nds_import_tree "${script_dir}/app/actionManager" || return 1
    return 0
}

# Description: Session entry: traps, runtime, mode, then actionManager loop.
nds_app_run() {
    if [[ "${_NDS_AUTO_CONFIRM_REQUESTED:-false}" == "true" ]]; then
        nds_skip_all
    fi

    trap _nds_ui_session_sigint SIGINT
    trap _nds_app_session_onExit EXIT
    nds_ui_input_guard_enable

    nds_runtime_init || crash "Failed to setup runtime directory"
    nds_install_log "NDS session started (v$SCRIPT_VERSION)"

    nds_mode_resolve || crash "Failed to resolve NDS_MODE"
    nds_install_log "NDS_MODE=${NDS_MODE}"

    _nds_app_warmupGitGh || true

    nds_app_actionManager_logic_discover "${SCRIPT_DIR}/actions" || crash "Failed to discover actions"
    nds_app_actionManager_logic_main || exit $?
}

main() {
    declare -ga _nds_app_originalArgs=("$@")

    _nds_setup_essentials || exit 1

    nds_app_bootstrap "$SCRIPT_DIR" || exit 1

    nds_app_session_cli_parseArgs "$@" || {
        local rc=$?
        [[ "$rc" -eq 2 ]] && exit 0
        exit "$rc"
    }

    nds_app_run
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    readonly APP_DIR SCRIPT_DIR SCRIPT_VERSION SCRIPT_NAME
    readonly NDS_INSTALL_LOG
    main "$@"
fi
