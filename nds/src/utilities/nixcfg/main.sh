#!/usr/bin/env bash
# ==================================================================================================
# nixcfg utility - classic configuration.nix builder (no prompts)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-02 | Modified: 2026-09-02
# ==================================================================================================

if (( BASH_VERSINFO[0] < 5 || (BASH_VERSINFO[0] == 5 && BASH_VERSINFO[1] < 3) )); then
    printf 'NIXCFG: requires Bash 5.3 or newer (found %s).\n' "${BASH_VERSION}" >&2
    return 1 2>/dev/null || exit 1
fi

_NIXCFG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

import_dir "${_NIXCFG_DIR}/logic" || return 1

nixcfg_onLoad() { return 0; }
nixcfg_onExit() { return 0; }
