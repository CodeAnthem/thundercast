# ==================================================================================================
# Thundercast - toolkit UI (NDS-style single-key menus, no NDS dependency)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-19 | Modified: 2026-08-20
# ==================================================================================================

declare -g _TCAST_UI_INPUT_GUARD=0
declare -g _TCAST_UI_INPUT_STTY=""
declare -g _TCAST_UI_PROMPT_DEPTH=0

tcast_ui_init() {
    TCAST_UI_INDENT="${TCAST_UI_INDENT:-  }"
}

_tcast_ui_tty_ok() {
    [[ -c /dev/tty && -r /dev/tty && -w /dev/tty ]]
}

_tcast_ui_drain_tty() {
    local _chunk
    _tcast_ui_tty_ok || return 0
    {
        while IFS= read -r -t 0 -n 256 _chunk; do
            :
        done
    } </dev/tty 2>/dev/null || true
}

_tcast_ui_input_restore_stty() {
    [[ -n "${_TCAST_UI_INPUT_STTY:-}" ]] || return 0
    stty "$_TCAST_UI_INPUT_STTY" </dev/tty 2>/dev/null || true
}

_tcast_ui_input_idle_stty() {
    _tcast_ui_tty_ok || return 0
    stty -echo isig -icanon min 0 time 0 </dev/tty 2>/dev/null || true
    _tcast_ui_drain_tty
}

tcast_ui_input_guard_enable() {
    [[ "${_TCAST_UI_INPUT_GUARD:-0}" == "1" ]] && return 0
    _tcast_ui_tty_ok || return 0
    _TCAST_UI_INPUT_STTY="$(stty -g </dev/tty 2>/dev/null || true)"
    [[ -n "${_TCAST_UI_INPUT_STTY}" ]] || return 0
    _TCAST_UI_INPUT_GUARD=1
    _TCAST_UI_PROMPT_DEPTH=0
    _tcast_ui_input_idle_stty
}

tcast_ui_input_guard_disable() {
    _tcast_ui_input_restore_stty
    _TCAST_UI_INPUT_GUARD=0
    _TCAST_UI_PROMPT_DEPTH=0
}

_tcast_ui_session_sigint() {
    tcast_ui_input_guard_disable
    exit 130
}

tcast_ui_prompt_enter() {
    _TCAST_UI_PROMPT_DEPTH=$((${_TCAST_UI_PROMPT_DEPTH:-0} + 1))
    if [[ "${_TCAST_UI_PROMPT_DEPTH}" -eq 1 && "${_TCAST_UI_INPUT_GUARD:-0}" == "1" ]]; then
        _tcast_ui_input_restore_stty
    fi
    _tcast_ui_drain_tty
}

tcast_ui_prompt_leave() {
    local depth="${_TCAST_UI_PROMPT_DEPTH:-0}"
    if (( depth > 0 )); then
        _TCAST_UI_PROMPT_DEPTH=$((depth - 1))
    fi
    if [[ "${_TCAST_UI_PROMPT_DEPTH}" -eq 0 && "${_TCAST_UI_INPUT_GUARD:-0}" == "1" ]]; then
        _tcast_ui_input_idle_stty
    fi
}

# Description: bash read from /dev/tty with the input guard lifted.
tcast_ui_tty_read() {
    local rc=0
    tcast_ui_prompt_enter
    # shellcheck disable=SC2162
    read "$@" </dev/tty
    rc=$?
    tcast_ui_prompt_leave
    return "$rc"
}

tcast_ui_clear() {
    [[ "${TCAST_UI_NO_CLEAR:-}" == "1" ]] && return 0
    printf '\033[2J\033[H' >&2
}

