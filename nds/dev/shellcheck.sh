#!/usr/bin/env bash
# ==================================================================================================
# NDS - ShellCheck (this product only)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-01 | Modified: 2026-09-02
# ==================================================================================================
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT}/.github/scripts/shellcheck-lib.sh"

mapfile -t SCRIPTS < <(
    {
        find "${ROOT}/nds/src" -name '*.sh' ! -path '*/tests/*' ! -name '*_TEST.sh'
        find "${ROOT}/utilities/bashTestSuite" -name '*.sh' 2>/dev/null || true
        [[ -f "${ROOT}/nds/start.sh" ]] && printf '%s\n' "${ROOT}/nds/start.sh"
        [[ -f "${ROOT}/nds/dev/selftest.sh" ]] && printf '%s\n' "${ROOT}/nds/dev/selftest.sh"
    } | sort -u
)

ci_shellcheck_resolve
"${SHELLCHECK_BIN}" --version
echo "Linting ${#SCRIPTS[@]} NDS scripts…" >&2
ver="$(< "${ROOT}/nds/VERSION")"
ci_shellcheck_lint "NDS v${ver}" "${ROOT}/.shellcheckrc" SCRIPTS
