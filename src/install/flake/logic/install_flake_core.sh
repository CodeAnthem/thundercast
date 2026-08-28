#!/usr/bin/env bash
# ==================================================================================================
# NDS - Flake checkout and flake nixos-install
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-28 | Modified: 2026-08-28
# Description:   Stage flake, git-add install facts, build+activate flake system
# ==================================================================================================

# Description: Stage flake checkout — reuse session clone or shallow-clone.
# Arguments:
# - repo_url:     <String> Git remote URL
# - install_path: <String> Destination directory
# Returns:
# - <Bool> 0 on success
_nds_install_stage_flake_repo() {
    local repo_url="$1"
    local install_path="$2"
    local probe norm_url

    [[ -n "$repo_url" && -n "$install_path" ]] || return 1
    norm_url=$(_nds_git_url_toSsh "$repo_url")
    probe="${NDS_FLAKE_PROBE_REPO:-}"

    mkdir -p "$(dirname "$install_path")"

    if [[ -d "${install_path}/.git" ]]; then
        return 0
    fi

    if [[ -n "$probe" && -f "${probe}/flake.nix" \
        && "${NDS_FLAKE_PROBE_REPO_URL:-}" == "$norm_url" ]]; then
        rm -rf "$install_path"
        cp -a "$probe" "$install_path"
        nds_install_log "git: staged flake from session clone -> ${install_path}"
        return 0
    fi

    rm -rf "$install_path"
    nds_git_clone "$repo_url" "$install_path" 1
}

# Description: Resolve flake root on the operator machine for remote install.
# Arguments:
# - source:     <String> remote | local
# - local_path: <String> Local flake path when source=local
# - repo_url:   <String> Git URL when source=remote
# Returns:
# - <String> Absolute flake root path (stdout)
_nds_install_resolve_flake_root() {
    local source="$1"
    local local_path="$2"
    local repo_url="$3"
    local install_dir="${NDS_RUNTIME_DIR}/flake_install"

    case "$source" in
        local)
            if [[ -z "$local_path" || ! -d "$local_path" ]]; then
                error "Local flake path not found: $local_path"
            fi
            echo "$local_path"
            ;;
        remote|*)
            if [[ -z "$repo_url" ]]; then
                error "Flake repo URL is required for remote install"
            fi
            if _nds_install_stage_flake_repo "$repo_url" "$install_dir"; then
                echo "$install_dir"
                return 0
            fi
            error "Failed to stage $repo_url to $install_dir"
            ;;
    esac
}

# Description: Install NixOS on a remote target via nixos-anywhere.
# Arguments:
# - flake_root: <String> Flake root on the operator machine
# - hostname:   <String> nixosConfigurations name
# - target_ip:  <String> Target host IP or hostname
_nds_install_via_nixos_anywhere() {
    local flake_root="$1"
    local hostname="$2"
    local target_ip="$3"
    local host_dir_rel="${NDS_FLAKE_HOST_DIR:-hosts/x86_64-linux}"
    local facter_dest="${flake_root}/${host_dir_rel}/${hostname}/facter.json"
    local -a cmd=(
        nix run github:nix-community/nixos-anywhere --
        --flake "${flake_root}#${hostname}"
        --generate-hardware-config nixos-facter "$facter_dest"
        --target-host "root@${target_ip}"
    )
    local encryption
    nds_install_ctx_ensure
    encryption="$(nds_install_ctx_get ENCRYPTION)"
    if [[ "$encryption" == "true" ]]; then
        local key_path="${NDS_RUNTIME_DIR}/secrets/luks_key.bin"
        if [[ ! -f "$key_path" ]]; then
            error "LUKS keyfile not found at $key_path — run encryption secret generation first"
        fi
        cmd+=(--disk-encryption-keys /tmp/luks.key "$key_path")
    fi

    log "Running: ${cmd[*]}"
    if ! "${cmd[@]}"; then
        error "nixos-anywhere installation failed"
    fi
    log "Remote install completed — commit ${facter_dest} to your flake repo"
    return 0
}

# Copy a local flake directory onto the mounted target root.
# Usage: _nds_install_stage_local_flake "local_path" "install_path"
_nds_install_stage_local_flake() {
    local local_path="$1"
    local install_path="$2"

    if [[ -z "$local_path" || ! -d "$local_path" ]]; then
        error "Local flake path not found: $local_path"
    fi

    log "Copying local flake from $local_path to $install_path"
    mkdir -p "$(dirname "$install_path")"

    if [[ -e "$install_path" ]]; then
        rm -rf "$install_path"
    fi

    cp -a "$local_path" "$install_path" || error "Failed to copy flake to $install_path"
    log "Local flake staged at $install_path"
    return 0
}

