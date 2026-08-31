#!/usr/bin/env bash
# ==================================================================================================
# NDS - Self-test runner (CI / local)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-29 | Modified: 2026-08-30
# Description:   Run read-only NDS self-tests (settings, git, bundle, install, structure).
# ==================================================================================================

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec "$BASH" "${ROOT}/src/tests/run.sh"
