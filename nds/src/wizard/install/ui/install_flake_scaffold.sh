#!/usr/bin/env bash
# ==================================================================================================
# NDS - Flake host scaffold prompts
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-05 | Modified: 2026-08-28
# Description:   Interactive existing/new host scaffold; writes AA via nds_aa_ask_*
# ==================================================================================================

# Description: Pipe-joined ids → id=id labels for numbered menus.
# Arguments:
# - options: <String> Pipe-joined ids
# Returns:
# - <String> id=id pairs separated by | (stdout)
_nds_flake_ids_to_choice_labels() {
    local options="$1"
    local option labels=""
    local -a opts=()

    IFS='|' read -ra opts <<< "$options"
    for option in "${opts[@]}"; do
        [[ -n "$option" ]] || continue
        labels="${labels:+$labels|}${option}=${option}"
    done
    printf '%s\n' "$labels"
}

# Description: Prefer worker when present; otherwise the first pipe-joined role.
# Arguments:
# - roles: <String> Pipe-joined role ids
# Returns:
# - <String> Default role id (stdout)
_nds_flake_default_role() {
    local roles="$1"
    case "|${roles}|" in
        *"|worker|"*) printf 'worker\n' ;;
        *) printf '%s\n' "${roles%%|*}" ;;
    esac
}

# Description: Pick existing host or new role+name. Does not write host files.
# Loads .nds/hosts/<name>.recipe or .roles/<role>/nds.sh.
# Arguments:
# - flake_root: <String> Path to the checked-out flake
# - system:     <String|optional> Nix system (default: x86_64-linux)
# Returns:
# - <Int> 0 on success; 1 when no .roles/ or profiles/
nds_flake_role_select() {
    local flake_root="$1"
    local system="${2:-x86_64-linux}"
    local prev_aa="${NDS_CFG_AA_NAME:-}"
    local -A _role_aa=()
    local owned=false rc=0

    if [[ -z "$prev_aa" ]]; then
        nds_cfg_aa_from_store _role_aa
        nds_cfg_aa_bind _role_aa
        owned=true
    fi
    _nds_flake_role_select_body "$flake_root" "$system" || rc=$?
    if [[ "$owned" == true ]]; then
        nds_cfg_aa_to_store _role_aa
        NDS_CFG_AA_NAME="$prev_aa"
    fi
    return "$rc"
}

# Description: Pick existing host or new role+name. Requires AA bind (wrapper binds).
_nds_flake_role_select_body() {
    local flake_root="$1"
    local system="${2:-x86_64-linux}"
    local roles hosts_dir existing default_role host role

    roles="${ _nds_install_flake_discover_roles "$flake_root"; }"
    if [[ -z "$roles" ]]; then
        return 1
    fi

    hosts_dir="${flake_root}/hosts/${system}"
    existing=""
    if [[ -d "$hosts_dir" ]]; then
        existing="$(find "$hosts_dir" -maxdepth 1 -mindepth 1 -type d -printf '%f\n' 2>/dev/null \
            | sort | tr '\n' '|' | sed 's/|$//')"
    fi

    nds_cfg_section_title "Host selection"

    if [[ -n "$existing" ]]; then
        nds_ui_b "Host:"
        nds_aa_ask_numbered_choice SCAFFOLD_MODE \
            "existing|new" \
            "existing=Use an existing host|new=Scaffold a new host from a role" \
            "new"
    else
        nds_feat_cfg_set SCAFFOLD_MODE "new"
    fi

    if nds_feat_cfg_is SCAFFOLD_MODE existing; then
        local first_host
        first_host="${existing%%|*}"
        nds_ui_b "Existing host:"
        nds_aa_ask_numbered_choice FLAKE_HOST "$existing" \
            "${ _nds_flake_ids_to_choice_labels "$existing"; }" "$first_host"
        host="${ nds_feat_cfg_get FLAKE_HOST; }"
        nds_feat_cfg_set NETWORK_HOSTNAME "$host"
        NDS_FLAKE_HOST="$host"
        export NDS_FLAKE_HOST
        nds_flake_load_host_restore "$flake_root" "$host" || true
        return 0
    fi

    default_role="${ _nds_flake_default_role "$roles"; }"
    nds_ui_b "Role:"
    nds_aa_ask_numbered_choice SCAFFOLD_ROLE "$roles" \
        "${ _nds_flake_ids_to_choice_labels "$roles"; }" "$default_role"

    host="${ nds_feat_cfg_get FLAKE_HOST 2>/dev/null || true; }"
    [[ -z "$host" ]] && host="${ nds_feat_cfg_get NETWORK_HOSTNAME 2>/dev/null || true; }"
    if [[ -z "$host" ]]; then
        nds_aa_ask_hostname FLAKE_HOST "New host name" "" true
        host="${ nds_feat_cfg_get FLAKE_HOST; }"
    else
        nds_feat_cfg_set FLAKE_HOST "$host"
    fi

    role="${ nds_feat_cfg_get SCAFFOLD_ROLE; }"
    nds_feat_cfg_set NETWORK_HOSTNAME "$host"
    export NDS_FLAKE_HOST="$host"
    nds_flake_apply_role_nds "$flake_root" "$role"
    return 0
}

