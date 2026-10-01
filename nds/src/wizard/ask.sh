#!/usr/bin/env bash
# ==================================================================================================
# NDS - Wizard fill
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# Description:   Ask active fields, then a summary until the recipe is accepted.
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

nds_skip_register recipe.summary "ask only fields that fail validation"

# shellcheck source=menu.sh
source "${BASH_SOURCE[0]%/*}/menu.sh"

_nds_ask_current() {
    local _ask_cur
    _ask_cur=$(nds_recipe_get "$1" "$2")
    if [[ -z "$_ask_cur" ]]; then
        _ask_cur=$(nds_schema_attr "$2" default)
    fi
    printf '%s\n' "$_ask_cur"
}

_nds_ask_run() {
    local _ask_name=$1 _ask_key=$2
    shift 2
    local _ask_rc=0 _ask_cur _ask_label _ask_hint
    local -a _ask_args=("$@")
    _ask_cur=$(_nds_ask_current "$_ask_name" "$_ask_key")
    _ask_label=$(nds_schema_attr "$_ask_key" label)
    _ask_hint=$(nds_schema_attr "$_ask_key" hint)
    [[ -n "$_ask_hint" ]] && ui_i "$_ask_hint"
    [[ -n "$_ask_cur" ]] && _ask_args+=(--default "$_ask_cur")
    _ask_args+=(--back "$_ask_label")
    prompt "${_ask_args[@]}" || _ask_rc=$?
    case "$_ask_rc" in
        0)
            nds_recipe_set "$_ask_name" "$_ask_key" "$UI_PROMPT_RESULT"
            return 0
            ;;
        2) return 2 ;;
        *) return "$_ask_rc" ;;
    esac
}

_nds_ask_hint() {
    case "$1" in
        country) printf '%s\n' 'US, DE, CH — empty skips' ;;
        timezone) printf '%s\n' 'Europe/Zurich, or zurich' ;;
        locale) printf '%s\n' 'en_US.UTF-8' ;;
        keyboard) printf '%s\n' 'us, de, ch' ;;
    esac
}

_nds_ask_timezone_match() {
    local _ask_raw=$1 _ask_list _ask_count _ask_hit
    if _nds_type_timezone "$_ask_raw"; then
        printf '%s\n' "$_ask_raw"
        return 0
    fi
    command -v timedatectl >/dev/null 2>&1 || return 1
    _ask_list=$(timedatectl list-timezones 2>/dev/null | grep -i -- "$_ask_raw" || true)
    [[ -n "$_ask_list" ]] || return 1
    _ask_count=$(printf '%s\n' "$_ask_list" | wc -l)
    if [[ "$_ask_count" -eq 1 ]]; then
        printf '%s\n' "$_ask_list"
        return 0
    fi
    ui_b "  Multiple matches — be more specific"
    return 2
}

_nds_ask_checked() {
    local _ask_type=$1 _ask_value=$2 _ask_key=$3
    case "$_ask_type" in
        country) _ask_value=${_ask_value^^} ;;
        keyboard) _ask_value=${_ask_value,,} ;;
        locale) _ask_value=${_ask_value/.utf8/.UTF-8} ;;
        timezone)
            _ask_value=$(_nds_ask_timezone_match "$_ask_value") || return $?
            printf '%s\n' "$_ask_value"
            return 0
            ;;
    esac
    _nds_type_ok "$_ask_type" "$_ask_value" "$_ask_key" || return 1
    printf '%s\n' "$_ask_value"
}

