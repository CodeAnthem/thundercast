#!/usr/bin/env bash
# ==================================================================================================
# Thundercast - Bash Essentials - Loader
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-06 | Modified: 2026-09-23
# ==================================================================================================

# Block Script Execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

_essentials_loadModules() {
    local -a originalArgs=("$@")
    local current_dir
    current_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)" || exit 1

    loadModule() {
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
    loadModule "bashVersion/bashVersion.sh"

    # No feature dependencies, so the re-exec path can already log.
    # shellcheck source=./logger/logger.sh
    loadModule "logger/logger.sh"
    logger_scopeCreate "Essentials Warm Up" "internal_essentials" || echo "Failed to create logger scope" >&2
    debug "Essentials Warm Up: logger scope created"

    # May exec and not return. Later modules do not exist on that path.
    # shellcheck source=./rootReexec/rootReexec.sh
    loadModule "rootReexec/rootReexec.sh"

    # Bus before anything that registers a hook. Traps do not survive the exec above.
    # shellcheck source=./eventBus/eventBus.sh
    loadModule "eventBus/eventBus.sh"

    # shellcheck source=./trapBridge/trapBridge.sh
    loadModule "trapBridge/trapBridge.sh"

    # Name, keyboard policy, and scratch dir. The screen features below read these.
    # shellcheck source=./scriptInfo/scriptInfo.sh
    loadModule "scriptInfo/scriptInfo.sh"

    # shellcheck source=./ttyHandler/ttyHandler.sh
    loadModule "ttyHandler/ttyHandler.sh"

    # shellcheck source=./sessionDir/sessionDir.sh
    loadModule "sessionDir/sessionDir.sh"

    # Format toolkit, then the bar, the frame, the task line, and prompts.
    # chrome needs ui, progress, and tty. prompt needs ui and tty.
    # shellcheck source=./ui/ui.sh
    loadModule "ui/ui.sh"

    # shellcheck source=./progress/progress.sh
    loadModule "progress/progress.sh"

    # shellcheck source=./chrome/chrome.sh
    loadModule "chrome/chrome.sh"

    # shellcheck source=./task/task.sh
    loadModule "task/task.sh"

    # shellcheck source=./prompt/prompt.sh
    loadModule "prompt/prompt.sh"
}
