#!/usr/bin/env bash
# ==================================================================================================
# NDS - Schema group flake
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

_nds_flake_tool() {
    local _nds_flake_tool=$1 _nds_flake_key=$2
    if declare -f "$_nds_flake_tool" >/dev/null; then
        return 0
    fi
    error "${_nds_flake_key}: tool not loaded"
    return 1
}

nds_check_flake() {
    local _nds_flake_name=$1
    local -n _nds_flake_aa=$1
    local _nds_flake_n=0 _nds_flake_tools=0 _nds_flake_dest="" _nds_flake_hosts="" _nds_flake_host _nds_flake_found=0
    local _nds_flake_url _nds_flake_rev _nds_flake_nar _nds_flake_lock
    if [[ ${_nds_flake_aa[INSTALL_MODE]:-} == remote && -z ${_nds_flake_aa[REMOTE_TARGET_IP]:-} ]]; then
        error "REMOTE_TARGET_IP: required"
        _nds_flake_n=$((_nds_flake_n + 1))
    fi
    if [[ -z ${_nds_flake_aa[FLAKE_LOCATION]:-} && -z ${_nds_flake_aa[FLAKE_REPO_URL]:-} && -z ${_nds_flake_aa[FLAKE_LOCAL_PATH]:-} ]]; then
        error "FLAKE_LOCATION: required"
        _nds_flake_n=$((_nds_flake_n + 1))
    fi
    _nds_flake_tool flake_listHosts FLAKE_HOST || _nds_flake_tools=$((_nds_flake_tools + 1))
    _nds_flake_tool flake_probe FLAKE_HOST || _nds_flake_tools=$((_nds_flake_tools + 1))
    _nds_flake_tool flake_hostHasDisko DISK_STRATEGY || _nds_flake_tools=$((_nds_flake_tools + 1))
    _nds_flake_tool git_probe GIT_KEYS_DIR || _nds_flake_tools=$((_nds_flake_tools + 1))
    _nds_flake_n=$((_nds_flake_n + _nds_flake_tools))
    if (( _nds_flake_tools > 0 )); then
        return "$_nds_flake_n"
    fi
    _nds_flake_url=${_nds_flake_aa[FLAKE_REPO_URL]:-}
    if [[ -n "$_nds_flake_url" ]]; then
        if ! git_probe "${_nds_flake_aa[GIT_KEYS_DIR]:-}" "$_nds_flake_url"; then
            error "GIT_KEYS_DIR: probe failed"
            _nds_flake_n=$((_nds_flake_n + 1))
        fi
        _nds_flake_dest="${ nds_session_dir work; }/flake-probe"
        if ! flake_probe "${_nds_flake_aa[GIT_KEYS_DIR]:-}" "$_nds_flake_url" "$_nds_flake_dest"; then
            error "FLAKE_LOCATION: probe failed"
            _nds_flake_n=$((_nds_flake_n + 1))
            return "$_nds_flake_n"
        fi
    elif [[ -n ${_nds_flake_aa[FLAKE_LOCAL_PATH]:-} ]]; then
        _nds_flake_dest=${_nds_flake_aa[FLAKE_LOCAL_PATH]}
    fi
    if [[ -n "$_nds_flake_dest" && -d "$_nds_flake_dest" ]]; then
        if ! _nds_flake_hosts=${ flake_listHosts "$_nds_flake_dest"; }; then
            error "FLAKE_HOST: could not list hosts"
            _nds_flake_n=$((_nds_flake_n + 1))
        else
            while IFS= read -r _nds_flake_host; do
                [[ "$_nds_flake_host" == "${_nds_flake_aa[FLAKE_HOST]:-}" ]] && _nds_flake_found=1
            done <<< "$_nds_flake_hosts"
            if (( _nds_flake_found == 0 )); then
                error "FLAKE_HOST: not in nixosConfigurations"
                _nds_flake_n=$((_nds_flake_n + 1))
            fi
            if flake_hostHasDisko "$_nds_flake_dest" "${_nds_flake_aa[FLAKE_HOST]:-}" "${_nds_flake_aa[FLAKE_HOST_DIR]:-hosts/x86_64-linux}"; then
                nds_recipe_set "$_nds_flake_name" DISK_STRATEGY flake
            fi
        fi
        _nds_flake_lock="${_nds_flake_dest}/flake.lock"
        if declare -f flake_listLockGitEntries >/dev/null && [[ -f "$_nds_flake_lock" ]]; then
            while IFS=$'\t' read -r _nds_flake_url _nds_flake_rev _; do
                [[ -n "$_nds_flake_url" && -n "$_nds_flake_rev" ]] || continue
                if ! git_probe "${_nds_flake_aa[GIT_KEYS_DIR]:-}" "$_nds_flake_url"; then
                    error "GIT_KEYS_DIR: probe failed"
                    _nds_flake_n=$((_nds_flake_n + 1))
                fi
            done < <(flake_listLockGitEntries "$_nds_flake_lock")
        fi
    fi
    return "$_nds_flake_n"
}

nds_schema_group flake "Flake" --when 'INSTALL_KIND=flake' --check nds_check_flake
nds_schema_field flake FLAKE_LOCATION string --required --ask nds_ask_flakeLocation --label 'Flake location'
nds_schema_field flake FLAKE_SOURCE choice --default remote \
    --choices 'remote|local' --labels 'remote=Git URL|local=Local path' --label 'Flake source'
nds_schema_field flake FLAKE_REPO_URL url --when 'FLAKE_SOURCE=remote' --label 'Flake repository URL'
nds_schema_field flake FLAKE_LOCAL_PATH path --when 'FLAKE_SOURCE=local' --label 'Flake local path'
nds_schema_field flake FLAKE_INSTALL_PATH path --default '/mnt/etc/nixos' --label 'Flake path on installed disk'
nds_schema_field flake FLAKE_HOST hostname --required --ask nds_ask_flakeHost --label 'Flake host'
nds_schema_field flake FLAKE_HOST_DIR string --default 'hosts/x86_64-linux' --label 'Host directory'
nds_schema_field flake FLAKE_HARDWARE_PLACEMENT choice --default 'host-dir' \
    --choices 'host-dir|etc-nixos|skip' \
    --labels 'host-dir=Host directory|etc-nixos=/etc/nixos|skip=Skip' --label 'Hardware configuration'
nds_schema_field flake SOPS_AGE_REUSE choice --default generate \
    --choices 'generate|file' --labels 'generate=New key|file=Reuse a key file' --label 'Machine age key'
nds_schema_field flake SOPS_AGE_KEY_FILE secret \
    --generate nds_generate_ageKey --generate-when 'SOPS_AGE_REUSE=generate' --label 'Age key file'
