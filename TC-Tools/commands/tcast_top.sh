#!/usr/bin/env bash
# ==================================================================================================
# ThunderCast host CLI — top (pidstat CPU watcher)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-01 | Modified: 2026-09-01
# ==================================================================================================

# Description: Print loadavg + key unit CPUUsage snapshot.
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

# Description: Print end summary (loadavg + unit CPU deltas since start).
# Arguments:
# - start_ns_live / start_ns_dash / start_ns_comin: baseline CPUUsageNSec strings
_tcast_top_summary() {
    local start_live="${1:-0}" start_dash="${2:-0}" start_comin="${3:-0}"
    local loadavg
    printf '\n======== summary ========\n'
    loadavg="$(tr -d '\n' </proc/loadavg 2>/dev/null || true)"
    printf 'loadavg: %s\n' "${loadavg:-?}"
    local u label start now delta
    for u in \
        thunderstorm-console-banner-live.service \
        thunderstorm-console-dashboard@tty1.service \
        comin.service
    do
        case "$u" in
            *live*) start="$start_live" ;;
            *dashboard*) start="$start_dash" ;;
            *comin*) start="$start_comin" ;;
            *) start=0 ;;
        esac
        if systemctl cat "$u" >/dev/null 2>&1; then
            now="$(systemctl show -p CPUUsageNSec --value "$u" 2>/dev/null || printf 0)"
            [[ "$now" =~ ^[0-9]+$ ]] || now=0
            [[ "$start" =~ ^[0-9]+$ ]] || start=0
            delta=$((now - start))
            # ms of CPU used during the watch window
            printf '  %s  ΔCPU=%sms (lifetime=%s)\n' "$u" "$((delta / 1000000))" "$now"
        fi
    done
    printf '=========================\n'
}

# Description: Stream process CPU via pidstat; on Ctrl+C print unit CPU summary.
# Arguments:
# - --once | -1: one sample then exit (with summary)
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
  tcast top              pidstat every 1s until Ctrl+C (then summary)
  tcast top --once       One pidstat sample + summary
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

    local ns_live=0 ns_dash=0 ns_comin=0
    ns_live="$(systemctl show -p CPUUsageNSec --value thunderstorm-console-banner-live.service 2>/dev/null || printf 0)"
    ns_dash="$(systemctl show -p CPUUsageNSec --value thunderstorm-console-dashboard@tty1.service 2>/dev/null || printf 0)"
    ns_comin="$(systemctl show -p CPUUsageNSec --value comin.service 2>/dev/null || printf 0)"

    _tcast_top_preamble

    if [[ "$once" -eq 1 ]]; then
        pidstat -u -h "$interval" 1 || true
        _tcast_top_summary "$ns_live" "$ns_dash" "$ns_comin"
        return 0
    fi

    local pidstat_pid=""
    _tcast_top_on_int() {
        if [[ -n "${pidstat_pid:-}" ]]; then
            kill "$pidstat_pid" 2>/dev/null || true
            wait "$pidstat_pid" 2>/dev/null || true
            pidstat_pid=""
        fi
        _tcast_top_summary "$ns_live" "$ns_dash" "$ns_comin"
        exit 0
    }
    trap _tcast_top_on_int INT TERM

    printf 'pidstat -u every %ss — Ctrl+C for summary.\n\n' "$interval"
    pidstat -u -h "$interval" &
    pidstat_pid=$!
    wait "$pidstat_pid" || true
    pidstat_pid=""
    trap - INT TERM
    _tcast_top_summary "$ns_live" "$ns_dash" "$ns_comin"
}
