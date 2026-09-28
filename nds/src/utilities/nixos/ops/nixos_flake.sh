#!/usr/bin/env bash
# ==================================================================================================
# nixos - flake eval / build on target store / nixos-anywhere (no git, no prompts)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-28 | Modified: 2026-09-04
# ==================================================================================================

# Description: Flake attr for nixosConfigurations.<host>.config.system.build.toplevel.
# Arguments:
# - host_name: <String> nixosConfigurations key
# Returns:
# - <String> flake fragment (stdout)
nixos_flakeSystemRef() {
    printf 'nixosConfigurations."%s".config.system.build.toplevel' "$1"
}

# Description: GIT_SSH env lines for nix flake eval/build (all registered session keys).
# Returns:
# - <String> NAME=value lines on stdout (may be empty)
_nixos_gitInstallEnv() {
    declare -f _nds_git_ssh_env &>/dev/null || return 0
    _nds_git_ssh_env
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
    local flake_ref rc=0
    local -a store_args=() git_env=()

    [[ -f "${flake_root}/flake.nix" ]] || { err "flake missing at ${flake_root}"; return 1; }
    [[ -n "$host_name" ]] || { err "host name is required"; return 1; }
    [[ "$host_name" =~ ^[A-Za-z0-9._-]+$ ]] || { err "invalid flake host name: ${host_name}"; return 1; }

    flake_root="$(readlink -f "$flake_root" 2>/dev/null || printf '%s' "$flake_root")"
    flake_ref=$(nixos_flakeSystemRef "$host_name")
    mapfile -t store_args < <(nixos_installStoreArgs 2>/dev/null || true)
    while IFS= read -r line; do
        [[ -n "$line" ]] && git_env+=("$line")
    done < <(_nixos_gitInstallEnv 2>/dev/null || true)

    logger_scopeAppend "=== nix eval nixosConfigurations.${host_name} ===" install
    nixos_runLogged env -C "$flake_root" NIX_CONFIG="$(nixos_installNixConfig)" "${git_env[@]}" \
        nix eval --raw --impure --show-trace \
        --no-update-lock-file --no-write-lock-file \
        --extra-experimental-features 'nix-command flakes' \
        "${store_args[@]}" \
        "path:${flake_root}#${flake_ref}.drvPath" || rc=$?
    [[ "$rc" -eq 0 ]] || { err "flake eval failed for ${host_name}"; return 1; }
    debug "flake: eval ok path:${flake_root}#${host_name}"
    return 0
}

# Description: Build flake system on the target store; install into the system profile.
# Arguments:
# - out_var:     <Name> Variable that receives the /nix/store/… nixos-system path
# - flake_root:  <String> Flake directory
# - host_name:   <String> nixosConfigurations key
# - build_flags: <String...> Extra nix build flags (e.g. --override-input)
# Returns:
# - <Bool> 0 on success. The path is written to out_var (same shell, so the progress bar survives).
nixos_buildFlakeSystem() {
    local -n _nixos_built=$1
    local flake_root="$2"
    local host_name="$3"
    shift 3
    local -a build_flags=("$@") git_env=()
    local root store profile_dst flake_ref system_rel tmpdir out_link

    [[ -d "$flake_root" ]] || return 1
    while IFS= read -r line; do
        [[ -n "$line" ]] && git_env+=("$line")
    done < <(_nixos_gitInstallEnv 2>/dev/null || true)
    root=$(nixos_targetRoot)
    store="$root"
    profile_dst="${root}/nix/var/nix/profiles/system"
    flake_ref=$(nixos_flakeSystemRef "$host_name")

    mkdir -p "${root}/nix/store" "$(dirname "$profile_dst")"
    nixos_ensureStoreReady "$store" || true

    if nixos_runLogged env NIX_CONFIG="$(nixos_installNixConfig)" "${git_env[@]}" \
        nix build \
        --extra-experimental-features 'nix-command flakes' \
        --store "$store" \
        --extra-substituters "auto?trusted=1" \
        --profile "$profile_dst" \
        "${build_flags[@]}" \
        "${flake_root}#${flake_ref}" \
        && nixos_systemProfileOk "$root"; then
        system_rel=$(env NIX_CONFIG="$(nixos_installNixConfig)" \
            nix --store "$store" path-info -M /nix/var/nix/profiles/system 2>/dev/null || true)
        [[ -n "$system_rel" ]] || system_rel=$(_nixos_findSystemClosure "$root")
        [[ -n "$system_rel" ]] || return 1
        system_rel=$(_nixos_canonicalStorePath "$store" "$system_rel") || return 1
        _nixos_built=$system_rel
        return 0
    fi

    warn "Profile build failed — building out-link and activating manually"
    tmpdir=$(mktemp -d -p "$root")
    out_link="${tmpdir}/system"

    if ! nixos_runLogged env NIX_CONFIG="$(nixos_installNixConfig)" "${git_env[@]}" \
        nix build \
        --extra-experimental-features 'nix-command flakes' \
        --store "$store" \
        --extra-substituters "auto?trusted=1" \
        --out-link "$out_link" \
        "${build_flags[@]}" \
        "${flake_root}#${flake_ref}"; then
        rm -rf "$tmpdir"
        return 1
    fi

    system_rel=$(_nixos_canonicalStorePath "$store" "$out_link") || {
        rm -rf "$tmpdir"
        return 1
    }
    rm -rf "$tmpdir"
    _nixos_built=$system_rel
    return 0
}