# Clone or refresh flake checkout on the mounted target root.
# Usage: _nds_install_ensure_flake_checkout "repo_url" "install_path"
_nds_install_ensure_flake_checkout() {
    local repo_url="$1"
    local install_path="$2"

    if [[ -z "$repo_url" ]]; then
        error "Flake repo URL is required"
    fi

    if [[ -z "$install_path" ]]; then
        error "Flake install path is required"
    fi

    log "Ensuring flake checkout at $install_path"

    if _nds_install_stage_flake_repo "$repo_url" "$install_path"; then
        log "Flake staged at $install_path"
        return 0
    fi

    error "Failed to stage $repo_url to $install_path"
}

# Description: Eval the install host so nixos-install does not start on a broken config.
# path: includes gitignored facter.json. Same --store as prefetch so locked git
# inputs are found locally. --no-update-lock-file: getFlake on a dirty tree
# re-fetches SSH inputs without NDS keys (Permission denied).
# Does not run nix flake check — ThunderCore checks every nixosConfiguration.
# Arguments:
# - flake_root: <String> Flake checkout
# - host_name:  <String|optional> nixosConfigurations key (FLAKE_HOST / CTX)
_nds_install_flake_check() {
    local flake_root="$1"
    local host_name="${2:-}"
    local log="${NDS_NIXOS_INSTALL_LOG:-/tmp/nds_nixosInstallation.log}"
    local flake_ref nix_config rc=0
    local -a store_args=()

    [[ -f "${flake_root}/flake.nix" ]] || {
        error "Flake missing at ${flake_root}"
        return 1
    }
    if [[ -z "$host_name" ]]; then
        host_name="${NDS_CTX_HOSTNAME:-}"
    fi
    if [[ -z "$host_name" ]] && declare -f nds_cfg_get &>/dev/null; then
        host_name="$(nds_cfg_get FLAKE_HOST 2>/dev/null || true)"
    fi
    [[ -n "$host_name" ]] || {
        error "FLAKE_HOST is required to check the install target"
        return 1
    }
    [[ "$host_name" =~ ^[A-Za-z0-9._-]+$ ]] || {
        error "Invalid flake host name: ${host_name}"
        return 1
    }

    flake_root="$(readlink -f "$flake_root" 2>/dev/null || printf '%s' "$flake_root")"
    flake_ref=$(_nds_install_nix_flake_system_ref "$host_name")
    mapfile -t store_args < <(_nds_install_nix_install_store_args 2>/dev/null || true)
    nix_config="experimental-features = nix-command flakes"
    if declare -f _nds_install_nix_nixos_install_config &>/dev/null; then
        nix_config="$(_nds_install_nix_nixos_install_config)"
    fi

    mkdir -p "$(dirname "$log")" 2>/dev/null || true
    printf '\n=== nix eval nixosConfigurations.%s ===\n' "$host_name" | tee -a "$log"
    # stdout/stderr stay on this fd so nds_step_exec captures them in the
    # detail log (diagnostics). tee keeps a copy in nixosInstallation.log.
    (
        set -o pipefail
        cd "$flake_root" || exit 1
        env NIX_CONFIG="$nix_config" nix eval --raw --impure --show-trace \
            --no-update-lock-file --no-write-lock-file \
            --extra-experimental-features 'nix-command flakes' \
            "${store_args[@]}" \
            "path:${flake_root}#${flake_ref}.drvPath" 2>&1 | tee -a "$log"
    )
    rc=$?
    if [[ "$rc" -ne 0 ]]; then
        error "flake eval failed for ${host_name}"
        return 1
    fi
    nds_install_log "flake: eval ok path:${flake_root}#${host_name}"
    return 0
}

# Description: Flake attr for nixosConfigurations.<host>.config.system.build.toplevel.
# Arguments:
# - host_name: <String> nixosConfigurations key
# Returns:
# - <String> flake fragment (stdout)
_nds_install_nix_flake_system_ref() {
    local host_name="$1"

    printf 'nixosConfigurations."%s".config.system.build.toplevel' "$host_name"
}

