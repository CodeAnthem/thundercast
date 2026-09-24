#!/usr/bin/env bash
# ==================================================================================================
# Thundercast - Bash Essentials - Chrome demo (interactive)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-21 | Modified: 2026-09-21
# ==================================================================================================
#
# Run, do not source:
#   bash utilities/essentials/chrome/chrome_DEMO.sh
#
# Header/footer stay put. Body is logger + ui + task + prompt.
# Does not re-exec as root.
#
# ==================================================================================================
set -euo pipefail

if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    echo "Run this script, do not source it." >&2
    return 1
fi

_demo_load() {
    local demo_dir essentials src version logdir
    demo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)" || exit 1
    essentials="$(cd -- "${demo_dir}/.." && pwd -P)" || exit 1
    src="$(cd -- "${essentials}/../../nds/src" && pwd -P)" || exit 1
    version="$(< "${src}/VERSION")"
    logdir="${TMPDIR:-/tmp}/essentials-chrome-demo-logs"

    local -A essentials_config=(
        [SCRIPTINFO_DIR]="${src}"
        [SCRIPTINFO_NAME]="Essentials Chrome Demo"
        [SCRIPTINFO_VERSION]="${version}"
        [LOG_ROOT]="${logdir}"
        [LOG_PURGE]="true"
        [LOG_MINLEVEL]="info"
        [LOG_STDERRLEVEL]="info"
        [LOG_INDENT]="2"
        [LOG_COLOR]="true"
        [LOG_COMPOSE_FILENAME]="demo.log"
        [TRAP_PRESETS]="true"
        [ROOTREEXEC_ROOT]="false"
        [RUNTIME_PREFIX]="chromedemo"
        [RUNTIME_SUBDIRS]="scratch"
        [RUNTIME_PURGE_STALE]="true"
        [UI_MODE]="auto"
        [UI_NO_CLEAR]="false"
        [UI_NO_PAUSE]="false"
        [CHROME_HEADER_BG]="blue"
        [CHROME_HEADER_FG]="white"
        [CHROME_FOOTER_BG]="blue"
        [CHROME_FOOTER_FG]="white"
    )

    # shellcheck source=../essentials.sh
    source "${essentials}/essentials.sh" || {
        echo "Failed to source essentials.sh" >&2
        exit 1
    }
    essentials_loadEssentials || {
        echo "Failed to load essentials modules" >&2
        exit 1
    }
}

_demo_cleanup() {
    taskCancel
    chrome_end
    tty_restore
    runtime_purgeAll || true
}

main() {
    local rc=0 i
    local -a items=('one|One' 'two|Two' 'three|Three')
    local -a feats=('a|Alpha' 'b|Beta' 'c|Gamma')

    [[ -c /dev/tty && -r /dev/tty && -w /dev/tty ]] || {
        echo "Need a controlling TTY. Run from a terminal, not a pipe." >&2
        exit 1
    }

    _demo_load
    trapRegister INT taskOnInt
    eventRegister exitClean _demo_cleanup 90
    eventRegister exitError _demo_cleanup 90
    tty_guardEnable
    chrome_begin "Start"
    chrome_setFooter 0 "Header/footer are bars. Body starts at the top."

    ui_section "Logger + UI"
    info "This info line is in the scrollable body."
    ui_b "ui_b starts under the header, not on the footer."
    ui_kv "Mode" "chrome"
    ui_kv "Cols" "${ chrome_getCols; }"
    ui_kv "Body rows" "${ chrome_getBodyRows; }"
    for ((i = 1; i <= 30; i++)); do
        ui_i "scroll line ${i} — fills the body, then scrolls under the header"
    done
    echo "stdout line — captured too, stays in history"

    ui_section "Footer widgets"
    chrome_setFooterRows 5
    chrome_setFooter 0 -t sep -c "─"
    chrome_setFooter 1 -a left "Current file:" -r "0/12"
    chrome_setFooter 2 -t progress -m 12 -v 0 "Copy"
    chrome_setFooter 3 -t hint "PgUp/PgDn/Wheel: history" "Home/End: oldest/live" "Esc: cancel"
    chrome_setFooter 4 -t spacer
    ui_b "Footer grew to 5 rows: sep, info + right slot, progress, hint, spacer."
    for ((i = 1; i <= 12; i++)); do
        chrome_setFooter 1 "Current file: part-${i}.img" -r "${i}/12"
        chrome_setFooter 2 -v "$i"
        ui_i "copied part-${i}.img"
        sleep 0.15
    done

    ui_section "Header rows"
    chrome_setHeaderRows 3
    chrome_setHeader 1 "Centered subtitle" -a center
    chrome_setHeader 2 -t sep -c "═" -b 27
    ui_b "Header is 3 rows now: title, centered subtitle, separator in colour 27."
    ui_b "Resize the window: everything is redrawn from history, bars re-fit."

    ui_section "Task"
    chrome_setFooterRows 2
    chrome_setFooter 0 -t text "Footer back to 2 rows. Spinner must not touch it."
    chrome_setFooter 1 -t hint "PgUp/PgDn: history" "Esc: cancel"
    taskSpin "Pretend work"
    sleep 2
    taskOk

    ui_section "Inline progress"
    ui_b "progress_begin/set/end is its own feature — same line style as task."
    progress_begin 20 "Verify"
    for ((i = 1; i <= 20; i++)); do
        progress_set "$i"
        sleep 0.05
    done
    progress_end

    ui_section "Prompt"
    chrome_setFooter 0 "Wheel / PageUp / PageDown / Home / End scroll history. Bars stay. Esc cancels."
    prompt --type confirm --default y "Does the header stay put?" || rc=$?
    ui_b "confirm rc=${rc} value=${UI_PROMPT_RESULT}"
    rc=0
    chrome_setSubtitle "Select a choice"
    prompt --type select --options items -b "Choice" || rc=$?
    ui_b "select rc=${rc} value=${UI_PROMPT_RESULT}"
    rc=0
    prompt --type multi-select --options feats -b "Features" || rc=$?
    ui_b "multi rc=${rc} value=${UI_PROMPT_RESULT}"
    rc=0

    ui_section "Suspend / run"
    chrome_setFooter 0 "chrome_run leaves the frame for an external program and comes back."
    prompt --type confirm --default n "Run 'less' outside the frame? (q to return)" || rc=$?
    if [[ "${UI_PROMPT_RESULT}" == y ]]; then
        chrome_run less "${BASH_SOURCE[0]}" || true
        ui_b "Back in the frame. History is intact — PageUp to check."
    fi
    rc=0

    chrome_setFooter 0 "Demo finished — PageUp here still scrolls; Enter leaves chrome."
    prompt --type pause "Press Enter to leave chrome"
}

main "$@"
