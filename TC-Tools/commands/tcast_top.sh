#!/usr/bin/env bash
# ==================================================================================================
# ThunderCast host CLI — top (live costly processes)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-01 | Modified: 2026-09-01
# ==================================================================================================

# Description: Print one sample of load + top processes + key unit CPU.
_tcast_top_sample() {
    local n="${1:-15}"
    local loadavg
    loadavg="$(tr -d '\n' </proc/loadavg 2>/dev/null || true)"
    printf 'loadavg: %s\n' "${loadavg:-?}"
    printf 'time:    %s\n\n' "$(date '+%H:%M:%S' 2>/dev/null || date)"

    printf '    PID  %%CPU %%MEM    RSS ELAPSED CMD\n'
    ps -eo pid,pcpu,pmem,rss,etime,cmd --sort=-pcpu 2>/dev/null | head -n "$((n + 1))" | tail -n +2

    printf '\n'
    printf 'systemd CPUUsage (lifetime nsec → rough):\n'
    local u
    for u in \
        thunderstorm-console-banner-live.service \
        thunderstorm-console-banner-tick.service \
        thunderstorm-console-dashboard@tty1.service \
        comin.service
    do
        if systemctl cat "$u" >/dev/null 2>&1; then
            local ns state
            ns="$(systemctl show -p CPUUsageNSec --value "$u" 2>/dev/null || printf 0)"
            state="$(systemctl is-active "$u" 2>/dev/null || printf '?')"
            printf '  %-52s active=%-8s CPUUsageNSec=%s\n' "$u" "$state" "$ns"
        fi
    done
    printf '\n'
    printf 'Note: banner LOAD%% is loadavg/cores, not a single process.\n'
    printf 'Short-lived children (jq/comin status) show in cgtop, often miss ps.\n'
}

# Description: Watch costly processes (Ctrl+C to stop).
# Arguments:
# - --once | -1: print one sample and exit
# - --interval N | -n N: refresh seconds (default 1)
# - --lines N | -l N: process rows (default 15)
tcast_cmd_top() {
    local once=0 interval=1 lines=15
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --once|-1) once=1; shift ;;
            --interval|-n)
                interval="$2"
                shift 2
                ;;
            --lines|-l)
                lines="$2"
                shift 2
                ;;
            -h|--help)
                cat <<'EOF'
tcast top — live view of costly processes

Usage:
  tcast top              Refresh every 1s until Ctrl+C
  tcast top --once       One sample
  tcast top -n 2 -l 20   Every 2s, 20 process rows
EOF
                return 0
                ;;
            *)
                tcast_die "tcast top: unknown arg: $1 (try: tcast top --help)"
                ;;
        esac
    done

    if [[ "$once" -eq 1 ]]; then
        _tcast_top_sample "$lines"
        return 0
    fi

    trap 'printf "\n"; exit 0' INT
    while true; do
        printf '\033c'
        _tcast_top_sample "$lines"
        printf 'Refreshing every %ss — Ctrl+C to stop.\n' "$interval"
        sleep "$interval"
    done
}
