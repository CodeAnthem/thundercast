#!/usr/bin/env bash
# ==================================================================================================
# NDS - Committed host structure (mounts.nix / boot.nix)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-09 | Modified: 2026-08-19
# Description:   Patch configuration.nix imports; stage committed structural modules for flake eval
# ==================================================================================================

# Description: Filenames that must stay in the flake Git tree (not gitignored).
_nds_install_flake_committed_host_names() {
    printf '%s\n' mounts.nix boot.nix guest.nix opts.nix
}

# Description: Ensure configuration.nix imports committed mounts.nix and boot.nix.
# Arguments:
# - host_dir: <String> Host directory (…/hosts/…/hostname)
_nds_install_ensure_host_imports() {
    local host_dir="$1"
    local cfg="${host_dir}/configuration.nix"
    local tmp

    [[ -f "$cfg" ]] || {
        warn "No configuration.nix in ${host_dir} — skip import patch"
        return 0
    }

    if grep -q './mounts.nix' "$cfg" && grep -q './boot.nix' "$cfg" \
        && ! grep -qE 'mkNdsBoot\.nix|mkRootFs\.nix' "$cfg"; then
        return 0
    fi

    tmp=$(mktemp)
    awk '
        /mkNdsBoot\.nix/ { next }
        /mkRootFs\.nix/ { next }
        /imports = \[/ {
            print
            if (!seen_mounts) { print "    ./mounts.nix"; seen_mounts = 1 }
            if (!seen_boot) { print "    ./boot.nix"; seen_boot = 1 }
            next
        }
        { print }
    ' "$cfg" >"$tmp"
    mv -f "$tmp" "$cfg"
    nds_install_log "host: patched ${cfg} -> ./mounts.nix + ./boot.nix"
    return 0
}

# Description: Write hosts/<name>/guest.nix when PLATFORM_VM_GUEST_TOOLS is on.
# method=host auto-imports sibling .nix files (except disko.nix).
# Arguments:
# - host_dir: <String> Host directory
_nds_install_flake_write_guest_nix() {
    local host_dir="$1"
    local virt out body=""

    [[ -d "$host_dir" ]] || return 0
    if ! declare -f nds_cfg_true >/dev/null || ! nds_cfg_true PLATFORM_VM_GUEST_TOOLS; then
        return 0
    fi

    virt="$(nds_cfg_get PLATFORM_VM_TYPE 2>/dev/null || true)"
    out="${host_dir}/guest.nix"
    case "$virt" in
        vmware)
            body='{ ... }: { virtualisation.vmware.guest.enable = true; }'
            ;;
        qemu|kvm)
            body='{ ... }: { services.qemuGuest.enable = true; }'
            ;;
        hyperv)
            body='{ ... }: { virtualisation.hypervGuest.enable = true; }'
            ;;
        virtualbox)
            body='{ ... }: { virtualisation.virtualbox.guest.enable = true; }'
            ;;
        *)
            return 0
            ;;
    esac

    printf '%s\n' "$body" > "$out" || return 1
    nds_install_log "host: wrote ${out} (guest tools ${virt})"
    return 0
}

# Description: git add committed structural modules so flake eval sees them.
# Arguments:
# - flake_root: <String> Flake checkout root
# - host_dir:   <String> Host directory
_nds_install_flake_git_stage_committed_files() {
    local flake_root="$1" host_dir="$2"
    local log rel f
    local -a files=()

    [[ -d "${flake_root}/.git" ]] || return 0

    for f in $(_nds_install_flake_committed_host_names); do
        [[ -f "${host_dir}/${f}" ]] && files+=("${host_dir}/${f}")
    done
    [[ -f "${host_dir}/configuration.nix" ]] && files+=("${host_dir}/configuration.nix")
    [[ ${#files[@]} -gt 0 ]] || return 0

    log="${NDS_INSTALL_DETAIL_LOG:-/tmp/nds_install.log}"
    {
        printf '\n=== git add committed host structure (mounts.nix / boot.nix / guest.nix) ===\n'
    } >>"$log"

    for rel in "${files[@]}"; do
        rel="${rel#"${flake_root}/"}"
        git -C "$flake_root" add -f "$rel" >>"$log" 2>&1 || return 1
        nds_install_log "flake: git add -f ${rel}"
    done
    return 0
}
