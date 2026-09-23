#!/usr/bin/env bash
# ==================================================================================================
# Thundercast - Bash Essentials - TTY - Controller
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-18 | Modified: 2026-09-21
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

# True when this process can open the controlling TTY (not just that /dev/tty exists).
tty_ok() {
    { :; } 2>/dev/null </dev/tty
}

# True if the kernel has typeahead (Bash 5.3 `read -t 0` does not consume).
tty_pending() {
    tty_ok || return 1
    { IFS= read -r -t 0; } </dev/tty 2>/dev/null
}

# Discard queued keys. Safe with no TTY.
tty_drain() {
    local _chunk
    tty_ok || return 0
    {
        while IFS= read -r -t 0; do
            _chunk=""
            IFS= read -r -t 0.05 -N 256 _chunk || true
            [[ -n "$_chunk" ]] || break
        done
        dd if=/dev/tty of=/dev/null bs=4096 count=32 iflag=nonblock status=none 2>/dev/null || true
    } </dev/tty 2>/dev/null || true
    return 0
}

_tty_applyIdle() {
    tty_ok || return 0
    stty -echo isig -icanon min 0 time 0 -ixon -ixoff </dev/tty 2>/dev/null || true
    tty_drain
}

_tty_applyCooked() {
    tty_ok || return 0
    if [[ -n "${__TTY_STTY:-}" ]]; then
        stty "${__TTY_STTY}" </dev/tty 2>/dev/null || true
        return 0
    fi
    stty echo icanon isig </dev/tty 2>/dev/null || true
}

_tty_applyHidden() {
    tty_ok || return 0
    if [[ -n "${__TTY_STTY:-}" ]]; then
        stty "${__TTY_STTY}" </dev/tty 2>/dev/null || true
    fi
    stty -echo icanon isig </dev/tty 2>/dev/null || true
}

_tty_applyCbreak() {
    tty_ok || return 0
    stty -echo isig -icanon min 1 time 0 -ixon -ixoff </dev/tty 2>/dev/null || true
}

# Map one byte to an assoc key. Quote/space/] cannot be unset as raw char keys.
_tty_allowKey() {
    printf -v "$1" '%d' "'$2"
}

# True if $1 is Enter, backspace, or a key in __TTY_ALLOW_SET.
_tty_charAllowed() {
    local ch="$1" k
    case "$ch" in
        ''|$'\n'|$'\r'|$'\b'|$'\177') return 0 ;;
    esac
    _tty_allowKey k "$ch"
    [[ -n "${__TTY_ALLOW_SET[$k]+_}" ]]
}

_tty_allowAppendPreset() {
    local name="${1,,}" extra
    case "$name" in
        digits)
            __TTY_ALLOW_BODY='0123456789'
            ;;
        decimal)
            _tty_allowAppendPreset digits || return 1
            __TTY_ALLOW_BODY+='.'
            ;;
        hex)
            _tty_allowAppendPreset digits || return 1
            __TTY_ALLOW_BODY+='ABCDEFabcdef'
            ;;
        upper)
            __TTY_ALLOW_BODY='ABCDEFGHIJKLMNOPQRSTUVWXYZ'
            ;;
        lower)
            __TTY_ALLOW_BODY='abcdefghijklmnopqrstuvwxyz'
            ;;
        alpha)
            _tty_allowAppendPreset upper || return 1
            extra="${__TTY_ALLOW_BODY}"
            _tty_allowAppendPreset lower || return 1
            __TTY_ALLOW_BODY="${extra}${__TTY_ALLOW_BODY}"
            ;;
        alnum)
            _tty_allowAppendPreset digits || return 1
            extra="${__TTY_ALLOW_BODY}"
            _tty_allowAppendPreset alpha || return 1
            __TTY_ALLOW_BODY="${extra}${__TTY_ALLOW_BODY}"
            ;;
        *)
            error "Tty: unknown tty_allow preset ${1}"
            __TTY_ALLOW_BODY=""
            return 1
            ;;
    esac
}

# Fill the allow map from literal add/exclude strings, then cbreak. No getopts.
_tty_allowActivate() {
    local add="$1" excl="$2"
    local i c k
    local -i n
    local -A next=()
    n=${#add}
    for (( i = 0; i < n; i++ )); do
        c="${add:i:1}"
        _tty_allowKey k "$c"
        next[$k]=1
    done
    n=${#excl}
    for (( i = 0; i < n; i++ )); do
        c="${excl:i:1}"
        _tty_allowKey k "$c"
        unset "next[$k]"
    done
    if (( ${#next[@]} == 0 )); then
        error "Tty: tty_allow produced an empty set"
        return 1
    fi
    declare -gA __TTY_ALLOW_SET=()
    for k in "${!next[@]}"; do
        __TTY_ALLOW_SET[$k]=1
    done
    _tty_setPolicy allow
}

# Put the TTY into a named policy. See tty_setPreset / tty_allow.
_tty_setPolicy() {
    local policy="$1"
    if [[ "$policy" != allow ]]; then
        declare -gA __TTY_ALLOW_SET=()
    fi
    __TTY_POLICY="$policy"
    case "$policy" in
        idle) _tty_applyIdle ;;
        cooked) _tty_applyCooked ;;
        hidden) _tty_applyHidden ;;
        cbreak|allow) _tty_applyCbreak ;;
        *)
            error "Tty: unknown policy ${policy}"
            return 1
            ;;
    esac
    return 0
}

