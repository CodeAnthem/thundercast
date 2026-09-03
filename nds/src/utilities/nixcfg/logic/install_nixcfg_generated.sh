#!/usr/bin/env bash
# ==================================================================================================
# nixcfg - committed host module nds_generated.nix (boot + mounts + guest in one file)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-09 | Modified: 2026-09-03
# ==================================================================================================

nds_nixcfg_generated_name() {
    printf 'nds_generated.nix\n'
}

# Description: Print inner attrs of a `{ ... }: { ... }` module (stdout).
_nds_nixcfg_module_inner() {
    local f="$1" line inner started=0
    [[ -f "$f" ]] || return 0
    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$started" != 1 ]]; then
            if [[ "$line" =~ \{[^$'\n']*\}:[[:space:]]*\{[[:space:]]*(.*) ]]; then
                inner="${BASH_REMATCH[1]}"
                if [[ "$inner" == *'}'* ]]; then
                    inner="${inner%\}*}"
                    inner="${inner%"${inner##*[![:space:]]}"}"
                    [[ -n "$inner" ]] && printf '  %s\n' "${inner#"${inner%%[![:space:]]*}"}"
                    return 0
                fi
                started=1
            fi
            continue
        fi
        printf '%s\n' "$line"
    done <"$f" | sed '$ { /^[[:space:]]*}[[:space:]]*$/d; }'
}

# Description: Guest-tools module body when PLATFORM_VM_GUEST_TOOLS is on (skip otherwise).
# Arguments:
# - dest: <String> Write path
_nds_nixcfg_write_guest_module() {
    local dest="$1"
    local virt body=""

    if ! declare -f nds_cfg_true >/dev/null || ! nds_cfg_true PLATFORM_VM_GUEST_TOOLS; then
        return 0
    fi
    virt="$(nds_cfg_get PLATFORM_VM_TYPE 2>/dev/null || true)"
    case "$virt" in
        vmware) body='{ ... }: { virtualisation.vmware.guest.enable = true; }' ;;
        qemu|kvm) body='{ ... }: { services.qemuGuest.enable = true; }' ;;
        hyperv) body='{ ... }: { virtualisation.hypervGuest.enable = true; }' ;;
        virtualbox) body='{ ... }: { virtualisation.virtualbox.guest.enable = true; }' ;;
        *) return 0 ;;
    esac
    printf '%s\n' "$body" > "$dest" || return 1
    nds_install_log "host: guest tools ${virt} → ${dest}"
    return 0
}

# Description: Remove leftover split host modules once nds_generated.nix exists.
_nds_nixcfg_retire_legacy_host_modules() {
    local flake_root="$1" host_dir="$2"
    local f rel
    for f in boot.nix mounts.nix guest.nix; do
        [[ -e "${host_dir}/${f}" ]] || continue
        rel="${host_dir#"${flake_root}/"}/${f}"
        if [[ -n "$flake_root" && -d "${flake_root}/.git" ]]; then
            git -C "$flake_root" rm -f --quiet "$rel" >/dev/null 2>&1 || rm -f "${host_dir}/${f}"
        else
            rm -f "${host_dir}/${f}"
        fi
    done
}

# Description: Write nds_generated.nix = boot (settings) + mounts (target) + guest (settings).
# Arguments:
# - host_dir:   <String> Host directory (…/hosts/…/hostname)
# - hostname:   <String> Host name
# - disk:       <String> Target disk
# - encryption: <String> true | false
# - flake_root: <String> Flake root (for legacy module retirement via git)
# Returns:
# - <Bool> 0 on success
nds_nixcfg_write_generated_host() {
    local host_dir="$1" hostname="$2" disk="$3"
    local encryption="${4:-false}" flake_root="${5:-}"
    local tmpd gen today

    mkdir -p "$host_dir" || return 1
    tmpd="$(mktemp -d)" || return 1
    nds_nixcfg_write_boot_module "${tmpd}/boot.nix" || { rm -rf "$tmpd"; return 1; }
    nds_nixcfg_write_mounts_module "${tmpd}/mounts.nix" "$hostname" "$disk" "$encryption" \
        || { rm -rf "$tmpd"; return 1; }
    _nds_nixcfg_write_guest_module "${tmpd}/guest.nix" || true

    gen="${host_dir}/$(nds_nixcfg_generated_name)"
    today="$(date -u +%Y-%m-%d)"
    {
        printf '%s\n' \
            '# ==================================================================================================' \
            "# NDS - ${hostname}" \
            '# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::' \
            "# Date:          Created: ${today} | Modified: ${today}" \
            '# Description:   NDS generated — do not edit (boot + mounts + guest)' \
            '# ==================================================================================================' \
            '' \
            '{ lib, ... }: {'
        _nds_nixcfg_module_inner "${tmpd}/boot.nix"
        _nds_nixcfg_module_inner "${tmpd}/mounts.nix"
        _nds_nixcfg_module_inner "${tmpd}/guest.nix"
        printf '%s\n' '}'
    } >"$gen" || { rm -rf "$tmpd"; return 1; }
    rm -rf "$tmpd"
    _nds_nixcfg_retire_legacy_host_modules "$flake_root" "$host_dir"
    nds_install_log "host: wrote ${gen#"${flake_root}/"}"
    return 0
}
