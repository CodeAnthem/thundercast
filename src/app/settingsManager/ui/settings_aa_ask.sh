#!/usr/bin/env bash
# ==================================================================================================
# NDS - Feature AA prompts (require nds_cfg_aa_bind)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-05 | Modified: 2026-08-16
# Description:   Feature UI ask_* — write live feature AA, not bare CONFIG_DATA
# ==================================================================================================

# Description: Fail unless nds_cfg_aa_bind is active for this feature.
_nds_aa_ask_require_bound() {
    [[ -n "${NDS_CFG_AA_NAME:-}" ]] || {
        error "Feature config AA not bound — call nds_cfg_aa_bind before nds_aa_ask_*"
        return 1
    }
    return 0
}

# Bound get/set for feature UI — under bind hit feature AA; else CONFIG_DATA (compat).
# Description: Read a config key via the bound feature AA (else CONFIG_DATA).
nds_feat_cfg_get() {
    nds_cfg_get "$@"
}

# Description: Write a config key via the bound feature AA (else CONFIG_DATA).
nds_feat_cfg_set() {
    nds_cfg_set "$@"
}

# Description: True when a config key equals the given value (bound AA).
nds_feat_cfg_is() {
    nds_cfg_is "$@"
}

# Description: True when a config key is the string true (bound AA).
nds_feat_cfg_true() {
    nds_cfg_true "$@"
}

# Description: Prompt for a string after AA bind.
nds_aa_ask_string() {
    _nds_aa_ask_require_bound || return 1
    nds_cfg_ask_string "$@"
}

# Description: Prompt for a path after AA bind.
nds_aa_ask_path() {
    _nds_aa_ask_require_bound || return 1
    nds_cfg_ask_path "$@"
}

# Description: Prompt for an IPv4 address after AA bind.
nds_aa_ask_ip() {
    _nds_aa_ask_require_bound || return 1
    nds_cfg_ask_ip "$@"
}

# Description: Prompt for a hostname after AA bind.
nds_aa_ask_hostname() {
    _nds_aa_ask_require_bound || return 1
    nds_cfg_ask_hostname "$@"
}

# Description: Prompt for a disk device after AA bind.
nds_aa_ask_disk() {
    _nds_aa_ask_require_bound || return 1
    nds_cfg_ask_disk "$@"
}

# Description: Prompt for a toggle after AA bind.
nds_aa_ask_toggle() {
    _nds_aa_ask_require_bound || return 1
    nds_cfg_ask_toggle "$@"
}

# Description: Prompt for a choice after AA bind.
nds_aa_ask_choice() {
    _nds_aa_ask_require_bound || return 1
    nds_cfg_ask_choice "$@"
}

# Description: Prompt for a numbered choice after AA bind.
nds_aa_ask_numbered_choice() {
    _nds_aa_ask_require_bound || return 1
    nds_cfg_ask_numbered_choice "$@"
}
