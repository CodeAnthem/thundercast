#!/usr/bin/env bash
# ==================================================================================================
# essentials - ShellCheck (this product only)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-23 | Modified: 2026-09-23
# ==================================================================================================
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT}/.github/scripts/shellcheck-lib.sh"

mapfile -t SCRIPTS < <(
    find "${ROOT}/utilities/essentials" -type f -name '*.sh' \
        ! -name '*_TEST.sh' ! -name '*_DEMO.sh' | sort -u
)

ci_shellcheck_resolve
"${SHELLCHECK_BIN}" --version
echo "Linting ${#SCRIPTS[@]} essentials scripts…" >&2
ver="$(< "${ROOT}/utilities/essentials/VERSION")"
ci_shellcheck_lint "essentials v${ver}" "${ROOT}/.shellcheckrc" SCRIPTS
