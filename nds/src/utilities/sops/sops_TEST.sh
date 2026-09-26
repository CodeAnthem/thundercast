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

    declare -gA R=()
    R[FLAKE_HOST]=host
    R[SOPS_AGE_REUSE]=file
    R[SOPS_AGE_KEY_FILE]=$key
    local leaf
    leaf=$(mktemp -d)
    # key was removed above; write it again
    key=$(mktemp)
    printf '%s\n' '# public key: age1leaf' 'AGE-SECRET-KEY-1TEST' > "$key"
    R[SOPS_AGE_KEY_FILE]=$key
    if sops_writeLeafPub R "$leaf" && [[ $(<"${leaf}/.toolkit/machines/host/keys/age.pub") == age1leaf ]]; then
        bts_pass "sops_writeLeafPub records the machine age.pub"
    else
        bts_fail "leaf pub missing"
    fi
    rm -rf "$key" "$leaf"
}
