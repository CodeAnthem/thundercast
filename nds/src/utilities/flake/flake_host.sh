#!/usr/bin/env bash
# ==================================================================================================
# flake - host directory facts: install-time files, git index staging, disko probe
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-03 | Modified: 2026-09-03
# Description:   Gitignored host facts must be `git add -f`ed for nix eval and unstaged afterwards
#                so the checkout stays fast-forwardable.
# ==================================================================================================

# Description: Install-time host facts (gitignored after staging).
flake_hostFactNames() {
    printf '%s\n' facter.json hardware-configuration.nix machine.nix nds-boot.nix
}

# Description: Filenames that must stay tracked in the flake (not gitignored).
flake_committedHostNames() {
    printf '%s\n' nds_generated.nix opts.nix configuration.nix
}

# Description: Absolute paths of the given names that exist in host_dir.
# Arguments:
# - host_dir: <String> Host directory
# - names:    <String...> Basenames to look for
# Returns:
# - <String> absolute paths (stdout)
flake_hostFilesPresent() {
    local host_dir="$1" f
    shift
    for f in "$@"; do
        [[ -f "${host_dir}/${f}" ]] && printf '%s\n' "${host_dir}/${f}"
    done
    return 0
}

# Description: git add -f the given host files so flake eval sees them.
# Arguments:
# - flake_root: <String> Flake checkout root
# - host_dir:   <String> Host directory
# - names:      <String...> Basenames (see flake_hostFactNames / flake_committedHostNames)
# Returns:
# - <Bool> 0 on success or when not a git checkout
flake_gitStageHostFiles() {
    local flake_root="$1" host_dir="$2"
    shift 2
    local log rel
    local -a files=()

    [[ -d "${flake_root}/.git" ]] || return 0
    mapfile -t files < <(flake_hostFilesPresent "$host_dir" "$@")
    [[ ${#files[@]} -gt 0 ]] || return 0

    log="${NDS_INSTALL_DETAIL_LOG:-/tmp/nds_install.log}"
    printf '\n=== git add -f host files (%s) ===\n' "$*" >>"$log"
    for rel in "${files[@]}"; do
        rel="${rel#"${flake_root}/"}"
        git -C "$flake_root" add -f "$rel" >>"$log" 2>&1 || return 1
        nds_install_log "flake: git add -f ${rel}"
    done
    return 0
}

# Description: Unstage install-time host facts and ensure .gitignore covers them.
# Files stay on disk; only the Git index is cleaned so the checkout is pullable.
# Arguments:
# - flake_root: <String> Flake checkout root
# - host_dir:   <String> Host directory
flake_gitUnstageHostFacts() {
    local flake_root="$1" host_dir="$2"
    local log rel gi line
    local -a files=() needed=()

    [[ -d "${flake_root}/.git" ]] || return 0
    mapfile -t files < <(flake_hostFilesPresent "$host_dir" "${ flake_hostFactNames; }")
    [[ ${#files[@]} -gt 0 ]] || return 0

    log="${NDS_INSTALL_DETAIL_LOG:-/tmp/nds_install.log}"
    gi="${flake_root}/.gitignore"
    needed=(
        'hosts/**/facter.json'
        'hosts/**/hardware-configuration.nix'
        'hosts/**/machine.nix'
        'hosts/**/nds-boot.nix'
    )

    touch "$gi"
    for line in "${needed[@]}"; do
        if ! grep -qxF "$line" "$gi" 2>/dev/null; then
            printf '%s\n' "$line" >>"$gi"
            nds_install_log "flake: append .gitignore ${line}"
        fi
    done

    printf '\n=== git reset HEAD install-time host facts (keep pullable) ===\n' >>"$log"
    for rel in "${files[@]}"; do
        rel="${rel#"${flake_root}/"}"
        git -C "$flake_root" reset HEAD -- "$rel" >>"$log" 2>&1 || true
        if git -C "$flake_root" ls-files --error-unmatch "$rel" &>/dev/null; then
            nds_install_log "flake: ${rel} still tracked — leave (operator/repo owned)"
        else
            nds_install_log "flake: unstaged ${rel} (ignored / untracked)"
        fi
    done
    return 0
}

# Description: Confirm host_dir has configuration.nix + nds_generated.nix with fileSystems.
# Arguments:
# - host_dir: <String> Host directory
# Returns:
# - <Bool> 0 when structure is complete (or no configuration.nix to check against)
flake_hostStructureOk() {
    local host_dir="$1" gen

    [[ -d "$host_dir" ]] || { err "host directory missing: ${host_dir}"; return 1; }
    [[ -f "${host_dir}/configuration.nix" ]] || return 0
    gen="${host_dir}/nds_generated.nix"
    [[ -f "$gen" ]] || { err "nds_generated.nix missing: ${gen}"; return 1; }
    grep -qE 'fileSystems|by-uuid|by-label' "$gen" || { err "nds_generated.nix missing fileSystems: ${gen}"; return 1; }
    return 0
}

# Description: True when the host directory declares disko.nix.
# Arguments:
# - flake_root:   <String> Flake checkout root
# - host:         <String> nixosConfigurations name
# - host_dir_rel: <String|optional> Hosts prefix (default hosts/x86_64-linux)
flake_hostHasDisko() {
    local flake_root="$1" host="$2" host_dir_rel="${3:-hosts/x86_64-linux}" found

    [[ -f "${flake_root}/${host_dir_rel}/${host}/disko.nix" ]] && return 0
    found=$(find "${flake_root}/${host_dir_rel}/${host}" -maxdepth 2 -name 'disko.nix' -print -quit 2>/dev/null || true)
    [[ -n "$found" ]]
}
