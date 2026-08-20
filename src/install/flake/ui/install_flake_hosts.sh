#!/usr/bin/env bash
# ==================================================================================================
# NDS - Flake host picker prompts
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-05 | Modified: 2026-08-05
# Description:   Interactive host selection; writes FLAKE_HOST via bound nds_cfg_*
# ==================================================================================================

# Description: Interactive host picker; sets FLAKE_HOST / NETWORK_HOSTNAME.
# Respects existing FLAKE_HOST / NDS_FLAKE_HOST when it is in the discovered list.
# Arguments:
# - flake_root: <String|optional> Flake path (defaults via nds_flake_resolve_root)
# Returns:
# - 0 on selection, NDS_ACTION_BACK on back, 1 on failure
nds_flake_pick_host() {
    local flake_root="${1:-}"
    local -a hosts=()
    local options labels host default rc existing

    if [[ -z "$flake_root" ]]; then
        flake_root="$(nds_flake_resolve_root)" || {
            error "Flake root required to list nixosConfigurations"
            return 1
        }
    fi

    nds_ui_section_header "Configuration — select host"
    nds_ui_b "Choose a nixosConfigurations attribute from this flake."
    nds_ui_b ""

    if declare -f nds_step_start &>/dev/null; then
        nds_step_start "Listing nixosConfigurations"
        mapfile -t hosts < <(nds_flake_list_hosts "$flake_root")
        if [[ ${#hosts[@]} -gt 0 ]]; then
            nds_step_complete "Listing nixosConfigurations (${#hosts[@]} hosts)"
        else
            nds_step_fail "Listing nixosConfigurations"
        fi
    else
        mapfile -t hosts < <(nds_flake_list_hosts "$flake_root")
    fi

    existing="$(nds_feat_cfg_get FLAKE_HOST 2>/dev/null || true)"
    [[ -z "$existing" ]] && existing="${NDS_FLAKE_HOST:-}"

    if [[ ${#hosts[@]} -eq 0 ]]; then
        warn "Could not list nixosConfigurations — enter host name manually."
        nds_aa_ask_hostname FLAKE_HOST "nixosConfigurations host name" "$existing" true
        host="$(nds_feat_cfg_get FLAKE_HOST)"
        [[ -n "$host" ]] || return 1
        nds_feat_cfg_set NETWORK_HOSTNAME "$host"
        return 0
    fi

    if [[ -n "$existing" ]]; then
        if nds_flake_host_in_list "$existing" "${hosts[@]}"; then
            nds_feat_cfg_set FLAKE_HOST "$existing"
            nds_feat_cfg_set NETWORK_HOSTNAME "$existing"
            success "Using nixosConfigurations host from env/config: ${existing}"
            return 0
        fi
        warn "FLAKE_HOST='${existing}' is not in nixosConfigurations — pick from the list."
        nds_feat_cfg_set FLAKE_HOST ""
        existing=""
    fi

    options="$(printf '%s|' "${hosts[@]}")"
    options="${options%|}"
    labels=""
    for host in "${hosts[@]}"; do
        labels+="${host}=${host}|"
    done
    labels="${labels%|}"
    default="${hosts[0]}"

    nds_cfg_section_title "nixosConfigurations hosts"
    nds_aa_ask_numbered_choice FLAKE_HOST "$options" "$labels" "$default" true
    rc=$?
    [[ "$rc" -eq "${NDS_ACTION_BACK:-10}" ]] && return "$rc"

    host="$(nds_feat_cfg_get FLAKE_HOST)"
    nds_feat_cfg_set NETWORK_HOSTNAME "$host"
    return 0
}
