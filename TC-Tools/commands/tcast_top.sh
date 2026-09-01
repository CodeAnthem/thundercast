#!/usr/bin/env bash
# ==================================================================================================
# ThunderCast host CLI — top (generic pidstat CPU watcher)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-01 | Modified: 2026-09-01
# ==================================================================================================

# Description: Run pidstat in the foreground so Ctrl+C yields pidstat's Average summary.
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

Foreground pidstat so Ctrl+C prints pidstat's own Average summary
(costliest processes over the watch window). No service-specific probes.

Usage:
  tcast top              pidstat every 1s until Ctrl+C
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

    if [[ "$once" -eq 1 ]]; then
        exec pidstat -u -h "$interval" 1
    fi

    # Foreground: SIGINT reaches pidstat → it prints Average: lines.
    exec pidstat -u -h "$interval"
}
