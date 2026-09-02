# ==================================================================================================
# Thundercast - cluster nodes (roles as templates; domain hooks stay on the leaf)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-19 | Modified: 2026-08-28
# ==================================================================================================

tcast_nodes_roles() {
    local leaf
    leaf="$(tcast_leaf)"
    if [[ -d "${leaf}/.roles" ]]; then
        find "${leaf}/.roles" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | sort
    fi
}

tcast_nodes_role_exists() {
    local leaf="$1" role="$2"
    [[ -f "${leaf}/.roles/${role}/opts.nix" ]]
}

tcast_nodes_host_dirs() {
    local leaf
    leaf="$(tcast_leaf)"
    find "${leaf}/hosts" -mindepth 2 -maxdepth 2 -type d -printf '%f\n' 2>/dev/null | sort -u
}

tcast_nodes_host_dir() {
    local host="$1" leaf sys
    leaf="$(tcast_leaf)"
    for sys in "${leaf}/hosts"/*; do
        [[ -d "${sys}/${host}" ]] && { printf '%s\n' "${sys}/${host}"; return 0; }
    done
    return 1
}

# Description: Scaffold hosts/<system>/<hostname> from a role template.
tcast_nodes_scaffold() {
    local hostname="$1" role="$2" system="${3:-x86_64-linux}"
    local leaf host_dir today
    leaf="$(tcast_leaf)"
    tcast_nodes_role_exists "$leaf" "$role" || tcast_die "unknown role: ${role}"
    host_dir="${leaf}/hosts/${system}/${hostname}"
    if [[ -d "$host_dir" ]]; then
        tcast_die "host folder already exists: ${host_dir}"
    fi
    mkdir -p "$host_dir"
    today="$(date -u +%Y-%m-%d)"
    printf '(import ../../../.roles/%s/opts.nix)\n' "$role" > "${host_dir}/opts.nix"
    cat > "${host_dir}/nds_generated.nix" << EOF
# ==================================================================================================
# Date:          Created: ${today} | Modified: ${today}
# Description:   NDS generated — do not edit (boot + mounts)
# ==================================================================================================

{ lib, ... }: {
  boot.loader.grub = {
    enable = lib.mkForce true;
    device = lib.mkForce "/dev/sda";
  };
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };
  fileSystems."/boot" = {
    device = "/dev/disk/by-label/boot";
    fsType = "vfat";
    neededForBoot = true;
    options = [ "fmask=0077" "dmask=0077" ];
  };
}
EOF
    cat > "${host_dir}/configuration.nix" << EOF
# ==================================================================================================
# Date:          Created: ${today} | Modified: ${today}
# Description:   Scaffolded by toolkit (role ${role})
# ==================================================================================================

{ config, lib, pkgs, inputs, ... }: {
  imports = [
    (inputs.thundercast.nixosModules.host { hostDir = ./.; })
  ];

  networking.hostName = "${hostname}";
  system.stateVersion = "24.11";
}
EOF
    tcast_register_host_set "$hostname" role "$role"
    tcast_register_host_set "$hostname" system "$system"
    tcast_register_host_set "$hostname" scaffolded_at "$(tcast_now)"
    mkdir -p "${leaf}/.nds/hosts"
    cat > "${leaf}/.nds/hosts/${hostname}.recipe" << EOF
# tc-recipe v1
[flake]
FLAKE_HOST="${hostname}"
FLAKE_HOST_DIR="hosts/${system}"
SCAFFOLD_MODE="existing"
EOF
    tcast_info "scaffolded ${host_dir} (role=${role})"
}

tcast_nodes_enroll_age() {
    local host="$1" pub="$2"
    [[ "$pub" == age1* ]] || tcast_die "need an age1… public key"
    tcast_register_host_set "$host" age_pub "$pub"
    tcast_register_host_set "$host" enrolled_at "$(tcast_now)"
    tcast_register_meta_set last_enrolled_host "$host"
    tcast_register_meta_set last_enrolled_at "$(tcast_now)"
    tcast_register_scope_add_member host "$host"
    tcast_sops_write_policy
}
