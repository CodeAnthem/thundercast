#!/usr/bin/env bash
# ==================================================================================================
# NDS - Committed host structure (nds_generated.nix)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-09 | Modified: 2026-08-28
# Description:   NDS-owned boot/mounts/guest in one file; stage for flake eval
# ==================================================================================================

_nds_install_generated_name() {
    printf 'nds_generated.nix\n'
}

# Description: Filenames that must stay in the flake Git tree (not gitignored).
_nds_install_flake_committed_host_names() {
    printf '%s\n' nds_generated.nix opts.nix
}

# Description: Print inner attrs of a `{ ... }: { ... }` module (stdout).
_nds_install_nix_inner() {
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

# Description: Confirm committed nds_generated.nix has fileSystems.
# Sibling .nix files are auto-imported by fileStore method=host.
# Arguments:
# - host_dir: <String> Host directory (…/hosts/…/hostname)
_nds_install_ensure_host_imports() {
    local host_dir="$1"
    local gen

    [[ -d "$host_dir" ]] || {
        error "Host directory missing: ${host_dir}"
        return 1
    }
    [[ -f "${host_dir}/configuration.nix" ]] || {
        warn "No configuration.nix in ${host_dir} — skip structural check"
        return 0
    }
    gen="${host_dir}/$(_nds_install_generated_name)"
    [[ -f "$gen" ]] || {
        error "nds_generated.nix missing: ${gen}"
        return 1
    }
    grep -qE 'fileSystems|by-uuid|by-label' "$gen" || {
        error "nds_generated.nix missing fileSystems: ${gen}"
        return 1
    }
    return 0
}

# Description: Guest-tools module body when PLATFORM_VM_GUEST_TOOLS is on.
# Arguments:
# - host_dir: <String> Host directory
# - dest:     <String|optional> Write path (default: skip file, used by generated writer)
_nds_install_flake_write_guest_nix() {
    local host_dir="$1"
    local dest="${2:-}"
    local virt body=""

    [[ -d "$host_dir" ]] || return 0
    if ! declare -f nds_cfg_true >/dev/null || ! nds_cfg_true PLATFORM_VM_GUEST_TOOLS; then
        return 0
    fi

    virt="$(nds_cfg_get PLATFORM_VM_TYPE 2>/dev/null || true)"
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

    [[ -n "$dest" ]] || return 0
    printf '%s\n' "$body" > "$dest" || return 1
    nds_install_log "host: guest tools ${virt} → ${dest}"
    return 0
}

# Description: Remove leftover split host modules after nds_generated.nix is written.
_nds_install_retire_legacy_host_modules() {
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

# Description: Merge boot + mounts + guest into nds_generated.nix (NDS-owned).
# Arguments:
# - host_dir:     <String> Host directory
# - disk:         <String> Target disk
# - hostname:     <String> Host name
# - flake_root:   <String> Flake root
# - encryption:   <String> true|false
# - host_dir_rel: <String> Hosts prefix
_nds_install_write_generated_nix() {
    local host_dir="$1" disk="$2" hostname="$3" flake_root="$4"
    local encryption="${5:-false}" host_dir_rel="${6:-hosts/x86_64-linux}"
    local tmpd gen today

    tmpd="$(mktemp -d)" || return 1
    nds_nixcfg_write_boot_module "${tmpd}/boot.nix" || { rm -rf "$tmpd"; return 1; }
    _nds_install_write_mounts_nix "$disk" "$hostname" "$flake_root" "$encryption" \
        "$host_dir_rel" "${tmpd}/mounts.nix" || { rm -rf "$tmpd"; return 1; }
    _nds_install_flake_write_guest_nix "$host_dir" "${tmpd}/guest.nix" || true

    gen="${host_dir}/$(_nds_install_generated_name)"
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
        _nds_install_nix_inner "${tmpd}/boot.nix"
        _nds_install_nix_inner "${tmpd}/mounts.nix"
        _nds_install_nix_inner "${tmpd}/guest.nix"
        printf '%s\n' '}'
    } >"$gen" || { rm -rf "$tmpd"; return 1; }
    rm -rf "$tmpd"
    _nds_install_retire_legacy_host_modules "$flake_root" "$host_dir"
    nds_install_log "host: wrote ${gen#"${flake_root}/"}"
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
        printf '\n=== git add committed host structure (nds_generated.nix) ===\n'
    } >>"$log"

    for rel in "${files[@]}"; do
        rel="${rel#"${flake_root}/"}"
        git -C "$flake_root" add -f "$rel" >>"$log" 2>&1 || return 1
        nds_install_log "flake: git add -f ${rel}"
    done
    return 0
}
