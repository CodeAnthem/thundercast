#!/usr/bin/env bash
# ==================================================================================================
# NDS - App CLI helpers
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-29 | Modified: 2026-08-20
# Description:   Parse app CLI flags and render help text
# ==================================================================================================

# Description: Print app CLI usage and the operator-facing skip flags.
nds_app_session_cli_showHelp() {
    printf 'Usage: src/app/main.sh [options]\n\n'
    printf 'Options:\n'
    printf '  --auto-confirm   Skip interactive menus and Y/n prompts (headless install)\n'
    printf '  --skip-menu      Skip the configuration category menu when validation passes\n'
    printf '  --action NAME    Enter action NAME directly (e.g. installFlake, addRole, toolkit)\n'
    printf '  --recipe FILE    Load a sectioned or export-NDS_* recipe into the settings session\n'
    printf '  --help           Show this help\n\n'
    printf 'Environment:\n'
    printf '  NDS_ACTION              Action name — skip action picker\n'
    printf '  NDS_RECIPE_FILE         Recipe path (same as --recipe)\n'
    printf '  NDS_AUTO_CONFIRM        Umbrella — skip menus and Y/n (does not skip git auth)\n'
    printf '  NDS_INSTALL_CONFIRM_SKIP  Skip disk/remote wipe confirm (covers format + remote)\n'
    printf '  NDS_GIT_AUTH_SKIP       Fail if git access is missing (never implied by auto-confirm)\n'
    printf '  NDS_REBOOT_SKIP         Interactive — skip “Reboot now?”\n'
    printf '  NDS_REBOOT_FORCE        Unattended — reboot after install\n'
    printf '  NDS_GIT_PERSIST_ACCESS  true|false — keep SSH keys + tc-switch on the installed machine\n'
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
            --recipe)
                [[ -n "${2:-}" ]] || { echo "Missing value for --recipe"; return 1; }
                export NDS_RECIPE_FILE="$2"
                shift 2
                ;;
            --help|-h)
                nds_app_session_cli_showHelp || return 1
                return 2
                ;;
            apply)
                export NDS_ACTION="apply"
                if [[ -n "${2:-}" && "$2" != --* ]]; then
                    export NDS_RECIPE_FILE="$2"
                    shift 2
                else
                    shift
                fi
                ;;
            *) echo "Unknown option: $1"; return 1 ;;
        esac
    done
    return 0
}
