#!/usr/bin/env bash
# ==================================================================================================
# NDS - Flake host asker
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

_nds_ask_flake_root() {
    local _flake_name=$1 _flake_path _flake_url _flake_dir
    _flake_path=$(nds_recipe_get "$_flake_name" FLAKE_LOCAL_PATH)
    if [[ -n "$_flake_path" && -d "$_flake_path" ]]; then
        printf '%s\n' "$_flake_path"
        return 0
    fi
    _flake_url=$(nds_recipe_get "$_flake_name" FLAKE_REPO_URL)
    _flake_dir="${ nds_session_dir work; }/flake-probe"
    if [[ -n "$_flake_url" ]] && declare -f flake_probe >/dev/null; then
        flake_probe "$(nds_recipe_get "$_flake_name" GIT_KEYS_DIR)" "$_flake_url" "$_flake_dir" || true
    fi
    printf '%s\n' "$_flake_dir"
}

nds_ask_flakeHost() {
    local _host_name=$1 _host_key=$2 _host_root _host_one _host_rc=0
    _host_root=$(_nds_ask_flake_root "$_host_name")
    _nds_wiz_opts=()
    if declare -f flake_listHosts >/dev/null && [[ -d "$_host_root" ]]; then
        while IFS= read -r _host_one; do
            [[ -n "$_host_one" ]] && _nds_wiz_opts+=("${_host_one}|${_host_one}")
        done < <(flake_listHosts "$_host_root")
    fi
    if ((${#_nds_wiz_opts[@]} == 0)); then
        _nds_ask_text "$_host_name" "$_host_key"
        return
    fi
    _nds_ask_run "$_host_name" "$_host_key" --type select --options _nds_wiz_opts || _host_rc=$?
    return "$_host_rc"
}