# Snapshot the TTY and start discarding keys until tty_begin. No-op without a TTY.
tty_guardEnable() {
    [[ "${__TTY_GUARD:-0}" == "1" ]] && return 0
    tty_ok || return 0
    __TTY_STTY="${ { stty -g; } 2>/dev/null </dev/tty || true; }"
    [[ -n "${__TTY_STTY}" ]] || return 0
    __TTY_GUARD=1
    __TTY_DEPTH=0
    _tty_setPolicy idle
}

# Restore the snapshot taken at tty_guardEnable. Idempotent. EXIT hook.
tty_restore() {
    if [[ -n "${__TTY_STTY:-}" ]]; then
        stty "${__TTY_STTY}" </dev/tty 2>/dev/null || true
    fi
    __TTY_GUARD=0
    __TTY_DEPTH=0
    __TTY_POLICY=cooked
    declare -gA __TTY_ALLOW_SET=()
    return 0
}

# About to interact: drain typeahead, leave idle. Pair with tty_end.
tty_begin() {
    __TTY_DEPTH=$((${__TTY_DEPTH:-0} + 1))
    if [[ "${__TTY_DEPTH}" -eq 1 && "${__TTY_GUARD:-0}" == "1" ]]; then
        tty_drain
        _tty_setPolicy cooked
    fi
    return 0
}

# Interaction finished. Last end returns to idle when the guard is on.
tty_end() {
    local depth="${__TTY_DEPTH:-0}"
    if (( depth > 0 )); then
        __TTY_DEPTH=$((depth - 1))
    fi
    if [[ "${__TTY_DEPTH}" -eq 0 && "${__TTY_GUARD:-0}" == "1" ]]; then
        _tty_setPolicy idle
    fi
    return 0
}

# Restrict tty_getc to a literal character set. Union -p / -a / positionals, then -x.
# OPTARG is stored as-is: -x " " drops space, -x '"' drops double-quote. No escape decode.
tty_allow() {
    local OPTIND=1 OPTARG="" opt add="" excl="" name pos
    local -a names=()

    while getopts ':p:a:x:' opt; do
        case "$opt" in
            p) names+=("$OPTARG") ;;
            a) add+="$OPTARG" ;;
            x) excl+="$OPTARG" ;;
            :)
                error "Tty: tty_allow -${OPTARG} requires an argument"
                return 1
                ;;
            \?)
                error "Tty: tty_allow unknown flag -${OPTARG}"
                return 1
                ;;
        esac
    done
    shift $((OPTIND - 1))
    for pos in "$@"; do
        add+="$pos"
    done

    for name in "${names[@]}"; do
        _tty_allowAppendPreset "$name" || return 1
        add+="${__TTY_ALLOW_BODY}"
    done

    [[ -n "$add" || -n "$excl" ]] || {
        error "Tty: tty_allow requires -p, -a, or a character string"
        return 1
    }
    _tty_allowActivate "$add" "$excl"
}

# bash read, always from /dev/tty. Does not parse flags or apply allowlists.
# With __TTY_READ_TICK set (chrome on) the wait is sliced and __TTY_TICK_HOOK runs after each
# timed-out slice. A trap that fires while a read blocks must only set a flag: bash has one
# read timer, so a nested read -t inside the trap would leave this read waiting forever.
# __TTY_READING is 1 while a read is in flight so traps can tell.
# Callers must not pass -p while the tick is set (it would reprint every slice).
tty_read() {
    local rc
    if [[ -z "${__TTY_READ_TICK:-}" ]]; then
        # shellcheck disable=SC2162
        read "$@" </dev/tty
        return $?
    fi
    while true; do
        __TTY_READING=1
        # shellcheck disable=SC2162
        read -t "$__TTY_READ_TICK" "$@" </dev/tty && {
            __TTY_READING=0
            return 0
        }
        rc=$?
        __TTY_READING=0
        (( rc > 128 )) || return "$rc"
        [[ -n "${__TTY_TICK_HOOK:-}" ]] && "$__TTY_TICK_HOOK"
    done
}

# One key from /dev/tty into <var>. Drops illegal keys when policy is allow.
# Returns 1 on EOF or if policy is idle.
# Locals are _tty_* so printf -v cannot hit them when the dest is named ch/dest.
tty_getc() {
    local _tty_dest="${1:-}" _tty_raw="${2:-}" _tty_ch=""
    [[ -n "$_tty_dest" ]] || {
        error "Tty: tty_getc requires a variable name"
        return 1
    }
    tty_ok || return 1
    [[ "${__TTY_POLICY:-}" != idle ]] || return 1
    while true; do
        _tty_ch=""
        IFS= tty_read -r -n 1 _tty_ch || return 1
        if [[ "$_tty_raw" != raw && "${__TTY_POLICY}" == allow ]] && ! _tty_charAllowed "$_tty_ch"; then
            continue
        fi
        printf -v "$_tty_dest" '%s' "$_tty_ch"
        return 0
    done
}
