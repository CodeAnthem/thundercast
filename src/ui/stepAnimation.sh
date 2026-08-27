#!/usr/bin/env bash
# ==================================================================================================
# NDS - UI - Step progress and spinner animation
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-29 | Modified: 2026-08-27
# Description:   Install step lines, spinner, and nds_step_exec wrapper
# ==================================================================================================

declare -g NDS_UI_STEP_NAME=""
declare -g NDS_UI_STEP_START=0

# Description: Render the icon prefix for a step state.
# Arguments:
# - state: <String> start | ok | fail
# Returns:
# - <String> Fixed-width 5-char icon (colored when supported)
# True when step animation may use color / CR rewrites (console TTY only).
nds_ui_step_tty() {
    [[ -t 2 ]]
}

# Description: Bracket icon for a step (start / ok / fail).
nds_ui_step_icon() {
    local state="$1"
    nds_ui_init
    case "$state" in
        start)
            printf '[   ]'
            ;;
        ok)
            if [[ "$NDS_UI_COLOR" == true ]] && nds_ui_step_tty; then
                printf '\033[32m[OK]\033[0m'
            else
                printf '[OK]'
            fi
            ;;
        fail)
            if [[ "$NDS_UI_COLOR" == true ]] && nds_ui_step_tty; then
                printf '\033[31m[FAIL]\033[0m'
            else
                printf '[FAIL]'
            fi
            ;;
    esac
}

# Description: Clear the in-progress step line so other TTY output can print.
nds_ui_step_yield() {
    [[ -n "${NDS_UI_STEP_NAME:-}" ]] || return 0
    nds_ui_step_tty || return 0
    printf '\r\033[K' >&2
}

# Description: Re-draw the in-progress step after yielded TTY output.
nds_ui_step_resume() {
    [[ -n "${NDS_UI_STEP_NAME:-}" ]] || return 0
    nds_ui_step_tty || return 0
    printf '%s%s %s' "$NDS_UI_INDENT_B" "$(nds_ui_step_icon start)" "$NDS_UI_STEP_NAME" >&2
}

# Description: Start an in-progress step line on stderr.
nds_step_start() {
    local message="$1"
    NDS_UI_STEP_NAME="$message"
    NDS_UI_STEP_START=$(date +%s)
    nds_ui_step_tty || return 0
    printf '%s%s %s' "$NDS_UI_INDENT_B" "$(nds_ui_step_icon start)" "$message" >&2
}

# Description: Finish the current step as success (elapsed seconds).
nds_step_complete() {
    local message="${1:-$NDS_UI_STEP_NAME}"
    local elapsed=$(( $(date +%s) - ${NDS_UI_STEP_START:-$(date +%s)} ))
    if nds_ui_step_tty; then
        printf '\r\033[K%s%s %s  (%ds)\n' "$NDS_UI_INDENT_B" "$(nds_ui_step_icon ok)" "$message" "$elapsed" >&2
    else
        printf '%s[OK] %s  (%ds)\n' "$NDS_UI_INDENT_B" "$message" "$elapsed" >&2
    fi
    NDS_UI_STEP_NAME=""
    NDS_UI_STEP_START=0
}

# Description: Finish the current step as failure (elapsed seconds).
nds_step_fail() {
    local message="${1:-$NDS_UI_STEP_NAME}"
    local elapsed=$(( $(date +%s) - ${NDS_UI_STEP_START:-$(date +%s)} ))
    if nds_ui_step_tty; then
        printf '\r\033[K%s%s %s  (%ds)\n' "$NDS_UI_INDENT_B" "$(nds_ui_step_icon fail)" "$message" "$elapsed" >&2
    else
        printf '%s[FAIL] %s  (%ds)\n' "$NDS_UI_INDENT_B" "$message" "$elapsed" >&2
    fi
    NDS_UI_STEP_NAME=""
    NDS_UI_STEP_START=0
}

# Description: Spinner that overwrites the step's icon slot until pid exits.
# No-op when stderr is not a TTY (nested nds_step_exec would otherwise log frames).
# Arguments:
# - pid:     <Int>    Background process id
# - message: <String> Step label to keep visible
nds_step_spinner() {
    local pid=$1
    local message="$2"
    local delay=0.12
    local spinstr="|/-\\"
    local char
    nds_ui_step_tty || {
        while ps -p "$pid" > /dev/null 2>&1; do
            sleep "$delay"
        done
        return 0
    }
    while ps -p "$pid" > /dev/null 2>&1; do
        char="${spinstr:0:1}"
        printf '\r\033[K%s[%s%s] %s' "$NDS_UI_INDENT_B" "$char" "$char" "$message" >&2
        spinstr="${spinstr:1}${spinstr:0:1}"
        sleep "$delay"
    done
}

# Description: Run a command with spinner; stdout/stderr append to logfile.
# Arguments:
# - label:   <String> Step label
# - logfile: <String> Destination log path
# - command: <String+> Command and args
nds_step_exec_to() {
    local label="$1"
    local logfile="$2"
    shift 2
    local rc=0

    mkdir -p "$(dirname "$logfile")" 2>/dev/null || true
    nds_step_start "$label"
    {
        printf '\n=== %s ===\n' "$label"
        "$@"
    } >>"$logfile" 2>&1 &
    local pid=$!
    nds_step_spinner "$pid" "$label"
    wait "$pid" || rc=$?
    if [[ "$rc" -eq 0 ]]; then
        nds_step_complete "$label"
        return 0
    fi
    nds_step_fail "$label"
    if declare -f nds_install_diag_step_failure &>/dev/null; then
        nds_install_diag_step_failure "$label"
    fi
    if declare -f nds_install_logs_fetch_hints &>/dev/null; then
        nds_install_logs_fetch_hints
    fi
    warn "Step failed — see ${logfile}"
    return "$rc"
}

# Description: Run a command with spinner; stdout/stderr go to the install detail log.
nds_step_exec() {
    nds_step_exec_to "$1" "${NDS_INSTALL_DETAIL_LOG:-/tmp/nds_install.log}" "${@:2}"
}

# Description: Run the NixOS installer step; output goes to nixosInstallation.log.
# Writes a pointer into the NDS detail log instead of the installer dump.
nds_step_exec_nixos() {
    local label="$1"
    shift
    local detail="${NDS_INSTALL_DETAIL_LOG:-/tmp/nds_install.log}"
    local nixos="${NDS_NIXOS_INSTALL_LOG:-/tmp/nds_nixosInstallation.log}"

    mkdir -p "$(dirname "$detail")" 2>/dev/null || true
    {
        printf '\n=== %s ===\n' "$label"
        printf '(see logs/nixosInstallation.log)\n'
    } >>"$detail"
    nds_step_exec_to "$label" "$nixos" "$@"
}
