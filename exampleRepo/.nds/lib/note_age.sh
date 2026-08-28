#!/usr/bin/env bash
# ==================================================================================================
# exampleRepo — record machine age pubkey after nixos-install (ISO still)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-17 | Modified: 2026-08-28
# Description:   Function only. Register from .nds/common or .nds/<action>.
# ==================================================================================================

dp_note_age_pubkey() {
    local secrets_dir="${NDS_RUNTIME_DIR:-/tmp/nds}/secrets"
    local host flake_root dest
    host="$(nds_cfg_get FLAKE_HOST 2>/dev/null || true)"
    flake_root="${NDS_FLAKE_PROBE_DIR:-.}"
    [[ -n "$host" ]] || return 0
    [[ -f "${secrets_dir}/age_pubkey.txt" ]] || return 0
    dest="${flake_root}/.toolkit/machines/${host}/keys/age.pub"
    mkdir -p "$(dirname "$dest")"
    cp "${secrets_dir}/age_pubkey.txt" "$dest"
    info "Recorded machine age pubkey at ${dest#"$flake_root"/} — toolkit: enroll then Apply"
}
