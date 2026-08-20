#!/usr/bin/env bash
# ==================================================================================================
# NDS - Install layer selfchecks
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-05 | Modified: 2026-08-05
# ==================================================================================================

nds_install_aa_bridge_selfcheck() {
    declare -f nds_cfg_aa_from_store &>/dev/null || return 1
    declare -f nds_cfg_aa_bind &>/dev/null || return 1
    declare -f nds_feature_require_keys &>/dev/null || return 1
    declare -f nds_mode_is_unattended &>/dev/null || return 1
    declare -f nds_flake_install_gate &>/dev/null || return 1
    declare -f nds_flake_gate_logic_normalize_location &>/dev/null || return 1
    declare -f nds_flake_pick_host &>/dev/null || return 1
    local -A cfg=([DISK_TARGET]="/dev/sda")
    nds_feature_require_keys cfg DISK_TARGET || return 1

    cfg[FLAKE_REPO_URL]="git@github.com:CodeAnthem/dps_swarm.git"
    nds_cfg_aa_bind cfg
    nds_flake_gate_logic_existing_location || {
        nds_cfg_aa_unbind
        return 1
    }
    [[ "$(nds_cfg_get FLAKE_SOURCE)" == "remote" ]] || {
        nds_cfg_aa_unbind
        return 1
    }
    nds_cfg_aa_unbind
    return 0
}
