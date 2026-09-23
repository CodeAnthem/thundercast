#!/usr/bin/env bash
# ==================================================================================================
# bashTestSuite - ShellCheck (this product only)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-23 | Modified: 2026-09-23
# ==================================================================================================
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT}/.github/scripts/shellcheck-lib.sh"

mapfile -t SCRIPTS < <(
    find "${ROOT}/utilities/bashTestSuite" -type f -name '*.sh' \
        ! -path '*/tests/*' ! -name '*_TEST.sh' | sort -u
)

ci_shellcheck_resolve
"${SHELLCHECK_BIN}" --version
echo "Linting ${#SCRIPTS[@]} bashTestSuite scripts…" >&2
ver="$(< "${ROOT}/utilities/bashTestSuite/VERSION")"
ci_shellcheck_lint "bashTestSuite v${ver}" "${ROOT}/.shellcheckrc" SCRIPTS
