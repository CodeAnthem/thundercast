#!/usr/bin/env bash
# ==================================================================================================
# Thundercast - toolkit operator console
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-19 | Modified: 2026-08-20
# Description:   Nodes + sops + tools update. Leaf git is TCAST_LEAF_DIR, not /etc/nixos.
# ==================================================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export TCAST_TOOLKIT_ROOT="$ROOT"

# shellcheck source=lib/core.sh
source "${ROOT}/lib/core.sh"
# shellcheck source=lib/ui.sh
source "${ROOT}/lib/ui.sh"
# shellcheck source=lib/register.sh
source "${ROOT}/lib/register.sh"
# shellcheck source=lib/sops.sh
source "${ROOT}/lib/sops.sh"
# shellcheck source=lib/git.sh
source "${ROOT}/lib/git.sh"
# shellcheck source=lib/nodes.sh
source "${ROOT}/lib/nodes.sh"
# shellcheck source=menus.sh
source "${ROOT}/menus.sh"

if [[ $# -gt 0 ]]; then
    case "$1" in
        -h|--help|help)
            echo "toolkit — operator menu (no arguments)"
            echo "toolkit --version — print VERSION"
            echo "toolkit sops … — same as tcast-sops (health, init, put, apply, …)"
            echo "toolkit-update — fetch a new tools VERSION"
            exit 0
            ;;
        -V|--version|version)
            tcast_toolkit_version
            exit 0
            ;;
        sops)
            shift
            tcast_sops_cli "$@"
            exit $?
            ;;
        *)
            echo "Run toolkit (no arguments) for the menu. Try: toolkit sops help" >&2
            exit 1
            ;;
    esac
fi

tcast_menu_main
