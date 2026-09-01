#!/usr/bin/env bash
# ==================================================================================================
# ThunderCast host CLI — top (pidstat CPU watcher)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-01 | Modified: 2026-09-01
# ==================================================================================================

# Description: Print a one-line loadavg + key unit CPUUsage snapshot (no clear).
_tcast_top_preamble() {
    local loadavg
    loadavg="$(tr -d '\n' </proc/loadavg 2>/dev/null || true)"
    printf 'loadavg: %s\n' "${loadavg:-?}"
    printf 'Banner LOAD%% is loadavg/cores — not process CPU. Short bursts: watch pidstat lines.\n\n'
    local u
    for u in \
        thunderstorm-console-banner-live.service \
        thunderstorm-console-dashboard@tty1.service \
        comin.service
    do
        if systemctl cat "$u" >/dev/null 2>&1; then
            printf '  %s  active=%s  CPUUsageNSec=%s\n' \
                "$u" \
                "$(systemctl is-active "$u" 2>/dev/null || printf '?')" \
                "$(systemctl show -p CPUUsageNSec --value "$u" 2>/dev/null || printf 0)"
        fi
    done
    printf '\n'
}

# Description: Stream process CPU via pidstat (no screen clear / flicker).
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
tcast top — stream process CPU with pidstat (no flicker)

Usage:
  tcast top              pidstat every 1s until Ctrl+C
  tcast top --once       One pidstat sample
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

    _tcast_top_preamble

    if [[ "$once" -eq 1 ]]; then
        # One interval then one report.
        pidstat -u -h "$interval" 1
        return 0
    fi

    printf 'pidstat -u every %ss — Ctrl+C to stop.\n\n' "$interval"
    exec pidstat -u -h "$interval"
}
