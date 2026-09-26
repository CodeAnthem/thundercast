#!/usr/bin/env bash
# ==================================================================================================
# NDS - Skip store
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# Description:   Named questions. Unattended skips every registered name.
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

declare -ga _NDS_SKIP_NAMES=()
declare -gA _NDS_SKIP_WHY=()
declare -gA _NDS_SKIP_KEEP=()

_nds_skip_env_name() {
    local _skip_key=${1^^}
    _skip_key=${_skip_key//./_}
    printf 'NDS_SKIP_%s\n' "$_skip_key"
}

_nds_skip_known() {
    local _skip_name=$1 _skip_have
    for _skip_have in "${_NDS_SKIP_NAMES[@]+"${_NDS_SKIP_NAMES[@]}"}"; do
        [[ "$_skip_have" == "$_skip_name" ]] && return 0
    done
    return 1
}

nds_skip_register() {
    local _skip_name=$1 _skip_why=$2 _skip_keep=${3:-}
    [[ "$_skip_name" =~ ^[a-z]+(\.[a-zA-Z]+)+$ ]] || {
        error "${_skip_name}: invalid skip name"
        return 1
    }
    _nds_skip_known "$_skip_name" && return 0
    _NDS_SKIP_NAMES+=("$_skip_name")
    _NDS_SKIP_WHY[$_skip_name]=$_skip_why
    [[ "$_skip_keep" == keep-on-yes ]] && _NDS_SKIP_KEEP[$_skip_name]=1
}

nds_skip_startup() {
    local _skip_item _skip_var _skip_name _skip_env _skip_found
    local IFS=','
    local -a _skip_items=()
    read -ra _skip_items <<< "${NDS_SKIP:-}"
    for _skip_item in "${_skip_items[@]+"${_skip_items[@]}"}"; do
        [[ -n "$_skip_item" ]] || continue
        _nds_skip_known "$_skip_item" || {
            error "${_skip_item}: unregistered skip"
            return 1
        }
    done
    for _skip_var in ${!NDS_SKIP_@}; do
        [[ ${!_skip_var:-} == true ]] || continue
        _skip_found=0
        for _skip_name in "${_NDS_SKIP_NAMES[@]+"${_NDS_SKIP_NAMES[@]}"}"; do
            _skip_env=${ _nds_skip_env_name "$_skip_name"; }
            [[ "$_skip_env" == "$_skip_var" ]] && _skip_found=1
        done
        if [[ "$_skip_found" -eq 0 ]]; then
            error "${_skip_var}: unregistered skip"
            return 1
        fi
    done
}

nds_skip() {
    local _skip_name=$1 _skip_env _skip_item
    _nds_skip_known "$_skip_name" || {
        error "${_skip_name}: unregistered skip"
        return 1
    }
    nds_mode_is_unattended && return 0
    _skip_env=${ _nds_skip_env_name "$_skip_name"; }
    [[ ${!_skip_env:-} == true ]] && return 0
    local IFS=','
    local -a _skip_items=()
    read -ra _skip_items <<< "${NDS_SKIP:-}"
    for _skip_item in "${_skip_items[@]+"${_skip_items[@]}"}"; do
        [[ "$_skip_item" == "$_skip_name" ]] && return 0
    done
    if [[ ${NDS_YES:-} == true && -z ${_NDS_SKIP_KEEP[$_skip_name]:-} ]]; then
        return 0
    fi
    return 1
}

nds_skip_list() {
    local _skip_name _skip_source
    for _skip_name in "${_NDS_SKIP_NAMES[@]+"${_NDS_SKIP_NAMES[@]}"}"; do
        if nds_mode_is_unattended; then
            _skip_source=unattended
        elif [[ ${NDS_YES:-} == true && -z ${_NDS_SKIP_KEEP[$_skip_name]:-} ]]; then
            _skip_source=NDS_YES
        else
            _skip_source=default
        fi
        printf '%s\t%s\t%s\n' "$_skip_name" "${_NDS_SKIP_WHY[$_skip_name]}" "$_skip_source"
    done
}

nds_skip_register action.preview "accept the action preview"
nds_skip_register recipe.summary "ask only fields that fail validation"
nds_skip_register install.confirm "proceed without the wipe confirm"
nds_skip_register finish.backup "do not wait for the bundle copy"
nds_skip_register finish.reboot "reboot only when NDS_REBOOT=true" keep-on-yes
