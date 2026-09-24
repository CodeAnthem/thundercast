#!/usr/bin/env bash
# ==================================================================================================
# Thundercast - Bash Essentials - Test environment (dummy config + load)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-18 | Modified: 2026-09-24
# ==================================================================================================

_ESSENTIALS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

_essentials_test_ensureConfig() {
    declare -gA essentials_config
    [[ -n "${essentials_config[LOG_ROOT]:-}" ]] && return 0
    local logdir base
    logdir="$(mktemp -d)"
    base="$(mktemp -d)"
    essentials_config=(
        [SCRIPTINFO_DIR]="/tmp/essentials-test"
        [SCRIPTINFO_NAME]="Essentials Test"
        [SCRIPTINFO_VERSION]="0.0.1"
        [LOG_ROOT]="$logdir"
        [LOG_PURGE]=false
        [LOG_MINLEVEL]=fatal
        [LOG_STDERRLEVEL]=error
        [LOG_COLOR]=false
        [LOG_INDENT]=0
        [LOG_COMPOSE_FILENAME]=compose.log
        [TTY_EXIT_PRIORITY]="7"
        [RUNTIME_BASE]="$base"
        [RUNTIME_PREFIX]=et
        [RUNTIME_SUBDIRS]="config secrets"
        [RUNTIME_MODE]=700
        [RUNTIME_PURGE_STALE]=false
        [UI_MODE]=plain
        [UI_NO_CLEAR]=true
        [UI_NO_PAUSE]=true
        [UI_BANNER_MIN]=20
        [UI_LABEL_WIDTH]=12
        [TRAP_PRESETS]=false
        [ROOTREEXEC_ROOT]=false
    )
}

_essentials_test_ensureInit() {
    declare -F _essentials_init_isDone >/dev/null && return 0
    # shellcheck source=../essentials.sh
    source "${_ESSENTIALS_ROOT}/essentials.sh"
}

_essentials_test_ensure_loadEssential() {
    declare -F _loadEssential >/dev/null && return 0
    _loadEssential() {
        # shellcheck disable=SC1090
        source "${_ESSENTIALS_ROOT}/$1"
    }
}

_essentials_test_loadOne() {
    local name="$1"
    case "$name" in
        bashVersion)
            declare -f bashVersion_check >/dev/null && return 0
            # shellcheck source=../bashVersion/bashVersion.sh
            source "${_ESSENTIALS_ROOT}/bashVersion/bashVersion.sh"
            ;;
        scriptInfo)
            declare -f scriptInfo_get_name >/dev/null && return 0
            # shellcheck source=./scriptInfo/scriptInfo.sh
            source "${_ESSENTIALS_ROOT}/scriptInfo/scriptInfo.sh"
            ;;
        eventBus)
            declare -f eventRun >/dev/null && return 0
            # shellcheck source=./eventBus/eventBus.sh
            source "${_ESSENTIALS_ROOT}/eventBus/eventBus.sh"
            ;;
        logger)
            _essentials_init_isDone logger && return 0
            # shellcheck source=./logger/logger.sh
            source "${_ESSENTIALS_ROOT}/logger/logger.sh"
            logger_scopeCreate "Essentials Test" "essentials_test" >/dev/null
            ;;
        importer)
            _essentials_test_loadOne logger
            declare -f import_file >/dev/null && return 0
            # shellcheck source=./importer/importer.sh
            source "${_ESSENTIALS_ROOT}/importer/importer.sh"
            ;;
        ttyHandler)
            _essentials_test_loadOne eventBus
            _essentials_test_loadOne logger
            declare -f tty_restore >/dev/null && return 0
            # shellcheck source=../ttyHandler/ttyHandler.sh
            source "${_ESSENTIALS_ROOT}/ttyHandler/ttyHandler.sh"
            ;;
        sessionDir)
            _essentials_test_loadOne logger
            declare -f runtime_getDir >/dev/null && return 0
            # shellcheck source=./sessionDir/sessionDir.sh
            source "${_ESSENTIALS_ROOT}/sessionDir/sessionDir.sh"
            ;;
        ui)
            _essentials_test_loadOne scriptInfo
            _essentials_test_loadOne eventBus
            declare -f ui_h >/dev/null && return 0
            # shellcheck source=./ui/ui.sh
            source "${_ESSENTIALS_ROOT}/ui/ui.sh"
            ;;
        progress)
            _essentials_test_loadOne ui
            _essentials_test_loadOne logger
            declare -f progress_render >/dev/null && return 0
            # shellcheck source=./progress/progress.sh
            source "${_ESSENTIALS_ROOT}/progress/progress.sh"
            ;;
        chrome)
            _essentials_test_loadOne ui
            _essentials_test_loadOne progress
            _essentials_test_loadOne ttyHandler
            declare -f chrome_isOn >/dev/null && return 0
            # shellcheck source=./chrome/chrome.sh
            source "${_ESSENTIALS_ROOT}/chrome/chrome.sh"
            ;;
        task)
            _essentials_test_loadOne ui
            declare -f taskStart >/dev/null && return 0
            # shellcheck source=./task/task.sh
            source "${_ESSENTIALS_ROOT}/task/task.sh"
            ;;
        prompt)
            _essentials_test_loadOne ui
            _essentials_test_loadOne ttyHandler
            declare -f prompt >/dev/null && return 0
            # shellcheck source=./prompt/prompt.sh
            source "${_ESSENTIALS_ROOT}/prompt/prompt.sh"
            ;;
        trapBridge)
            _essentials_test_loadOne eventBus
            _essentials_test_loadOne logger
            declare -f trapRegister >/dev/null && return 0
            # shellcheck source=./trapBridge/trapBridge.sh
            source "${_ESSENTIALS_ROOT}/trapBridge/trapBridge.sh"
            ;;
        rootReexec)
            _essentials_test_loadOne logger
            _essentials_init_isDone rootReexec && return 0
            # shellcheck source=./rootReexec/rootReexec.sh
            source "${_ESSENTIALS_ROOT}/rootReexec/rootReexec.sh"
            ;;
        *)
            printf '%s\n' "essentials_test_load: unknown module: ${name}" >&2
            return 1
            ;;
    esac
}

essentials_test_load() {
    local name
    _essentials_test_ensureConfig
    _essentials_test_ensureInit || return 1
    _essentials_test_ensure_loadEssential
    for name in "$@"; do
        _essentials_test_loadOne "$name" || return 1
    done
}
