#!/usr/bin/env bash
# nds-hook: post_scaffold
# ==================================================================================================
# NDS - toolkit action pack: public operator keys into .toolkit/ (not .nds)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-28 | Modified: 2026-08-28
# ==================================================================================================

_nds_toolkit_hook_write_operator_pubs() {
    local flake_root dest
    flake_root="${NDS_FLAKE_PROBE_DIR:-.}"
    dest="$(_nds_toolkit_secrets_dir)"
    mkdir -p "${flake_root}/.toolkit/operator/keys" || return 1
    if [[ -f "${dest}/operator_age.pub" ]]; then
        cp "${dest}/operator_age.pub" "${flake_root}/.toolkit/operator/keys/age.pub"
    fi
    if [[ -f "${dest}/toolkit_ssh.pub" ]]; then
        cp "${dest}/toolkit_ssh.pub" "${flake_root}/.toolkit/operator/keys/ssh.pub"
    fi
}

nds_hook_register post_scaffold _nds_toolkit_hook_write_operator_pubs
