#!/usr/bin/env bash
# ==================================================================================================
# NDS - Flake tools — prepare, scaffold, detect disko
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-01 | Modified: 2026-08-28
# Description:   Flake prepare, disko detect, host-folder scaffold (no interactive picker)
# ==================================================================================================

# Description: Export NDS_FLAKE_* env vars from settings answers so the
# install pipeline (nds_nixos_install_flake) can read them. Also mirrors the
# chosen host into NETWORK_HOSTNAME. Pass a source ("remote"|"local") to override
# FLAKE_SOURCE — remoteAction always uses "remote".
# Arguments:
# - source: <String|optional> "remote" | "local" (default: read FLAKE_SOURCE)
nds_flake_prepare() {
    local source="${1:-}"

    local host net_host repo_url local_path install_path host_dir hw_placement disk_strategy install_mode target_ip
    host=$(nds_cfg_get "FLAKE_HOST")
    net_host=$(nds_cfg_get "NETWORK_HOSTNAME")
    repo_url=$(nds_cfg_get "FLAKE_REPO_URL")
    local_path=$(nds_cfg_get "FLAKE_LOCAL_PATH")

    # Derive source from whichever location field is populated (robust to env
    # overrides and the auto-detecting single-location prompt).
    if [[ -z "$source" || "$source" == "none" ]]; then
        if [[ -n "$repo_url" ]]; then source="remote"
        elif [[ -n "$local_path" ]]; then source="local"
        else source="$(nds_cfg_get "FLAKE_SOURCE")"; fi
        [[ -z "$source" ]] && source="remote"
    fi
    install_path=$(nds_cfg_get "FLAKE_INSTALL_PATH")
    host_dir=$(nds_cfg_get "FLAKE_HOST_DIR")
    hw_placement=$(nds_cfg_get "FLAKE_HARDWARE_PLACEMENT")
    disk_strategy=$(nds_cfg_get "DISK_STRATEGY")
    install_mode=$(nds_cfg_get "INSTALL_MODE")
    target_ip=$(nds_cfg_get "REMOTE_TARGET_IP")

    if [[ -z "$host" && -n "$net_host" ]]; then
        host="$net_host"
        nds_cfg_set "FLAKE_HOST" "$host"
    elif [[ -n "$host" ]]; then
        nds_cfg_set "NETWORK_HOSTNAME" "$host"
    fi
    export NDS_FLAKE_HOST="$host"
    export NDS_FLAKE_SOURCE="$source"
    export NDS_FLAKE_REPO_URL="$repo_url"
    export NDS_FLAKE_LOCAL_PATH="$local_path"
    export NDS_FLAKE_INSTALL_PATH="$install_path"
    export NDS_FLAKE_HOST_DIR="$host_dir"
    export NDS_HARDWARE_PLACEMENT="$hw_placement"
    export NDS_DISK_STRATEGY="$disk_strategy"
    export NDS_INSTALL_MODE="${install_mode:-local}"
    export NDS_REMOTE_TARGET_IP="$target_ip"

    # Console copy lives on the Ready-to-install screen; keep a stamp in the log only.
    nds_install_log "Flake target: ${install_path}#${host} (source: ${source}, mode: ${NDS_INSTALL_MODE})"
}

# Description: Inspect the flake (local path or remote clone) and apply a disko
# disk strategy if the flake declares one. Best-effort — silently skips when no
# disko config is found or the source is unavailable.
nds_flake_detect_disko() {
    local host host_dir local_path repo_url probe_root
    host=$(nds_cfg_get "FLAKE_HOST")
    host_dir=$(nds_cfg_get "FLAKE_HOST_DIR")
    host_dir="${host_dir:-hosts/x86_64-linux}"
    local_path=$(nds_cfg_get "FLAKE_LOCAL_PATH")
    repo_url=$(nds_cfg_get "FLAKE_REPO_URL")

    if [[ -n "$local_path" ]]; then
        [[ -d "$local_path" ]] && nds_preflight_apply_disko_strategy "$local_path" "$host" "$host_dir"
    elif [[ -n "$repo_url" ]]; then
        probe_root=$(nds_preflight_probe_flake "$repo_url") || return 0
        nds_preflight_apply_disko_strategy "$probe_root" "$host" "$host_dir"
    fi
}

# Description: Absolute path to the NDS install templates directory.
# Returns:
# - <String> templates dir (stdout)
_nds_install_flake_templates_dir() {
    local bootstrap_dir="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
    echo "${bootstrap_dir}/install/templates/scaffold"
}

