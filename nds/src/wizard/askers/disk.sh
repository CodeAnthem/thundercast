#!/usr/bin/env bash
# ==================================================================================================
# NDS - Disk asker
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

nds_ask_disk() {
    local _disk_name=$1 _disk_key=$2 _disk_dev _disk_rc=0
    local -a _disk_devs=()
    while IFS= read -r _disk_dev; do
        [[ -n "$_disk_dev" ]] && _disk_devs+=("$_disk_dev")
    done < <(find /dev \( -name 'sd[a-z]' -o -name 'nvme[0-9]*n[0-9]*' -o -name 'vd[a-z]' \) 2>/dev/null | sort)
    if ((${#_disk_devs[@]} == 0)); then
        _nds_ask_text "$_disk_name" "$_disk_key"
        return
    fi
    _nds_wiz_opts=()
    for _disk_dev in "${_disk_devs[@]}"; do
        _nds_wiz_opts+=("${_disk_dev}|${_disk_dev}")
    done
    _nds_wiz_opts+=('other|Type a path')
    prompt --type select --options _nds_wiz_opts --back "$(nds_schema_attr "$_disk_key" label)" || _disk_rc=$?
    case "$_disk_rc" in
        0) ;;
        2) return 2 ;;
        *) return "$_disk_rc" ;;
    esac
    if [[ "$UI_PROMPT_RESULT" == other ]]; then
        _nds_ask_text "$_disk_name" "$_disk_key"
        return
    fi
    nds_recipe_set "$_disk_name" "$_disk_key" "$UI_PROMPT_RESULT"
}
