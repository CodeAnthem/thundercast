#!/usr/bin/env bash
# ==================================================================================================
# NDS - Open the install flake (leaf) with write access for git-pushing composers
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-20 | Modified: 2026-09-03
# Description:   Compose helper for addFleetHost, toolkit, remoteAction (not installFlake).
# ==================================================================================================

# Description: Clone the install flake with write access; set NDS_FLAKE_PROBE_DIR.
# Injects leaf presets (.nds/) and switches DISK_STRATEGY when the host ships disko.nix.
# Returns:
# - <Bool> 0 on success
nds_install_open_leaf() {
    local host_dir probe_dir injected=0 parsed host owner repo key_path repo_url

    repo_url="${ nds_cfg_get FLAKE_REPO_URL; }"
    if [[ -z "$repo_url" ]]; then
        error "FLAKE_REPO_URL is required (install flake Git URL)"
        return 1
    fi

    nds_flake_prepare remote
    nds_app_actionManager_logic_callFeature nds_git_access_run \
        "FLAKE_REPO_URL=${repo_url}" \
        write \
        "This action git-pushes host files to the install flake." || return 1

    host_dir="${ nds_cfg_get FLAKE_HOST_DIR; }"
    host_dir="${host_dir:-hosts/x86_64-linux}"

    nds_step_start_spin "Cloning install flake"
    if ! probe_dir=$(nds_flake_probe_clone "$repo_url"); then
        nds_step_fail "Install flake clone"
        return 1
    fi
    nds_step_complete "Install flake cloned"
    export NDS_FLAKE_PROBE_DIR="$probe_dir"

    nds_preset_inject_from_flake "$probe_dir" || true
    injected=$NDS_PRESET_INJECT_COUNT
    if [[ "${injected:-0}" -gt 0 ]]; then
        info "Loaded ${injected} custom preset(s) from flake .nds/"
    fi

    nds_flake_apply_disko_strategy "$probe_dir" "${ nds_cfg_get FLAKE_HOST; }" "$host_dir"

    nds_step_start_spin "Verifying leaf write access"
    if nds_install_flake_probe_leaf_write "$probe_dir"; then
        nds_step_complete "Leaf write access OK"
    else
        nds_step_cancel
        warn "This key cloned the leaf but cannot push (GitHub deploy keys are read-only unless Allow write access is on)."
        parsed="$(_nds_git_url_parse "$(_nds_git_url_toSsh "$repo_url")" 2>/dev/null || true)"
        IFS=$'\t' read -r host owner repo <<< "$parsed"
        if [[ -z "$host" || -z "$owner" || -z "$repo" ]]; then
            error "Cannot parse FLAKE_REPO_URL for write-key wizard"
            return 1
        fi
        while true; do
            nds_git_auth_wizard_step_repo "$host" "$owner" "$repo" write \
                "Need a key that can push host files to this repository." || return $?
            nds_step_start_spin "Verifying leaf write access"
            if nds_install_flake_probe_leaf_write "$probe_dir"; then
                nds_step_complete "Leaf write access OK"
                break
            fi
            nds_step_cancel
            warn "Still cannot push — generate a write deploy key or paste an account key."
        done
    fi

    if declare -f nds_git_register_keys_in_dir &>/dev/null; then
        nds_git_register_keys_in_dir "/root/.ssh"
        nds_git_register_keys_in_dir "$PWD"
        while IFS= read -r key_path; do
            [[ -n "$key_path" && -f "$key_path" ]] || continue
            nds_git_register_keys_in_dir "$(dirname "$key_path")"
        done < <(nds_git_keys_list 2>/dev/null || true)
    fi

    nds_git_ensure_flake_closure_access "$probe_dir" "$repo_url" || return 1
    return 0
}