# Description: Install-time host facts (gitignored after staging).
_nds_install_flake_host_fact_names() {
    printf '%s\n' facter.json hardware-configuration.nix machine.nix nds-boot.nix
}

# Description: Collect absolute paths of install-time host fact files that exist.
# Arguments:
# - host_dir: <String> Host directory
# Returns:
# - <String> absolute paths (stdout)
_nds_install_flake_host_fact_paths() {
    local host_dir="$1" f
    for f in $(_nds_install_flake_host_fact_names); do
        [[ -f "${host_dir}/${f}" ]] && printf '%s\n' "${host_dir}/${f}"
    done
}

# Description: Stage install-time host files into the flake Git tree for nix eval.
# Gitignored secrets (facter.json) are invisible to flake eval unless git add -f.
# Committed nds_generated.nix is staged separately and stays tracked.
# Arguments:
# - flake_root: <String> Flake checkout root
# - host_dir:   <String> Host directory (…/hosts/…/hostname)
_nds_install_flake_git_stage_install_files() {
    local flake_root="$1" host_dir="$2"
    local log rel
    local -a files=()

    [[ -d "${flake_root}/.git" ]] || {
        nds_install_log "flake: no .git in ${flake_root} — skip git add for install files"
        return 0
    }

    mapfile -t files < <(_nds_install_flake_host_fact_paths "$host_dir")
    [[ ${#files[@]} -gt 0 ]] || return 0

    log="${NDS_INSTALL_DETAIL_LOG:-/tmp/nds_install.log}"
    {
        printf '\n=== git add -f install-time flake files (required for nix eval) ===\n'
    } >>"$log"

    for rel in "${files[@]}"; do
        rel="${rel#"${flake_root}/"}"
        git -C "$flake_root" add -f "$rel" >>"$log" 2>&1 || return 1
        nds_install_log "flake: git add -f ${rel}"
    done
    return 0
}

# Description: Unstage install-time host facts and mark them gitignored so the
# checkout stays fast-forwardable with origin (no machine-local commits).
# Files remain on disk for the installed system; only the Git index is cleaned.
# Arguments:
# - flake_root: <String> Flake checkout root
# - host_dir:   <String> Host directory
_nds_install_flake_git_unstage_install_files() {
    local flake_root="$1" host_dir="$2"
    local log rel gi line
    local -a files=() needed=()

    [[ -d "${flake_root}/.git" ]] || return 0

    mapfile -t files < <(_nds_install_flake_host_fact_paths "$host_dir")
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

    {
        printf '\n=== git reset HEAD install-time flake files (keep pullable) ===\n'
    } >>"$log"

    for rel in "${files[@]}"; do
        rel="${rel#"${flake_root}/"}"
        # Drop from index only — leave working tree files on disk.
        git -C "$flake_root" reset HEAD -- "$rel" >>"$log" 2>&1 || true
        # If somehow still tracked from a prior commit, leave it (operator ownership).
        if git -C "$flake_root" ls-files --error-unmatch "$rel" &>/dev/null; then
            nds_install_log "flake: ${rel} still tracked — leave (operator/repo owned)"
        else
            nds_install_log "flake: unstaged ${rel} (ignored / untracked)"
        fi
    done
    return 0
}

# Description: Build flake system on target store; install into system profile.
# Arguments:
# - flake_root:  <String> Flake directory
# - host_name:   <String> nixosConfigurations key
# - build_flags: <String...> Extra nix build flags (e.g. --override-input)
# Returns:
# - <String> /nix/store/… nixos-system path (stdout)
_nds_install_build_flake_system() {
    local flake_root="$1"
    local host_name="$2"
    shift 2
    local -a build_flags=("$@")
    local root store nixos_log profile_dst flake_ref system_rel tmpdir out_link

    [[ -d "$flake_root" ]] || return 1
    root=$(_nds_install_nix_target_root)
    nixos_log="${NDS_NIXOS_INSTALL_LOG:-/tmp/nds_nixosInstallation.log}"
    store="$root"
    profile_dst="${root}/nix/var/nix/profiles/system"
    flake_ref=$(_nds_install_nix_flake_system_ref "$host_name")

    mkdir -p "${root}/nix/store" "$(dirname "$profile_dst")"
    _nds_install_nix_ensure_store_ready "$store" || true

    if env NIX_CONFIG="$(_nds_install_nix_nixos_install_config)" \
        nix build \
        --extra-experimental-features 'nix-command flakes' \
        --store "$store" \
        --extra-substituters "auto?trusted=1" \
        --profile "$profile_dst" \
        "${build_flags[@]}" \
        "${flake_root}#${flake_ref}" >>"$nixos_log" 2>&1 \
        && _nds_install_nix_system_profile_ok "$root"; then
        system_rel=$(env NIX_CONFIG="$(_nds_install_nix_nixos_install_config)" \
            nix --store "$store" path-info -M /nix/var/nix/profiles/system 2>/dev/null || true)
        [[ -n "$system_rel" ]] || system_rel=$(_nds_install_nix_find_system_closure "$root")
        [[ -n "$system_rel" ]] || return 1
        system_rel=$(_nds_install_nix_canonical_store_path "$store" "$system_rel") || return 1
        printf '%s\n' "$system_rel"
        return 0
    fi

    warn "Profile build failed — building out-link and activating manually"
    tmpdir=$(mktemp -d -p "$root")
    out_link="${tmpdir}/system"

    if ! env NIX_CONFIG="$(_nds_install_nix_nixos_install_config)" \
        nix build \
        --extra-experimental-features 'nix-command flakes' \
        --store "$store" \
        --extra-substituters "auto?trusted=1" \
        --out-link "$out_link" \
        "${build_flags[@]}" \
        "${flake_root}#${flake_ref}" >>"$nixos_log" 2>&1; then
        rm -rf "$tmpdir"
        return 1
    fi

    system_rel=$(_nds_install_nix_canonical_store_path "$store" "$out_link") || {
        rm -rf "$tmpdir"
        return 1
    }
    rm -rf "$tmpdir"
    printf '%s\n' "$system_rel"
    return 0
}

# Usage: _nds_install_nixos_flake "flake_root" "host_name" ["hardware_placement"]
_nds_install_nixos_flake() {
    local flake_root="$1"
    local host_name="$2"
    local hw_placement="${3:-host-dir}"
    local -a build_flags=()
    local root system_rel nixos_log host_dir_rel host_dir

    log "Installing NixOS from flake ${flake_root}#${host_name}"
    root=$(_nds_install_nix_target_root)

    if [[ ! -d "$flake_root" ]]; then
        error "Flake root not found: $flake_root"
        return 1
    fi

    host_dir_rel="${NDS_CTX_FLAKE_HOST_DIR:-hosts/x86_64-linux}"
    host_dir="${flake_root}/${host_dir_rel}/${host_name}"
    _nds_install_flake_git_stage_committed_files "$flake_root" "$host_dir" || {
        error "Failed to stage committed host structure for nix build"
        return 1
    }
    _nds_install_flake_git_stage_install_files "$flake_root" "$host_dir" || {
        error "Failed to stage install-time flake files for nix build"
        return 1
    }

    if [[ "$hw_placement" == "etc-nixos" ]]; then
        local hw_artifact
        hw_artifact=$(_nds_install_hardware_artifact_name)
        if [[ "$hw_artifact" == "hardware-configuration.nix" && -f /mnt/etc/nixos/hardware-configuration.nix ]]; then
            build_flags+=(--override-input hardware "path:/etc/nixos/hardware-configuration.nix")
            log "Using --override-input hardware path:/etc/nixos/hardware-configuration.nix"
        fi
    fi

    nixos_log="${NDS_NIXOS_INSTALL_LOG:-/tmp/nds_nixosInstallation.log}"

    log "Building NixOS system on target store"
    if ! system_rel=$(_nds_install_build_flake_system "$flake_root" "$host_name" "${build_flags[@]}"); then
        error "Flake-based NixOS build failed"
        return 1
    fi
    nds_install_log "nix: built system ${system_rel}"

    # After nix eval, keep host facts on disk but out of the Git index so
    # post-boot `git pull --ff-only` / nds-switch is not blocked by local commits.
    _nds_install_flake_git_unstage_install_files "$flake_root" "$host_dir" || true

    log "Activating system (profile + bootloader)"
    if ! nds_nix_activate_system "$root" "$system_rel" >>"$nixos_log" 2>&1; then
        error "Flake-based NixOS activation failed — see ${nixos_log}"
        return 1
    fi

    nds_nix_ensure_install_artifacts || return 1

    log "Flake-based NixOS installation completed"
    return 0
}
