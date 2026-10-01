#!/usr/bin/env bash
# ==================================================================================================
# NDS - Settings menu
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-10-01 | Modified: 2026-10-01
# Description:   Category menu over the recipe. Enter keeps the current value.
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

# ssh-ed25519 AAAA...Ic9y/1QDluotA averon@host — the full key stays in the recipe.
_nds_settings_show_pubkey() {
    local _set_line=$1 _set_type _set_rest _set_blob _set_comment
    _set_type=${_set_line%% *}
    _set_rest=${_set_line#"$_set_type"}
    _set_rest=${_set_rest# }
    _set_blob=${_set_rest%% *}
    [[ "$_set_blob" =~ ^[A-Za-z0-9+/]+=*$ ]] || {
        printf '%s\n' "$_set_line"
        return 0
    }
    if [[ "$_set_rest" == *" "* ]]; then
        _set_comment=${_set_rest#* }
    else
        _set_comment=""
    fi
    if (( ${#_set_blob} > 20 )); then
        _set_blob="${_set_blob:0:4}...${_set_blob: -13}"
    fi
    if [[ -n "$_set_comment" ]]; then
        printf '%s %s %s\n' "$_set_type" "$_set_blob" "$_set_comment"
    else
        printf '%s %s\n' "$_set_type" "$_set_blob"
    fi
}

_nds_settings_show() {
    local _set_value=$1
    case "$_set_value" in
        true) printf '%s\n' yes ;;
        false) printf '%s\n' no ;;
        "") printf '%s\n' '-' ;;
        ssh-*|ecdsa-*|sk-*) _nds_settings_show_pubkey "$_set_value" ;;
        *) printf '%s\n' "$_set_value" ;;
    esac
}

# A generated secret is not a setting while its generate-when holds.
_nds_settings_visible() {
    local _set_name=$1 _set_key=$2 _set_when
    nds_schema_isActive "$_set_name" "$_set_key" || return 1
    _set_when=$(nds_schema_attr "$_set_key" generate_when)
    [[ -n "$_set_when" ]] || return 0
    _nds_schema_condHolds "$_set_name" "$_set_when" && return 1
    return 0
}

_nds_settings_summary() {
    local _set_name=$1 _set_group=$2 _set_key _set_value _set_label _set_n=0
    while IFS= read -r _set_key; do
        [[ -n "$_set_key" ]] || continue
        _nds_settings_visible "$_set_name" "$_set_key" || continue
        _set_value=$(nds_recipe_get "$_set_name" "$_set_key")
        [[ -n "$_set_value" ]] || _set_value=$(nds_schema_attr "$_set_key" default)
        _set_label=$(nds_schema_attr "$_set_key" label)
        ui_kv "${_set_label:-$_set_key}" "$(_nds_settings_show "$_set_value")"
        _set_n=$((_set_n + 1))
    done < <(nds_schema_groupFields "$_set_group")
    [[ "$_set_n" -eq 0 ]] && ui_b "(no fields)"
}

_nds_settings_bad() {
    local _set_name=$1 _set_group _set_key
    shift
    for _set_group in "$@"; do
        while IFS= read -r _set_key; do
        [[ -n "$_set_key" ]] || continue
        _nds_settings_visible "$_set_name" "$_set_key" || continue
        _nds_wizard_field_bad "$_set_name" "$_set_key" && return 0
        done < <(nds_schema_groupFields "$_set_group")
    done
    return 1
}

_nds_settings_read_key() {
    local _set_dest=$1 _set_tok=""
    if ! declare -f _ui_promptGetKey >/dev/null; then
        IFS= read -r -n1 _set_tok || return 1
        printf -v "$_set_dest" '%s' "$_set_tok"
        return 0
    fi
    _ui_promptGetKey _set_tok one || return 1
    printf -v "$_set_dest" '%s' "$_set_tok"
}

_nds_settings_chrome_begin() {
    _NDS_SETTINGS_FOOTER=${__CHROME_FOOTER_ROWS:-1}
    if declare -f chrome_setFooterRows >/dev/null; then
        chrome_setFooterRows 0
    fi
}

_nds_settings_chrome_end() {
    _NDS_ASK_FORCE=
    if declare -f chrome_setFooterRows >/dev/null; then
        chrome_setFooterRows "${_NDS_SETTINGS_FOOTER:-1}"
    fi
    if declare -f chrome_setSubtitle >/dev/null; then
        chrome_setSubtitle "${NDS_MODE:-interactive}"
    fi
    if declare -f _nds_chrome_subtitleIdle >/dev/null; then
        _nds_chrome_subtitleIdle
    fi
}

_nds_settings_title() {
    local _set_cat=$1
    if declare -f chrome_setSubtitle >/dev/null; then
        if [[ -n "$_set_cat" ]]; then
            chrome_setSubtitle "Configuration — ${_set_cat}"
        else
            chrome_setSubtitle "Configuration"
        fi
    fi
    if declare -f _nds_chrome_subtitleWait >/dev/null; then
        _nds_chrome_subtitleWait
    fi
}

_nds_settings_clear() {
    if declare -f chrome_clear >/dev/null; then
        chrome_clear
    fi
    ui_b ""
}

_nds_settings_configure() {
    local _set_name=$1 _set_group=$2 _set_key _set_rc
    local _set_title=${_NDS_SCHEMA_GROUP_TITLE[$_set_group]:-$_set_group}
    _NDS_ASK_FORCE=1
    _nds_settings_clear
    _nds_settings_title "$_set_title"
    ui_b "Press Enter to keep the current value. b goes back."
    ui_b ""
    while IFS= read -r _set_key; do
        [[ -n "$_set_key" ]] || continue
        _nds_settings_visible "$_set_name" "$_set_key" || continue
        _set_rc=0
        _nds_wizard_ask_one "$_set_name" "$_set_key" || _set_rc=$?
        if [[ "$_set_rc" -eq 2 ]]; then
            _NDS_ASK_FORCE=
            return 0
        fi
        if [[ "$_set_rc" -ne 0 ]]; then
            _NDS_ASK_FORCE=
            return "$_set_rc"
        fi
    done < <(nds_schema_groupFields "$_set_group")
    _NDS_ASK_FORCE=
}

_nds_settings_has_country() {
    local _set_group
    for _set_group in "$@"; do
        [[ "$_set_group" == region ]] || continue
        nds_schema_hasKey REGION_COUNTRY && return 0
    done
    return 1
}

_nds_settings_summary_quick() {
    local _set_name=$1 _set_country
    ui_b "1. Quick Setup"
    _set_country=$(nds_recipe_get "$_set_name" REGION_COUNTRY)
    if [[ -n "$_set_country" ]]; then
        ui_kv "Country" "$_set_country"
    else
        ui_kv "Country" "(manual region setup)"
    fi
}

_nds_settings_configure_quick() {
    local _set_rc=0
    _NDS_ASK_FORCE=1
    _nds_settings_clear
    _nds_settings_title "Quick Setup"
    ui_b "Country fills timezone, locale, and keyboard. Empty leaves them for Region."
    ui_b ""
    _nds_wizard_ask_one "$1" REGION_COUNTRY || _set_rc=$?
    _NDS_ASK_FORCE=
    [[ "$_set_rc" -eq 0 || "$_set_rc" -eq 2 ]] || return "$_set_rc"
}

_nds_settings_ask_missing() {
    local _set_name=$1 _set_group _set_key _set_started=0 _set_rc
    shift
    for _set_group in "$@"; do
        while IFS= read -r _set_key; do
            [[ -n "$_set_key" ]] || continue
            _nds_settings_visible "$_set_name" "$_set_key" || continue
            [[ $(nds_schema_attr "$_set_key" required) == 1 ]] || continue
            [[ -z $(nds_recipe_get "$_set_name" "$_set_key") ]] || continue
            if [[ "$_set_started" -eq 0 ]]; then
                _nds_settings_clear
                _nds_settings_title ""
                ui_b "Required values first. The menu opens after these."
                ui_b ""
                _set_started=1
            fi
            _NDS_ASK_FORCE=1
            _set_rc=0
            _nds_wizard_ask_one "$_set_name" "$_set_key" || _set_rc=$?
            _NDS_ASK_FORCE=
            [[ "$_set_rc" -eq 0 || "$_set_rc" -eq 2 ]] || return "$_set_rc"
        done < <(nds_schema_groupFields "$_set_group")
    done
}

_nds_settings_draw() {
    local _set_name=$1 _set_status=$2 _set_group _set_i=0 _set_quick=0
    shift 2
    _nds_settings_clear
    _nds_settings_title ""
    [[ -n "$_set_status" ]] && ui_b "$_set_status" && ui_b ""
    if _nds_settings_has_country "$@"; then
        _nds_settings_summary_quick "$_set_name"
        _set_quick=1
        _set_i=1
    fi
    for _set_group in "$@"; do
        _set_i=$((_set_i + 1))
        ui_b "${_set_i}. ${_NDS_SCHEMA_GROUP_TITLE[$_set_group]:-$_set_group}"
        _nds_settings_summary "$_set_name" "$_set_group"
    done
    ui_b ""
    ui_b "Press a number to open a category, or x when ready."
    printf -v _NDS_SETTINGS_COUNT '%s' "$_set_i"
    printf -v _NDS_SETTINGS_QUICK '%s' "$_set_quick"
}

nds_settings_menu() {
    local _set_name=$1 _set_group _set_pick _set_i _set_rc=0 _set_status=""
    shift
    local -a _set_groups=("$@")
    ((${#_set_groups[@]})) || return 0
    _nds_settings_chrome_begin
    _nds_settings_ask_missing "$_set_name" "${_set_groups[@]}" || _set_rc=$?
    if [[ "$_set_rc" -ne 0 ]]; then
        _nds_settings_chrome_end
        return "$_set_rc"
    fi
    _nds_settings_draw "$_set_name" "" "${_set_groups[@]}"
    if declare -f _ui_promptSessionBegin >/dev/null; then
        _ui_promptSessionBegin cbreak || _set_rc=$?
        if [[ "$_set_rc" -ne 0 ]]; then
            _nds_settings_chrome_end
            return "$_set_rc"
        fi
    fi
    while true; do
        _set_pick=""
        _set_rc=0
        _nds_settings_read_key _set_pick || _set_rc=$?
        if [[ "$_set_rc" -ne 0 ]]; then
            declare -f _ui_promptSessionEnd >/dev/null && _ui_promptSessionEnd
            _nds_settings_chrome_end
            return "$_set_rc"
        fi
        case "$_set_pick" in
            pageup) declare -f chrome_scrollUp >/dev/null && chrome_scrollUp ;;
            pagedown) declare -f chrome_scrollDown >/dev/null && chrome_scrollDown ;;
            wheelup) declare -f chrome_scrollUp >/dev/null && chrome_scrollUp 3 ;;
            wheeldn) declare -f chrome_scrollDown >/dev/null && chrome_scrollDown 3 ;;
            home) declare -f chrome_scrollUp >/dev/null && chrome_scrollUp 1000000 ;;
            end) declare -f chrome_follow >/dev/null && chrome_follow ;;
            x|X)
                if _nds_settings_bad "$_set_name" "${_set_groups[@]}"; then
                    _set_status="Required fields are still empty."
                    _nds_settings_draw "$_set_name" "$_set_status" "${_set_groups[@]}"
                    continue
                fi
                declare -f _ui_promptSessionEnd >/dev/null && _ui_promptSessionEnd
                _nds_settings_chrome_end
                return 0
                ;;
            [1-9])
                declare -f _ui_promptSessionEnd >/dev/null && _ui_promptSessionEnd
                _set_rc=0
                if [[ ${_NDS_SETTINGS_QUICK:-0} == 1 && "$_set_pick" == 1 ]]; then
                    _nds_settings_configure_quick "$_set_name" || _set_rc=$?
                    _set_status="Quick Setup updated"
                else
                    _set_i=$_set_pick
                    [[ ${_NDS_SETTINGS_QUICK:-0} == 1 ]] && _set_i=$((_set_pick - 1))
                    if (( _set_i < 1 || _set_i > ${#_set_groups[@]} )); then
                        declare -f _ui_promptSessionBegin >/dev/null && _ui_promptSessionBegin cbreak
                        continue
                    fi
                    _set_group=${_set_groups[$((_set_i - 1))]}
                    _nds_settings_configure "$_set_name" "$_set_group" || _set_rc=$?
                    _set_status="${_NDS_SCHEMA_GROUP_TITLE[$_set_group]:-$_set_group} updated"
                fi
                if [[ "$_set_rc" -ne 0 ]]; then
                    _nds_settings_chrome_end
                    return "$_set_rc"
                fi
                declare -f _ui_promptSessionBegin >/dev/null && _ui_promptSessionBegin cbreak
                _nds_settings_draw "$_set_name" "$_set_status" "${_set_groups[@]}"
                ;;
        esac
    done
}
