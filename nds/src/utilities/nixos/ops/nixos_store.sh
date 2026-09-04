#!/usr/bin/env bash
# ==================================================================================================
# nixos - Nix store helpers (live ISO vs install disk)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-07 | Modified: 2026-09-04
# Description:   Chroot store on mounted /mnt during install; activate profile and bootloader
# ==================================================================================================

# Description: Mounted target root (default /mnt).
# Returns:
# - <String> path (stdout)
nixos_targetRoot() {
    printf '%s\n' "${NDS_NIX_TARGET_ROOT:-/mnt}"
}

# Description: Free space in MB on the active Nix store (/nix/store on live ISO).
# Returns:
# - <Int> megabytes free (stdout), 0 when unknown
nixos_storeFreeMb() {
    df -BM /nix/store 2>/dev/null | awk 'NR==2 { gsub(/M/, "", $4); print $4 + 0 }'
}

# Description: Ensure the live ISO Nix store can accept small derivations.
# The overlay tmpfs fills after a failed flake build; reboot if GC cannot recover.
# Arguments:
# - need_mb: <Int> Minimum free megabytes (default 64)
nixos_ensureLiveStoreSpace() {
    local need_mb="${1:-64}"
    local free

    free=$(nixos_storeFreeMb)
    if [[ "${free:-0}" -ge "$need_mb" ]]; then
        return 0
    fi
    warn "Live ISO Nix store is low (${free:-0} MB). Collecting garbage…"
    nix-collect-garbage -d >/dev/null 2>&1 || true
    free=$(nixos_storeFreeMb)
    if [[ "${free:-0}" -ge "$need_mb" ]]; then
        log "ISO Nix store recovered to ${free} MB"
        return 0
    fi
    error "Live ISO Nix store is full (${free:-0} MB free)."
    error "Reboot the installer ISO and rerun — a failed install fills the tmpfs overlay."
    return 1
}

# Description: Legacy flat scratch store (pre-5.14.3 builds only).
# Returns:
# - <String> store path (stdout)
_nixos_scratchStorePath() {
    printf '%s/var/nds-build-store\n' "$(nixos_targetRoot)"
}

# Description: True when the install target root filesystem is mounted.
# Returns:
# - <Bool> 0 when ready for chroot store builds
_nixos_targetRootMounted() {
    [[ "${NDS_NIX_INSTALL_STORE_FORCE:-}" == "1" ]] && return 0
    local root
    root=$(nixos_targetRoot)
    mountpoint -q "$root" 2>/dev/null
}

# Description: Chroot store URI for install-time nix/nixos-install (e.g. /mnt).
# Returns:
# - <String> store URI (stdout), non-zero when ISO store should be used
nixos_installStoreUri() {
    local root free_mb

    free_mb=$(nixos_storeFreeMb)
    [[ "${free_mb:-0}" -lt 4096 ]] || return 1

    root=$(nixos_targetRoot)
    _nixos_targetRootMounted || return 1

    mkdir -p "${root}/nix/store"
    nixos_ensureStoreReady "$root"
    printf '%s\n' "$root"
}

# Description: Optional `--store` arguments for nix CLI (stdout, one arg per line).
nixos_installStoreArgs() {
    local uri
    uri=$(nixos_installStoreUri 2>/dev/null) || return 0
    printf '%s\n' --store "$uri"
}

# Description: Initialize a chroot or scratch Nix store if needed.
# Arguments:
# - store_uri: <String> Chroot root (/mnt) or scratch store path
nixos_ensureStoreReady() {
    local store_uri="$1"

    [[ -n "$store_uri" ]] || return 0
    if nix --store "$store_uri" store ping &>/dev/null 2>&1; then
        return 0
    fi

    if [[ "$store_uri" == "$(nixos_targetRoot)" ]]; then
        debug "Seeding Nix tools into target store (${store_uri}/nix/store)"
    else
        debug "Initializing scratch Nix store at ${store_uri}"
    fi
    nix copy --to "$store_uri" "$(command -v nix)" "$(command -v nixos-install)" 2>/dev/null || true
}

