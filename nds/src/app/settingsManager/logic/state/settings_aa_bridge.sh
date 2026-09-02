#!/usr/bin/env bash
# ==================================================================================================
# NDS - Config AA bridge (store <-> feature nameref)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-05 | Modified: 2026-08-05
# Description:   Pass full config AA into features; apply returned AA back to store
# ==================================================================================================

# Description: Copy CONFIG_DATA into a nameref associative array.
# Arguments:
# - out: <Nameref> Target declare -A
nds_cfg_aa_from_store() {
    local -n _nds_aa_out=$1
    local k
    _nds_aa_out=()
    for k in "${!CONFIG_DATA[@]}"; do
        _nds_aa_out["$k"]="${CONFIG_DATA[$k]}"
    done
}

# Description: Write nameref AA keys into CONFIG_DATA (overwrite matching keys).
# Arguments:
# - in: <Nameref> Source declare -A
nds_cfg_aa_to_store() {
    local -n _nds_aa_in=$1
    local k
    for k in "${!_nds_aa_in[@]}"; do
        CONFIG_DATA["$k"]="${_nds_aa_in[$k]}"
    done
}

# Description: Redirect nds_cfg_get/set onto a live feature AA (name of nameref/AA).
# Call from feature entry before nds_aa_ask_* / nds_feat_cfg_*; unbind after.
# Arguments:
# - aa_name: <String> Variable name of the config AA (e.g. _g_run)
nds_cfg_aa_bind() {
    NDS_CFG_AA_NAME="${1:?config AA variable name}"
}

# Description: Restore nds_cfg_get/set to CONFIG_DATA.
nds_cfg_aa_unbind() {
    NDS_CFG_AA_NAME=""
}

# Description: Require non-empty keys in a config AA (feature unattended checks).
# Arguments:
# - cfg:  <Nameref> Config AA
# - keys: <String...> Required keys
# Returns:
# - 0 when all present; 1 and prints missing list on stderr
nds_feature_require_keys() {
    local -n _nds_req_cfg=$1
    shift
    local key missing=()
    for key in "$@"; do
        [[ -n "${_nds_req_cfg[$key]:-}" ]] || missing+=("$key")
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        error "Missing required configuration: ${missing[*]}"
        return 1
    fi
    return 0
}
