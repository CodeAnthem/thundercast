#!/usr/bin/env bash
# ==================================================================================================
# Thundercast - Bash Essentials - Prompt demo (interactive)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-20 | Modified: 2026-09-21
# ==================================================================================================
#
# Run, do not source:
#   bash utilities/essentials/prompt/prompt_DEMO.sh
#
# Walks every public prompt type on a real TTY. Does not re-exec as root.
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
    logdir="${TMPDIR:-/tmp}/essentials-prompt-demo-logs"

    local -A essentials_config=(
        [SCRIPTINFO_DIR]="${src}"
        [SCRIPTINFO_NAME]="Essentials Prompt Demo"
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
        [RUNTIME_PREFIX]="promptdemo"
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
    _essentials_loadModules || {
        echo "Failed to load essentials modules" >&2
        exit 1
    }
}

_demo_cleanup() {
    taskCancel
    tty_restore
    runtime_purgeAll || true
}

_demo_show() {
    ui_b "→ status=${1}  action=${UI_PROMPT_ACTION}  value=${UI_PROMPT_RESULT}"
    ui_b ""
}

_demo_confirm() {
    local rc=0
    ui_section "1/4 — confirm"
    ui_b "Try y, n, and b. Paste is rejected (type one key). No is still success."
    ui_b ""
    rc=0
    prompt --type confirm --default y "Use the default (Enter = yes)?" || rc=$?
    _demo_show "$rc"
    rc=0
    prompt --type confirm -b "Proceed with back enabled?" || rc=$?
    _demo_show "$rc"
}

_demo_pick() {
    local rc=0
    local i
    local -a items=('first|First' 'second|Second' 'third|Third')
    local -a feats=('git|Git' 'docker|Docker' 'k8s|Kubernetes')
    local -a pre=('git' 'docker')
    local -a many=()
    for ((i = 1; i <= 12; i++)); do
        many+=("item${i}|Item ${i}")
    done
    ui_section "2/4 — select / multi-select / text / key"
    rc=0
    prompt --type select --options items -b "Choice" || rc=$?
    _demo_show "$rc"
    ui_b "12 items: 1-9 jump the first nine. Item 10+ is arrows + Enter only."
    ui_b ""
    rc=0
    prompt --type select --options many -b "Long list" || rc=$?
    _demo_show "$rc"
    rc=0
    prompt --type multi-select --options feats --selected pre -b "Features" || rc=$?
    _demo_show "$rc"
    rc=0
    prompt --type text --default demo-host "Hostname" || rc=$?
    _demo_show "$rc"
    rc=0
    prompt --type text --hide --allow-empty "Hidden line (empty is ok)" || rc=$?
    _demo_show "$rc"
    rc=0
    prompt --type key "Press any single key" || rc=$?
    _demo_show "$rc"
}

_demo_block() {
    local rc=0
    ui_section "3/4 — multiline"
    ui_b "Block input is hidden. End a paste with a line that is only a period."
    ui_b ""
    rc=0
    prompt --type confirm --default n "Try a hidden multiline paste?" || rc=$?
    if [[ "$rc" -eq 0 && "$UI_PROMPT_RESULT" == y ]]; then
        rc=0
        prompt --type multiline --hide --end . "Paste a few lines (end with a lone period)" || rc=$?
        _demo_show "$rc"
        if [[ -n "${UI_PROMPT_RESULT}" ]]; then
            ui_i "First line: ${UI_PROMPT_RESULT%%$'\n'*}"
            ui_b ""
        fi
    else
        ui_b "Skipped block."
        ui_b ""
    fi
}

_demo_idle() {
    ui_section "4/4 — idle + pause"
    ui_b "Mash keys for two seconds. The guard is idle — they must not appear."
    sleep 2
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

    _demo_confirm
    _demo_pick
    _demo_block
    _demo_idle
}

main "$@"
