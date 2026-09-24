#!/usr/bin/env bash
# ==================================================================================================
# Thundercast - Bash Essentials - Prompt
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-17 | Modified: 2026-09-24
# Description:   One prompt command that must not be captured; the result is UI_PROMPT_RESULT, UI_PROMPT_ACTION, and the return code.
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

_essentials_prompt_init() {
    _essentials_init_isDone prompt && return 0

    local -n config="essentials_config"
    declare -g __UI_NO_PAUSE="${config[UI_NO_PAUSE]:-false}"
    declare -g UI_PROMPT_RESULT=""
    declare -g UI_PROMPT_ACTION=""
    declare -gA __PROMPT=()

    # shellcheck source=./prompt_input.sh
    _loadEssential "prompt/prompt_input.sh"
    # shellcheck source=./prompt_types.sh
    _loadEssential "prompt/prompt_types.sh"
    # shellcheck source=./prompt_menu.sh
    _loadEssential "prompt/prompt_menu.sh"
    # shellcheck source=./prompt_select.sh
    _loadEssential "prompt/prompt_select.sh"
    # shellcheck source=./prompt_multi.sh
    _loadEssential "prompt/prompt_multi.sh"

    _essentials_init_mark prompt
}

_prompt_err() {
    echo "[ERROR] - [prompt] - $1" >&2
}

_ui_promptReset() {
    UI_PROMPT_RESULT=""
    UI_PROMPT_ACTION=""
    unset __PROMPT
    declare -gA __PROMPT=(
        [type]=
        [msg]=
        [default]=
        [allow_empty]=
        [hide]=
        [mask]=
        [end]=
        [include_end]=
        [options]=
        [desc]=
        [placeholder]=
        [prefix]=
        [suffix]=
        [footer]=
        [plain]=
        [no_color]=
        [help]=
        [color]=
        [cursor]=0
        [want_back]=
        [selected]=
    )
    unset __UI_PROMPT_BIND
    declare -gA __UI_PROMPT_BIND=()
    unset __UI_PROMPT_OPT_VALS __UI_PROMPT_OPT_LABELS __UI_PROMPT_OPT_DESCS __UI_PROMPT_OPT_ON
    declare -ga __UI_PROMPT_OPT_VALS=()
    declare -ga __UI_PROMPT_OPT_LABELS=()
    declare -ga __UI_PROMPT_OPT_DESCS=()
    declare -ga __UI_PROMPT_OPT_ON=()
}

_ui_promptUsage() {
    _prompt_err "prompt: --type text|multiline|select|multi-select|confirm|key|pause  [--message TEXT]"
}

_ui_promptNeedArg() {
    local flag="$1" val="${2:-}"
    if [[ -z "$val" || "$val" == --* ]]; then
        _prompt_err "prompt: ${flag} requires an argument"
        return 1
    fi
    return 0
}

_ui_promptBindClearAction() {
    local action="$1" key
    local -a drop=()
    for key in "${!__UI_PROMPT_BIND[@]}"; do
        if [[ "${__UI_PROMPT_BIND[$key]}" == "$action" ]]; then
            drop+=("$key")
        fi
    done
    for key in "${drop[@]}"; do
        unset '__UI_PROMPT_BIND[$key]'
    done
}

_ui_promptHasAction() {
    local action="$1" key
    for key in "${!__UI_PROMPT_BIND[@]}"; do
        [[ "${__UI_PROMPT_BIND[$key]}" == "$action" ]] && return 0
    done
    return 1
}

_ui_promptBindSet() {
    local action="$1" key="${2,,}" prev
    [[ -n "$action" && -n "$key" ]] || {
        _prompt_err "prompt: --bind needs ACTION=KEY"
        return 1
    }
    if [[ "${__PROMPT[type]}" == select || "${__PROMPT[type]}" == multi-select ]] && [[ "$key" =~ ^[1-9]$ ]]; then
        _prompt_err "prompt: cannot bind ${action} to option key ${key}"
        return 1
    fi
    prev="${__UI_PROMPT_BIND[$key]:-}"
    if [[ -n "$prev" && "$prev" != "$action" ]]; then
        _prompt_err "prompt: key ${key} already bound to ${prev}"
        return 1
    fi
    __UI_PROMPT_BIND[$key]="$action"
}

_ui_promptBindApply() {
    local spec="$1" action key
    [[ "$spec" == *=* ]] || {
        _prompt_err "prompt: --bind needs ACTION=KEY"
        return 1
    }
    action="${spec%%=*}"
    key="${spec#*=}"
    _ui_promptBindClearAction "$action"
    _ui_promptBindSet "$action" "$key"
}

_ui_promptBindDefaults() {
    case "${__PROMPT[type]}" in
        text|multiline|select|multi-select)
            _ui_promptBindSet submit enter || return 1
            _ui_promptBindSet cancel esc || return 1
            ;;
        confirm)
            _ui_promptBindSet cancel esc || return 1
            ;;
    esac
    if [[ "${__PROMPT[type]}" == multi-select ]]; then
        _ui_promptBindSet toggle space || return 1
    fi
    if [[ -n "${__PROMPT[help]}" ]]; then
        _ui_promptBindSet help '?' || return 1
    fi
    if [[ "${__PROMPT[want_back]}" == true ]]; then
        _ui_promptBindClearAction back
        _ui_promptBindSet back b || return 1
        if [[ "${__PROMPT[type]}" == select || "${__PROMPT[type]}" == multi-select ]]; then
            _ui_promptBindSet back 0 || return 1
        fi
    fi
}

