#!/usr/bin/env bash
# ==================================================================================================
# NDS - App CLI helpers
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-29 | Modified: 2026-08-15
# Description:   Parse app CLI flags and render help text
# ==================================================================================================

# Description: Print app CLI usage and registered skip variables.
nds_app_session_cli_showHelp() {
    local skip_var

    printf 'Usage: src/app/main.sh [options]\n\n'
    printf 'Options:\n'
    printf '  --auto-confirm   Skip interactive menus and Y/n prompts (headless install)\n'
    printf '  --skip-menu      Skip the configuration category menu when validation passes\n'
    printf '  --action NAME    Enter action NAME directly (e.g. installFlake)\n'
    printf '  --help           Show this help\n\n'
    printf 'Environment:\n'
    printf '  NDS_ACTION              Action name — skip action picker\n'
    printf '  NDS_AUTO_CONFIRM        Umbrella — same as --auto-confirm\n'
    printf '  NDS_GIT_PERSIST_ACCESS  true|false — keep SSH keys + nds-switch on the installed machine\n'
    printf '  Registered skip vars:\n'
    for skip_var in "${_NDS_SKIP_REGISTRY[@]}"; do
        printf '    %s\n' "$skip_var"
    done
}

# Description: Parse CLI flags and export app env settings.
nds_app_session_cli_parseArgs() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --auto-confirm) export _NDS_AUTO_CONFIRM_REQUESTED=true; shift ;;
            --skip-menu) export NDS_SKIP_MENU=true; shift ;;
            --action)
                [[ -n "${2:-}" ]] || { echo "Missing value for --action"; return 1; }
                export NDS_ACTION="$2"
                shift 2
                ;;
            --help|-h)
                nds_app_session_cli_showHelp || return 1
                return 2
                ;;
            *) echo "Unknown option: $1"; return 1 ;;
        esac
    done
    return 0
}
