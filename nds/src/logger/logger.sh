#!/usr/bin/env bash
# ==================================================================================================
# NDS - Foundation logger (console + install log)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-06 | Modified: 2026-09-02
# Description:   Leveled emit for console and/or install log (UI-independent foundation)
# ==================================================================================================

console() { echo "${1:-}" >&2; }

declare -g NDS_UI_QUIET=false

# Description: Emit a leveled message.
# Arguments:
# - level:       <String> info|success|warn|error|fatal|debug|validation|log
# - msg:         <String> Message body
# - destination: <String|optional> console|log|both (default: both)
nds_log() {
    local level="$1"
    local msg="$2"
    local destination="${3:-both}"
    local levelTxt color_code=''

    if declare -f nds_ui_init &>/dev/null; then
        nds_ui_init
    fi

    case "$level" in
        success)
            color_code='32'
            if [[ "${NDS_UI_MODE:-}" == "unicode" ]]; then
                levelTxt=$'\u2705 [PASS] -'
            else
                levelTxt='[OK] -'
            fi
            ;;
        info)
            color_code='36'
            if [[ "${NDS_UI_MODE:-}" == "unicode" ]]; then
                levelTxt=$'\u2139\ufe0f  [INFO] -'
            else
                levelTxt='[INFO] -'
            fi
            ;;
        warn)
            color_code='33'
            if [[ "${NDS_UI_MODE:-}" == "unicode" ]]; then
                levelTxt=$'\u26a0\ufe0f  [WARN] -'
            else
                levelTxt='[WARN] -'
            fi
            ;;
        error|validation)
            color_code='31'
            if [[ "${NDS_UI_MODE:-}" == "unicode" ]]; then
                levelTxt=$'\u274c [FAIL] -'
            else
                levelTxt='[FAIL] -'
            fi
            ;;
        fatal)
            color_code='31'
            if [[ "${NDS_UI_MODE:-}" == "unicode" ]]; then
                levelTxt=$'\u274c [FATAL] -'
            else
                levelTxt='[FATAL] -'
            fi
            ;;
        debug)
            color_code='35'
            if [[ "${NDS_UI_MODE:-}" == "unicode" ]]; then
                levelTxt=$'\U1f41b [DEBUG] -'
            else
                levelTxt='[DEBUG] -'
            fi
            ;;
        log)
            color_code='0'
            levelTxt=''
            ;;
        *)
            color_code='0'
            levelTxt='[LOG] -'
            ;;
    esac

    if [[ "$destination" == "console" || "$destination" == "both" ]]; then
        # Failures stay on the console even during quiet install steps.
        local quiet="${NDS_UI_QUIET:-false}"
        case "$level" in
            error|validation|fatal) quiet=false ;;
        esac
        # An open step owns the TTY line (`[   ] …` has no newline). Inner
        # success/info would glue onto it; the step complete line is the OK.
        if [[ "$quiet" != true && -n "${NDS_UI_STEP_NAME:-}" ]]; then
            case "$level" in
                success|info|debug|log) quiet=true ;;
            esac
        fi
        if [[ "$quiet" != true ]]; then
            if [[ -n "${NDS_UI_STEP_NAME:-}" ]] && declare -f nds_ui_step_yield &>/dev/null; then
                nds_ui_step_yield
            fi
            if [[ "$level" == "log" ]]; then
                printf '  %s\n' "$msg" >&2
            elif [[ "${NDS_UI_COLOR:-false}" == true && "$NDS_UI_MODE" != "unicode" && -n "$color_code" ]]; then
                # Strip trailing " -" from levelTxt for colored label form: [TAG] - msg
                local label="${levelTxt% -}"
                printf '  \033[%sm%s\033[0m - %s\n' "$color_code" "$label" "$msg" >&2
            else
                if [[ -n "$levelTxt" ]]; then
                    printf '  %s %s\n' "$levelTxt" "$msg" >&2
                else
                    printf '  %s\n' "$msg" >&2
                fi
            fi
            if [[ -n "${NDS_UI_STEP_NAME:-}" ]] && declare -f nds_ui_step_resume &>/dev/null; then
                nds_ui_step_resume
            fi
        fi
    fi

    if [[ "$destination" == "log" || "$destination" == "both" ]]; then
        if declare -f nds_install_log &>/dev/null; then
            if [[ -n "$levelTxt" ]]; then
                nds_install_log "${levelTxt} ${msg}"
            else
                nds_install_log "$msg"
            fi
        fi
    fi
}

log() { nds_log log "$1" both; }
info() { nds_log info "$1" both; }
error() { nds_log error "$1" both; }
fatal() { nds_log fatal "$1" both; }
success() { nds_log success "$1" both; }
warn() { nds_log warn "$1" both; }
validation_error() { nds_log validation "$1" both; }
debug() { [[ "${DEBUG:-0}" == "1" ]] && nds_log debug "$1" both || true; }

# Description: Note a choice taken from env or unattended (not a menu).
# Arguments:
# - msg: <String> What was decided
nds_log_from_env() {
    local msg="$1"
    local tag="env"
    if declare -f nds_mode_is_unattended &>/dev/null && nds_mode_is_unattended; then
        tag="unattended"
    fi
    if [[ -z "${NDS_UI_STEP_NAME:-}" ]]; then
        printf '    -> [%s] - %s\n' "$tag" "$msg" >&2
    fi
    if declare -f nds_install_log &>/dev/null; then
        nds_install_log "-> [${tag}] - ${msg}"
    fi
}