_nds_ask_text() {
    local _ask_name=$1 _ask_key=$2 _ask_rc=0 _ask_cur _ask_req _ask_type _ask_value _ask_hint _ask_label
    local -a _ask_args=()
    _ask_type=${_NDS_SCHEMA_FIELD_TYPE[$_ask_key]:-string}
    _ask_cur=$(_nds_ask_current "$_ask_name" "$_ask_key")
    _ask_req=$(nds_schema_attr "$_ask_key" required)
    _ask_hint=$(_nds_ask_hint "$_ask_type")
    _ask_label=$(nds_schema_attr "$_ask_key" label)
    [[ -n "$_ask_hint" ]] && _ask_label="${_ask_label} (${_ask_hint})"
    while true; do
        _ask_args=(--type text)
        [[ -n "$_ask_cur" ]] && _ask_args+=(--default "$_ask_cur")
        if [[ "$_ask_req" != 1 || -n "$_ask_cur" ]]; then
            _ask_args+=(--allow-empty)
        fi
        _ask_args+=(--back "$_ask_label")
        _ask_rc=0
        prompt "${_ask_args[@]}" || _ask_rc=$?
        case "$_ask_rc" in
            0) ;;
            2) return 2 ;;
            *) return "$_ask_rc" ;;
        esac
        _ask_value=$UI_PROMPT_RESULT
        if [[ -z "$_ask_value" ]]; then
            return 0
        fi
        _ask_rc=0
        _ask_value=$(_nds_ask_checked "$_ask_type" "$_ask_value" "$_ask_key") || _ask_rc=$?
        if [[ "$_ask_rc" -eq 0 ]]; then
            nds_recipe_set "$_ask_name" "$_ask_key" "$_ask_value"
            return 0
        fi
        [[ "$_ask_rc" -eq 2 ]] && continue
        ui_b "  Error: invalid ${_ask_type}"
    done
}

_nds_ask_string() { _nds_ask_text "$@"; }
_nds_ask_int() { _nds_ask_text "$@"; }
_nds_ask_port() { _nds_ask_text "$@"; }
_nds_ask_path() { _nds_ask_text "$@"; }
_nds_ask_file() { _nds_ask_text "$@"; }
_nds_ask_dir() { _nds_ask_text "$@"; }
_nds_ask_disk() { _nds_ask_text "$@"; }
_nds_ask_ip() { _nds_ask_text "$@"; }
_nds_ask_hostname() { _nds_ask_text "$@"; }
_nds_ask_username() { _nds_ask_text "$@"; }
_nds_ask_url() { _nds_ask_text "$@"; }
_nds_ask_timezone() { _nds_ask_text "$@"; }
_nds_ask_locale() { _nds_ask_text "$@"; }
_nds_ask_keyboard() { _nds_ask_text "$@"; }
_nds_ask_country() { _nds_ask_text "$@"; }
_nds_ask_mask() { _nds_ask_text "$@"; }
_nds_ask_secret() { _nds_ask_text "$@"; }

_nds_ask_bool() {
    local _ask_name=$1 _ask_key=$2 _ask_cur _ask_def=y _ask_rc=0 _ask_value
    _ask_cur=$(_nds_ask_current "$_ask_name" "$_ask_key")
    [[ "$_ask_cur" == false ]] && _ask_def=n
    prompt --type confirm --default "$_ask_def" --back "$(nds_schema_attr "$_ask_key" label)" || _ask_rc=$?
    case "$_ask_rc" in
        0)
            case "${UI_PROMPT_RESULT,,}" in
                y|yes|true) _ask_value=true ;;
                *) _ask_value=false ;;
            esac
            nds_recipe_set "$_ask_name" "$_ask_key" "$_ask_value"
            return 0
            ;;
        2) return 2 ;;
        *) return "$_ask_rc" ;;
    esac
}

