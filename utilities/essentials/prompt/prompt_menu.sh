#!/usr/bin/env bash
# ==================================================================================================
# Thundercast - Bash Essentials - Prompt - Menu (select / multi-select)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-21 | Modified: 2026-09-21
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

# Session map __PROMPT is assigned by _ui_promptReset / prompt() in prompt.sh.
# shellcheck disable=SC2153,SC2154

_ui_promptMenuIsMulti() {
    [[ "${__PROMPT[type]}" == multi-select ]]
}

_ui_promptMenuMark() {
    _ui_promptMenuIsMulti || {
        printf ''
        return 0
    }
    if [[ "${__UI_PROMPT_OPT_ON[$1]}" == 1 ]]; then
        printf '[x] '
    else
        printf '[ ] '
    fi
}

_ui_promptMenuToggle() {
    local idx="$1"
    if [[ "${__UI_PROMPT_OPT_ON[idx]}" == 1 ]]; then
        __UI_PROMPT_OPT_ON[idx]=0
    else
        __UI_PROMPT_OPT_ON[idx]=1
    fi
}

_ui_promptMenuCollect() {
    local i out=""
    if ! _ui_promptMenuIsMulti; then
        printf '%s' "${__UI_PROMPT_OPT_VALS[__PROMPT[cursor]]}"
        return 0
    fi
    for i in "${!__UI_PROMPT_OPT_VALS[@]}"; do
        if [[ "${__UI_PROMPT_OPT_ON[i]}" == 1 ]]; then
            out+="${__UI_PROMPT_OPT_VALS[i]}"$'\n'
        fi
    done
    printf '%s' "${out%$'\n'}"
}

