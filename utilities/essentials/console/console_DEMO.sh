#!/usr/bin/env bash
# ==================================================================================================
# Thundercast - Bash Essentials - Console demo (task + logger)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-28 | Modified: 2026-09-28
# Description:   Opens one task and logs through it. No install, disk, or network.
# ==================================================================================================
#
# Run, do not source:
#   bash /home/averon/_repos/thundercast/utilities/essentials/console/console_DEMO.sh
#
# Chrome joins stdout onto stderr, which is the VM case. A working yield prints
# each log on its own line, then redraws [   ] Disk. A broken yield glues it on.
#
# ==================================================================================================
set -euo pipefail

if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    echo "Run this script, do not source it." >&2
    return 1
fi

_demo_load() {
    local demo_dir essentials src
    demo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)" || exit 1
    essentials="$(cd -- "${demo_dir}/.." && pwd -P)" || exit 1
    src="$(cd -- "${essentials}/../../nds/src" && pwd -P)" || exit 1

    declare -gA essentials_config=(
        [SCRIPTINFO_DIR]="${src}"
        [SCRIPTINFO_NAME]="Task logger demo"
        [SCRIPTINFO_VERSION]="$(< "${src}/VERSION")"
        [LOG_ROOT]="${TMPDIR:-/tmp}/essentials-console-demo-logs"
        [LOG_PURGE]="true"
        [LOG_MINLEVEL]="verbose"
        [LOG_STDERRLEVEL]="warn"
        [LOG_INDENT]="2"
        [LOG_COLOR]="true"
        [LOG_COMPOSE_FILENAME]="demo.log"
        [ROOTREEXEC_ROOT]="false"
        [TRAP_PRESETS]="true"
        [RUNTIME_PREFIX]="consoledemo"
        [RUNTIME_SUBDIRS]="scratch"
        [RUNTIME_PURGE_STALE]="true"
        [UI_MODE]="auto"
    )

    # shellcheck source=../essentials.sh
    source "${essentials}/essentials.sh"
    essentials_init
}

main() {
    [[ -c /dev/tty && -r /dev/tty && -w /dev/tty ]] || {
        echo "Need a terminal. Run it in a tty, not a pipe." >&2
        exit 1
    }

    _demo_load
    tty_guardEnable
    logger_scopeCreate "Demo" demo
    logger_scopeSet demo
    chrome_begin "unattended"

    info "stdout is a tty: $([[ -t 1 ]] && echo yes || echo no)"
    info "stderr is a tty: $([[ -t 2 ]] && echo yes || echo no)"

    taskSpin "Disk"
    sleep 1
    warn "Unmounting leftover /mnt"
    sleep 1
    info "Disk /dev/sda, strategy nds"
    sleep 1
    debug "Target root /mnt"
    sleep 1
    verbose "Partitioning disk: /dev/sda"
    sleep 1
    taskOk "Disk"
    prompt --type pause "Press Enter to close"
}

main "$@"
