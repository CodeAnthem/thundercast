#!/usr/bin/env bash
# ==================================================================================================
# NDS - Validators: timezone
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-06 | Modified: 2026-07-06
# ==================================================================================================

validate_timezone() {
    local tz="$1"
    [[ -n "$tz" ]] || return 1
    if command -v timedatectl &>/dev/null; then
        local timezones
        if timezones=$(timedatectl list-timezones 2>/dev/null) && [[ -n "$timezones" ]]; then
            grep -qxi "$tz" <<< "$timezones" && return 0
            return 1
        fi
    fi
    case "$tz" in
        UTC|GMT) return 0 ;;
    esac
    [[ "$tz" =~ ^[A-Za-z0-9_+-]+/[A-Za-z0-9_+-]+$ ]] && return 0
    return 1
}
