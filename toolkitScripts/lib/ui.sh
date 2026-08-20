# ==================================================================================================
# Thundercast - toolkit UI (NDS-style single-key menus, no NDS dependency)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-19 | Modified: 2026-08-20
# ==================================================================================================

tcast_ui_init() {
    TCAST_UI_INDENT="${TCAST_UI_INDENT:-  }"
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
    title_line=" === Thundercast toolkit  v${ver} === "
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

# Description: True when keys/lines were supplied for automation (never use /dev/tty).
tcast_ui_batch() {
    [[ "${TCAST_UI_BATCH:-}" == "1" ]]
}

# Description: Pop one character from TCAST_UI_KEYS (tests) or read -n1.
# Must be called as a statement (not $(...)): command substitution is a subshell
# and would never advance TCAST_UI_KEYS. Result is TCAST_UI_KEY.
# Batch mode never falls through to /dev/tty: exhausted keys act as q.
tcast_ui_read_key() {
    local prompt="${1:-Choice: }" choice=""
    tcast_ui_init
    TCAST_UI_KEY=""
    if tcast_ui_batch || [[ -n "${TCAST_UI_KEYS:-}" ]]; then
        if [[ -z "${TCAST_UI_KEYS:-}" ]]; then
            printf '%sq\n' "$prompt" >&2
            TCAST_UI_KEY=q
            return 0
        fi
        choice="${TCAST_UI_KEYS:0:1}"
        TCAST_UI_KEYS="${TCAST_UI_KEYS:1}"
        printf '%s%s\n' "$prompt" "$choice" >&2
        TCAST_UI_KEY="$choice"
        return 0
    fi
    if [[ -e /dev/tty ]]; then
        read -rsp "$prompt" -n 1 choice < /dev/tty || return 1
        printf '\n' >&2
        TCAST_UI_KEY="$choice"
        return 0
    fi
    read -r choice || return 1
    TCAST_UI_KEY="${choice:0:1}"
}

# Description: Read a line. Result is TCAST_UI_LINE (do not use $(...)).
tcast_ui_read_line() {
    local prompt="${1:-}" var
    TCAST_UI_LINE=""
    if tcast_ui_batch || [[ -n "${TCAST_UI_LINES:-}" ]]; then
        if [[ -z "${TCAST_UI_LINES:-}" ]]; then
            printf '%s\n' "$prompt" >&2
            return 0
        fi
        var="${TCAST_UI_LINES%%$'\n'*}"
        if [[ "$TCAST_UI_LINES" == *$'\n'* ]]; then
            TCAST_UI_LINES="${TCAST_UI_LINES#*$'\n'}"
        else
            TCAST_UI_LINES=""
        fi
        printf '%s%s\n' "$prompt" "$var" >&2
        TCAST_UI_LINE="$var"
        return 0
    fi
    if [[ -e /dev/tty ]]; then
        read -rp "$prompt" var < /dev/tty || return 1
        TCAST_UI_LINE="$var"
        return 0
    fi
    read -rp "$prompt" var || return 1
    TCAST_UI_LINE="$var"
}

tcast_ui_read_secret() {
    local prompt="${1:-Value: }" var
    if tcast_ui_batch || [[ -n "${TCAST_UI_LINES:-}" ]]; then
        tcast_ui_read_line "$prompt"
        return 0
    fi
    TCAST_UI_LINE=""
    if [[ -e /dev/tty ]]; then
        read -rsp "$prompt" var < /dev/tty || return 1
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
    if tcast_ui_batch || [[ -n "${TCAST_UI_KEYS:-}" || "${TCAST_UI_NO_PAUSE:-}" == "1" ]]; then
        return 0
    fi
    printf '  Press Enter… ' >&2
    if [[ -e /dev/tty ]]; then
        read -r _x < /dev/tty || true
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
