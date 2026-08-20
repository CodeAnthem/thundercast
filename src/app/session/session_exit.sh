#!/usr/bin/env bash
# ==================================================================================================
# NDS - App exit and trap helpers
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-29 | Modified: 2026-08-16
# Description:   Exit hooks, fatal handling, and trap-safe shutdown output
# ==================================================================================================

declare -g _nds_app_session_fatalMessage=""

# Description: Store a fatal message and terminate with the app fatal exit code.
crash() {
    _nds_app_session_fatalMessage="$1"
    exit 200
}

# Description: Run registered hook function by hook key when present.
_nds_app_session_callHook() {
    local hookName="$1"
    shift
    local hookFunction="${NDS_HOOK_FUNCTIONS[$hookName]}"
    [[ -n "$hookFunction" ]] || { error "Hook '$hookName' not found"; return 1; }
    declare -f "$hookFunction" &>/dev/null && { "$hookFunction" "$@"; return 0; }
    return 1
}

# Description: Default EXIT trap handler for the app entrypoint.
_nds_app_session_onExit() {
    local exit_code=$?
    local exit_msg=""
    NDS_UI_QUIET=false
    exit_msg=$(_nds_app_session_callHook "exit_msg" "$exit_code" || true)

    [[ "$exit_code" -eq "$NDS_ACTION_BACK" ]] && return 0

    if [[ -n "$exit_msg" ]]; then
        console "$exit_msg"
    else
        case "${exit_code}" in
            0)
                if [[ -z "${NDS_CURRENT_ACTION:-}" ]]; then
                    success "Script completed successfully"
                fi
                ;;
            130) warn "Script aborted by user" ;;
            200) fatal "Internal error! - ${_nds_app_session_fatalMessage:-}" ;;
            *) warn "Script failed with exit code: $exit_code" ;;
        esac
    fi

    [[ "$exit_code" -eq "$NDS_ACTION_BACK" ]] && return 0

    if [[ "$exit_code" -ne 0 ]]; then
        nds_app_session_ui_showFailure "$exit_code"
        # Ask last so Ctrl+C / failure still offers clearing a leftover gh session.
        _nds_app_session_callHook "exit_cleanup" "$exit_code" || true
        return 0
    fi

    info "Cleaning up session"
    nds_runtime_purge
    _nds_app_session_callHook "exit_cleanup" "$exit_code" || true
    if [[ "${NDS_REBOOT_IN_PROGRESS:-}" != "1" ]] \
        && declare -f nds_bundle_print_reboot_hint &>/dev/null; then
        nds_bundle_print_reboot_hint
    fi
}
