#!/usr/bin/env bash
# ==================================================================================================
# NDS - Run mode (interactive | unattended)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-05 | Modified: 2026-08-18
# Description:   Global NDS_MODE; features decide their own UI when mode allows
# ==================================================================================================

# interactive | unattended — set by nds_mode_resolve or env
declare -g NDS_MODE="${NDS_MODE:-}"

# Description: True when value is boolean true (true/1, case-insensitive).
nds_mode_env_true() {
    nds_lib_env_is_true "$1"
}

# Description: Resolve NDS_MODE from env if unset (env only; no settings store).
# Order: NDS_MODE → NDS_UNATTENDED → NDS_AUTO_CONFIRM → interactive.
nds_mode_resolve() {
    if [[ -n "${NDS_MODE:-}" ]]; then
        case "${NDS_MODE}" in
            interactive|unattended) ;;
            *)
                if declare -f error &>/dev/null; then
                    error "NDS_MODE must be interactive or unattended (got: ${NDS_MODE})"
                else
                    printf 'NDS_MODE must be interactive or unattended (got: %s)\n' "$NDS_MODE" >&2
                fi
                return 1
                ;;
        esac
        export NDS_MODE
        return 0
    fi

    if nds_mode_env_true "${NDS_UNATTENDED:-}"; then
        NDS_MODE="unattended"
    elif nds_mode_env_true "${NDS_AUTO_CONFIRM:-}"; then
        NDS_MODE="unattended"
    else
        NDS_MODE="interactive"
    fi
    export NDS_MODE
    return 0
}

# Description: True when global mode is unattended.
nds_mode_is_unattended() {
    [[ "${NDS_MODE:-interactive}" == "unattended" ]]
}

# Description: True when global mode is interactive.
nds_mode_is_interactive() {
    [[ "${NDS_MODE:-interactive}" == "interactive" ]]
}

# Description: True when unattended should reboot without asking.
# Interactive never returns true here — that path uses NDS_REBOOT_SKIP + a prompt.
nds_unattended_wants_reboot() {
    nds_mode_is_unattended || return 1
    nds_mode_env_true "${NDS_REBOOT_FORCE:-}"
}

# ==================================================================================================
# Skip registry (unattended / auto-confirm gates) — backbone, not UI
# ==================================================================================================

declare -ga _NDS_SKIP_REGISTRY=()

# Description: Register a skip variable name so nds_skip_all can set it.
# Arguments:
# - var: <String> Variable name (e.g. NDS_INSTALL_CONFIRM_SKIP)
nds_skip_register() {
    local var="$1"
    [[ " ${_NDS_SKIP_REGISTRY[*]} " == *" $var "* ]] || _NDS_SKIP_REGISTRY+=("$var")
}

nds_skip_register NDS_ACTION_PREVIEW_SKIP
nds_skip_register NDS_INSTALL_CONFIRM_SKIP
nds_skip_register NDS_REMOTE_CONFIRM_SKIP
nds_skip_register NDS_CAST_WARN_SKIP

# Description: Set all registered skip vars and NDS_AUTO_CONFIRM (--auto-confirm).
nds_skip_all() {
    local var
    for var in "${_NDS_SKIP_REGISTRY[@]}"; do
        export "$var"=true
    done
    export NDS_AUTO_CONFIRM=true
}

# Description: Skip an interactive menu when its NDS_*_SKIP flag or NDS_AUTO_CONFIRM is set.
# Arguments:
# - skip_var: <String> Name of the skip env var
# Returns:
# - 0 when the step should be skipped, 1 when the menu should run
nds_skip_menu() {
    local skip_var="${1:-}"
    if declare -f nds_env_is_true &>/dev/null; then
        nds_env_is_true "${NDS_AUTO_CONFIRM:-false}" && return 0
        [[ -n "$skip_var" ]] && nds_env_is_true "${!skip_var:-false}" && return 0
    else
        nds_mode_env_true "${NDS_AUTO_CONFIRM:-false}" && return 0
        [[ -n "$skip_var" ]] && nds_mode_env_true "${!skip_var:-false}" && return 0
    fi
    return 1
}
