#!/usr/bin/env bash
# ==================================================================================================
# Thundercast - Bash Essentials - UI tests
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-17 | Modified: 2026-09-20
# ==================================================================================================

# shellcheck source=../testEnvironment/testEnvironment.sh
source "$(dirname "${BASH_SOURCE[0]}")/../testEnvironment/testEnvironment.sh"

suite_ui() {
    local out tmp

    essentials_test_load ui

    tmp=$(mktemp)
    {
        ui_h "HEAD"
        ui_indentPush ">>"
        ui_h "NEST"
        ui_indentPop
        ui_h "HEAD"
    } 2>"$tmp"
    if grep -q 'HEAD' "$tmp" && grep -q '>>' "$tmp"; then
        bts_pass "indent push/pop"
    else
        bts_fail "indent output $(printf '%q' "$(<"$tmp")")"
    fi
    rm -f "$tmp"

    out=${ ui_formatBool true; }
    if [[ "$out" == *yes* ]]; then
        bts_pass "formatBool true is yes"
    else
        bts_fail "formatBool true was '$out'"
    fi

    tmp=$(mktemp)
    out=${ scriptInfo_get_name; }
    { ui_banner "Sub"; } 2>"$tmp"
    if grep -q "$out" "$tmp" && grep -q 'Sub' "$tmp" && ! grep -q $'\033\[2J' "$tmp"; then
        bts_pass "banner uses scriptInfo, no clear"
    else
        bts_fail "banner $(printf '%q' "$(<"$tmp")")"
    fi
    rm -f "$tmp"

    tmp=$(mktemp)
    {
        local -a _menu_items=(Alpha)
        ui_printMenu _menu_items true
    } 2>"$tmp"
    if grep -q '1) Alpha' "$tmp" && grep -q '0) Back' "$tmp"; then
        one_lead=$(sed -n 's/^\([ ]*\)1) Alpha.*/\1/p' "$tmp" | head -1)
        back_lead=$(sed -n 's/^\([ ]*\)0) Back.*/\1/p' "$tmp" | head -1)
        if [[ "$one_lead" == "$back_lead" && -n "$one_lead" ]]; then
            bts_pass "printMenu Back matches choice indent"
        else
            bts_fail "Back indent mismatch $(printf '%q' "$(<"$tmp")")"
        fi
    else
        bts_fail "printMenu output $(printf '%q' "$(<"$tmp")")"
    fi
    rm -f "$tmp"

    if eventHas ui.line.take && eventHas ui.section.begin; then
        bts_pass "screen events exist"
    else
        bts_fail "screen events missing"
    fi
}
