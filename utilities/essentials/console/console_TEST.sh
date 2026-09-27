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
    local out err rc yields_before out_file err_file

    essentials_test_load console
    _console_stub_task_io

    bts_section "Stderr"

    out=${ console_writeErr "partition done" 2>&1; }
    if [[ "$out" == "partition done" && "$_console_yields" -eq 0 && "$_console_resumes" -eq 0 ]]; then
        bts_pass "closed task prints stderr and does not yield"
    else
        bts_fail "closed stderr out='${out}' yield=${_console_yields} resume=${_console_resumes}"
    fi

    taskStart "Disk" 2>/dev/null # in-progress task line
    out=${ console_writeErr "partition done" 2>&1; }
    if [[ "$out" == $'YIELD\npartition done\nRESUME' && "$_console_yields" -eq 1 && "$_console_resumes" -eq 1 ]] && taskIsOpen; then
        bts_pass "open task yields, prints stderr, resumes, and stays open"
    else
        bts_fail "open stderr out='${out}' yield=${_console_yields} resume=${_console_resumes} open=$(taskIsOpen && printf yes || printf no)"
    fi
    taskCancel 2>/dev/null # drop the in-progress line

    bts_section "Stdout"

    if [[ -t 1 ]]; then
        bts_fail "stdout is a terminal; the non-tty case is not observable"
    else
        taskStart "Disk" 2>/dev/null # in-progress task line
        yields_before="$_console_yields"
        out_file="$(mktemp)"
        err_file="$(mktemp)"
        console_writeOut "stdout line" >"$out_file" 2>"$err_file"
        out=$(<"$out_file")
        err=$(<"$err_file")
        rm -f -- "$out_file" "$err_file"
        if [[ "$out" == "stdout line" && -z "$err" && "$_console_yields" -eq "$yields_before" ]]; then
            bts_pass "stdout that is not a terminal prints and does not yield"
        else
            bts_fail "stdout out='${out}' err='${err}' yield=${_console_yields}"
        fi
        taskCancel 2>/dev/null # drop the in-progress line
    fi

    bts_section "Logger"

    essentials_test_load logger
    logger_setMinLevel info
    taskStart "Disk" 2>/dev/null # in-progress task line
    yields_before="$_console_yields"
    out_file="$(mktemp)"
    err_file="$(mktemp)"
    error "hello-error" >"$out_file" 2>"$err_file"
    out=$(<"$out_file")
    err=$(<"$err_file")
    if [[ -z "$out" && "$err" == $'YIELD\n[ERROR] - hello-error\nRESUME' && "$_console_yields" -eq $((yields_before + 1)) ]]; then
        bts_pass "error yields and prints on stderr"
    else
        bts_fail "logger stderr out='${out}' err='${err}' yield=${_console_yields}"
    fi

    yields_before="$_console_yields"
    info "hello-info" >"$out_file" 2>"$err_file"
    out=$(<"$out_file")
    err=$(<"$err_file")
    rm -f -- "$out_file" "$err_file"
    if [[ "$out" == "[INFO]  - hello-info" && -z "$err" && "$_console_yields" -eq "$yields_before" ]]; then
        bts_pass "info prints on stdout and does not yield"
    else
        bts_fail "logger stdout out='${out}' err='${err}' yield=${_console_yields}"
    fi
    taskCancel 2>/dev/null # drop the in-progress line

    yields_before="$_console_yields"
    unset -f taskYield
    rc=0
    out=${ console_writeErr "partition done" 2>&1; } || rc=$?
    if [[ "$rc" -eq 0 && "$out" == "partition done" && "$_console_yields" -eq "$yields_before" ]]; then
        bts_pass "missing taskYield prints stderr and returns 0"
    else
        bts_fail "missing taskYield rc=${rc} out='${out}' yield=${_console_yields}"
    fi
}
