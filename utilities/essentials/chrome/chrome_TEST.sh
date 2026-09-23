#!/usr/bin/env bash
# ==================================================================================================
# Thundercast - Bash Essentials - Chrome tests
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-21 | Modified: 2026-09-21
# ==================================================================================================

# shellcheck source=../testEnvironment/testEnvironment.sh
source "$(dirname "${BASH_SOURCE[0]}")/../testEnvironment/testEnvironment.sh"

# Fresh bash: fd 1/2 are replaced while the tee runs, which must not touch the runner's capture.
_chrome_isolated() {
    local rc=0
    __CHROME_ISOLATED_ERR=""
    __CHROME_ISOLATED_ERR=$(
        bash -c '
set -euo pipefail
source "$1/testEnvironment/testEnvironment.sh"
essentials_test_load chrome
eval "$2"
' _chrome_iso "$_ESSENTIALS_ROOT" "$1" 2>&1
    ) || rc=$?
    return "$rc"
}

# Fake "on" with chrome paints captured in a file, fixed 80x<lines>. Pair with _chrome_fakeOff.
_chrome_fakeOn() {
    __CHROME_FAKE_OUT="$(mktemp)"
    exec {__CHROME_TTY}>"$__CHROME_FAKE_OUT"
    __CHROME_ON=1
    __CHROME_FAKE_LINES="${1:-20}"
    _chrome_termSize() {
        __CHROME_LINES=$__CHROME_FAKE_LINES
        __CHROME_COLS=80
        _chrome_layoutRows
    }
    _chrome_termSize
    __CHROME_LOG_ROW=$__CHROME_BODY_TOP
    __CHROME_SCROLL=0
}

# Fresh capture file (truncating in place would leave the open fd's offset → NUL holes).
_chrome_fakeReset() {
    exec {__CHROME_TTY}>&-
    : > "$__CHROME_FAKE_OUT"
    exec {__CHROME_TTY}>"$__CHROME_FAKE_OUT"
}

_chrome_fakeOff() {
    __CHROME_ON=0
    exec {__CHROME_TTY}>&-
    __CHROME_TTY=""
    __CHROME_HIST_PATH=""
    __CHROME_SCROLL=0
    rm -f "$__CHROME_FAKE_OUT"
    __CHROME_FAKE_OUT=""
    unset -f _chrome_cursorRow
    # shellcheck source=./chrome_layout.sh
    source "${_ESSENTIALS_ROOT}/chrome/chrome_layout.sh"
    __CHROME_HEADER_ROWS=2
    __CHROME_FOOTER_ROWS=1
    _chrome_barsInit
}