_nds_ask_choice() {
    local _ask_name=$1 _ask_key=$2 _ask_choices _ask_labels _ask_item _ask_pair _ask_label
    local -a _ask_items=() _ask_pairs=()
    _ask_choices=$(nds_schema_attr "$_ask_key" choices)
    _ask_labels=$(nds_schema_attr "$_ask_key" labels)
    local IFS='|'
    read -ra _ask_items <<< "$_ask_choices"
    read -ra _ask_pairs <<< "$_ask_labels"
    IFS=$' \t\n'
    _nds_wiz_opts=()
    for _ask_item in "${_ask_items[@]+"${_ask_items[@]}"}"; do
        [[ -n "$_ask_item" ]] || continue
        _ask_label=$_ask_item
        for _ask_pair in "${_ask_pairs[@]+"${_ask_pairs[@]}"}"; do
            [[ "$_ask_pair" == "${_ask_item}="* ]] && _ask_label=${_ask_pair#*=}
        done
        _nds_wiz_opts+=("${_ask_item}|${_ask_label}")
    done
    if ((${#_nds_wiz_opts[@]} == 0)); then
        _nds_ask_text "$_ask_name" "$_ask_key"
        return
    fi
    _nds_ask_run "$_ask_name" "$_ask_key" --type select --options _nds_wiz_opts
}

_nds_wizard_field_bad() {
    local _wiz_name=$1 _wiz_key=$2 _wiz_value _wiz_type _wiz_fn
    nds_schema_isActive "$_wiz_name" "$_wiz_key" || return 1
    nds_schema_isLocked "$_wiz_key" && return 1
    _wiz_value=$(nds_recipe_get "$_wiz_name" "$_wiz_key")
    if [[ $(nds_schema_attr "$_wiz_key" required) == 1 && -z "$_wiz_value" ]]; then
        return 0
    fi
    [[ -n "$_wiz_value" ]] || return 1
    _wiz_type=${_NDS_SCHEMA_FIELD_TYPE[$_wiz_key]}
    _nds_type_ok "$_wiz_type" "$_wiz_value" "$_wiz_key" || return 0
    _wiz_fn=$(nds_schema_attr "$_wiz_key" validate)
    if [[ -n "$_wiz_fn" ]] && ! "$_wiz_fn" "$_wiz_value"; then
        return 0
    fi
    return 1
}

nds_ask_if_empty() {
    local _ask_name=$1 _ask_key=$2 _ask_fn=${3:-}
    [[ ${_NDS_ANSWERED[$_ask_key]:-} == 1 ]] && return 0
    nds_mode_is_interactive || return 0
    if [[ -n "$_ask_fn" ]]; then
        "$_ask_fn" "$_ask_name" "$_ask_key"
        return
    fi
    _nds_wizard_ask_one "$_ask_name" "$_ask_key"
}

nds_ask_groups_if_empty() {
    local _ask_name=$1 _ask_group
    shift
    for _ask_group in "$@"; do
        nds_schema_enable "$_ask_group"
        if [[ "$_ask_group" == disk ]] && declare -f nds_flake_note_disko >/dev/null; then
            nds_flake_note_disko "$_ask_name"
        fi
    done
    nds_mode_is_interactive || return 0
    nds_settings_menu "$_ask_name" "$@"
}

_nds_wizard_ask_one() {
    local _wiz_name=$1 _wiz_key=$2 _wiz_fn _wiz_rc=0
    nds_schema_isActive "$_wiz_name" "$_wiz_key" || return 0
    nds_schema_isLocked "$_wiz_key" && return 0
    if [[ ${_NDS_ASK_FORCE:-} != 1 && ${_NDS_ANSWERED[$_wiz_key]:-} == 1 ]]; then
        return 0
    fi
    _nds_wiz_asked=$((${_nds_wiz_asked:-0} + 1))
    _wiz_fn=$(nds_schema_attr "$_wiz_key" ask)
    if [[ -z "$_wiz_fn" ]] || ! declare -f "$_wiz_fn" >/dev/null; then
        _wiz_fn="_nds_ask_${_NDS_SCHEMA_FIELD_TYPE[$_wiz_key]}"
    fi
    "$_wiz_fn" "$_wiz_name" "$_wiz_key" || _wiz_rc=$?
    if [[ ${_NDS_ASK_FORCE:-} == 1 && "$_wiz_rc" -eq 2 ]]; then
        return 2
    fi
    case "$_wiz_rc" in
        0|2) return 0 ;;
        *) return 1 ;;
    esac
}

_nds_wizard_ask_group() {
    local _wiz_name=$1 _wiz_group=$2 _wiz_key
    ui_h "${_NDS_SCHEMA_GROUP_TITLE[$_wiz_group]:-$_wiz_group}"
    chrome_setSubtitle "$_wiz_group"
    while IFS= read -r _wiz_key; do
        [[ -n "$_wiz_key" ]] || continue
        _nds_wizard_ask_one "$_wiz_name" "$_wiz_key" || return 1
    done < <(nds_schema_groupFields "$_wiz_group")
}

_nds_wizard_ask_all() {
    local _wiz_name=$1 _wiz_group
    while IFS= read -r _wiz_group; do
        [[ -n "$_wiz_group" ]] || continue
        nds_schema_groupIsActive "$_wiz_name" "$_wiz_group" || continue
        if [[ "$_wiz_group" == disk ]] && declare -f nds_flake_note_disko >/dev/null; then
            nds_flake_note_disko "$_wiz_name"
        fi
        _nds_wizard_ask_group "$_wiz_name" "$_wiz_group" || return 1
    done < <(nds_schema_groups)
}

_nds_wizard_ask_failing() {
    local _wiz_name=$1 _wiz_group _wiz_key
    _nds_wiz_asked=0
    while IFS= read -r _wiz_group; do
        [[ -n "$_wiz_group" ]] || continue
        nds_schema_groupIsActive "$_wiz_name" "$_wiz_group" || continue
        while IFS= read -r _wiz_key; do
            [[ -n "$_wiz_key" ]] || continue
            _nds_wizard_field_bad "$_wiz_name" "$_wiz_key" || continue
            ui_h "${_NDS_SCHEMA_GROUP_TITLE[$_wiz_group]:-$_wiz_group}"
            _nds_wizard_ask_one "$_wiz_name" "$_wiz_key" || return 1
        done < <(nds_schema_groupFields "$_wiz_group")
    done < <(nds_schema_groups)
}

_nds_wizard_summary() {
    local _wiz_name=$1 _wiz_group _wiz_key _wiz_value _wiz_type
    while IFS= read -r _wiz_group; do
        [[ -n "$_wiz_group" ]] || continue
        nds_schema_groupIsActive "$_wiz_name" "$_wiz_group" || continue
        ui_h "${_NDS_SCHEMA_GROUP_TITLE[$_wiz_group]:-$_wiz_group}"
        while IFS= read -r _wiz_key; do
            [[ -n "$_wiz_key" ]] || continue
            nds_schema_isActive "$_wiz_name" "$_wiz_key" || continue
            _wiz_value=$(nds_recipe_get "$_wiz_name" "$_wiz_key")
            _wiz_type=${_NDS_SCHEMA_FIELD_TYPE[$_wiz_key]}
            [[ "$_wiz_type" == secret && -n "$_wiz_value" ]] && _wiz_value="(file)"
            ui_kv "$(nds_schema_attr "$_wiz_key" label)" "$_wiz_value"
        done < <(nds_schema_groupFields "$_wiz_group")
    done < <(nds_schema_groups)
}

_nds_wizard_review() {
    local _wiz_name=$1 _wiz_group _wiz_rc=0
    _nds_wiz_opts=('accept|Accept')
    while IFS= read -r _wiz_group; do
        [[ -n "$_wiz_group" ]] || continue
        nds_schema_groupIsActive "$_wiz_name" "$_wiz_group" || continue
        _nds_wiz_opts+=("edit:${_wiz_group}|Edit ${_NDS_SCHEMA_GROUP_TITLE[$_wiz_group]:-$_wiz_group}")
    done < <(nds_schema_groups)
    _nds_wiz_opts+=('abort|Abort')
    prompt --type select --options _nds_wiz_opts "Review the recipe" || _wiz_rc=$?
    [[ "$_wiz_rc" -eq 0 ]] || return 1
    _NDS_WIZ_CHOICE=$UI_PROMPT_RESULT
}

nds_wizard_fill() {
    local _wiz_name=$1 _wiz_mode=all _wiz_group="" _wiz_problems=0
    if nds_skip recipe.summary; then
        _wiz_mode=failing
    fi
    while true; do
        _nds_wiz_asked=0
        case "$_wiz_mode" in
            all) _nds_wizard_ask_all "$_wiz_name" || return 1 ;;
            failing) _nds_wizard_ask_failing "$_wiz_name" || return 1 ;;
            group) _nds_wizard_ask_group "$_wiz_name" "$_wiz_group" || return 1 ;;
        esac
        _wiz_problems=0
        nds_recipe_validate "$_wiz_name" || _wiz_problems=$?
        if nds_skip recipe.summary; then
            (( _wiz_problems == 0 )) && return 0
            [[ "$_wiz_mode" == failing && "$_nds_wiz_asked" -eq 0 ]] && return 1
            _wiz_mode=failing
            continue
        fi
        _nds_wizard_summary "$_wiz_name"
        _nds_wizard_review "$_wiz_name" || return 1
        case "$_NDS_WIZ_CHOICE" in
            accept)
                (( _wiz_problems == 0 )) && return 0
                _wiz_mode=failing
                ;;
            abort) return 1 ;;
            edit:*)
                _wiz_mode=group
                _wiz_group=${_NDS_WIZ_CHOICE#edit:}
                ;;
            *) return 1 ;;
        esac
    done
}
