#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - App entry point
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-12 | Modified: 2026-08-20
# ==================================================================================================
# shellcheck disable=SC2162
set -euo pipefail

_nds_app_here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd || exit 1)"
: "${APP_DIR:=${_nds_app_here}}"
: "${SCRIPT_DIR:=$(cd "${APP_DIR}/.." && pwd || exit 1)}"
: "${SCRIPT_VERSION:=$(< "${APP_DIR}/VERSION")}"
: "${SCRIPT_NAME:=Thunderboot - Nix Deploy System}"

# Session events (info/warn). Merged into published nds.log.
: "${NDS_INSTALL_LOG:=/tmp/nds_session.log}"
# NDS step dumps (partition, facter, …). Rebased under RUNTIME_DIR in nds_runtime_init.
: "${NDS_INSTALL_DETAIL_LOG:=/tmp/nds_install.log}"
# nixos-install / nixos-anywhere stdout. Kept separate because it is huge.
: "${NDS_NIXOS_INSTALL_LOG:=/tmp/nds_nixosInstallation.log}"
export NDS_INSTALL_LOG NDS_INSTALL_DETAIL_LOG NDS_NIXOS_INSTALL_LOG

declare -gA NDS_HOOK_FUNCTIONS=(
    ["exit_msg"]="hook_exit_msg"
    ["exit_cleanup"]="nds_git_access_onExit"
)
declare -g NDS_FEATURES_LOADED=false
declare -g NDS_SETTINGS_LOADED=false

# shellcheck disable=SC1091
source "${APP_DIR}/import.sh"

_nds_app_elevateToRoot() {
    [[ $EUID -eq 0 ]] && return 0
    if ! command -v sudo &>/dev/null; then
        printf '  [FAIL] - NDS must run as root, but sudo is not available.\n' >&2
        exit 1
    fi
    if sudo -n true 2>/dev/null; then
        printf '  [INFO] - NDS requires root — re-running as root (sudo is passwordless).\n' >&2
    else
        printf '  [INFO] - NDS requires root — re-running via sudo.\n' >&2
    fi
    local nds_vars=()

    while IFS='=' read -r name value; do
        [[ "$name" =~ ^NDS_ ]] || continue
        nds_vars+=("$name=$value")
    done < <(env)
    if [[ ${#nds_vars[@]} -gt 0 ]]; then
        exec sudo "${nds_vars[@]}" DEBUG="${DEBUG:-0}" bash "${BASH_SOURCE[0]}" "${_nds_app_originalArgs[@]}"
    fi
    exec sudo DEBUG="${DEBUG:-0}" bash "${BASH_SOURCE[0]}" "${_nds_app_originalArgs[@]}"
}

# Description: Leftover gh session probe only — do not nix-prefetch gh.
_nds_app_warmupGitGh() {
    if declare -f nds_gh_host_logged_in &>/dev/null && nds_gh_host_logged_in; then
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

# Description: Load git, bundle, and install after an action is chosen.
nds_app_loadFeatures() {
    [[ "${NDS_FEATURES_LOADED}" == "true" ]] && return 0
    nds_import_tree "${SCRIPT_DIR}/git" || return 1
    nds_import_tree "${SCRIPT_DIR}/app/bundle" || return 1
    nds_import_tree "${SCRIPT_DIR}/install" || return 1
    if declare -f nds_install_logs_init &>/dev/null; then
        nds_install_logs_init || true
    fi
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
    nds_import_file "${script_dir}/app/mode.sh" || return 1
    nds_import_tree "${script_dir}/app/session" || return 1
    nds_import_tree "${script_dir}/tools" || return 1

    nds_import_file "${script_dir}/ui/terminal.sh" || return 1
    nds_import_file "${script_dir}/ui/input.sh" || return 1
    nds_import_file "${script_dir}/ui/logger.sh" || return 1
    nds_import_file "${script_dir}/ui/section.sh" || return 1
    nds_import_file "${script_dir}/ui/prompts.sh" || return 1
    nds_import_file "${script_dir}/ui/stepAnimation.sh" || return 1
    nds_ui_init

    nds_import_tree "${script_dir}/app/actionHandler" || return 1
    return 0
}

# Description: Session entry: traps, runtime, mode, then action-handler loop.
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

    nds_app_actionHandler_logic_discover "${SCRIPT_DIR}/actions" || crash "Failed to discover actions"
    nds_app_actionHandler_logic_main || exit $?
}

main() {
    declare -ga _nds_app_originalArgs=("$@")

    nds_app_bootstrap "$SCRIPT_DIR" || exit 1

    nds_app_session_cli_parseArgs "$@" || {
        local rc=$?
        [[ "$rc" -eq 2 ]] && exit 0
        exit "$rc"
    }

    _nds_app_elevateToRoot
    nds_app_run
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    readonly APP_DIR SCRIPT_DIR SCRIPT_VERSION SCRIPT_NAME
    readonly NDS_INSTALL_LOG
    main "$@"
fi
