#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-11-03 | Modified: 2026-08-16
# Description:   Disko-based partitioning workflow (template+params or user file)
# Feature:       Generate params.nix and apply a flexible disko template; or run user-provided file
# ==================================================================================================

# ----------------------------------------------------------------------------------
# PARAM GENERATION (from arguments)
# ----------------------------------------------------------------------------------

_nds_install_partition_disko_generate_params() {
    local out="$1" disk="$2" fs_type="$3" swap_mib="$4" separate_home="$5" home_size="$6" enc="$7" unlock="$8"
    local boot_loader="${9:-${NDS_CTX_BOOT_LOADER:-systemd-boot}}"
    [[ -n "$out" && -n "$disk" ]] || { error "Missing params"; return 1; }

    cat >"$out" <<EOF
{
  disk = "${disk}";
  fsType = "${fs_type}";
  encrypt = ${enc};
  unlockMode = "${unlock}";
  swapSize = ${swap_mib};
  separateHome = ${separate_home};
  homeSize = "${home_size}";
  bootLoader = "${boot_loader}";
}
EOF
}

# ----------------------------------------------------------------------------------
# TEMPLATE SELECTION
# ----------------------------------------------------------------------------------
_nds_install_partition_disko_pick_template() {
    echo "${SCRIPT_DIR}/install/templates/disko/default.nix"
}

# Description: Run disko --mode disko on a config file.
# Prefer PATH, then ISO/channel <nixpkgs>, then github:nix-community/disko.
# Arguments:
# - config: <String> Disko Nix file
_nds_install_partition_disko_run() {
    local config_file="$1"
    local out=""

    if command -v disko >/dev/null 2>&1; then
        disko --mode disko "$config_file"
        return $?
    fi
    if command -v nix-build >/dev/null 2>&1 && [[ "${NIX_PATH:-}" == *nixpkgs* ]]; then
        if out=$(nix-build --no-out-link '<nixpkgs>' -A disko); then
            out=$(printf '%s\n' "$out" | grep -E '^/nix/store/' | tail -1 || true)
            if [[ -n "$out" && -x "${out}/bin/disko" ]]; then
                "${out}/bin/disko" --mode disko "$config_file"
                return $?
            fi
        fi
    fi
    nix run github:nix-community/disko -- --mode disko "$config_file"
}

# ----------------------------------------------------------------------------------
# APPLY DISKO
# ----------------------------------------------------------------------------------
_nds_install_partition_disko_apply() {
    local disk="$1" fs_type="$2" swap_mib="$3" separate_home="$4" home_size="$5" enc="$6" unlock="$7" user_file="$8"
    local tmpl work_dir rc=0

    export NIX_CONFIG="experimental-features = nix-command flakes"

    if [[ -n "$user_file" ]]; then
        warn "Using user-provided disko file: $user_file"
        _nds_install_partition_disko_run "$user_file" || rc=$?
    else
        tmpl=$(_nds_install_partition_disko_pick_template)
        [[ -f "$tmpl" ]] || { error "Disko template missing: $tmpl"; return 1; }
        work_dir="${NDS_RUNTIME_DIR:-/tmp}/disko"
        mkdir -p "$work_dir"
        cp "$tmpl" "${work_dir}/default.nix"
        _nds_install_partition_disko_generate_params \
            "${work_dir}/params.nix" "$disk" "$fs_type" "$swap_mib" \
            "$separate_home" "$home_size" "$enc" "$unlock" \
            "${NDS_CTX_BOOT_LOADER:-systemd-boot}" || return 1

        (
            cd "$work_dir" || exit 1
            _nds_install_partition_disko_run default.nix
        ) || rc=$?
    fi

    if declare -f nds_install_diag_after_partition &>/dev/null; then
        nds_install_diag_after_partition "$disk"
    fi

    return "$rc"
}
