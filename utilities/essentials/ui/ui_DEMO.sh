#!/usr/bin/env bash
# ==================================================================================================
# Thundercast - Bash Essentials - UI demo (interactive)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-18 | Modified: 2026-09-20
# ==================================================================================================
#
# Run, do not source:
#   bash utilities/essentials/ui/ui_DEMO.sh
#
# Walks the format toolkit on a real TTY. Step: task/task_DEMO.sh.
# Prompt: prompt/prompt_DEMO.sh. Does not re-exec as root.
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
    logdir="${TMPDIR:-/tmp}/essentials-ui-demo-logs"

    local -A essentials_config=(
        [SCRIPTINFO_DIR]="${src}"
        [SCRIPTINFO_NAME]="Essentials UI Demo"
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
        [RUNTIME_PREFIX]="uidemo"
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

main() {
    local yes no
    local -a items=(Alpha Beta Gamma)

    [[ -c /dev/tty && -r /dev/tty && -w /dev/tty ]] || {
        echo "Need a controlling TTY. Run from a terminal, not a pipe." >&2
        exit 1
    }

    _demo_load
    trapRegister INT taskOnInt
    eventRegister exitClean _demo_cleanup 90
    eventRegister exitError _demo_cleanup 90
    tty_guardEnable

    ui_section "layout"
    ui_h "Heading"
    ui_b "Body line"
    ui_i "Inner line"
    ui_warn "Warning (orange when color is on)"
    ui_b ""
    yes=${ ui_formatBool true; }
    no=${ ui_formatBool false; }
    ui_kv "Script" "${ scriptInfo_get_name; }"
    ui_kv "Version" "${ scriptInfo_get_version; }"
    ui_kv "Runtime" "${ runtime_getDir; }"
    ui_kv "Bool true" "$yes"
    ui_kv "Bool false" "$no"
    ui_b ""
    ui_indentPush
    ui_b "Indented once"
    ui_indentPop
    ui_b ""
    ui_b "Menu rows are layout only — input is prompt/prompt_DEMO.sh."
    ui_printMenu items true
    ui_b ""
    prompt --type pause "Demo finished — Press Enter to exit"
}

main "$@"
