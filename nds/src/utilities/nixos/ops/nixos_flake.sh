#!/usr/bin/env bash
# ==================================================================================================
# nixos - flake eval / build on target store / nixos-anywhere (no git, no prompts)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-28 | Modified: 2026-09-03
# ==================================================================================================

# Description: Flake attr for nixosConfigurations.<host>.config.system.build.toplevel.
# Arguments:
# - host_name: <String> nixosConfigurations key
# Returns:
# - <String> flake fragment (stdout)
nixos_flakeSystemRef() {
    printf 'nixosConfigurations."%s".config.system.build.toplevel' "$1"
}

# Description: Eval the host toplevel so install does not start on a broken config.
# path: includes gitignored facter.json. Same --store as prefetch so locked git
# inputs are found locally. --no-update-lock-file: getFlake on a dirty tree
# re-fetches SSH inputs without NDS keys (Permission denied).
# Arguments:
# - flake_root: <String> Flake checkout
# - host_name:  <String> nixosConfigurations key
# Returns:
# - <Bool> 0 when eval succeeds
nixos_flakeEval() {
    local flake_root="$1"
    local host_name="$2"
    local log="${NDS_NIXOS_INSTALL_LOG:-/tmp/nds_nixosInstallation.log}"
    local flake_ref rc=0
    local -a store_args=()

    [[ -f "${flake_root}/flake.nix" ]] || { err "flake missing at ${flake_root}"; return 1; }
    [[ -n "$host_name" ]] || { err "host name is required"; return 1; }
    [[ "$host_name" =~ ^[A-Za-z0-9._-]+$ ]] || { err "invalid flake host name: ${host_name}"; return 1; }

    flake_root="$(readlink -f "$flake_root" 2>/dev/null || printf '%s' "$flake_root")"
    flake_ref=$(nixos_flakeSystemRef "$host_name")
    mapfile -t store_args < <(nixos_installStoreArgs 2>/dev/null || true)

    mkdir -p "$(dirname "$log")" 2>/dev/null || true
    printf '\n=== nix eval nixosConfigurations.%s ===\n' "$host_name" | tee -a "$log"
    # stdout/stderr stay on this fd so the step runner captures them; tee keeps a copy.
    (
        set -o pipefail
        cd "$flake_root" || exit 1
        env NIX_CONFIG="$(nixos_installNixConfig)" nix eval --raw --impure --show-trace \
            --no-update-lock-file --no-write-lock-file \
            --extra-experimental-features 'nix-command flakes' \
            "${store_args[@]}" \
            "path:${flake_root}#${flake_ref}.drvPath" 2>&1 | tee -a "$log"
    )
    rc=$?
    [[ "$rc" -eq 0 ]] || { err "flake eval failed for ${host_name}"; return 1; }
    nds_install_log "flake: eval ok path:${flake_root}#${host_name}"
    return 0
}

# Description: Build flake system on the target store; install into the system profile.
# Arguments:
# - flake_root:  <String> Flake directory
# - host_name:   <String> nixosConfigurations key
# - build_flags: <String...> Extra nix build flags (e.g. --override-input)
# Returns:
# - <String> /nix/store/… nixos-system path (stdout)
nixos_buildFlakeSystem() {
    local flake_root="$1"
    local host_name="$2"
    shift 2
    local -a build_flags=("$@")
    local root store nixos_log profile_dst flake_ref system_rel tmpdir out_link

    [[ -d "$flake_root" ]] || return 1
    root=$(nixos_targetRoot)
    nixos_log="${NDS_NIXOS_INSTALL_LOG:-/tmp/nds_nixosInstallation.log}"
    store="$root"
    profile_dst="${root}/nix/var/nix/profiles/system"
    flake_ref=$(nixos_flakeSystemRef "$host_name")

    mkdir -p "${root}/nix/store" "$(dirname "$profile_dst")"
    nixos_ensureStoreReady "$store" || true

    if env NIX_CONFIG="$(nixos_installNixConfig)" \
        nix build \
        --extra-experimental-features 'nix-command flakes' \
        --store "$store" \
        --extra-substituters "auto?trusted=1" \
        --profile "$profile_dst" \
        "${build_flags[@]}" \
        "${flake_root}#${flake_ref}" >>"$nixos_log" 2>&1 \
        && nixos_systemProfileOk "$root"; then
        system_rel=$(env NIX_CONFIG="$(nixos_installNixConfig)" \
            nix --store "$store" path-info -M /nix/var/nix/profiles/system 2>/dev/null || true)
        [[ -n "$system_rel" ]] || system_rel=$(_nixos_findSystemClosure "$root")
        [[ -n "$system_rel" ]] || return 1
        system_rel=$(_nixos_canonicalStorePath "$store" "$system_rel") || return 1
        printf '%s\n' "$system_rel"
        return 0
    fi

    warn "Profile build failed — building out-link and activating manually"
    tmpdir=$(mktemp -d -p "$root")
    out_link="${tmpdir}/system"

    if ! env NIX_CONFIG="$(nixos_installNixConfig)" \
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

    system_rel=$(_nixos_canonicalStorePath "$store" "$out_link") || {
        rm -rf "$tmpdir"
        return 1
    }
    rm -rf "$tmpdir"
    printf '%s\n' "$system_rel"
    return 0
}

# Description: Install NixOS on a remote target via nixos-anywhere.
# Arguments:
# - flake_root:  <String> Flake root on the operator machine
# - host_name:   <String> nixosConfigurations name
# - target_ip:   <String> Target host IP or hostname
# - facter_dest: <String> Where nixos-anywhere writes facter.json
# - luks_key:    <String|optional> LUKS keyfile to pass as /tmp/luks.key
# Returns:
# - <Bool> 0 on success
nixos_anywhere() {
    local flake_root="$1"
    local host_name="$2"
    local target_ip="$3"
    local facter_dest="$4"
    local luks_key="${5:-}"
    local -a cmd=(
        nix run github:nix-community/nixos-anywhere --
        --flake "${flake_root}#${host_name}"
        --generate-hardware-config nixos-facter "$facter_dest"
        --target-host "root@${target_ip}"
    )

    if [[ -n "$luks_key" ]]; then
        [[ -f "$luks_key" ]] || { err "LUKS keyfile not found at ${luks_key}"; return 1; }
        cmd+=(--disk-encryption-keys /tmp/luks.key "$luks_key")
    fi

    log "Running: ${cmd[*]}"
    "${cmd[@]}" || { err "nixos-anywhere installation failed"; return 1; }
    log "Remote install completed — commit ${facter_dest} to your flake repo"
    return 0
}
