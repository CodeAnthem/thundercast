#!/usr/bin/env bash
# ==================================================================================================
# targetSeed - copy preserves modes
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# ==================================================================================================

# shellcheck source=../../setup_TEST.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../setup_TEST.sh"
import_dir "$(dirname "${BASH_SOURCE[0]}")" --depth 0

suite_targetSeed() {
    local src mnt mode
    src=$(mktemp -d)
    mnt=$(mktemp -d)
    mkdir -p "${src}/root"
    printf '%s\n' secret > "${src}/root/key"
    chmod 600 "${src}/root/key"
    targetSeed_copy "$src" "$mnt"
    mode=$(stat -c '%a' "${mnt}/root/key")
    if [[ "$mode" == 600 && $(<"${mnt}/root/key") == secret ]]; then
        bts_pass "targetSeed_copy preserves the file mode"
    else
        bts_fail "copied mode was ${mode}"
    fi
    rm -rf "$src" "$mnt"
}
