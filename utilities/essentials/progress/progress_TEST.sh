#!/usr/bin/env bash
# ==================================================================================================
# Thundercast - Bash Essentials - Progress tests
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-21 | Modified: 2026-09-21
# ==================================================================================================

# shellcheck source=../testEnvironment/testEnvironment.sh
source "$(dirname "${BASH_SOURCE[0]}")/../testEnvironment/testEnvironment.sh"

suite_progress() {
    local out tmp err rc
    local -a lines

    essentials_test_load progress

    bts_section "Render"

    lines=(
        "${ progress_render 3 10 30 "Lbl"; }"
        "${ progress_render -c 37 120 40 "Copy"; }"
        "${ progress_render 0 0 20; }"
        "${ progress_render 5 5 8; }"
        "${ progress_render 12 10 20; }"
        "${ progress_render -3 10 20; }"
    )
    if [[ "${lines[0]}" == "Lbl [#####--------------]  30%" \
        && "${lines[1]}" == "Copy [######---------------] 37/120  30%" \
        && "${lines[2]}" == "[-------------]   0%" \
        && "${lines[3]}" == "[#] 100%" \
        && "${lines[4]}" == "[#############] 100%" \
        && "${lines[5]}" == "[-------------]   0%" ]]; then
        bts_pass "render: label, counter, zero max, tiny width, clamp above max and below 0"
    else
        bts_fail "render $(printf '[%s] ' "${lines[@]}")"
    fi

    for out in "${lines[@]}"; do
        (( ${#out} == 30 || ${#out} == 40 || ${#out} == 20 || ${#out} == 8 )) || break
    done
    if (( ${#lines[0]} == 30 && ${#lines[1]} == 40 && ${#lines[2]} == 20 && ${#lines[3]} == 8 )); then
        bts_pass "render is exactly the requested width"
    else
        bts_fail "widths ${#lines[0]} ${#lines[1]} ${#lines[2]} ${#lines[3]}"
    fi

    out=${ progress_render 1 2 4 "A long label"; }
    if [[ "$out" == "A lo" ]]; then
        bts_pass "no room for a bar → clipped text, never wider than width"
    else
        bts_fail "clip $(printf '%q' "$out")"
    fi

    bts_section "Inline"

    tmp="$(mktemp)"
    _progressTty() { return 0; }
    {
        progress_begin 4 "Files"
        progress_set 1
        progress_set 1
        progress_set 2 "Files (2)"
        progress_end
    } 2>"$tmp"
    err="$(cat "$tmp"; printf x)"
    err="${err%x}"
    if [[ "$err" == $'\r\033[K'*"Files ["*"0/4   0%"$'\r\033[K'*"1/4  25%"$'\r\033[K'*"Files (2) ["*"2/4  50%"$'\r\033[K'*"4/4 100%"$'\n' ]] && ! progress_isOpen; then
        bts_pass "begin/set/end: CR line, same value is not redrawn, label change redraws, end at 100 %"
    else
        bts_fail "inline $(printf '%q' "$err") open=${__PROGRESS_OPEN}"
    fi

    {
        progress_begin 3
        progress_yield
        progress_set 1
        progress_cancel
    } 2>"$tmp"
    err="$(<"$tmp")"
    if [[ "$err" == *$'\r\033[K\r\033[K'*"1/3"*$'\r\033[K' && "$err" != *$'\n'* ]] && ! progress_isOpen; then
        bts_pass "yield vacates the line, next set redraws, cancel leaves no final line"
    else
        bts_fail "yield/cancel $(printf '%q' "$err")"
    fi

    _progressTty() { return 1; }
    {
        progress_begin 2 "Quiet"
        progress_set 1
        progress_end
    } 2>"$tmp"
    err="$(cat "$tmp"; printf x)"
    err="${err%x}"
    if [[ "$err" == "  Quiet ["*"2/2 100%"$'\n' ]]; then
        bts_pass "non-TTY prints only the final line"
    else
        bts_fail "non-tty $(printf '%q' "$err")"
    fi
    unset -f _progressTty

    rc=0
    progress_begin abc 2>"$tmp" || rc=$?
    if (( rc == 1 )) && ! progress_isOpen && [[ "$(<"$tmp")" == *"must be a number"* ]]; then
        bts_pass "begin with a bad max is an error"
    else
        bts_fail "bad max rc=$rc open=${__PROGRESS_OPEN}"
    fi
    rm -f "$tmp"

    progress_set 1 2>/dev/null
    progress_end 2>/dev/null
    if ! progress_isOpen; then
        bts_pass "set/end without begin are no-ops"
    else
        bts_fail "open without begin"
    fi
}
