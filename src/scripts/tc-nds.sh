#!/usr/bin/env bash
# ==================================================================================================
# ThunderCast - tc-nds (installer entry)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-20 | Modified: 2026-08-20
# Description:   tc-nds apply RECIPE  |  tc-nds --action addRole
# ==================================================================================================
set -euo pipefail
_here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "${_here}/../app/main.sh" "$@"
