#!/usr/bin/env bash
# ==================================================================================================
# NDS - Self-test
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-29 | Modified: 2026-09-26
# Description:   Run NDS and fleet action tests. Does not run essentials or bashTestSuite tests.
# ==================================================================================================
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
exec bash "$ROOT/utilities/bashTestSuite/main.sh" "$ROOT/nds/src" "$ROOT/fleet/nds-actions"
