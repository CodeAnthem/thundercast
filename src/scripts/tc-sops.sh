#!/usr/bin/env bash
# ==================================================================================================
# ThunderCast - tc-sops (find toolkit, then sops CLI)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-20 | Modified: 2026-08-20
# Description:   On a toolkit host this execs the seeded toolkit. In the Cast tree it
#                uses toolkitScripts/. GUI NixOS: install nixosModules.toolkit or seed scripts.
# ==================================================================================================
set -euo pipefail

if [[ -x /var/lib/nds-toolkit/current/toolkit.sh ]]; then
    exec bash /var/lib/nds-toolkit/current/toolkit.sh sops "$@"
fi
if command -v toolkit >/dev/null 2>&1; then
    exec toolkit sops "$@"
fi
_here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_repo="$(cd "${_here}/../.." && pwd)"
if [[ -x "${_repo}/toolkitScripts/toolkit.sh" ]]; then
    exec bash "${_repo}/toolkitScripts/toolkit.sh" sops "$@"
fi
echo "tc-sops: toolkit not found (seed toolkitScripts or install nixosModules.toolkit)" >&2
exit 1
