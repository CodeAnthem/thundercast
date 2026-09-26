#!/usr/bin/env bash
# ==================================================================================================
# sops - install an existing age key
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# ==================================================================================================

# shellcheck source=../../setup_TEST.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../setup_TEST.sh"
import_dir "$(dirname "${BASH_SOURCE[0]}")" --depth 0

suite_sops() {
    local key mnt secrets
    key=$(mktemp)
    mnt=$(mktemp -d)
    secrets=$(mktemp -d)
    cat > "$key" <<'EOF'
# public key: age1testpublickey
AGE-SECRET-KEY-1TEST
EOF
    if sops_installKey "$key" "$mnt" "$secrets" host \
        && [[ $(<"${mnt}/etc/sops/age/keys.txt") == *AGE-SECRET-KEY-1TEST* ]] \
        && [[ $(<"${secrets}/age_pubkey.txt") == age1testpublickey ]] \
        && [[ -f "${secrets}/sops_enroll.md" ]]; then
        bts_pass "sops_installKey copies the key and writes the enroll note"
    else
        bts_fail "sops_installKey did not write the key and note"
    fi
    rm -rf "$key" "$mnt" "$secrets"
}
