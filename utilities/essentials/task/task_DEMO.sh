#!/usr/bin/env bash
# ==================================================================================================
# Thundercast - Bash Essentials - Task demo (interactive)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-20 | Modified: 2026-09-20
# ==================================================================================================
#
# Run, do not source:
#   bash utilities/essentials/task/task_DEMO.sh
#
# Walks the public task API on a real TTY. Ctrl+C must abort (exit 130).
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
    logdir="${TMPDIR:-/tmp}/essentials-task-demo-logs"

    local -A essentials_config=(
        [SCRIPTINFO_DIR]="${src}"
        [SCRIPTINFO_NAME]="Essentials Task Demo"
        [SCRIPTINFO_VERSION]="${version}"
        [LOG_ROOT]="${logdir}"
        [LOG_PURGE]="true"
        [LOG_MINLEVEL]="info"
        [LOG_STDERRLEVEL]="warn"
        [LOG_INDENT]="2"
        [LOG_COLOR]="true"
        [LOG_COMPOSE_FILENAME]="demo.log"
        [TRAP_PRESETS]="true"
        [ROOTREEXEC_ROOT]="false"
        [RUNTIME_PREFIX]="taskdemo"
        [RUNTIME_SUBDIRS]="scratch"
        [RUNTIME_PURGE_STALE]="true"
        [UI_MODE]="auto"
        [UI_NO_CLEAR]="false"
        [UI_NO_PAUSE]="false"
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
    tty_restore
    runtime_purgeAll || true
}

_demo_watch() {
    local pid
    ui_section "1/3 — watch + ok"
    ui_b "Foreground watch. Ctrl+C must abort the script."
    ui_b ""
    taskStart "Pretend work"
    sleep 1.2 &
    pid=$!
    taskWatch "$pid"
    wait "$pid" || true
    taskOk
    ui_b ""
    prompt --type pause "Press Enter"
}

_demo_spin() {
    ui_section "2/3 — spin / yield / resume / fail"
    ui_b "Background spinner. Yield vacates the CR line; resume redraws it."
    ui_b ""
    taskSpin "Yield demo"
    sleep 1
    taskYield
    ui_b "(yield — this line printed through the task)"
    taskResume
    sleep 1
    taskFail "Yield demo"
    ui_b ""
    prompt --type pause "Press Enter"
}

_demo_take() {
    ui_section "3/3 — ui.line.take + cancel"
    ui_b "A hanging task. Prompt fires ui.line.take — the spinner must leave the line."
    ui_b "Name stays; we cancel after."
    ui_b ""
    taskSpin "Hanging"
    sleep 0.8
    prompt --type pause "Press Enter (task is still open)"
    taskCancel
    ui_b "Cancelled — no OK/FAIL."
    ui_b ""
    prompt --type pause "Demo finished — Press Enter to exit"
}

main() {
    [[ -c /dev/tty && -r /dev/tty && -w /dev/tty ]] || {
        echo "Need a controlling TTY. Run from a terminal, not a pipe." >&2
        exit 1
    }

    _demo_load
    trapRegister INT taskOnInt
    eventRegister exitClean _demo_cleanup 90
    eventRegister exitError _demo_cleanup 90
    tty_guardEnable

    _demo_watch
    _demo_spin
    _demo_take
}

main "$@"
