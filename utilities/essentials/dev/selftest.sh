#!/usr/bin/env bash
# ==================================================================================================
# essentials - Self-test (bashTestSuite over this tree)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-23 | Modified: 2026-09-23
# ==================================================================================================
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
exec bash "${ROOT}/utilities/bashTestSuite/main.sh" "${ROOT}/utilities/essentials" "$@"
