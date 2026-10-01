#!/usr/bin/env bash
# ==================================================================================================
# NDS - Wizard fill
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# ==================================================================================================

# shellcheck source=../setup_TEST.sh
source "$(dirname "${BASH_SOURCE[0]}")/../setup_TEST.sh"
logger_setMinLevel warn
# shellcheck source=../app/session/mode.sh
source "$(dirname "${BASH_SOURCE[0]}")/../app/session/mode.sh"
# shellcheck source=../app/session/skip.sh
source "$(dirname "${BASH_SOURCE[0]}")/../app/session/skip.sh"
import_dir "$(dirname "${BASH_SOURCE[0]}")/../recipe" --depth 0
# shellcheck source=ask.sh
source "$(dirname "${BASH_SOURCE[0]}")/ask.sh"

_ask_types() {
    local _type _key _answer _got
    nds_schema_group types "Types"
    for _type in string bool int port choice path file dir disk ip hostname username url timezone locale keyboard country mask secret; do
        _key="T_${_type^^}"
        if [[ "$_type" == choice ]]; then
            nds_schema_field types "$_key" choice --choices 'a|b' --label "$_type"
        else
            nds_schema_field types "$_key" "$_type" --label "$_type"
        fi
    done
    declare -gA R=()
    mkdir -p "${_NDS_TEST_SESSION}/dir"
    printf '%s\n' secret > "${_NDS_TEST_SESSION}/file"
    for _type in string bool int port choice path file dir disk ip hostname username url timezone locale keyboard country mask secret; do
        _key="T_${_type^^}"
        case "$_type" in
            bool) _answer=true ;;
            int) _answer=8 ;;
            port) _answer=22 ;;
            choice) _answer=a ;;
            path) _answer=/tmp ;;
            file|secret) _answer="${_NDS_TEST_SESSION}/file" ;;
            dir) _answer="${_NDS_TEST_SESSION}/dir" ;;
            disk) _answer=/dev/sda ;;
            ip) _answer=1.2.3.4 ;;
            hostname) _answer=host ;;
            username) _answer=admin ;;
            url) _answer=https://example.com/a.git ;;
            timezone) _answer=UTC ;;
            locale) _answer=en_US.UTF-8 ;;
            keyboard) _answer=us ;;
            country) _answer=US ;;
            mask) _answer=255.255.255.0 ;;
            *) _answer=hello ;;
        esac
        prompt() { UI_PROMPT_RESULT=$_answer; }
        "_nds_ask_${_type}" R "$_key" || { bts_fail "${_type} asker failed"; return; }
        _got=$(nds_recipe_get R "$_key")
        if [[ "$_type" == bool ]]; then
            [[ "$_got" == true ]] || { bts_fail "bool was '${_got}'"; return; }
        else
            [[ "$_got" == "$_answer" ]] || { bts_fail "${_type} was '${_got}'"; return; }
        fi
    done
    bts_pass "each type asker sets its key"
}