# Description: Discover installable roles from .roles/<id>/ (opts.nix) or profiles/.
# Arguments:
# - flake_root: <String> Path to the checked-out flake
# Returns:
# - <String> Pipe-joined role names (stdout), empty when none found
_nds_install_flake_discover_roles() {
    local flake_root="$1"
    local roles_dir="${flake_root}/.roles"
    local profiles_dir="${flake_root}/profiles"
    local name names=""

    if [[ -d "$roles_dir" ]]; then
        while IFS= read -r name; do
            [[ -f "${roles_dir}/${name}/opts.nix" ]] || continue
            [[ "$name" == "toolkit" ]] && continue
            names="${names:+$names|}${name}"
        done < <(find "$roles_dir" -maxdepth 1 -mindepth 1 -type d -printf '%f\n' 2>/dev/null | sort)
        echo "$names"
        return 0
    fi

    if [[ ! -d "$profiles_dir" ]]; then
        echo ""
        return 0
    fi

    find "$profiles_dir" -maxdepth 1 -name '*.nix' -printf '%f\n' 2>/dev/null | \
        sed -e 's/-eval\.nix$//' -e 's/\.nix$//' | sort -u | \
        grep -Ev '^(options|control-toolkit|toolkit)$' | tr '\n' '|' | sed 's/|$//'
}

