#!/usr/bin/env bash
# ==================================================================================================
# ThunderCast host CLI — durable host config (outside the Nix store)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-31 | Modified: 2026-09-01
# Description:   Key=value + git.map under $TCAST_CONFIG_DIR survive package upgrades.
# ==================================================================================================

# Shared host config (default /var/lib/tcast) — any sudoer; not per-user ~/.config.
: "${TCAST_STATE_DIR:=/var/lib/tcast}"
: "${TCAST_CONFIG_DIR:=${TCAST_STATE_DIR}}"

tcast_conf_ensure_dirs() {
    mkdir -p "$TCAST_CONFIG_DIR"
    chmod 755 "$TCAST_CONFIG_DIR" 2>/dev/null || true
}

tcast_conf_path() {
    printf '%s/%s.conf\n' "$TCAST_CONFIG_DIR" "$1"
}

tcast_conf_get() {
    local name="$1" key="$2" path line
    path="$(tcast_conf_path "$name")"
    [[ -f "$path" ]] || return 0
    while IFS= read -r line || [[ -n "${line:-}" ]]; do
        [[ -z "$line" || "$line" == \#* ]] && continue
        if [[ "$line" == "${key}="* ]]; then
            printf '%s\n' "${line#${key}=}"
            return 0
        fi
    done <"$path"
}

tcast_conf_set() {
    local name="$1" key="$2" value="$3" path tmp
    tcast_conf_ensure_dirs
    path="$(tcast_conf_path "$name")"
    tmp="$(mktemp)"
    if [[ -f "$path" ]]; then
        grep -v "^${key}=" "$path" >"$tmp" || true
    else
        : >"$tmp"
    fi
    printf '%s=%s\n' "$key" "$value" >>"$tmp"
    mv "$tmp" "$path"
    chmod 644 "$path"
}

# Description: Fill TCAST_FLAKE_* from switch.conf only when unset.
tcast_conf_apply_switch_env() {
    local v
    if [[ -z "${TCAST_FLAKE_ROOT:-}" ]]; then
        v="$(tcast_conf_get switch FLAKE_ROOT)"
        [[ -n "$v" ]] && TCAST_FLAKE_ROOT="$v"
    fi
    if [[ -z "${TCAST_FLAKE_HOST:-}" ]]; then
        v="$(tcast_conf_get switch FLAKE_HOST)"
        [[ -n "$v" ]] && TCAST_FLAKE_HOST="$v"
    fi
    if [[ -z "${TCAST_FLAKE_REF:-}" ]]; then
        v="$(tcast_conf_get switch FLAKE_REF)"
        [[ -n "$v" ]] && TCAST_FLAKE_REF="$v"
    fi
    return 0
}

# Description: Fill TCAST_CLEAN_* from clean.conf when unset.
tcast_conf_apply_clean_env() {
    local v
    if [[ -z "${TCAST_CLEAN_KEEP_GENS:-}" ]]; then
        v="$(tcast_conf_get clean KEEP_GENS)"
        [[ -n "$v" ]] && TCAST_CLEAN_KEEP_GENS="$v"
    fi
    if [[ -z "${TCAST_CLEAN_OLDER_THAN:-}" ]]; then
        v="$(tcast_conf_get clean OLDER_THAN)"
        [[ -n "$v" ]] && TCAST_CLEAN_OLDER_THAN="$v"
    fi
    return 0
}
