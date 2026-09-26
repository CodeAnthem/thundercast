#!/usr/bin/env bash
# ==================================================================================================
# NDS - Recipe schema
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# Description:   Group and field declarations. schema/ is sourced after this file.
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

declare -gA _NDS_SCHEMA_GROUP_TITLE=()
declare -gA _NDS_SCHEMA_GROUP_WHEN=()
declare -gA _NDS_SCHEMA_GROUP_CHECK=()
declare -ga _NDS_SCHEMA_GROUP_ORDER=()
declare -ga _NDS_SCHEMA_ENABLED=()
declare -gA _NDS_SCHEMA_FIELD_GROUP=()
declare -gA _NDS_SCHEMA_FIELD_TYPE=()
declare -gA _NDS_SCHEMA_ATTR=()
declare -gA _NDS_SCHEMA_GROUP_FIELDS=()

_nds_schema_condCheck() {
    local _nds_schema_key=$1 _nds_schema_cond=$2 _nds_schema_term
    local -a _nds_schema_terms=()
    local IFS=','
    read -ra _nds_schema_terms <<< "$_nds_schema_cond"
    if ((${#_nds_schema_terms[@]} == 0)); then
        error "${_nds_schema_key}: malformed condition"
        return 1
    fi
    for _nds_schema_term in "${_nds_schema_terms[@]}"; do
        if [[ "$_nds_schema_term" == *[[:space:]]* || -z "$_nds_schema_term" ]]; then
            error "${_nds_schema_key}: malformed condition"
            return 1
        fi
        if [[ "$_nds_schema_term" =~ ^[A-Z][A-Z0-9_]*!=.+$ ]]; then
            continue
        fi
        if [[ "$_nds_schema_term" =~ ^[A-Z][A-Z0-9_]*=[^=].*$ ]]; then
            continue
        fi
        if [[ "$_nds_schema_term" =~ ^[A-Z][A-Z0-9_]*$ ]]; then
            continue
        fi
        error "${_nds_schema_key}: malformed condition"
        return 1
    done
    return 0
}

_nds_schema_condHolds() {
    local -n _nds_schema_aa=$1
    local _nds_schema_cond=$2 _nds_schema_term _nds_schema_key _nds_schema_value
    local -a _nds_schema_terms=()
    [[ -z "$_nds_schema_cond" ]] && return 0
    local IFS=','
    read -ra _nds_schema_terms <<< "$_nds_schema_cond"
    for _nds_schema_term in "${_nds_schema_terms[@]}"; do
        if [[ "$_nds_schema_term" == *'!='* ]]; then
            _nds_schema_key=${_nds_schema_term%%!=*}
            _nds_schema_value=${_nds_schema_term#*!=}
            [[ ${_nds_schema_aa[$_nds_schema_key]:-} == "$_nds_schema_value" ]] && return 1
        elif [[ "$_nds_schema_term" == *=* ]]; then
            _nds_schema_key=${_nds_schema_term%%=*}
            _nds_schema_value=${_nds_schema_term#*=}
            [[ ${_nds_schema_aa[$_nds_schema_key]:-} == "$_nds_schema_value" ]] || return 1
        else
            [[ -n ${_nds_schema_aa[$_nds_schema_term]:-} ]] || return 1
        fi
    done
    return 0
}

_nds_schema_isEnabled() {
    local _nds_schema_group=$1 _nds_schema_have
    for _nds_schema_have in "${_NDS_SCHEMA_ENABLED[@]+"${_NDS_SCHEMA_ENABLED[@]}"}"; do
        [[ "$_nds_schema_have" == "$_nds_schema_group" ]] && return 0
    done
    return 1
}

_nds_schema_defaultLabel() {
    local _nds_schema_key=$1 _nds_schema_group _nds_schema_prefix _nds_schema_rest
    _nds_schema_group=${_NDS_SCHEMA_FIELD_GROUP[$_nds_schema_key]:-}
    _nds_schema_prefix=$(printf '%s' "$_nds_schema_group" | tr '[:lower:]' '[:upper:]')
    _nds_schema_rest=$_nds_schema_key
    if [[ "$_nds_schema_rest" == "${_nds_schema_prefix}_"* ]]; then
        _nds_schema_rest=${_nds_schema_rest#"${_nds_schema_prefix}_"}
    fi
    printf '%s' "$_nds_schema_rest" | tr '[:upper:]' '[:lower:]' | tr '_' ' '
}

nds_schema_group() {
    local _nds_schema_group=$1 _nds_schema_title=$2
    shift 2
    if [[ -n ${_NDS_SCHEMA_GROUP_TITLE[$_nds_schema_group]:-} ]]; then
        error "${_nds_schema_group}: already declared"
        return 1
    fi
    local _nds_schema_when="" _nds_schema_check="" _nds_schema_opt _nds_schema_val
    while (( $# )); do
        _nds_schema_opt=$1
        shift
        case "$_nds_schema_opt" in
            --when|--check)
                if (( $# == 0 )); then
                    error "${_nds_schema_group}: missing value for ${_nds_schema_opt}"
                    return 1
                fi
                _nds_schema_val=$1
                shift
                if [[ "$_nds_schema_opt" == --when ]]; then
                    _nds_schema_when=$_nds_schema_val
                else
                    _nds_schema_check=$_nds_schema_val
                fi
                ;;
            *)
                error "${_nds_schema_group}: unknown option ${_nds_schema_opt}"
                return 1
                ;;
        esac
    done
    if [[ -n "$_nds_schema_when" ]]; then
        _nds_schema_condCheck "$_nds_schema_group" "$_nds_schema_when" || return 1
    fi
    _NDS_SCHEMA_GROUP_TITLE[$_nds_schema_group]=$_nds_schema_title
    _NDS_SCHEMA_GROUP_WHEN[$_nds_schema_group]=$_nds_schema_when
    _NDS_SCHEMA_GROUP_CHECK[$_nds_schema_group]=$_nds_schema_check
    _NDS_SCHEMA_GROUP_ORDER+=("$_nds_schema_group")
}

nds_schema_field() {
    local _nds_schema_group=$1 _nds_schema_key=$2 _nds_schema_type=$3
    shift 3
    if [[ -z ${_NDS_SCHEMA_GROUP_TITLE[$_nds_schema_group]:-} ]]; then
        error "${_nds_schema_group}: unknown group"
        return 1
    fi
    if [[ -n ${_NDS_SCHEMA_FIELD_GROUP[$_nds_schema_key]:-} ]]; then
        error "${_nds_schema_key}: already declared"
        return 1
    fi
    if [[ ! "$_nds_schema_key" =~ ^[A-Z][A-Z0-9_]*$ ]]; then
        error "${_nds_schema_key}: invalid key"
        return 1
    fi
    case "$_nds_schema_type" in
        string|bool|int|port|choice|path|file|dir|disk|ip|hostname|username|url|timezone|locale|keyboard|country|mask|secret) ;;
        *)
            error "${_nds_schema_key}: unknown type ${_nds_schema_type}"
            return 1
            ;;
    esac
    local _nds_schema_opt _nds_schema_val _nds_schema_attr
    while (( $# )); do
        _nds_schema_opt=$1
        shift
        case "$_nds_schema_opt" in
            --required)
                _NDS_SCHEMA_ATTR[$_nds_schema_key|required]=1
                ;;
            --default|--detect|--when|--choices|--labels|--min|--max|--label|--hint|--ask|--validate|--generate|--generate-when)
                if (( $# == 0 )); then
                    error "${_nds_schema_key}: missing value for ${_nds_schema_opt}"
                    return 1
                fi
                _nds_schema_val=$1
                shift
                if [[ "$_nds_schema_opt" == --generate-when ]]; then
                    _nds_schema_attr=generate_when
                else
                    _nds_schema_attr=${_nds_schema_opt#--}
                fi
                _NDS_SCHEMA_ATTR[$_nds_schema_key|$_nds_schema_attr]=$_nds_schema_val
                ;;
            *)
                error "${_nds_schema_key}: unknown option ${_nds_schema_opt}"
                return 1
                ;;
        esac
    done
    if [[ -n ${_NDS_SCHEMA_ATTR[$_nds_schema_key|when]:-} ]]; then
        _nds_schema_condCheck "$_nds_schema_key" "${_NDS_SCHEMA_ATTR[$_nds_schema_key|when]}" || return 1
    fi
    if [[ -n ${_NDS_SCHEMA_ATTR[$_nds_schema_key|generate_when]:-} ]]; then
        _nds_schema_condCheck "$_nds_schema_key" "${_NDS_SCHEMA_ATTR[$_nds_schema_key|generate_when]}" || return 1
    fi
    _NDS_SCHEMA_FIELD_GROUP[$_nds_schema_key]=$_nds_schema_group
    _NDS_SCHEMA_FIELD_TYPE[$_nds_schema_key]=$_nds_schema_type
    if [[ -n ${_NDS_SCHEMA_GROUP_FIELDS[$_nds_schema_group]:-} ]]; then
        _NDS_SCHEMA_GROUP_FIELDS[$_nds_schema_group]+=$'\n'"$_nds_schema_key"
    else
        _NDS_SCHEMA_GROUP_FIELDS[$_nds_schema_group]=$_nds_schema_key
    fi
}

nds_schema_groups() {
    local _nds_schema_group
    for _nds_schema_group in "${_NDS_SCHEMA_ENABLED[@]+"${_NDS_SCHEMA_ENABLED[@]}"}"; do
        printf '%s\n' "$_nds_schema_group"
    done
}

nds_schema_allGroups() {
    local _nds_schema_group
    for _nds_schema_group in "${_NDS_SCHEMA_GROUP_ORDER[@]+"${_NDS_SCHEMA_GROUP_ORDER[@]}"}"; do
        printf '%s\n' "$_nds_schema_group"
    done
}

nds_schema_groupFields() {
    local _nds_schema_group=$1
    [[ -n ${_NDS_SCHEMA_GROUP_TITLE[$_nds_schema_group]:-} ]] || return 1
    [[ -n ${_NDS_SCHEMA_GROUP_FIELDS[$_nds_schema_group]:-} ]] || return 0
    printf '%s\n' "${_NDS_SCHEMA_GROUP_FIELDS[$_nds_schema_group]}"
}

nds_schema_attr() {
    local _nds_schema_key=$1 _nds_schema_attr=$2 _nds_schema_value
    _nds_schema_value=${_NDS_SCHEMA_ATTR[$_nds_schema_key|$_nds_schema_attr]:-}
    if [[ -z "$_nds_schema_value" && "$_nds_schema_attr" == label ]]; then
        _nds_schema_defaultLabel "$_nds_schema_key"
        return 0
    fi
    printf '%s\n' "$_nds_schema_value"
}

nds_schema_hasKey() {
    [[ -n ${_NDS_SCHEMA_FIELD_GROUP[$1]:-} ]]
}

nds_schema_groupIsActive() {
    local _nds_schema_name=$1 _nds_schema_group=$2
    _nds_schema_isEnabled "$_nds_schema_group" || return 1
    _nds_schema_condHolds "$_nds_schema_name" "${_NDS_SCHEMA_GROUP_WHEN[$_nds_schema_group]:-}"
}

nds_schema_isActive() {
    local _nds_schema_name=$1 _nds_schema_key=$2 _nds_schema_group
    _nds_schema_group=${_NDS_SCHEMA_FIELD_GROUP[$_nds_schema_key]:-}
    [[ -n "$_nds_schema_group" ]] || return 1
    nds_schema_groupIsActive "$_nds_schema_name" "$_nds_schema_group" || return 1
    _nds_schema_condHolds "$_nds_schema_name" "${_NDS_SCHEMA_ATTR[$_nds_schema_key|when]:-}"
}

nds_schema_enable() {
    local _nds_schema_group
    for _nds_schema_group in "$@"; do
        if [[ -z ${_NDS_SCHEMA_GROUP_TITLE[$_nds_schema_group]:-} ]]; then
            error "${_nds_schema_group}: unknown group"
            return 1
        fi
        _nds_schema_isEnabled "$_nds_schema_group" && continue
        _NDS_SCHEMA_ENABLED+=("$_nds_schema_group")
    done
}

nds_schema_enableAll() {
    local _nds_schema_group
    for _nds_schema_group in "${_NDS_SCHEMA_GROUP_ORDER[@]+"${_NDS_SCHEMA_GROUP_ORDER[@]}"}"; do
        nds_schema_enable "$_nds_schema_group" || return 1
    done
}

nds_schema_lock() {
    nds_schema_hasKey "$1" || { error "$1: unknown key"; return 1; }
    _NDS_SCHEMA_ATTR[$1|locked]=1
}

nds_schema_isLocked() {
    [[ ${_NDS_SCHEMA_ATTR[$1|locked]:-} == 1 ]]
}
