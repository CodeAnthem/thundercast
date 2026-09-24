#!/usr/bin/env bash
# ==================================================================================================
# Thundercast - Bash Essentials - Loader
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-06 | Modified: 2026-09-24
# ==================================================================================================

# Block Script Execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

# One store for feature init. A second source returns before repeating side effects.
# -g: this file is sourced from a function. Do not re-declare; that would wipe marks.
if ! declare -p __ESSENTIALS_INIT >/dev/null 2>&1; then
    declare -gA __ESSENTIALS_INIT=()
fi

_essentials_init_isDone() {
    [[ "${__ESSENTIALS_INIT[$1]:-}" == 1 ]]
}

_essentials_init_mark() {
    __ESSENTIALS_INIT[$1]=1
}

essentials_init() {
    local -a originalArgs=("$@")
    local current_dir
    current_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)" || exit 1

    _loadEssential() {
        local file=$1
        source "${current_dir}/${file}" && return 0
        echo "[Essentials] [FATAL] - Failed to source ${file}" >&2
        exit 1
    }

    # Order is dependency order. rootReexec may exec sudo and replace this
    # process, so only the version gate and the logger run before it. Traps
    # and everything below are installed on the process that continues.

    # Refuse an old Bash before any later file is parsed.
    # shellcheck source=./bashVersion/bashVersion.sh
    _loadEssential "bashVersion/bashVersion.sh"

    # No feature dependencies, so the re-exec path can already log.
    # Logger init leaves internal_compose current; the scope below replaces it.
    # shellcheck source=./logger/logger.sh
    _loadEssential "logger/logger.sh"
    logger_scopeCreate "Essentials Warm Up" "internal_essentials" || echo "Failed to create logger scope" >&2
    debug "Essentials Warm Up: logger scope created"

    # May exec and not return. Later modules do not exist on that path.
    # shellcheck source=./rootReexec/rootReexec.sh
    _loadEssential "rootReexec/rootReexec.sh"

    # Bus before anything that registers a hook. Traps do not survive the exec above.
    # shellcheck source=./eventBus/eventBus.sh
    _loadEssential "eventBus/eventBus.sh"

    # shellcheck source=./trapBridge/trapBridge.sh
    _loadEssential "trapBridge/trapBridge.sh"

    # Name, keyboard policy, and scratch dir. The screen features below read these.
    # shellcheck source=./scriptInfo/scriptInfo.sh
    _loadEssential "scriptInfo/scriptInfo.sh"

    # shellcheck source=./ttyHandler/ttyHandler.sh
    _loadEssential "ttyHandler/ttyHandler.sh"

    # shellcheck source=./sessionDir/sessionDir.sh
    _loadEssential "sessionDir/sessionDir.sh"

    # Format toolkit, then the bar, the frame, the task line, and prompts.
    # chrome needs ui, progress, and tty. prompt needs ui and tty.
    # shellcheck source=./ui/ui.sh
    _loadEssential "ui/ui.sh"

    # shellcheck source=./progress/progress.sh
    _loadEssential "progress/progress.sh"

    # shellcheck source=./chrome/chrome.sh
    _loadEssential "chrome/chrome.sh"

    # shellcheck source=./task/task.sh
    _loadEssential "task/task.sh"

    # shellcheck source=./prompt/prompt.sh
    _loadEssential "prompt/prompt.sh"

    debug "Essentials Warm Up: completed"
    unset -f _loadEssential
    return 0
}