# Description: Box banner with title + optional subtitle.
tcast_ui_banner() {
    local subtitle="${1:-}"
    local ver title_line sub_line inner border margin
    tcast_ui_init
    ver="$(tcast_toolkit_version)"
    title_line=" === ThunderCast toolkit  v${ver} === "
    sub_line="  ${subtitle}"
    inner=${#title_line}
    (( ${#sub_line} > inner )) && inner=${#sub_line}
    (( inner < 56 )) && inner=56
    margin='  '
    border=$(printf -- '-%.0s' $(seq 1 "$inner"))
    printf "%s+%s+\n" "$margin" "$border" >&2
    printf "%s|%s%*s|\n" "$margin" "$title_line" "$(( inner - ${#title_line} ))" '' >&2
    [[ -n "$subtitle" ]] && printf "%s|%s%*s|\n" "$margin" "$sub_line" "$(( inner - ${#sub_line} ))" '' >&2
    printf "%s+%s+\n" "$margin" "$border" >&2
}

tcast_ui_section() {
    TCAST_UI_SUBTITLE="${1:-}"
    tcast_ui_clear
    tcast_ui_banner "${TCAST_UI_SUBTITLE}"
}

tcast_ui_line() {
    printf '%s%s\n' "${TCAST_UI_INDENT:-  }" "$*" >&2
}

tcast_ui_blank() {
    printf '\n' >&2
}

# Description: Pop one character from /dev/tty (or stdin). Result is TCAST_UI_KEY.
tcast_ui_read_key() {
    local prompt="${1:-Choice: }" choice="" rc=0
    tcast_ui_init
    TCAST_UI_KEY=""
    if [[ -e /dev/tty ]]; then
        tcast_ui_tty_read -rsp "$prompt" -n 1 choice || rc=$?
        [[ "$rc" -eq 0 ]] || return "$rc"
        printf '\n' >&2
        TCAST_UI_KEY="$choice"
        return 0
    fi
    read -r choice || return 1
    TCAST_UI_KEY="${choice:0:1}"
}

# Description: Read a line. Result is TCAST_UI_LINE (do not use $(...)).
tcast_ui_read_line() {
    local prompt="${1:-}" var rc=0
    TCAST_UI_LINE=""
    if [[ -e /dev/tty ]]; then
        tcast_ui_tty_read -rp "$prompt" var || rc=$?
        [[ "$rc" -eq 0 ]] || return "$rc"
        TCAST_UI_LINE="$var"
        return 0
    fi
    read -rp "$prompt" var || return 1
    TCAST_UI_LINE="$var"
}

tcast_ui_read_secret() {
    local prompt="${1:-Value: }" var rc=0
    TCAST_UI_LINE=""
    if [[ -e /dev/tty ]]; then
        tcast_ui_tty_read -rsp "$prompt" var || rc=$?
        [[ "$rc" -eq 0 ]] || return "$rc"
        printf '\n' >&2
        TCAST_UI_LINE="$var"
        return 0
    fi
    read -rsp "$prompt" var || return 1
    printf '\n' >&2
    TCAST_UI_LINE="$var"
}

# Returns 0 yes, 1 no, 2 back.
tcast_ui_yesno() {
    local prompt="${1:-Proceed?}" key
    while true; do
        tcast_ui_read_key "${prompt} [y/n/b]: " || return 1
        key="$TCAST_UI_KEY"
        case "${key,,}" in
            y) printf 'Yes\n' >&2; return 0 ;;
            n|q) printf 'No\n' >&2; return 1 ;;
            b|0) printf 'Back\n' >&2; return 2 ;;
            *) tcast_ui_line "Press y, n, or b" ;;
        esac
    done
}

tcast_ui_pause() {
    local _x
    if [[ "${TCAST_UI_NO_PAUSE:-}" == "1" ]]; then
        return 0
    fi
    printf '  Press Enter… ' >&2
    if [[ -e /dev/tty ]]; then
        tcast_ui_tty_read -r _x || true
    else
        read -r _x || true
    fi
}

# Description: Print numbered items from remaining args; 0=back.
# Sets TCAST_UI_LAST_MAX to item count.
tcast_ui_print_menu() {
    local i=1 item
    TCAST_UI_LAST_MAX=0
    for item in "$@"; do
        printf '    %s) %s\n' "$i" "$item" >&2
        i=$((i + 1))
    done
    TCAST_UI_LAST_MAX=$((i - 1))
    printf '    0) Back\n' >&2
}

# Description: Read 1..max or 0. Result is TCAST_UI_CHOICE (do not use $(...)).
tcast_ui_pick() {
    local max="$1" prompt="${2:-Choice: }" key
    TCAST_UI_CHOICE=""
    while true; do
        tcast_ui_read_key "$prompt" || return 1
        key="$TCAST_UI_KEY"
        if [[ "$key" == "0" || "${key,,}" == "b" ]]; then
            TCAST_UI_CHOICE=0
            return 0
        fi
        if [[ "$key" == "q" || "$key" == "Q" ]]; then
            TCAST_UI_CHOICE=q
            return 0
        fi
        if [[ "$key" =~ ^[1-9]$ ]] && (( key >= 1 && key <= max )); then
            TCAST_UI_CHOICE="$key"
            return 0
        fi
        tcast_ui_line "Choose 1-${max}, or 0 to go back"
    done
}