# mode=fancy ends every row with erase-to-EOL: the frame is redrawn in place, and after a chrome
# scroll it lands over history rows that may be longer than the menu line.
_ui_promptMenuDraw() {
    local mode="${1:-plain}" i n label desc footer mark el=""
    [[ "$mode" == fancy ]] && el=$'\033[K'
    n=${#__UI_PROMPT_OPT_VALS[@]}
    for ((i = 0; i < n; i++)); do
        label="${__UI_PROMPT_OPT_LABELS[i]}"
        desc="${__UI_PROMPT_OPT_DESCS[i]}"
        mark=${ _ui_promptMenuMark "$i"; }
        if ((i == __PROMPT[cursor])); then
            if [[ "${__PROMPT[color]}" == true ]]; then
                printf '%s\033[7m %s%d. %s \033[0m%s\n' "$__UI_INDENT_I" "$mark" "$((i + 1))" "$label" "$el" >&2
            else
                printf '%s> %s%d. %s%s\n' "$__UI_INDENT_I" "$mark" "$((i + 1))" "$label" "$el" >&2
            fi
        else
            printf '%s  %s%d. %s%s\n' "$__UI_INDENT_I" "$mark" "$((i + 1))" "$label" "$el" >&2
        fi
        [[ -n "$desc" ]] && printf '%s    %s%s\n' "$__UI_INDENT_I" "$desc" "$el" >&2
    done
    footer=${ _ui_promptDefaultFooter; }
    [[ -n "$el" ]] && printf '%s' "$el" >&2
    ui_i "$footer"
}

_ui_promptMenuRows() {
    local i n
    n=${#__UI_PROMPT_OPT_VALS[@]}
    for i in "${!__UI_PROMPT_OPT_DESCS[@]}"; do
        [[ -n "${__UI_PROMPT_OPT_DESCS[i]}" ]] && n=$((n + 1))
    done
    printf '%s' $((n + 1))
}

# Drop cursor chrome on the last frame so inverse / ">" does not linger.
_ui_promptMenuSettle() {
    local rows="$1"
    printf '\033[%dA' "$rows" >&2
    __PROMPT[cursor]=-1
    _ui_promptMenuDraw fancy
}

_ui_promptMenuFinish() {
    local action="$1" value="${2:-}" rows="${3:-}"
    [[ -n "$rows" ]] && _ui_promptMenuSettle "$rows"
    printf '\n' >&2
    _ui_promptSessionEnd
    _ui_promptDone "$action" "$value"
}

_ui_promptMenuFancy() {
    local token="" action idx first=true rows
    rows=${ _ui_promptMenuRows; }
    _ui_promptHead
    _ui_promptSessionBegin cbreak || return 1
    printf '\033[?25l' >&2
    while true; do
        if [[ "$first" != true ]]; then
            printf '\033[%dA' "$rows" >&2
        fi
        first=false
        _ui_promptMenuDraw fancy
        token=""
        if ! _ui_promptGetKey token one; then
            _ui_promptSessionEnd
            _ui_promptEof
            return 4
        fi
        if [[ "$token" == paste ]]; then
            _ui_promptRejectPaste
            first=true
            continue
        fi
        action=${ _ui_promptBindLookup "$token"; }
        case "$action" in
            submit)
                _ui_promptMenuFinish submit "${ _ui_promptMenuCollect; }" "$rows"
                return $?
                ;;
            cancel)
                _ui_promptMenuFinish cancel "" "$rows"
                return $?
                ;;
            back)
                _ui_promptMenuFinish back "" "$rows"
                return $?
                ;;
            help)
                _ui_promptShowHelp
                first=true
                continue
                ;;
            toggle)
                if _ui_promptMenuIsMulti; then
                    _ui_promptMenuToggle "${__PROMPT[cursor]}"
                fi
                continue
                ;;
        esac
        case "$token" in
            pageup|pagedown|wheelup|wheeldn|home|end)
                # Chrome leaves the cursor where the frame ends; the normal cursor-up redraw
                # replaces the frame on screen and in history instead of appending a copy.
                _ui_promptChromeScroll "$token"
                continue
                ;;
            up)
                if ((__PROMPT[cursor] > 0)); then
                    __PROMPT[cursor]=$((__PROMPT[cursor] - 1))
                fi
                ;;
            down)
                if ((__PROMPT[cursor] < ${#__UI_PROMPT_OPT_VALS[@]} - 1)); then
                    __PROMPT[cursor]=$((__PROMPT[cursor] + 1))
                fi
                ;;
            enter)
                _ui_promptMenuFinish submit "${ _ui_promptMenuCollect; }" "$rows"
                return $?
                ;;
            esc)
                _ui_promptMenuFinish cancel "" "$rows"
                return $?
                ;;
            space)
                if _ui_promptMenuIsMulti; then
                    _ui_promptMenuToggle "${__PROMPT[cursor]}"
                fi
                ;;
            [1-9])
                idx=$((10#$token - 1))
                if ((idx >= 0 && idx < ${#__UI_PROMPT_OPT_VALS[@]})); then
                    if _ui_promptMenuIsMulti; then
                        _ui_promptMenuToggle "$idx"
                    else
                        __PROMPT[cursor]=$idx
                    fi
                fi
                ;;
        esac
    done
}

_ui_promptMenuPlain() {
    local line="" action idx
    _ui_promptHead
    _ui_promptMenuDraw
    _ui_promptSessionBegin cooked || return 1
    while true; do
        printf '%sChoice: ' "$__UI_INDENT_I" >&2
        line=""
        if ! tty_read -r line; then
            _ui_promptSessionEnd
            _ui_promptEof
            return 4
        fi
        if [[ -z "$line" ]]; then
            if _ui_promptMenuIsMulti || [[ -n "${__PROMPT[default]}" ]]; then
                _ui_promptSessionEnd
                _ui_promptDone submit "${ _ui_promptMenuCollect; }"
                return $?
            fi
        fi
        action=${ _ui_promptBindLookup "${line,,}"; }
        case "$action" in
            submit)
                _ui_promptSessionEnd
                _ui_promptDone submit "${ _ui_promptMenuCollect; }"
                return $?
                ;;
            cancel)
                _ui_promptSessionEnd
                _ui_promptDone cancel
                return $?
                ;;
            back)
                _ui_promptSessionEnd
                _ui_promptDone back
                return $?
                ;;
            help)
                _ui_promptShowHelp
                continue
                ;;
            toggle)
                if _ui_promptMenuIsMulti; then
                    _ui_promptMenuToggle "${__PROMPT[cursor]}"
                fi
                continue
                ;;
        esac
        if [[ "$line" =~ ^[1-9][0-9]*$ ]]; then
            idx=$((10#$line - 1))
            if ((idx >= 0 && idx < ${#__UI_PROMPT_OPT_VALS[@]})); then
                if _ui_promptMenuIsMulti; then
                    _ui_promptMenuToggle "$idx"
                    continue
                fi
                _ui_promptSessionEnd
                _ui_promptDone submit "${__UI_PROMPT_OPT_VALS[idx]}"
                return $?
            fi
        fi
        if ! _ui_promptMenuIsMulti; then
            for idx in "${!__UI_PROMPT_OPT_VALS[@]}"; do
                if [[ "${__UI_PROMPT_OPT_VALS[idx]}" == "$line" || "${__UI_PROMPT_OPT_LABELS[idx]}" == "$line" ]]; then
                    _ui_promptSessionEnd
                    _ui_promptDone submit "${__UI_PROMPT_OPT_VALS[idx]}"
                    return $?
                fi
            done
        fi
        ui_b "Invalid selection."
    done
}

_ui_promptMenuRun() {
    _ui_promptLoadOptions || return 1
    if [[ "${__PROMPT[plain]}" == true || "$__UI_MODE" == plain ]]; then
        _ui_promptMenuPlain
        return $?
    fi
    _ui_promptMenuFancy
}
