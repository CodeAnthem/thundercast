#!/usr/bin/env bash
# ==================================================================================================
# Thundercast - Bash Essentials - Console tests
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-27 | Modified: 2026-09-27
# ==================================================================================================

# shellcheck source=../testEnvironment/testEnvironment.sh
source "$(dirname "${BASH_SOURCE[0]}")/../testEnvironment/testEnvironment.sh"

_console_yields=0
_console_resumes=0

_console_stub_task_io() {
    # shellcheck disable=SC2329
    taskYield() {
        _console_yields=$((_console_yields + 1))
        printf 'YIELD\n' >&2
    }
    # shellcheck disable=SC2329
    taskResume() {
        _console_resumes=$((_console_resumes + 1))
        printf 'RESUME\n' >&2
    }
}

suite_console() {
    local out rc yields_before env out_file err_file out_got err_got

    essentials_test_load console
    _console_stub_task_io

    bts_section "Write"

    out=${ console_write "partition done" 2>&1; }
    if [[ "$out" == "partition done" && "$_console_yields" -eq 0 && "$_console_resumes" -eq 0 ]]; then
        bts_pass "closed task prints the line and does not yield"
    else
        bts_fail "closed task out='${out}' yield=${_console_yields} resume=${_console_resumes}"
    fi

    taskStart "Disk" 2>/dev/null # in-progress task line
    out=${ console_write "partition done" 2>&1; }
    if [[ "$out" == $'YIELD\npartition done\nRESUME' && "$_console_yields" -eq 1 && "$_console_resumes" -eq 1 ]] && taskIsOpen; then
        bts_pass "open task yields, prints, resumes, and stays open"
    else
        bts_fail "open task out='${out}' yield=${_console_yields} resume=${_console_resumes} open=$(taskIsOpen && printf yes || printf no)"
    fi
    taskCancel 2>/dev/null # drop the in-progress line

    yields_before="$_console_yields"
    unset -f taskYield
    rc=0
    out=${ console_write "partition done" 2>&1; } || rc=$?
    if [[ "$rc" -eq 0 && "$out" == "partition done" && "$_console_yields" -eq "$yields_before" ]]; then
        bts_pass "missing taskYield prints and returns 0"
    else
        bts_fail "missing taskYield rc=${rc} out='${out}' yield=${_console_yields}"
    fi

    bts_section "Stream"

    env="$(dirname "${BASH_SOURCE[0]}")/../testEnvironment/testEnvironment.sh"
    out_file="$(mktemp)"
    err_file="$(mktemp)"

    rc=0
    bash -c '
        source "$1"
        _essentials_test_ensureConfig
        essentials_config[CONSOLE_STREAM]=stdout
        essentials_test_load console || exit 1
        console_write "stream line"
    ' bash "$env" >"$out_file" 2>"$err_file" || rc=$?
    out_got=$(<"$out_file")
    err_got=$(<"$err_file")
    if [[ "$rc" -eq 0 && "$out_got" == "stream line" && -z "$err_got" ]]; then
        bts_pass "CONSOLE_STREAM=stdout prints on stdout"
    else
        bts_fail "stdout stream rc=${rc} out='${out_got}' err='${err_got}'"
    fi

    rc=0
    bash -c '
        source "$1"
        _essentials_test_ensureConfig
        essentials_config[CONSOLE_STREAM]=file
        essentials_test_load console
    ' bash "$env" >"$out_file" 2>"$err_file" || rc=$? # Console: invalid CONSOLE_STREAM
    err_got=$(<"$err_file")
    if [[ "$rc" -ne 0 ]] && [[ "$err_got" == *"invalid CONSOLE_STREAM"* ]]; then
        bts_pass "invalid CONSOLE_STREAM is rejected"
    else
        bts_fail "invalid stream rc=${rc} err='${err_got}'"
    fi

    rm -f -- "$out_file" "$err_file"
}
