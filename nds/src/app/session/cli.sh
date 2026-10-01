#!/usr/bin/env bash
# ==================================================================================================
# NDS - Command line
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-29 | Modified: 2026-09-26
# Description:   argv into NDS_MODE, NDS_SKIP, NDS_YES, NDS_REBOOT, NDS_ACTION, NDS_RECIPE_FILE.
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

nds_cli_help() {
    printf '%s\n' \
        'Usage: nds/src/app/main.sh [options]' \
        '' \
        'Options:' \
        '  --unattended     Run without questions' \
        '  --skip a,b       Skip named questions' \
        '  --yes            Skip every question except finish.reboot' \
        '  --reboot         Reboot after a successful finish' \
        '  --action NAME    Run one action' \
        '  --import FILE    Load a recipe, take its action, keep the preview' \
        '  --restore FILE   Unpack a bundle, take its action, keep the preview' \
        '  --recipe FILE    Load a recipe into the action you already chose' \
        '  --help           Show this help' \
        '' \
        'Questions:'
    if declare -f nds_skip_list >/dev/null; then
        nds_skip_list
    fi
}

nds_cli_parse() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --unattended) export NDS_MODE=unattended; shift ;;
            --yes) export NDS_YES=true; shift ;;
            --reboot) export NDS_REBOOT=true; shift ;;
            --skip)
                [[ -n ${2:-} ]] || { error "--skip: missing value"; return 1; }
                export NDS_SKIP="$2"
                shift 2
                ;;
            --action)
                [[ -n ${2:-} ]] || { error "--action: missing value"; return 1; }
                export NDS_ACTION="$2"
                shift 2
                ;;
            --recipe)
                [[ -n ${2:-} ]] || { error "--recipe: missing value"; return 1; }
                export NDS_RECIPE_FILE="$2"
                shift 2
                ;;
            --import)
                [[ -n ${2:-} ]] || { error "--import: missing value"; return 1; }
                [[ -f "$2" ]] || { error "--import: file not found"; return 1; }
                export NDS_IMPORT=1
                export NDS_RECIPE_FILE="$2"
                shift 2
                ;;
            --restore)
                [[ -n ${2:-} ]] || { error "--restore: missing value"; return 1; }
                [[ -f "$2" ]] || { error "--restore: file not found"; return 1; }
                export NDS_RESTORE_FILE="$2"
                shift 2
                ;;
            --help|-h)
                nds_cli_help
                return 2
                ;;
            *)
                error "Unknown option: $1"
                return 1
                ;;
        esac
    done
    if [[ -n ${NDS_IMPORT:-} && -n ${NDS_RESTORE_FILE:-} ]]; then
        error "--import and --restore together"
        return 1
    fi
    if [[ -n ${NDS_IMPORT:-} || -n ${NDS_RESTORE_FILE:-} ]]; then
        if [[ ${NDS_MODE:-} == unattended ]]; then
            error "--import and --restore stay interactive"
            return 1
        fi
    fi
}
