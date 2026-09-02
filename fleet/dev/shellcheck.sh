#!/usr/bin/env bash
# ==================================================================================================
# Fleet - ShellCheck (nds-actions + start hooks only)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-01 | Modified: 2026-09-01
# ==================================================================================================
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT}/.github/scripts/shellcheck-lib.sh"

mapfile -t SCRIPTS < <(
    find "${ROOT}/fleet/nds-actions" -type f -name '*.sh' ! -path '*/tests/*' | sort -u
)

ci_shellcheck_resolve
"${SHELLCHECK_BIN}" --version
echo "Linting ${#SCRIPTS[@]} fleet scripts…" >&2
ver="$(< "${ROOT}/fleet/toolkit/VERSION")"
ci_shellcheck_lint "fleet toolkit v${ver}" "${ROOT}/.shellcheckrc" SCRIPTS
