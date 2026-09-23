#!/usr/bin/env bash
# ==================================================================================================
# ThunderCast - bashTestSuite isolate (one child bash per file)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-20 | Modified: 2026-09-20
# ==================================================================================================

_bts_ttySave() {
    bts_config[stty]=
    if { :; } 2>/dev/null </dev/tty; then
        bts_config[stty]="$(stty -g </dev/tty 2>/dev/null || true)"
    fi
}

_bts_ttyRestore() {
    [[ -n "${bts_config[stty]:-}" ]] || return 0
    {
        stty "${bts_config[stty]}" </dev/tty
        printf '\033[?25h' >/dev/tty
    } 2>/dev/null || true
}

_bts_runCleanup() {
    _bts_ttyRestore
    if [[ -n "${bts_config[work]:-}" ]]; then
        rm -rf "${bts_config[work]}"
        bts_config[work]=
    fi
}

_bts_writeCounts() {
    [[ -n "${bts_config[counts_file]:-}" ]] || return 0
    printf 'passed=%s\nfailed=%s\nclean=%s\n' \
        "${bts_config[passed]:-0}" \
        "${bts_config[failed]:-0}" \
        "${bts_config[clean]:-0}" >"${bts_config[counts_file]}"
}

_bts_writeFailLog() {
    local passed="$1" failed="$2" nfiles="$3" body="$4" log="$5"
    if ((failed == 0)); then
        rm -f "$log"
        return 0
    fi
    {
        printf 'failed=%s passed=%s files=%s\n' "$failed" "$passed" "$nfiles"
        cat "$body"
    } >"$log"
}

# Suite-owned capture lines (after ANSI strip). Everything else is a leak.
_bts_childLineIsOurs() {
    local s="$1"
    [[ -z "${s//[$' \t\r']/}" ]] && return 0
    [[ "$s" == '  +='* ]] && return 0
    [[ "$s" == '  |  '* ]] && return 0
    case "$s" in
        '  [OK] '* | '  [FAIL] '* | '  [DEBUG] '*) return 0 ;;
    esac
    return 1
}

_bts_readCounts() {
    local file="$1"
    local -n _bts_passed="$2"
    local -n _bts_failed="$3"
    local -n _bts_clean="$4"
    local line
    _bts_passed=0
    _bts_failed=0
    _bts_clean=0
    [[ -f "$file" ]] || return 1
    while IFS= read -r line || [[ -n "$line" ]]; do
        case "$line" in
            passed=*) _bts_passed="${line#passed=}" ;;
            failed=*) _bts_failed="${line#failed=}" ;;
            clean=*) _bts_clean="${line#clean=}" ;;
        esac
    done <"$file"
    _bts_passed="${_bts_passed:-0}"
    _bts_failed="${_bts_failed:-0}"
    _bts_clean="${_bts_clean:-0}"
    return 0
}

_bts_replayChildOut() {
    local out="$1" body="$2" file="$3"
    local extglob_was=0 line plain leak_hdr=0

    shopt -q extglob && extglob_was=1
    shopt -s extglob

    while IFS= read -r line || [[ -n "$line" ]]; do
        plain="${line//$'\033['+([0-9;])m/}"
        if _bts_childLineIsOurs "$plain"; then
            if [[ "${bts_config[format]}" == 1 ]] \
                || { [[ "${bts_config[debug]}" == 1 && "$plain" == '  [DEBUG] '* ]]; }; then
                printf '%s\n' "$line" >&2
            fi
            continue
        fi
        if ((leak_hdr == 0)); then
            printf '\nFILE %s\nLEAK\n' "$file" >>"$body"
            leak_hdr=1
        fi
        printf '%s\n' "$line" >>"$body"
        bts_config[failed]=$((bts_config[failed] + 1))
        if [[ "${bts_config[format]}" == 1 ]]; then
            _bts_case_fail "leaked: ${plain}"
        fi
    done <"$out"

    ((extglob_was)) || shopt -u extglob
}

_bts_isolateFile() {
    local file="$1" body="$2" work="$3"
    local counts out rc=0 child_passed=0 child_failed=0 child_clean=0

    counts="${work}/counts"
    out="${work}/out"
    rm -f "$counts"
    : >"$out"

    rc=0
    BTS_FORMAT="${bts_config[format]}" \
        BTS_DEBUG="${bts_config[debug]}" \
        BTS_FAIL_LOG="$body" \
        BTS_CURRENT_FILE="$file" \
        BTS_COUNTS_FILE="$counts" \
        BTS_COLOR="${bts_config[color]}" \
        BTS_CHILD_FILE="$file" \
        bash "${bts_config[dir]}/main.sh" >"$out" 2>&1 || rc=$?

    _bts_ttyRestore

    if _bts_readCounts "$counts" child_passed child_failed child_clean; then
        bts_config[passed]=$((bts_config[passed] + child_passed))
        bts_config[failed]=$((bts_config[failed] + child_failed))
    fi

    if [[ ! -f "$counts" ]] || { ((rc != 0)) && ((child_clean == 0)); }; then
        if [[ "${bts_config[format]}" == 1 && -s "$out" ]]; then
            cat "$out" >&2
        fi
        {
            printf '\nFILE %s\nCRASH rc=%s\n' "$file" "$rc"
            if [[ -s "$out" ]]; then
                sed 's/^/  /' "$out"
            fi
        } >>"$body"
        bts_config[failed]=$((bts_config[failed] + 1))
        bts_debug "crash $file rc=$rc"
        return 0
    fi

    _bts_replayChildOut "$out" "$body" "$file"
}