# Description: Append `store = …` to NIX_CONFIG when live ISO store is nearly full.
# Arguments:
# - base_config: <String> Existing NIX_CONFIG value
# Returns:
# - <String> Combined NIX_CONFIG (stdout)
nixos_combinedNixConfig() {
    local base_config="${1:-}"
    local store store_cfg="" root uri

    uri=$(nixos_installStoreUri 2>/dev/null) || {
        printf '%s' "$base_config"
        return 0
    }

    store_cfg="store = ${uri}"
    if [[ -n "$base_config" ]]; then
        printf '%s\n%s\n' "$base_config" "$store_cfg"
    else
        printf '%s\n' "$store_cfg"
    fi
}

# Description: NIX_CONFIG for nixos-install (never override its --store /mnt).
# impure-envs: nix flake git fetches must see GIT_SSH_COMMAND from the installer env.
# Returns:
# - <String> NIX_CONFIG value (stdout)
nixos_installNixConfig() {
    printf '%s\n' \
        "experimental-features = nix-command flakes" \
        "impure-envs = GIT_SSH GIT_SSH_COMMAND GIT_TERMINAL_PROMPT"
}

# Description: Canonical /nix/store/… path for a store URI (nixos-anywhere style).
# Chroot builds return /mnt/nix/store/… from readlink; nix-env needs /nix/store/….
# Arguments:
# - store_uri: <String> Nix store URI (e.g. /mnt)
# - path:      <String> Store path or symlink
# Returns:
# - <String> /nix/store/… path (stdout)
_nixos_canonicalStorePath() {
    local store_uri="$1" path="$2" canon root

    path="${path%/}"
    [[ -n "$path" ]] || return 1
    canon=$(env NIX_CONFIG="$(nixos_installNixConfig)" \
        nix --store "$store_uri" path-info -M "$path" 2>/dev/null || true)
    if [[ -n "$canon" && "$canon" == /nix/store/* ]]; then
        printf '%s\n' "$canon"
        return 0
    fi
    root=$(nixos_targetRoot)
    if [[ "$path" == "${root}/nix/store/"* ]]; then
        printf '/nix/store/%s\n' "${path#${root}/nix/store/}"
        return 0
    fi
    [[ "$path" == /nix/store/* ]] && {
        printf '%s\n' "$path"
        return 0
    }
    return 1
}

# Description: True when the target system profile resolves in the chroot store.
# Host [[ -e /mnt/nix/…/system ]] is wrong: profile links target /nix/store/… on disk.
# Arguments:
# - root: <String> Target root mount (store URI)
# Returns:
# - <Bool> 0 when profile is valid
nixos_systemProfileOk() {
    local root="$1" link target phys

    env NIX_CONFIG="$(nixos_installNixConfig)" \
        nix --store "$root" path-info -M /nix/var/nix/profiles/system &>/dev/null && return 0

    link="${root}/nix/var/nix/profiles/system"
    [[ -L "$link" ]] || return 1
    target=$(readlink "$link")
    if [[ "$target" != /nix/store/* ]]; then
        target=$(readlink "${root}/nix/var/nix/profiles/${target}" 2>/dev/null || true)
    fi
    [[ "$target" == /nix/store/* ]] || return 1
    phys="${root}${target}"
    [[ -d "$phys" ]]
}

# Description: Create system profile symlinks without nix-env (last resort).
# Arguments:
# - root:       <String> Target root mount
# - system_rel: <String> /nix/store/… nixos-system path
# Returns:
# - <Bool> 0 on success
_nixos_linkSystemProfile() {
    local root="$1" system_rel="$2"
    local profiles="${root}/nix/var/nix/profiles" gen=1

    [[ "$system_rel" == /nix/store/* ]] || return 1
    while [[ -e "${profiles}/system-${gen}-link" ]]; do
        gen=$((gen + 1))
    done
    mkdir -p "$profiles"
    ln -sfn "$system_rel" "${profiles}/system-${gen}-link"
    ln -sfn "system-${gen}-link" "${profiles}/system"
    nixos_systemProfileOk "$root"
}

# Description: Install bootloader via nixos-enter (nixos-install bootloader step).
# Arguments:
# - root: <String> Target root mount
# Returns:
# - <Bool> 0 on success
_nixos_installBootloader() {
    local root="$1" log

    log="${NDS_NIXOS_INSTALL_LOG:-${NDS_INSTALL_DETAIL_LOG:-/tmp/nds_install.log}}"
    nixos_systemProfileOk "$root" || return 1

    mkdir -p "${root}/etc" "${root}/run"
    touch "${root}/etc/NIXOS"
    ln -sfn /proc/mounts "${root}/etc/mtab"
    ln -snf /nix/var/nix/profiles/system "${root}/run/current-system"

    export mountPoint="$root"
    if ! NIXOS_INSTALL_BOOTLOADER=1 nixos-enter --root "$root" -c "$(cat <<'EOF'
set -e
hash -r
mount --rbind --mkdir / "$mountPoint"
mount --make-rslave "$mountPoint"
/run/current-system/bin/switch-to-configuration boot
umount -R "$mountPoint" && (rmdir "$mountPoint" 2>/dev/null || true)
EOF
)" >>"$log" 2>&1; then
        nds_install_log "bootloader: switch-to-configuration boot failed (see verbose log)"
        return 1
    fi

    nds_install_log "nix: bootloader installed"
    _nixos_remountTargetIfNeeded || true

    # switch-to-configuration boot usually installs GRUB already — only repair if missing.
    if [[ "$_NIXOS_BOOT_LOADER" == "grub" && "$_NIXOS_BOOT_UEFI" != "true" && -n "$_NIXOS_DISK" ]]; then
        nds_requireUtility disk || return 1
        if disk_grubBiosBootOk "$_NIXOS_DISK"; then
            nds_install_log "grub: BIOS boot code already present on ${_NIXOS_DISK}"
        elif disk_grubInstallBios "$_NIXOS_DISK" "$root" "$log"; then
            nds_install_log "grub: installed BIOS boot code on ${_NIXOS_DISK}"
        else
            warn "GRUB BIOS boot code install failed — see verbose log"
        fi
    fi
    return 0
}

# Description: Set system profile and install bootloader for a built closure.
# Replaces nixos-install --system on chroot stores (/mnt) where nix-env breaks.
# Arguments:
# - root:       <String> Target root mount (store URI)
# - system_rel: <String> /nix/store/… nixos-system path
# Returns:
# - <Bool> 0 on success
nixos_activateSystem() {
    local root="$1" system_rel="$2" profile_dst log err

    profile_dst="${root}/nix/var/nix/profiles/system"
    log="${NDS_NIXOS_INSTALL_LOG:-${NDS_INSTALL_DETAIL_LOG:-/tmp/nds_install.log}}"
    system_rel="${system_rel%/}"
    [[ "$system_rel" == /nix/store/* ]] || return 1

    mkdir -p "${root}/etc"
    touch "${root}/etc/NIXOS"

    if ! nixos_systemProfileOk "$root"; then
        mkdir -p "$(dirname "$profile_dst")"
        if env NIX_CONFIG="$(nixos_installNixConfig)" \
            nix-env --store "$root" --extra-substituters "auto?trusted=1" \
            -p "$profile_dst" --set "$system_rel" >>"$log" 2>&1; then
            nds_install_log "nix: system profile (nix-env) -> ${profile_dst}"
        elif _nixos_linkSystemProfile "$root" "$system_rel"; then
            nds_install_log "nix: system profile (manual) -> ${profile_dst}"
        else
            err=$(tail -5 "$log" 2>/dev/null || true)
            nds_install_log "activate: profile failed for ${system_rel}${err:+ — $err}"
            return 1
        fi
    fi

    _nixos_ensureCurrentSystemLink "$root" || true
    _nixos_installBootloader "$root"
}

# Description: Resolve a built NixOS system closure on the target or scratch store.
# Arguments:
# - root: <String> Target root mount
# Returns:
# - <String> store path (stdout), empty when not found
_nixos_findSystemClosure() {
    local root="$1" scratch path system_out

    for path in \
        "${root}/nix/var/nix/profiles/system" \
        "${root}/var/nix/profiles/system"; do
        [[ -e "$path" ]] || continue
        system_out=$(nix --store "$root" path-info -M "$path" 2>/dev/null || true)
        [[ -n "$system_out" ]] && {
            printf '%s\n' "$system_out"
            return 0
        }
    done

    scratch=$(_nixos_scratchStorePath)
    path="${scratch}/var/nix/profiles/system"
    if [[ -e "$path" ]]; then
        system_out=$(nix --store "$scratch" path-info -M "$path" 2>/dev/null || true)
        [[ -n "$system_out" ]] && {
            printf '%s\n' "$system_out"
            return 0
        }
    fi

    system_out=$(ls -dt "${root}"/nix/store/*-nixos-system-*/ 2>/dev/null | head -1 || true)
    [[ -n "$system_out" && -d "$system_out" ]] && {
        printf '%s\n' "$system_out"
        return 0
    }

    system_out=$(ls -dt "${scratch}"/*-nixos-system-*/ 2>/dev/null | head -1 || true)
    [[ -n "$system_out" && -d "$system_out" ]] && {
        printf '%s\n' "$system_out"
        return 0
    }

    return 1
}

# Description: Ensure /mnt/nix/var/nix/profiles/system exists on the target.
# Arguments:
# - root: <String> Target root mount
# Returns:
# - <Bool> 0 on success
_nixos_ensureSystemProfile() {
    local root="$1" profile_dst system_out system_rel scratch log err

    profile_dst="${root}/nix/var/nix/profiles/system"
    nixos_systemProfileOk "$root" && return 0

    system_out=$(_nixos_findSystemClosure "$root") || {
        nds_install_log "ensure_system_profile: no nixos-system closure found"
        return 1
    }
    system_out="${system_out%/}"
    log="${NDS_NIXOS_INSTALL_LOG:-${NDS_INSTALL_DETAIL_LOG:-/tmp/nds_install.log}}"

    system_rel=$(_nixos_canonicalStorePath "$root" "$system_out") || {
        nds_install_log "ensure_system_profile: cannot canonicalize ${system_out}"
        return 1
    }

    scratch=$(_nixos_scratchStorePath)
    if [[ "$system_out" != "${root}"/* ]] && [[ -d "$scratch" ]]; then
        info "Copying NixOS system closure into ${root}/nix/store"
        nix copy --to "$root" "$system_rel" >>"$log" 2>&1 || return 1
    fi

    mkdir -p "$(dirname "$profile_dst")"
    if env NIX_CONFIG="$(nixos_installNixConfig)" \
        nix-env --store "$root" --extra-substituters "auto?trusted=1" \
        -p "$profile_dst" --set "$system_rel" >>"$log" 2>&1; then
        nds_install_log "nix: system profile -> ${profile_dst}"
        return 0
    fi

    err=$(tail -3 "$log" 2>/dev/null || true)
    nds_install_log "nix-env failed: store=${root} profile=${profile_dst} system=${system_rel}${err:+ — $err}"

    warn "nix-env profile failed — linking system profile manually"
    if _nixos_linkSystemProfile "$root" "$system_rel"; then
        nds_install_log "nix: system profile (manual link) -> ${profile_dst}"
        return 0
    fi
    return 1
}

# Description: Link /run/current-system to the system profile on the target.
# Arguments:
# - root: <String> Target root mount
_nixos_ensureCurrentSystemLink() {
    local root="$1"

    nixos_systemProfileOk "$root" || return 1
    mkdir -p "${root}/run"
    ln -snf /nix/var/nix/profiles/system "${root}/run/current-system"
    return 0
}

# Description: Reinstall bootloader when GRUB/EFI files are missing after activation.
# Arguments:
# - root: <String> Target root mount
# Returns:
# - <Bool> 0 on success
_nixos_reinstallBootloader() {
    local root="$1"

    if [[ "$_NIXOS_BOOT_UEFI" == "true" ]]; then
        nds_requireUtility disk || return 1
        disk_efiFilesPresent "$_NIXOS_BOOT_LOADER" "${root}/boot" && return 0
    elif [[ -e "${root}/boot/grub/grub.cfg" ]]; then
        return 0
    fi

    warn "Bootloader missing — retrying switch-to-configuration boot"
    _nixos_installBootloader "$root"
}

# Description: Remount target /boot when nixos-install tore down mounts.
_nixos_remountTargetIfNeeded() {
    local root
    root=$(nixos_targetRoot)
    mountpoint -q "${root}/boot" 2>/dev/null && return 0
    info "Remounting target filesystems"
    nds_requireUtility disk || return 1
    disk_mountRoot "$_NIXOS_ENCRYPTION" "$root"
}

# Description: Repair system profile and bootloader after install.
# Requires nixos_setBootContext (loader/uefi/disk/encryption) beforehand.
# Returns:
# - <Bool> 0 on success
nixos_ensureInstallArtifacts() {
    local root

    root=$(nixos_targetRoot)

    _nixos_remountTargetIfNeeded || return 1
    _nixos_ensureSystemProfile "$root" || return 1
    _nixos_ensureCurrentSystemLink "$root" || true

    _nixos_reinstallBootloader "$root" || {
        warn "Bootloader reinstall skipped or failed — see diag log"
    }

    return 0
}