# Description: Write hosts/<system>/<name>/ from the selected role (after disk confirm).
# Arguments:
# - flake_root: <String> Leaf checkout
# - system:     <String|optional> Nix system (default: x86_64-linux)
nds_flake_scaffold_apply() {
    local flake_root="$1"
    local system="${2:-x86_64-linux}"
    local host role
    host="${ nds_cfg_get FLAKE_HOST; }"
    role="${ nds_cfg_get SCAFFOLD_ROLE; }"
    [[ -n "$host" && -n "$role" ]] || {
        error "Scaffold apply needs FLAKE_HOST and SCAFFOLD_ROLE"
        return 1
    }
    _nds_install_flake_scaffold_host_folder "$flake_root" "$host" "$role" "$system" || return 1
    export NDS_FLAKE_SOURCE="local"
    export NDS_FLAKE_LOCAL_PATH="$flake_root"
    nds_cfg_set FLAKE_SOURCE "local"
    nds_cfg_set FLAKE_LOCAL_PATH "$flake_root"
    nds_cfg_set FLAKE_HOST "$host"
    nds_cfg_set NETWORK_HOSTNAME "$host"
    log "New host '${host}' scaffolded at ${flake_root}/hosts/${system}/${host}"
    return 0
}

# Description: Two-step host selection against a checked-out flake.
# Arguments:
# - flake_root: <String> Path to the checked-out flake
# - system:     <String|optional> Nix system (default: x86_64-linux)
nds_flake_scaffold_interactive() {
    local flake_root="$1"
    local system="${2:-x86_64-linux}"
    local prev_aa="${NDS_CFG_AA_NAME:-}"
    local -A _scaf_aa=()
    local owned=false

    if [[ -z "$prev_aa" ]]; then
        nds_cfg_aa_from_store _scaf_aa
        nds_cfg_aa_bind _scaf_aa
        owned=true
    fi

    if ! nds_flake_role_select "$flake_root" "$system"; then
        if [[ "$owned" == true ]]; then
            nds_cfg_aa_to_store _scaf_aa
            NDS_CFG_AA_NAME="$prev_aa"
        fi
        return 1
    fi

    if nds_feat_cfg_is SCAFFOLD_MODE new; then
        nds_flake_scaffold_apply "$flake_root" "$system" || {
            if [[ "$owned" == true ]]; then
                nds_cfg_aa_to_store _scaf_aa
                NDS_CFG_AA_NAME="$prev_aa"
            fi
            return 1
        }
    fi

    if [[ "$owned" == true ]]; then
        nds_cfg_aa_to_store _scaf_aa
        NDS_CFG_AA_NAME="$prev_aa"
    fi
    return 0
}