# Tee round trip: partial lines show at once and are mirrored, history holds filtered complete
# lines, markers never reach the screen, chrome_clear starts the live view, suspend keeps history.
_chrome_teeScript='
out=$(mktemp)
exec {fd}>"$out"
__CHROME_TTY=$fd
__CHROME_ON=1
_chrome_termSize() { __CHROME_LINES=8; __CHROME_COLS=40; _chrome_layoutRows; }
_chrome_captureStdout() { return 0; }
_chrome_termSize
_chrome_histStart
printf "label: " >&2
_chrome_sync
[[ "$(<"$out")" == "label: " ]] || { echo "partial not forwarded: $(printf %q "$(<"$out")")"; exit 2; }
[[ ! -s "$__CHROME_HIST_PATH" ]] || { echo "partial recorded early"; exit 3; }
[[ "$(<"${__CHROME_HIST_PATH}.partial")" == "label: " ]] || { echo "partial not mirrored"; exit 12; }
printf "Yes\n" >&2
printf "\033[?25l  \033[7m 1. One \033[0m\n  2. Two\n" >&2
printf "\033[2A  1. One\n\033[7m  2. Two \033[0m\n" >&2
printf "\r\033[K[|] spin\r\033[K[OK] done\n" >&2
printf "abc\b \bd\n" >&2
echo "stdout line"
chrome_clear
printf "after\n" >&2
_chrome_sync
[[ ! -s "${__CHROME_HIST_PATH}.partial" ]] || { echo "partial mirror not cleared"; exit 13; }
mapfile -t hist < "$__CHROME_HIST_PATH"
want=("label: Yes" "  1. One" $'"'"'\033[7m  2. Two \033[0m'"'"' "[OK] done" "abd" "stdout line" "$__CHROME_MARK_CLEAR" "after")
[[ "${hist[*]}" == "${want[*]}" ]] || { echo "hist: $(printf "%q " "${hist[@]}")"; exit 4; }
_chrome_histLoad
[[ "${#__CHROME_VIEW[@]}" == 7 && "$__CHROME_VIEW_BASE" == 6 ]] || { echo "view=${#__CHROME_VIEW[@]} base=$__CHROME_VIEW_BASE"; exit 5; }
chrome_scrollUp 99
[[ "$__CHROME_SCROLL" == 6 ]] || { echo "scroll after clear: $__CHROME_SCROLL"; exit 6; }
[[ "$(<"$out")" == *"[history -6]"* ]] || { echo "no history indicator"; exit 14; }
chrome_follow
[[ "$__CHROME_SCROLL" == 0 ]] || { echo "follow: $__CHROME_SCROLL"; exit 7; }
printf "pending " >&2
_chrome_sync
exec {fd}>&-; exec {fd}>"$out"; __CHROME_TTY=$fd
_chrome_redraw
[[ "$(<"$out")" == *$'"'"'\033[2J'"'"'* && "$(<"$out")" == *"after"*"pending "* ]] || { echo "redraw: $(printf %q "$(<"$out")")"; exit 15; }
hist_path=$__CHROME_HIST_PATH
chrome_suspend
[[ -e "$hist_path" && ! -e "${hist_path}.ack" && "$__CHROME_ON" == 0 ]] || { echo "suspend lost hist"; exit 16; }
chrome_isSuspended || { echo "not suspended"; exit 17; }
printf "outside\n" >&2
chrome_resume
on=$__CHROME_ON
path=$__CHROME_HIST_PATH
printf "back\n" >&2
_chrome_sync
mapfile -t hist < "$__CHROME_HIST_PATH"
chrome_end
[[ "$on" == 1 ]] || { echo "resume off"; exit 18; }
[[ "$path" == "$hist_path" ]] || { echo "resume new hist"; exit 19; }
[[ "${hist[-1]}" == "back" && "${hist[-2]}" == "pending " && "${hist[-3]}" == "after" ]] || { echo "resume hist: $(printf "%q " "${hist[@]}")"; exit 20; }
[[ ! -e "$hist_path" && ! -e "${hist_path}.ack" && ! -e "${hist_path}.partial" ]] || { echo "hist files left"; exit 8; }
[[ "$(<"$out")" != *$'"'"'\001'"'"'* ]] || { echo "marker reached the tty"; exit 9; }
[[ "$(<"$out")" == *$'"'"'\033[?1049l'"'"'* ]] || { echo "no leave: $(printf %q "$(<"$out")")"; exit 10; }
[[ "$(<"$out")" != *"outside"* ]] || { echo "suspended output went to chrome tty"; exit 11; }
rm -f "$out"
'

