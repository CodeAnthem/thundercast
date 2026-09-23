#!/usr/bin/env bash
# ==================================================================================================
# ThunderCast - bashTestSuite
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-02 | Modified: 2026-09-20
# Description:   bash main.sh PATH…  or  source main.sh (test helpers only)
# ==================================================================================================

_BTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! declare -p bts_config &>/dev/null; then
    declare -gA bts_config=(
        [dir]="$_BTS_DIR"
        [passed]=0
        [failed]=0
        [suite]=
        [format]="${BTS_FORMAT:-0}"
        [debug]="${BTS_DEBUG:-0}"
        [color]="${BTS_COLOR:-}"
        [fail_log]="${BTS_FAIL_LOG:-}"
        [current_file]="${BTS_CURRENT_FILE:-}"
        [counts_file]="${BTS_COUNTS_FILE:-}"
        [log_context]=
        [ok]=OK
        [fail]=FAIL
    )
    # shellcheck source=./logger.sh
    source "${_BTS_DIR}/logger.sh"
    # shellcheck source=./ui.sh
    source "${_BTS_DIR}/ui.sh"
    # shellcheck source=./assert.sh
    source "${_BTS_DIR}/assert.sh"
    # shellcheck source=./discover.sh
    source "${_BTS_DIR}/discover.sh"
    # shellcheck source=./execute.sh
    source "${_BTS_DIR}/execute.sh"
    # shellcheck source=./isolate.sh
    source "${_BTS_DIR}/isolate.sh"
    _bts_ui_init
    _bts_logger_init
fi

_bts_usage() {
    bts_status "Usage: main.sh [-f] [--log PATH] [--selftest] [--debug] [PATH ...]"
    bts_status "  PATH       *_TEST.sh file or directory of them"
    bts_status "  -f         print each case"
    bts_status "  --log PATH fail log (default \$PWD/.bashTestSuite.fail.log)"
    bts_status "  --selftest run bashTestSuite/tests"
    bts_status "  --debug    suite debug logs"
}

# Description: Run tests. Quiet: one OK/FAIL line. -f: case list.
bts() {
    local format=0 log="" selftest=0 debug=0
    local -a paths=()
    local -a files=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -f | --format)
                format=1
                shift
                ;;
            --debug)
                debug=1
                shift
                ;;
            --selftest)
                selftest=1
                shift
                ;;
            --log)
                if [[ -z "${2:-}" ]]; then
                    _bts_usage
                    return 2
                fi
                log="$2"
                shift 2
                ;;
            -h | --help)
                _bts_usage
                return 2
                ;;
            --)
                shift
                paths+=("$@")
                break
                ;;
            -*)
                bts_error "unknown flag: $1"
                _bts_usage
                return 2
                ;;
            *)
                paths+=("$1")
                shift
                ;;
        esac
    done

    if ((selftest)); then
        if ((${#paths[@]} > 0)); then
            bts_error "--selftest does not take PATH"
            return 2
        fi
        paths=("${bts_config[dir]}/tests")
    fi

    if ((${#paths[@]} == 0)); then
        _bts_usage
        return 2
    fi

    if [[ -z "$log" ]]; then
        log="${PWD}/.bashTestSuite.fail.log"
    elif [[ "$log" != /* ]]; then
        log="${PWD}/${log}"
    fi

    bts_config[format]="$format"
    bts_config[debug]="$debug"
    if [[ "${bts_config[color]}" != [01] ]]; then
        if [[ -z "${NO_COLOR:-}" && -t 2 ]]; then
            bts_config[color]=1
        else
            bts_config[color]=0
        fi
    fi
    _bts_ui_init
    _bts_logger_init

    _bts_collectFiles files "${paths[@]}" || return $?

    local work body file
    work="$(mktemp -d)"
    bts_config[work]="$work"
    body="${work}/body"
    : >"$body"

    bts_config[passed]=0
    bts_config[failed]=0
    bts_config[log_context]=
    _bts_ttySave
    local prev_exit
    prev_exit="$(trap -p EXIT || true)"
    trap '_bts_runCleanup' EXIT
    for file in "${files[@]}"; do
        _bts_isolateFile "$file" "$body" "$work"
    done

    _bts_writeFailLog "${bts_config[passed]}" "${bts_config[failed]}" "${#files[@]}" "$body" "$log"
    _bts_runCleanup
    if [[ -n "$prev_exit" ]]; then
        eval "$prev_exit"
    else
        trap - EXIT
    fi

    if ((format)); then
        _bts_summary
        return $?
    fi
    if ((bts_config[failed] > 0)); then
        bts_status "FAIL ${bts_config[failed]} ${log}"
        return 1
    fi
    bts_status "OK"
    return 0
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    set -euo pipefail
    if [[ -n "${BTS_CHILD_FILE:-}" ]]; then
        _bts_child_file="$BTS_CHILD_FILE"
        unset BTS_CHILD_FILE BTS_COUNTS_FILE BTS_FAIL_LOG BTS_CURRENT_FILE BTS_FORMAT BTS_DEBUG
        trap '_bts_writeCounts' EXIT
        _bts_executeFile "$_bts_child_file"
        bts_config[clean]=1
        if ((bts_config[failed] > 0)); then
            exit 1
        fi
        exit 0
    fi
    bts "$@"
    exit $?
fi
