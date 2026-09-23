#!/usr/bin/env bash
# ==================================================================================================
# NDS - Self-test (parked)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-29 | Modified: 2026-09-23
# Description:   NDS tests are parked while nds/ is under refactor. Do not discover nds/ here.
# ==================================================================================================
set -euo pipefail
echo "NDS selftest is parked (nds/ mid-refactor). No nds/ tests run." >&2
echo "Use: bash utilities/essentials/dev/selftest.sh" >&2
echo "     bash utilities/bashTestSuite/dev/selftest.sh" >&2
exit 0