suite_ask() {
    local _msgs _i _text _got _rc
    unset NDS_YES NDS_SKIP NDS_SKIP_RECIPE_SUMMARY
    export NDS_MODE=interactive
    nds_mode_resolve
    nds_test_session
    nds_schema_group zz "Stub"
    nds_schema_field zz ALPHA string --required --label 'Alpha'
    nds_schema_field zz BETA string --required --label 'Beta'
    nds_schema_enable zz
    _ask_types || return

    bts_section "Back and cancel"
    declare -gA R=()
    nds_recipe_set R ALPHA kept
    prompt() { return 2; }
    _rc=0
    _nds_ask_string R ALPHA || _rc=$?
    _got=$(nds_recipe_get R ALPHA)
    if [[ "$_rc" -eq 2 && "$_got" == kept ]]; then
        bts_pass "back keeps the current value"
    else
        bts_fail "back rc=${_rc} value='${_got}'"
    fi
    prompt() { return 3; }
    if nds_wizard_fill R 2>/dev/null; then
        bts_fail "cancel returned success"
    else
        bts_pass "cancel aborts the fill"
    fi

    bts_section "Summary"
    declare -gA R=()
    _i=0
    _msgs=()
    local -a _answers=(alpha '' beta)
    prompt() {
        local _msg="${*: -1}"
        _msgs+=("$_msg")
        if [[ "$_msg" == "Review the recipe" ]]; then
            UI_PROMPT_RESULT=accept
            return 0
        fi
        UI_PROMPT_RESULT=${_answers[_i]}
        _i=$((_i + 1))
    }
    nds_wizard_fill R 2>/dev/null || { bts_fail "summary fill failed"; return; } # validation errors while Beta is empty
    _text=$(printf '%s\n' "${_msgs[@]}")
    if [[ "$_text" == $'Alpha\nBeta\nReview the recipe\nBeta\nReview the recipe' ]]; then
        bts_pass "summary re-asks only the failing field"
    else
        bts_fail "prompts were '${_text}'"
    fi

    bts_section "Skip summary"
    declare -gA R=()
    nds_recipe_set R ALPHA alpha
    _i=0
    _msgs=()
    _answers=(beta)
    export NDS_SKIP_RECIPE_SUMMARY=true
    nds_wizard_fill R 2>/dev/null || { bts_fail "skip fill failed"; return; }
    unset NDS_SKIP_RECIPE_SUMMARY
    _text=$(printf '%s\n' "${_msgs[@]}")
    if [[ "$_text" == Beta ]]; then
        bts_pass "skip summary asks only the failing field"
    else
        bts_fail "skip prompts were '${_text}'"
    fi

    bts_section "Loaded default"
    declare -gA R=()
    nds_schema_field zz LOADED string --label 'Loaded'
    local _file _saw=0 _arg _prev
    _file="${ nds_session_dir recipe; }/loaded.recipe"
    printf '%s\n' 'LOADED="fromfile"' > "$_file"
    nds_recipe_loadFile R "$_file" || { bts_fail "load failed"; return; }
    prompt() {
        local _msg="${*: -1}"
        if [[ "$_msg" == "Review the recipe" ]]; then
            UI_PROMPT_RESULT=accept
            return 0
        fi
        _prev=""
        for _arg in "$@"; do
            [[ "$_prev" == --default && "$_arg" == fromfile ]] && _saw=1
            _prev=$_arg
        done
        UI_PROMPT_RESULT=fromfile
    }
    nds_recipe_set R ALPHA alpha
    nds_recipe_set R BETA beta
    nds_wizard_fill R 2>/dev/null || { bts_fail "default fill failed"; return; }
    if [[ "$_saw" -eq 1 ]]; then
        bts_pass "a loaded value is offered as the default"
    else
        bts_fail "loaded value was not the default"
    fi

    bts_section "Edit group"
    declare -gA R=()
    nds_recipe_set R ALPHA alpha
    nds_recipe_set R BETA beta
    nds_recipe_set R LOADED fromfile
    _review=0
    _i=0
    _msgs=()
    _answers=(alpha beta fromfile edited beta fromfile)
    prompt() {
        local _msg="${*: -1}"
        _msgs+=("$_msg")
        if [[ "$_msg" == "Review the recipe" ]]; then
            if [[ "$_review" -eq 0 ]]; then
                _review=1
                UI_PROMPT_RESULT='edit:zz'
            else
                UI_PROMPT_RESULT=accept
            fi
            return 0
        fi
        UI_PROMPT_RESULT=${_answers[_i]}
        _i=$((_i + 1))
    }
    nds_wizard_fill R 2>/dev/null || { bts_fail "edit fill failed"; return; }
    _text=$(printf '%s\n' "${_msgs[@]}")
    _got=$(nds_recipe_get R ALPHA)
    if [[ "$_text" == $'Alpha\nBeta\nLoaded\nReview the recipe\nAlpha\nBeta\nLoaded\nReview the recipe' \
        && "$_got" == edited ]]; then
        bts_pass "Edit group re-asks that group"
    else
        bts_fail "edit prompts were '${_text}' value '${_got}'"
    fi

    bts_section "Public key summary"
    _blob="AAAAC3NzaC1lZDI1NTE5AAAAIabcdefghijklmnopqrstuvwxIc9y/1QDluotA"
    _key="ssh-ed25519 ${_blob} averon@dp-bigbrotha"
    declare -gA R=()
    nds_recipe_set R ALPHA "$_key"
    _got=$(nds_recipe_get R ALPHA)
    _shown=$(_nds_settings_show "$_got")
    if [[ "$_got" == "$_key" && "$_shown" == "ssh-ed25519 AAAA...Ic9y/1QDluotA averon@dp-bigbrotha" ]]; then
        bts_pass "a public key is stored whole and shown shortened"
    else
        bts_fail "public key stored '${_got}' shown '${_shown}'"
    fi

    bts_section "Settings menu"
    ui_h() { :; }
    ui_b() { :; }
    ui_kv() { :; }
    ui_section() { :; }
    _ui_promptSessionBegin() { :; }
    _ui_promptSessionEnd() { :; }
    declare -gA R=()
    nds_schema_group menug "Region"
    nds_schema_field menug MENU_TZ timezone --default UTC --label 'Timezone'
    nds_schema_enable menug
    _i=0
    _msgs=()
    _nds_settings_read_key() {
        if [[ "$_i" -eq 0 ]]; then
            _i=1
            printf -v "$1" '%s' 1
            return 0
        fi
        printf -v "$1" '%s' x
    }
    prompt() {
        local _msg="${*: -1}"
        _msgs+=("$_msg")
        UI_PROMPT_RESULT=
        return 0
    }
    nds_schema_field menug MENU_SECRET secret --generate nds_generate_password \
        --generate-when 'MENU_TZ=UTC' --label 'Secret'
    nds_recipe_set R MENU_TZ UTC
    if _nds_settings_visible R MENU_SECRET; then
        bts_fail "a generated secret stayed visible"
        return
    fi
    nds_recipe_set R MENU_TZ nope
    if _nds_settings_visible R MENU_SECRET; then
        bts_pass "the secret is shown when it will not be generated"
    else
        bts_fail "the secret stayed hidden"
        return
    fi
    nds_recipe_set R MENU_TZ UTC
    if nds_settings_menu R menug; then
        _text=$(printf '%s\n' "${_msgs[@]}")
        if [[ "$_text" == 'Timezone (Europe/Zurich, or zurich)' ]]; then
            bts_pass "the settings menu opens a category, then finishes on x"
        else
            bts_fail "menu prompts were '${_text}'"
        fi
    else
        bts_fail "settings menu failed"
    fi
}
