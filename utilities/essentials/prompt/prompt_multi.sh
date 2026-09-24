#!/usr/bin/env bash
# ==================================================================================================
# Thundercast - Bash Essentials - Prompt - Multi-select
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-21 | Modified: 2026-09-24
# Description:   Multi-choice menu.
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

# Session map __PROMPT is assigned by _ui_promptReset / prompt() in prompt.sh.
# shellcheck disable=SC2153,SC2154

_ui_promptLoadSelected() {
    local name="${__PROMPT[selected]}" spec i found
    unset __UI_PROMPT_OPT_ON
    declare -ga __UI_PROMPT_OPT_ON=()
    for i in "${!__UI_PROMPT_OPT_VALS[@]}"; do
        __UI_PROMPT_OPT_ON[i]=0
    done
    [[ -n "$name" ]] || return 0
    declare -p "$name" &>/dev/null || {
        _prompt_err "prompt: --selected ${name} is not an array"
        return 1
    }
    local -n _ui_prompt_sel="$name"
    for spec in "${_ui_prompt_sel[@]}"; do
        found=0
        for i in "${!__UI_PROMPT_OPT_VALS[@]}"; do
            if [[ "${__UI_PROMPT_OPT_VALS[i]}" == "$spec" || "${__UI_PROMPT_OPT_LABELS[i]}" == "$spec" ]]; then
                __UI_PROMPT_OPT_ON[i]=1
                found=1
                break
            fi
        done
        if ((found == 0)) && [[ "$spec" =~ ^[1-9][0-9]*$ ]]; then
            i=$((10#$spec - 1))
            if ((i >= 0 && i < ${#__UI_PROMPT_OPT_VALS[@]})); then
                __UI_PROMPT_OPT_ON[i]=1
                found=1
            fi
        fi
        if ((found == 0)); then
            _prompt_err "prompt: --selected unknown option ${spec}"
            return 1
        fi
    done
}

_ui_promptMultiSelect() {
    _ui_promptLoadOptions || return 1
    _ui_promptLoadSelected || return 1
    if [[ "${__PROMPT[plain]}" == true || "$__UI_MODE" == plain ]]; then
        _ui_promptMenuPlain
        return $?
    fi
    _ui_promptMenuFancy
}