suite_chrome() {
    local rc found f err tmp
    local -a lines

    essentials_test_load chrome

    # --- Off is the contract ---
    bts_section "Off"

    if ! chrome_isOn; then
        bts_pass "off on load"
    else
        bts_fail "chrome was on after load"
    fi

    chrome_end
    chrome_end
    if ! chrome_isOn; then
        bts_pass "chrome_end twice is ok"
    else
        bts_fail "on after double end"
    fi

    tmp="$(mktemp)"
    {
        chrome_setSubtitle "x"
        chrome_setFooter 0 "y"
        chrome_setHeader 0 -a center
        chrome_setFooterRows 3
        chrome_setFooterRows 1
        chrome_repin
        chrome_redraw
        chrome_clear
        chrome_home
        chrome_clearLine
        chrome_clearLines 3
        chrome_clearToEnd
        chrome_scrollUp
        chrome_scrollDown
        chrome_follow
        chrome_setMouse off
        chrome_suspend
        chrome_resume
        chrome_tempBegin
        chrome_tempEnd
    } 2>"$tmp"
    if ! chrome_isOn && ! chrome_isTemp && ! chrome_isSuspended && [[ ! -s "$tmp" ]]; then
        bts_pass "public API is silent no-op when off"
    else
        bts_fail "off API wrote $(printf '%q' "$(<"$tmp")") on=${__CHROME_ON} temp=${__CHROME_TEMP}"
    fi
    rm -f "$tmp"

    if [[ "${__CHROME_FOOTER[0.text]}" == y && "${__CHROME_HEADER[1.text]}" == x ]]; then
        bts_pass "row content is stored while off and painted at begin"
    else
        bts_fail "off rows footer=${__CHROME_FOOTER[0.text]} header=${__CHROME_HEADER[1.text]}"
    fi
    _chrome_barsInit

    rc=0
    _chrome_isolated '
tty_ok() { return 1; }
chrome_begin "Disk"
[[ "${__CHROME_ON}" == 0 ]]
' || rc=$?
    if (( rc == 0 )); then
        bts_pass "begin without TTY stays off"
    else
        bts_fail "begin no-tty rc=$rc err=$(printf '%q' "${__CHROME_ISOLATED_ERR}")"
    fi

    rc=0
    _chrome_isolated '
n=0
hit() { n=$((n + 1)); }
chrome_run hit
[[ "$n" == 1 ]] || exit 2
chrome_run false && exit 3
chrome_run
' || rc=$?
    if (( rc == 0 )); then
        bts_pass "chrome_run off: runs the command, returns its rc"
    else
        bts_fail "chrome_run off rc=$rc err=$(printf '%q' "${__CHROME_ISOLATED_ERR}")"
    fi

    found=0
    if declare -p __EH_FUNC &>/dev/null; then
        for f in "${__EH_FUNC[@]}"; do
            [[ "$f" == chrome_end ]] && found=1
        done
    fi
    if (( found )); then
        bts_pass "chrome_end registered on exit"
    else
        bts_fail "chrome_end missing from event bus"
    fi

    # --- Bars: row model ---
    bts_section "Bars"

    _chrome_fakeOn 12
    __CHROME_COLS=40
    chrome_setFooterRows 5 2>/dev/null
    lines=("$__CHROME_BODY_TOP" "$__CHROME_BODY_BOT" "$__CHROME_HEADER_SHOW" "$__CHROME_FOOTER_SHOW")
    if [[ "${lines[*]}" == "3 7 2 5" ]]; then
        bts_pass "setFooterRows moves the body bottom"
    else
        bts_fail "rows 5 → top/bot/hs/fs were '${lines[*]}' (want 3 7 2 5)"
    fi

    __CHROME_COLS=40
    chrome_setFooter 0 -t sep -c "="
    chrome_setFooter 1 "Processing: file.txt" -r "3/9"
    chrome_setFooter 2 -t progress -v 37 -m 120 "Copy"
    chrome_setFooter 3 -t hint "Enter:ok" "Esc:cancel" "PgUp:scroll"
    chrome_setFooter 4 -t spacer
    chrome_setHeader 1 "Centered" -a center -f white -b 27
    __CHROME_COLS=40
    lines=()
    for f in 0 1 2 3 4; do lines+=("${ _chrome_rowText footer "$f"; }"); done
    lines+=("${ _chrome_rowText header 1; }")
    if [[ "${lines[0]}" == "$(printf '%040d' 0 | tr 0 =)" \
        && "${lines[1]}" == "Processing: file.txt                 3/9" \
        && "${lines[2]}" == "Copy [######---------------] 37/120  30%" \
        && "${lines[3]}" == "Enter:ok      Esc:cancel     PgUp:scroll" \
        && "${lines[4]}" == "$(printf '%40s' '')" \
        && "${lines[5]}" == "                Centered                " ]]; then
        bts_pass "sep / text+right / progress / hint / spacer / centered text fill exactly COLS"
    else
        bts_fail "row texts $(printf '[%s] ' "${lines[@]}")"
    fi

    err=${ _chrome_rowSgr header 1; }
    f=${ _chrome_rowSgr footer 0; }
    if [[ "$err" == $'\033[37;48;5;27m' && "$f" == $'\033[7m' ]]; then
        bts_pass "row colours: named + 256 index → SGR, none → reverse"
    else
        bts_fail "sgr header=$(printf '%q' "$err") footer=$(printf '%q' "$f")"
    fi

    __CHROME_SCROLL=7
    err=${ _chrome_rowText header 0; }
    __CHROME_SCROLL=0
    if [[ "$err" == *"Essentials Test"* && "$err" == *"[history -7]" ]]; then
        bts_pass "title row shows the history indicator while scrolled"
    else
        bts_fail "title row $(printf '%q' "$err")"
    fi

    tmp="$(mktemp)"
    rc=0
    chrome_setFooter 9 x 2>"$tmp" || rc=$?
    chrome_setFooter 1 -t bogus 2>>"$tmp" || rc=$((rc + 10))
    chrome_setFooter 1 -a middle 2>>"$tmp" || rc=$((rc + 100))
    chrome_setFooterRows 21 2>>"$tmp" || rc=$((rc + 1000))
    err="$(<"$tmp")"
    rm -f "$tmp"
    if [[ "$rc" == 1111 && "$err" == *"out of range"* && "$err" == *"unknown row type"* && "$err" == *"bad alignment"* && "$err" == *"0-20"* && "${__CHROME_FOOTER[1.type]:-text}" == text && "$__CHROME_FOOTER_ROWS" == 5 ]]; then
        bts_pass "bad row index / type / alignment / count are errors and leave the row alone"
    else
        bts_fail "row validation rc=$rc err=$(printf '%q' "$err") type=${__CHROME_FOOTER[1.type]:-text} rows=${__CHROME_FOOTER_ROWS}"
    fi

    _chrome_fakeReset
    chrome_setFooter 2 -v 60
    err="$(<"$__CHROME_FAKE_OUT")"
    if [[ "$err" == $'\0337\033[10;1H\033[7m'*"60/120  50%"$'\033[0m\0338' && "${__CHROME_FOOTER[2.text]}" == Copy ]]; then
        bts_pass "setFooter while on repaints that row only, cursor saved/restored"
    else
        bts_fail "row paint $(printf '%q' "$err")"
    fi

    __CHROME_FAKE_LINES=6
    _chrome_termSize
    lines=("$__CHROME_BODY_TOP" "$__CHROME_BODY_BOT" "$__CHROME_HEADER_SHOW" "$__CHROME_FOOTER_SHOW")
    __CHROME_FAKE_LINES=7
    _chrome_termSize
    lines+=("$__CHROME_HEADER_SHOW" "$__CHROME_FOOTER_SHOW")
    if [[ "${lines[*]}" == "3 5 2 1 2 2" ]]; then
        bts_pass "small terminal: body keeps 3 rows, footer gives way first, then header"
    else
        bts_fail "small layout '${lines[*]}' (want 3 5 2 1 2 2)"
    fi
    _chrome_fakeOff

    # --- Body erase (bars stay) ---
    bts_section "Body"

    _chrome_fakeOn 20
    __UI_NO_CLEAR=false
    chrome_setSubtitle "Start"
    tmp="$(mktemp)"
    ui_section "Layout" 2>"$tmp"
    __UI_NO_CLEAR=true
    err="$(<"$tmp")"
    rm -f "$tmp"
    if [[ "$err" == *'Layout'* && "$err" == *'==='* && "$err" != *$'\033[2J'* && "$(<"$__CHROME_FAKE_OUT")" != *$'\033[2J'* && "${__CHROME_HEADER[1.text]}" == Start && "$__CHROME_LOG_ROW" == 3 ]]; then
        bts_pass "ui_section on: body wipe + banner in body, subtitle untouched, no 2J"
    else
        bts_fail "section on: subtitle=${__CHROME_HEADER[1.text]} row=${__CHROME_LOG_ROW} err=$(printf '%q' "$err") tty=$(printf '%q' "$(<"$__CHROME_FAKE_OUT")")"
    fi

    __CHROME_LOG_ROW=12
    chrome_clear
    rc=$__CHROME_LOG_ROW
    _chrome_cursorRow() { printf 12; }
    chrome_clearLines 4
    f=$__CHROME_LOG_ROW
    _chrome_cursorRow() { printf 9; }
    chrome_clearToEnd
    err=$__CHROME_LOG_ROW
    _chrome_cursorRow() { printf 4; }
    chrome_clearLines 99
    found=$__CHROME_LOG_ROW
    chrome_clearLines x
    if [[ "$rc" == 3 && "$f" == 9 && "$err" == 9 && "$found" == 3 && "$(<"$__CHROME_FAKE_OUT")" != *$'\033[2J'* ]]; then
        bts_pass "clear / clearLines / clearToEnd park and clamp inside the body"
    else
        bts_fail "body erase rows clear=$rc lines=$f toEnd=$err clamp=$found"
    fi
    _chrome_fakeOff

    # --- History window (file + fake on, no tee) ---
    bts_section "History"

    _chrome_fakeOn 6
    __CHROME_HIST_PATH="$(mktemp)"
    printf '%s\n' 1 2 3 4 5 6 7 8 9 10 > "$__CHROME_HIST_PATH"
    lines=()
    chrome_scrollUp
    lines+=("$__CHROME_SCROLL")
    chrome_scrollUp 5
    lines+=("$__CHROME_SCROLL")
    chrome_scrollUp
    lines+=("$__CHROME_SCROLL")
    chrome_scrollDown 3
    lines+=("$__CHROME_SCROLL")
    chrome_scrollDown
    chrome_scrollDown
    chrome_scrollDown
    lines+=("$__CHROME_SCROLL")
    if [[ "${lines[*]}" == "2 7 8 5 0" ]]; then
        bts_pass "scrollUp / scrollDown page by view height and clamp to [0, lines - height]"
    else
        bts_fail "scroll offsets were '${lines[*]}' (want 2 7 8 5 0)"
    fi

    _chrome_fakeReset
    chrome_scrollUp 3
    err="$(<"$__CHROME_FAKE_OUT")"
    if [[ "$err" == *$'\033[3;1H6'* && "$err" == *$'\033[4;1H7'* && "$err" == *$'\033[5;1H\033[K\033[5;1H\033[?7h'* && "$err" == *"[history -3]"* && "$err" != *$'\033[2J'* && "$err" != *$'\033[r'* ]]; then
        bts_pass "render paints body rows + title indicator, cursor row kept free, no 2J / region reset"
    else
        bts_fail "render output $(printf '%q' "$err")"
    fi
    rm -f "$__CHROME_HIST_PATH"
    _chrome_fakeOff

    rc=0
    _chrome_isolated "$_chrome_teeScript" || rc=$?
    if (( rc == 0 )); then
        bts_pass "tee: partial mirror, stdout capture, filtered history, redraw, suspend/resume"
    else
        bts_fail "tee round trip rc=$rc err=$(printf '%q' "${__CHROME_ISOLATED_ERR}")"
    fi

    # --- Temp slot ---
    _chrome_fakeOn 20
    _chrome_cursorRow() { printf 12; }
    chrome_tempBegin
    rc=$__CHROME_TEMP_TOP
    f=$__CHROME_TEMP
    chrome_tempEnd
    if [[ "$rc" == 12 && "$f" == 1 && "$__CHROME_TEMP" == 0 && "$__CHROME_LOG_ROW" == 12 ]] && ! chrome_isTemp; then
        bts_pass "temp slot marks the row and erases mark to bottom"
    else
        bts_fail "temp slot top=$rc open=$f after=${__CHROME_TEMP} row=${__CHROME_LOG_ROW}"
    fi
    _chrome_fakeOff
}
