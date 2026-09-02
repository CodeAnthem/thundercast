#!/usr/bin/env bash
# ==================================================================================================
# ThunderCast host CLI — top (generic pidstat CPU watcher)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-01 | Modified: 2026-09-01
# ==================================================================================================

# Description: Foreground pidstat -u (no -h) so Ctrl+C prints Average of costly processes.
# Arguments:
# - --once | -1: one sample then exit
# - --interval N | -n N: seconds between samples (default 1)
tcast_cmd_top() {
    local once=0 interval=1
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --once|-1) once=1; shift ;;
            --interval|-n)
                interval="$2"
                shift 2
                ;;
            -h|--help)
                cat <<'EOF'
tcast top — generic process CPU via pidstat

Same as:  pidstat -u <interval>
Ctrl+C prints pidstat's Average: (costliest processes in the window).
Do not use pidstat -h here — that mode skips the Average summary.

Usage:
  tcast top              pidstat -u 1 until Ctrl+C
  tcast top --once       One sample
  tcast top -n 2         Sample every 2s
EOF
                return 0
                ;;
            *)
                tcast_die "tcast top: unknown arg: $1 (try: tcast top --help)"
                ;;
        esac
    done

    if ! command -v pidstat >/dev/null 2>&1; then
        tcast_die "pidstat not found (sysstat). Rebuild with tcast package wrapping sysstat."
    fi

    # Match `pidstat -u 1` exactly — no -h (horizontal mode suppresses Average on SIGINT).
    if [[ "$once" -eq 1 ]]; then
        exec pidstat -u "$interval" 1
    fi
    exec pidstat -u "$interval"
}
