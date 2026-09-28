#!/usr/bin/env bash
# ==================================================================================================
# nixos - install-log phase bar (classic, flake build, nixos-anywhere)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-28 | Modified: 2026-09-28
# Description:   One footer bar. A keyword opens only the next phase. The follower
#                reads the install log; it is not in the nix pipe.
# ==================================================================================================

declare -g _NIXOS_PROGRESS_PHASE=0
declare -g _NIXOS_PROGRESS_OFFSET=0
declare -g _NIXOS_PROGRESS_PARTIAL=""
declare -g _NIXOS_PROGRESS_OPENED=false

# Current phase, 0..6.
nixos_progressPhase() {
    printf '%s\n' "$_NIXOS_PROGRESS_PHASE"
}

# Drop phase state. Does not move the footer.
nixos_progressReset() {
    _NIXOS_PROGRESS_PHASE=0
    _NIXOS_PROGRESS_OFFSET=0
    _NIXOS_PROGRESS_PARTIAL=""
    _NIXOS_PROGRESS_OPENED=false
}

# Clear the footer after a finished install. Phase restarts; the log offset stays at EOF.
nixos_progressFinish() {
    local install_log size
    install_log=$(nixos_installLog)
    if [[ -f "$install_log" ]]; then
        size=$(wc -c < "$install_log") || size=0
        size=${size//[[:space:]]/}
        [[ "$size" =~ ^[0-9]+$ ]] && _NIXOS_PROGRESS_OFFSET=$size
    fi
    _NIXOS_PROGRESS_PHASE=0
    _NIXOS_PROGRESS_PARTIAL=""
    _NIXOS_PROGRESS_OPENED=false
    chrome_setFooter 0 -t text -- "" || true
}

# Read new install-log bytes and advance the phase.
nixos_progressSync() {
    local install_log
    install_log=$(nixos_installLog)
    _nixos_progressDrain "$install_log"
    _nixos_progressFlush
}

# One install-log line. Advances at most one phase, or jumps to 6 on "Installation finished".
nixos_progressConsider() {
    local line next=0
    line=$(_nixos_progressPlain "$1")
    if [[ "$line" == *"Installation finished"* ]]; then
        next=6
    elif (( _NIXOS_PROGRESS_PHASE == 0 )); then
        if [[ "$line" == *"=== nix eval"* || "$line" == *"=== Installing"* || "$line" == *"### Installing NixOS"* ]]; then
            next=1
        fi
    elif (( _NIXOS_PROGRESS_PHASE == 1 )); then
        if [[ "$line" == *"copying channel"* || "$line" == *"copying path"* ]]; then
            next=2
        fi
    elif (( _NIXOS_PROGRESS_PHASE == 2 )); then
        if [[ "$line" =~ these[[:space:]]+[0-9]+[[:space:]]+derivations[[:space:]]+will[[:space:]]+be[[:space:]]+built ]]; then
            next=3
        fi
    elif (( _NIXOS_PROGRESS_PHASE == 3 )); then
        if [[ "$line" == "building '"* || "$line" =~ ^[[:space:]]*building\ \' ]]; then
            next=4
        fi
    elif (( _NIXOS_PROGRESS_PHASE == 4 )); then
        if [[ "$line" == *"setting up /etc"* || "$line" == *"activating"* ]]; then
            next=5
        fi
    elif (( _NIXOS_PROGRESS_PHASE == 5 )); then
        if [[ "$line" == *"boot loader"* || "$line" == *"GRUB"* || "$line" == *"grub-install"* ]]; then
            next=6
        fi
    fi
    (( next > _NIXOS_PROGRESS_PHASE )) || return 0
    _NIXOS_PROGRESS_PHASE=$next
    _nixos_progressPaint "$next"
}

# Run a command with both streams appended to the install log.
# Chrome on: poll the file and move the footer. Chrome off: redirect only.
# Arguments:
# - command: <String...> Program and arguments
# Returns:
# - <Bool> the command's status
nixos_runLogged() {
    local install_log pid rc=0 monitor=0
    install_log=$(nixos_installLog)
    if ! chrome_isOn; then
        "$@" >>"$install_log" 2>&1
        return $?
    fi
    _nixos_progressOpen
    _nixos_progressDrain "$install_log"
    [[ $- == *m* ]] && monitor=1
    set +m
    "$@" >>"$install_log" 2>&1 &
    pid=$!
    while kill -0 "$pid" 2>/dev/null; do
        _nixos_progressDrain "$install_log" || true
        kill -0 "$pid" 2>/dev/null || break
        sleep 0.2
    done
    wait "$pid" || rc=$?
    if (( monitor )); then
        set -m
    fi
    _nixos_progressDrain "$install_log"
    _nixos_progressFlush
    return "$rc"
}

_nixos_progressLabel() {
    case "$1" in
        1) printf '%s\n' "evaluating" ;;
        2) printf '%s\n' "copying files" ;;
        3) printf '%s\n' "planning" ;;
        4) printf '%s\n' "building" ;;
        5) printf '%s\n' "setting up" ;;
        6) printf '%s\n' "installing the bootloader" ;;
        *) printf '%s\n' "starting" ;;
    esac
}

_nixos_progressPaint() {
    local phase="$1" label
    label=${ _nixos_progressLabel "$phase"; }
    chrome_setFooter 0 -t progress -m 6 -v "$phase" "Currently: ${label}" || true
}

_nixos_progressOpen() {
    [[ "${_NIXOS_PROGRESS_OPENED}" == true ]] && return 0
    _NIXOS_PROGRESS_OPENED=true
    (( _NIXOS_PROGRESS_PHASE == 0 )) || return 0
    chrome_setFooter 0 -t progress -m 6 -v 0 "Currently: starting" || true
}

_nixos_progressPlain() {
    local line="$1" pre suffix
    while [[ "$line" == *$'\e'* ]]; do
        pre=${line%%$'\e'*}
        suffix=${line#"$pre"}
        [[ "$suffix" =~ ^($'\e'\[[0-9;]*[A-Za-z])(.*)$ ]] || break
        line="${pre}${BASH_REMATCH[2]}"
    done
    printf '%s' "$line"
}

_nixos_progressDrain() {
    local file="$1" size=0 chunk="" data="" piece=""
    [[ -f "$file" ]] || return 0
    size=$(wc -c < "$file") || return 0
    size=${size//[[:space:]]/}
    [[ "$size" =~ ^[0-9]+$ ]] || return 0
    (( size > _NIXOS_PROGRESS_OFFSET )) || return 0
    chunk=$(tail -c +$((_NIXOS_PROGRESS_OFFSET + 1)) "$file" 2>/dev/null || true)
    _NIXOS_PROGRESS_OFFSET=$size
    data="${_NIXOS_PROGRESS_PARTIAL}${chunk}"
    _NIXOS_PROGRESS_PARTIAL=""
    data=${data//$'\r'/$'\n'}
    while [[ "$data" == *$'\n'* ]]; do
        piece=${data%%$'\n'*}
        data=${data#*$'\n'}
        [[ -n "$piece" ]] && nixos_progressConsider "$piece"
    done
    _NIXOS_PROGRESS_PARTIAL=$data
}

_nixos_progressFlush() {
    [[ -n "$_NIXOS_PROGRESS_PARTIAL" ]] || return 0
    nixos_progressConsider "$_NIXOS_PROGRESS_PARTIAL"
    _NIXOS_PROGRESS_PARTIAL=""
}
