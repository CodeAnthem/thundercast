#!/usr/bin/env bash
# ==================================================================================================
# tcast - ShellCheck (this product only)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-01 | Modified: 2026-09-01
# ==================================================================================================
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT}/.github/scripts/shellcheck-lib.sh"

mapfile -t SCRIPTS < <(
    find "${ROOT}/tcast" -type f \( -name '*.sh' -o -name 'tcast' -o -name 'tcast-git-ssh' \) \
        ! -path '*/tests/*' ! -path '*/modules/*' | sort -u
)

ci_shellcheck_resolve
"${SHELLCHECK_BIN}" --version
echo "Linting ${#SCRIPTS[@]} tcast scripts…" >&2
ver="$(< "${ROOT}/tcast/VERSION")"
ci_shellcheck_lint "tcast v${ver}" "${ROOT}/.shellcheckrc" SCRIPTS