# Description: Install NixOS on a remote target via nixos-anywhere.
# Arguments:
# - flake_root:  <String> Flake root on the operator machine
# - host_name:   <String> nixosConfigurations name
# - target_ip:   <String> Target host IP or hostname
# - facter_dest: <String> Where nixos-anywhere writes facter.json
# - luks_key:    <String|optional> LUKS keyfile to pass as /tmp/luks.key
# - extra:       <String|optional> --extra-files <dir>
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
    shift 5 || true
    while [[ $# -gt 0 ]]; do
        if [[ "$1" == --extra-files && -n ${2:-} ]]; then
            cmd+=(--extra-files "$2")
            shift 2
        else
            shift
        fi
    done

    if [[ -n "$luks_key" ]]; then
        [[ -f "$luks_key" ]] || { err "LUKS keyfile not found at ${luks_key}"; return 1; }
        cmd+=(--disk-encryption-keys /tmp/luks.key "$luks_key")
    fi

    log "Running: ${cmd[*]}"
    if ! nixos_runLogged "${cmd[@]}"; then
        err "nixos-anywhere installation failed"
        return 1
    fi
    nixos_progressFinish
    log "Remote install completed — commit ${facter_dest} to your flake repo"
    return 0
}

# Description: Prefetch every git input in flake.lock using the recipe key directory.
# Arguments:
# - flake_root: <String> Flake directory containing flake.lock
# - keys_dir:   <String> GIT_KEYS_DIR
nixos_prefetchFlake() {
    local _nixos_root=$1 _nixos_keys=${2:-} _nixos_lock _nixos_url _nixos_rev _nixos_nar
    local _nixos_fetch _nixos_ssh _nixos_expr _nixos_log
    _nixos_lock="${_nixos_root}/flake.lock"
    [[ -f "$_nixos_lock" ]] || return 0
    declare -f flake_listLockGitEntries >/dev/null || return 1
    if declare -f nds_session_dir >/dev/null; then
        _nixos_log="${ nds_session_dir logs; }/nixos-prefetch.log"
    else
        _nixos_log=/tmp/nds-nixos-prefetch.log
    fi
    mkdir -p "$(dirname "$_nixos_log")" 2>/dev/null || true
    while IFS=$'\t' read -r _nixos_url _nixos_rev _nixos_nar; do
        [[ -n "$_nixos_url" && -n "$_nixos_rev" && -n "$_nixos_nar" ]] || continue
        _nixos_fetch=${ flake_fetchTreeUrl "$_nixos_url"; }
        _nixos_ssh=${ git_sshCommand "$_nixos_keys" "$_nixos_url"; } || return 1
        _nixos_expr="builtins.fetchTree { type = \"git\"; url = \"${_nixos_fetch}\"; rev = \"${_nixos_rev}\"; narHash = \"${_nixos_nar}\"; }"
        if ! GIT_SSH_COMMAND="$_nixos_ssh" nix build --no-link --print-out-paths --impure \
            --extra-experimental-features 'nix-command flakes' --expr "$_nixos_expr" >>"$_nixos_log" 2>&1; then
            error "FLAKE_LOCATION: could not prefetch ${_nixos_url}"
            return 1
        fi
    done < <(flake_listLockGitEntries "$_nixos_lock")
}

# Description: Build the flake system, unstage host facts, activate, and repair boot files.
# Arguments:
# - flake_root:   <String> Flake checkout
# - host:         <String> nixosConfigurations key
# - host_dir:     <String> Host directory
# - hw_placement: <String> host-dir | etc-nixos | skip
nixos_installFlake() {
    local _nixos_root=$1 _nixos_host=$2 _nixos_host_dir=$3 _nixos_place=${4:-host-dir}
    local _nixos_system
    local -a _nixos_flags=()
    local _nixos_target
    _nixos_target=$(nixos_targetRoot)
    if [[ "$_nixos_place" == etc-nixos && -f "${_nixos_target}/etc/nixos/hardware-configuration.nix" ]]; then
        _nixos_flags+=(--override-input hardware path:/etc/nixos/hardware-configuration.nix)
    fi
    nixos_buildFlakeSystem _nixos_system "$_nixos_root" "$_nixos_host" \
        ${_nixos_flags[@]+"${_nixos_flags[@]}"} || return 1
    flake_gitUnstageHostFacts "$_nixos_root" "$_nixos_host_dir" || true
    nixos_activateSystem "$_nixos_target" "$_nixos_system" || return 1
    nixos_ensureInstallArtifacts || return 1
    nixos_progressFinish
}
