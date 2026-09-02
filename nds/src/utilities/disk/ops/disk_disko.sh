#!/usr/bin/env bash
# ==================================================================================================
# disk utility - Disko apply
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-02 | Modified: 2026-09-02
# ==================================================================================================

_disk_diskoGenerateParams() {
    local out="$1" disk="$2" fs_type="$3" swap_mib="$4" separate_home="$5" home_size="$6" enc="$7" unlock="$8"
    local boot_loader="${9:-systemd-boot}"
    [[ -n "$out" && -n "$disk" ]] || { err "Missing disko params"; return 1; }

    cat >"$out" <<NIX
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
NIX
}

_disk_diskoTemplate() {
    printf '%s\n' "${_DISK_DIR}/templates/disko/default.nix"
}

# Description: Run disko --mode disko on a config file.
disk_diskoRun() {
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

# Description: Apply Disko (user file or template+params).
# Arguments:
# - disk, fs_type, swap_mib, separate_home, home_size, enc, unlock,
#   user_file, boot_loader, work_dir
disk_diskoApply() {
    local disk="$1" fs_type="$2" swap_mib="$3" separate_home="$4" home_size="$5" enc="$6" unlock="$7"
    local user_file="${8:-}" boot_loader="${9:-systemd-boot}" work_dir="${10:-}"
    local tmpl rc=0

    export NIX_CONFIG="experimental-features = nix-command flakes"
    [[ -n "$work_dir" ]] || work_dir="${TMPDIR:-/tmp}/disk_disko.$$"

    if [[ -n "$user_file" ]]; then
        warn "Using user-provided disko file: $user_file"
        disk_diskoRun "$user_file" || rc=$?
    else
        tmpl=${ _disk_diskoTemplate; }
        [[ -f "$tmpl" ]] || { err "Disko template missing: $tmpl"; return 1; }
        mkdir -p "$work_dir"
        cp "$tmpl" "${work_dir}/default.nix"
        _disk_diskoGenerateParams \
            "${work_dir}/params.nix" "$disk" "$fs_type" "$swap_mib" \
            "$separate_home" "$home_size" "$enc" "$unlock" "$boot_loader" || return 1
        (
            cd "$work_dir" || exit 1
            disk_diskoRun default.nix
        ) || rc=$?
    fi
    return "$rc"
}