_ui_promptBindLookup() {
    local key="${1,,}"
    printf '%s' "${__UI_PROMPT_BIND[$key]:-}"
}

_ui_promptDone() {
    local action="$1" value="${2:-}"
    UI_PROMPT_ACTION="$action"
    UI_PROMPT_RESULT="$value"
    case "$action" in
        submit) return 0 ;;
        back) return 2 ;;
        cancel) return 3 ;;
        *) return 1 ;;
    esac
}

_ui_promptFail() {
    UI_PROMPT_ACTION=""
    UI_PROMPT_RESULT=""
    return 1
}

_ui_promptEof() {
    UI_PROMPT_ACTION=""
    UI_PROMPT_RESULT=""
    return 4
}

_ui_promptCheckCombo() {
    local t="${__PROMPT[type]}"
    case "$t" in
        multiselect|multi_select)
            __PROMPT[type]=multi-select
            t=multi-select
            ;;
    esac
    case "$t" in
        text|multiline|select|multi-select|confirm|key|pause) ;;
        "")
            _prompt_err "prompt: --type or message required"
            return 1
            ;;
        *)
            _prompt_err "prompt: unknown type ${t}"
            return 1
            ;;
    esac
    if [[ "${__PROMPT[hide]}" == true && -n "${__PROMPT[mask]}" ]]; then
        _prompt_err "prompt: --hide and --mask cannot be combined"
        return 1
    fi
    if [[ -n "${__PROMPT[mask]}" && ${#__PROMPT[mask]} -ne 1 ]]; then
        _prompt_err "prompt: --mask needs a single character"
        return 1
    fi
    if [[ -n "${__PROMPT[end]}" || "${__PROMPT[include_end]}" == true ]]; then
        [[ "$t" == multiline ]] || {
            _prompt_err "prompt: --end is only valid with --type multiline"
            return 1
        }
    fi
    if [[ "$t" == multiline && -z "${__PROMPT[end]}" ]]; then
        _prompt_err "prompt: --type multiline requires --end"
        return 1
    fi
    if [[ -n "${__PROMPT[options]}" && "$t" != select && "$t" != multi-select ]]; then
        _prompt_err "prompt: --options is only valid with select or multi-select"
        return 1
    fi
    if [[ "$t" == select || "$t" == multi-select ]] && [[ -z "${__PROMPT[options]}" ]]; then
        _prompt_err "prompt: --type ${t} requires --options"
        return 1
    fi
    if [[ -n "${__PROMPT[selected]}" && "$t" != multi-select ]]; then
        _prompt_err "prompt: --selected is only valid with --type multi-select"
        return 1
    fi
    if [[ -n "${__PROMPT[default]}" && "$t" == multi-select ]]; then
        _prompt_err "prompt: --default is not valid with --type multi-select (use --selected)"
        return 1
    fi
    if [[ -n "${__PROMPT[mask]}" && "$t" != text ]]; then
        _prompt_err "prompt: --mask is only valid with --type text"
        return 1
    fi
    if [[ "${__PROMPT[hide]}" == true && "$t" != text && "$t" != multiline ]]; then
        _prompt_err "prompt: --hide is only valid with text or multiline"
        return 1
    fi
    if [[ -n "${__PROMPT[placeholder]}" && "$t" != text ]]; then
        _prompt_err "prompt: --placeholder is only valid with --type text"
        return 1
    fi
    if [[ "${__PROMPT[allow_empty]}" == true && "$t" != text && "$t" != multiline ]]; then
        _prompt_err "prompt: --allow-empty is only valid with text or multiline"
        return 1
    fi
    if [[ -n "${__PROMPT[default]}" && "$t" == pause ]]; then
        _prompt_err "prompt: --default is not valid with --type pause"
        return 1
    fi
}

_ui_promptParse() {
    local -a user_binds=() pos=()
    local eq

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --)
                shift
                pos+=("$@")
                break
                ;;
            --type=*)
                __PROMPT[type]="${1#*=}"
                __PROMPT[type]="${__PROMPT[type],,}"
                shift
                ;;
            --type|-t)
                _ui_promptNeedArg "$1" "${2:-}" || return 1
                __PROMPT[type]="${2,,}"
                shift 2
                ;;
            --message=*)
                __PROMPT[msg]="${1#*=}"
                shift
                ;;
            --message)
                _ui_promptNeedArg "$1" "${2:-}" || return 1
                __PROMPT[msg]="$2"
                shift 2
                ;;
            --default=*)
                __PROMPT[default]="${1#*=}"
                shift
                ;;
            --default|-d)
                _ui_promptNeedArg "$1" "${2:-}" || return 1
                __PROMPT[default]="$2"
                shift 2
                ;;
            --allow-empty|-a)
                __PROMPT[allow_empty]=true
                shift
                ;;
            --hide|-H|-s)
                __PROMPT[hide]=true
                shift
                ;;
            --mask=*)
                __PROMPT[mask]="${1#*=}"
                shift
                ;;
            --mask)
                _ui_promptNeedArg "$1" "${2:-}" || return 1
                __PROMPT[mask]="$2"
                shift 2
                ;;
            --end=*)
                __PROMPT[end]="${1#*=}"
                shift
                ;;
            --end|-e)
                _ui_promptNeedArg "$1" "${2:-}" || return 1
                __PROMPT[end]="$2"
                shift 2
                ;;
            --include-end)
                __PROMPT[include_end]=true
                shift
                ;;
            --options=*)
                __PROMPT[options]="${1#*=}"
                shift
                ;;
            --options|-o)
                _ui_promptNeedArg "$1" "${2:-}" || return 1
                __PROMPT[options]="$2"
                shift 2
                ;;
            --selected=*)
                __PROMPT[selected]="${1#*=}"
                shift
                ;;
            --selected)
                _ui_promptNeedArg "$1" "${2:-}" || return 1
                __PROMPT[selected]="$2"
                shift 2
                ;;
            --bind=*)
                user_binds+=("${1#*=}")
                shift
                ;;
            --bind)
                _ui_promptNeedArg "$1" "${2:-}" || return 1
                user_binds+=("$2")
                shift 2
                ;;
            --description=*)
                __PROMPT[desc]="${1#*=}"
                shift
                ;;
            --description)
                _ui_promptNeedArg "$1" "${2:-}" || return 1
                __PROMPT[desc]="$2"
                shift 2
                ;;
            --placeholder=*)
                __PROMPT[placeholder]="${1#*=}"
                shift
                ;;
            --placeholder)
                _ui_promptNeedArg "$1" "${2:-}" || return 1
                __PROMPT[placeholder]="$2"
                shift 2
                ;;
            --prefix=*)
                __PROMPT[prefix]="${1#*=}"
                shift
                ;;
            --prefix)
                _ui_promptNeedArg "$1" "${2:-}" || return 1
                __PROMPT[prefix]="$2"
                shift 2
                ;;
            --suffix=*)
                __PROMPT[suffix]="${1#*=}"
                shift
                ;;
            --suffix)
                _ui_promptNeedArg "$1" "${2:-}" || return 1
                __PROMPT[suffix]="$2"
                shift 2
                ;;
            --footer=*)
                __PROMPT[footer]="${1#*=}"
                shift
                ;;
            --footer)
                _ui_promptNeedArg "$1" "${2:-}" || return 1
                __PROMPT[footer]="$2"
                shift 2
                ;;
            --plain)
                __PROMPT[plain]=true
                shift
                ;;
            --no-color)
                __PROMPT[no_color]=true
                shift
                ;;
            --help)
                if [[ -n "${2:-}" && "$2" != --* ]]; then
                    __PROMPT[help]="$2"
                    shift 2
                else
                    _ui_promptUsage
                    return 1
                fi
                ;;
            --help=*)
                __PROMPT[help]="${1#*=}"
                shift
                ;;
            --back|-b)
                __PROMPT[want_back]=true
                shift
                ;;
            -*)
                _prompt_err "prompt: unknown flag ${1}"
                return 1
                ;;
            *)
                pos+=("$1")
                shift
                ;;
        esac
    done

    if [[ -z "${__PROMPT[msg]}" && ${#pos[@]} -gt 0 ]]; then
        __PROMPT[msg]="${pos[*]}"
    fi
    if [[ -z "${__PROMPT[type]}" ]]; then
        if [[ -n "${__PROMPT[msg]}" ]]; then
            __PROMPT[type]=text
        fi
    fi

    _ui_promptCheckCombo || return 1
    _ui_promptBindDefaults || return 1
    for eq in "${user_binds[@]}"; do
        _ui_promptBindApply "$eq" || return 1
    done

    __PROMPT[color]=false
    if [[ "${__PROMPT[plain]}" != true && "${__PROMPT[no_color]}" != true && "${__UI_COLOR:-false}" == true && -z "${NO_COLOR:-}" ]]; then
        __PROMPT[color]=true
    fi
}

# Ask on the TTY. Long options (short aliases). Never capture this function.
prompt() {
    local rc
    _ui_promptReset
    _ui_promptParse "$@" || return 1

    if declare -f eventRun &>/dev/null && eventHas ui.line.take; then
        eventRun ui.line.take || true
    fi

    case "${__PROMPT[type]}" in
        confirm) _ui_promptConfirm ;;
        text) _ui_promptText ;;
        multiline) _ui_promptMultiline ;;
        select) _ui_promptSelect ;;
        multi-select) _ui_promptMultiSelect ;;
        key) _ui_promptKey ;;
        pause) _ui_promptPause ;;
        *)
            _prompt_err "prompt: unknown type ${__PROMPT[type]}"
            return 1
            ;;
    esac
    rc=$?
    return "$rc"
}

_essentials_prompt_init || return 1
