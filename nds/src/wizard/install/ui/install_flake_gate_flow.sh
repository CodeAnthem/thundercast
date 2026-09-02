#!/usr/bin/env bash
# ==================================================================================================
# NDS - installFlake early gate (mode + config AA)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-31 | Modified: 2026-08-16
# Description:   URL → git → hosts → target; binds AA for nested prompts
# ==================================================================================================

# Description: Early installFlake gate — mode + config AA (mutates AA).
# Arguments:
# - mode: <String> interactive|unattended
# - cfg:  <Nameref> Full config AA
# Returns:
# - 0 ready for config manager; non-zero abort
nds_flake_install_gate() {
    local mode="${1:-interactive}"
    local -n _fg=$2
    local flake_root="" rc
    local prev_aa="${NDS_CFG_AA_NAME:-}"

    nds_cfg_aa_bind _fg
    nds_ui_section_header "Flake access"

    while true; do
        nds_flake_gate_prompts_location || {
            NDS_CFG_AA_NAME="$prev_aa"
            return 1
        }
        nds_flake_gate_logic_ensure_access "$mode" _fg flake_root || {
            NDS_CFG_AA_NAME="$prev_aa"
            return 1
        }

        nds_flake_gate_prompts_persist
        rc=$?
        [[ "$rc" -eq "${NDS_ACTION_BACK:-10}" ]] && continue
        [[ "$rc" -ne 0 ]] && {
            NDS_CFG_AA_NAME="$prev_aa"
            return 1
        }

        nds_flake_pick_host "$flake_root"
        rc=$?
        if [[ "$rc" -eq "${NDS_ACTION_BACK:-10}" ]]; then
            nds_cfg_set FLAKE_LOCATION ""
            nds_cfg_set FLAKE_REPO_URL ""
            nds_cfg_set FLAKE_LOCAL_PATH ""
            nds_cfg_set FLAKE_HOST ""
            continue
        fi
        [[ "$rc" -ne 0 ]] && {
            NDS_CFG_AA_NAME="$prev_aa"
            return 1
        }

        nds_flake_gate_prompts_target
        rc=$?
        [[ "$rc" -eq "${NDS_ACTION_BACK:-10}" ]] && continue
        [[ "$rc" -ne 0 ]] && {
            NDS_CFG_AA_NAME="$prev_aa"
            return 1
        }

        nds_flake_gate_logic_seed_defaults
        export NDS_FLAKE_GATE_ROOT="$flake_root"
        NDS_CFG_AA_NAME="$prev_aa"
        return 0
    done
}

# Description: Prompt for flake location when unset; normalize into FLAKE_*.
nds_flake_gate_prompts_location() {
    local loc src

    if nds_flake_gate_logic_existing_location; then
        return 0
    fi

    if declare -f nds_mode_is_unattended &>/dev/null && nds_mode_is_unattended; then
        error "Unattended mode requires FLAKE_REPO_URL or FLAKE_LOCAL_PATH"
        return 1
    fi

    if declare -f _nds_settings_installFlake_ask_location &>/dev/null; then
        _nds_settings_installFlake_ask_location
        return $?
    fi

    nds_cfg_section_title "Your flake"
    nds_aa_ask_string FLAKE_LOCATION "Flake location (git URL or path)" "" true
    loc="${ nds_feat_cfg_get FLAKE_LOCATION; }"
    nds_flake_gate_logic_normalize_location "$loc"
}

# Description: Prompt install mode + disk or remote IP (interactive).
# Description: Prompt for install mode + disk or remote IP (interactive).
nds_flake_gate_prompts_target() {
    local mode rc

    if declare -f nds_mode_is_unattended &>/dev/null && nds_mode_is_unattended; then
        nds_flake_gate_logic_target_unattended
        return $?
    fi

    nds_cfg_section_title "Install mode"
    nds_aa_ask_numbered_choice INSTALL_MODE \
        "local|remote" \
        "local=On target (live ISO)|remote=From operator (nixos-anywhere)" \
        "local" \
        true
    rc=$?
    [[ "$rc" -eq "${NDS_ACTION_BACK:-10}" ]] && return "$rc"

    mode="${ nds_feat_cfg_get INSTALL_MODE; }"
    if [[ "$mode" == "remote" ]]; then
        nds_aa_ask_ip REMOTE_TARGET_IP "Target host IP or hostname" "" true
    else
        if [[ -z "${ nds_feat_cfg_get DISK_TARGET; }" ]]; then
            if declare -f nds_aa_ask_disk &>/dev/null; then
                nds_aa_ask_disk DISK_TARGET "Target disk" "" true
            else
                nds_aa_ask_path DISK_TARGET "Target disk (e.g. /dev/sda)" "/dev/sda" true
            fi
        fi
        [[ -z "${ nds_feat_cfg_get DISK_STRATEGY; }" ]] && nds_feat_cfg_set DISK_STRATEGY "nds"
    fi
    return 0
}

# Description: Persist-access ask after git access works.
# Honors GIT_PERSIST_ACCESS / NDS_GIT_PERSIST_ACCESS; unattended defaults to true.
# Description: Persist-access ask after git access works.
nds_flake_gate_prompts_persist() {
    local rc existing normalized
    declare -f nds_git_wizard_ask_persist_access &>/dev/null || return 0

    existing="${ nds_feat_cfg_get GIT_PERSIST_ACCESS 2>/dev/null || true; }"
    [[ -z "$existing" ]] && existing="${NDS_GIT_PERSIST_ACCESS:-}"
    if declare -f _nds_git_persist_normalize &>/dev/null; then
        normalized="${ _nds_git_persist_normalize "$existing"; }"
        if [[ -n "$normalized" ]]; then
            nds_feat_cfg_set GIT_PERSIST_ACCESS "$normalized"
            return 0
        fi
    fi

    if declare -f nds_mode_is_unattended &>/dev/null && nds_mode_is_unattended; then
        nds_feat_cfg_set GIT_PERSIST_ACCESS "true"
        return 0
    fi

    nds_git_wizard_ask_persist_access
    rc=$?
    [[ "$rc" -eq "${NDS_ACTION_BACK:-10}" ]] && return "$rc"
    [[ "$rc" -ne 0 ]] && return 1
    return 0
}