# Description: Resolve a stable /dev/disk/by-id path for a block device, falling
# back to the raw device node when no by-id link is found.
# Arguments:
# - disk: <String> Device node (e.g. /dev/sda)
# Returns:
# - <String> Resolved device path (stdout)
_nds_install_flake_disk_by_id() {
    local disk="$1"
    local target link
    [[ -z "$disk" ]] && { echo "$disk"; return 0; }
    target="$(readlink -f "$disk" 2>/dev/null || echo "$disk")"

    if [[ -d /dev/disk/by-id ]]; then
        for link in /dev/disk/by-id/*; do
            [[ -e "$link" ]] || continue
            if [[ "$(readlink -f "$link" 2>/dev/null)" == "$target" ]]; then
                echo "$link"
                return 0
            fi
        done
    fi
    echo "$disk"
}

# Description: Scaffold a new host folder (opts.nix, configuration.nix,
# mounts.nix; disko.nix + import only when DISK_STRATEGY is disko or flake).
# Arguments:
# - flake_root: <String> Path to the checked-out flake
# - hostname:   <String> New host name
# - role:       <String> Role id (.roles/<id> or profiles/<id>.nix)
# - system:     <String|optional> Nix system (default: x86_64-linux)
# Returns:
# - <Int> 0 on success, non-zero on failure
_nds_install_flake_scaffold_host_folder() {
    local flake_root="$1"
    local hostname="$2"
    local role="$3"
    local system="${4:-x86_64-linux}"
    local tmpl_dir host_dir
    tmpl_dir="$(_nds_install_flake_templates_dir)"
    host_dir="${flake_root}/hosts/${system}/${hostname}"

    if [[ -z "$hostname" || -z "$role" ]]; then
        error "Scaffold requires a hostname and a role"
        return 1
    fi

    if [[ -d "$host_dir" ]]; then
        warn "Host folder already exists: $host_dir"
        nds_install_ui_confirm_scaffold_overwrite "$host_dir" || return 1
    fi

    mkdir -p "$host_dir" || { error "Cannot create $host_dir"; return 1; }

    if [[ -f "${flake_root}/.roles/${role}/opts.nix" ]]; then
        printf '(import ../../../.roles/%s/opts.nix)\n' "$role" > "${host_dir}/opts.nix" || return 1
    else
        sed "s/__ROLE__/${role}/g" \
            "${tmpl_dir}/host-opts.nix.tmpl" > "${host_dir}/opts.nix" || return 1
    fi

    local ip gateway mask prefix interface dns1 dns2 nameservers state_version method
    ip=$(nds_cfg_get "NETWORK_IP")
    gateway=$(nds_cfg_get "NETWORK_GATEWAY")
    mask=$(nds_cfg_get "NETWORK_MASK")
    method=$(nds_cfg_get "NETWORK_METHOD")
    interface=$(nds_cfg_get "NETWORK_INTERFACE")
    interface="${interface:-eth0}"
    dns1=$(nds_cfg_get "NETWORK_DNS_PRIMARY")
    dns2=$(nds_cfg_get "NETWORK_DNS_SECONDARY")
    state_version="$(_nds_nixcfg_state_version)" || true
    if [[ ! "$state_version" =~ ^[0-9]+\.[0-9]+$ ]]; then
        error "Cannot determine system.stateVersion (set NDS_NIXOS_STATE_VERSION=MAJOR.MINOR)"
        return 1
    fi

    prefix="24"
    [[ -n "$mask" ]] && prefix="$(validate_mask_to_prefix "$mask")"

    nameservers=""
    [[ -n "$dns1" ]] && nameservers="\"${dns1}\""
    [[ -n "$dns2" ]] && nameservers="${nameservers:+$nameservers }\"${dns2}\""

    sed -e "s/__HOSTNAME__/${hostname}/g" \
        -e "s/__DATE__/$(date -u +%Y-%m-%d)/g" \
        "${tmpl_dir}/host-mounts.nix.tmpl" > "${host_dir}/mounts.nix" || return 1

    local cfg_tmpl
    if [[ "${method,,}" == "static" ]]; then
        cfg_tmpl="${tmpl_dir}/host-configuration.nix.tmpl"
    else
        cfg_tmpl="${tmpl_dir}/host-configuration-dhcp.nix.tmpl"
    fi

    sed -e "s/__HOSTNAME__/${hostname}/g" \
        -e "s/__IP__/${ip}/g" \
        -e "s/__GATEWAY__/${gateway}/g" \
        -e "s/__PREFIX__/${prefix}/g" \
        -e "s/__INTERFACE__/${interface}/g" \
        -e "s/__NAMESERVERS__/${nameservers}/g" \
        -e "s/__STATE_VERSION__/${state_version}/g" \
        "$cfg_tmpl" > "${host_dir}/configuration.nix" || return 1

    local disk disk_by_id fs_type swap_mib encryption enc_bool disk_strategy
    disk=$(nds_cfg_get "DISK_TARGET")
    fs_type=$(nds_cfg_get "DISK_FS_TYPE")
    fs_type="${fs_type:-ext4}"
    swap_mib=$(nds_cfg_get "DISK_SWAP_SIZE_MIB")
    swap_mib="${swap_mib:-0}"
    encryption=$(nds_cfg_get "ENCRYPTION")
    enc_bool="false"
    [[ "$encryption" == "true" ]] && enc_bool="true"
    disk_by_id="$(_nds_install_flake_disk_by_id "$disk")"
    disk_strategy="$(nds_cfg_get "DISK_STRATEGY")"
    disk_strategy="${disk_strategy:-nds}"

    case "${disk_strategy,,}" in
        disko|flake)
            sed -e "s|__DEVICE__|${disk_by_id}|g" \
                -e "s/__FSTYPE__/${fs_type}/g" \
                -e "s/__SWAPMIB__/${swap_mib}/g" \
                -e "s/__ENCRYPT__/${enc_bool}/g" \
                "${tmpl_dir}/host-disko.nix.tmpl" > "${host_dir}/disko.nix" || return 1
            if ! grep -q './disko.nix' "${host_dir}/configuration.nix"; then
                sed -i '/\.\/opts\.nix/a\    ./disko.nix' "${host_dir}/configuration.nix" || return 1
            fi
            ;;
        *)
            rm -f "${host_dir}/disko.nix"
            ;;
    esac

    _nds_install_flake_write_guest_nix "$host_dir" || true

    log "Scaffolded host folder: $host_dir (role=${role})"
    return 0
}

# Description: Locate the remoteAction script. Leaf .nds/action.sh is an override;
# otherwise load thundercast's .nds/action.sh from the leaf flake.lock input.
# Arguments:
# - flake_root: <String> Path to the checked-out flake
# Returns:
# - <String> Path to the action script (stdout), exit 1 if none found
nds_flake_find_action_script() {
    local flake_root="$1"
    local candidate src

    for candidate in \
        "${flake_root}/.nds/action.sh" \
        "${flake_root}/nds-action/setup.sh" \
        "${flake_root}/.nds/setup.sh"; do
        if [[ -f "$candidate" ]]; then
            echo "$candidate"
            return 0
        fi
    done

    src="$(nds_flake_resolve_thundercast_src "$flake_root")" || return 1
    candidate="${src}/.nds/action.sh"
    if [[ -f "$candidate" ]]; then
        echo "$candidate"
        return 0
    fi
    return 1
}
