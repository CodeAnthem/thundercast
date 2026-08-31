#!/usr/bin/env bash
# ==================================================================================================
# NDS - Install git SSH keys and tcast host CLI onto the target
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-07 | Modified: 2026-08-31
# Description:   Copy deploy keys, known_hosts, and TC-Tools under /mnt as /var/lib/tcast
# ==================================================================================================

# Description: Absolute path under repo-root TC-Tools/ (sibling of src/).
# Arguments:
# - rel: <String> Path relative to TC-Tools/ (e.g. bin/tcast)
_nds_tc_src() {
    printf '%s/../TC-Tools/%s\n' "${SCRIPT_DIR}" "$1"
}

# Description: install(1) with root:root when running as root.
_nds_git_install_exe() {
    local src="$1" dst="$2" mode="${3:-755}"
    if [[ "$(id -u)" -eq 0 ]]; then
        install -m "$mode" -o root -g root "$src" "$dst"
    else
        install -m "$mode" "$src" "$dst"
    fi
}

# Description: Install GitHub host key for non-interactive git on the target.
# Arguments:
# - mount_root: <String> Target mount (default /mnt)
_nds_git_install_github_known_hosts() {
    local mount_root="${1:-/mnt}"
    local kh="${mount_root}/etc/ssh/ssh_known_hosts"
    local kh_root="${mount_root}/root/.ssh/known_hosts"
    local line

    mkdir -p "${mount_root}/etc/ssh" "${mount_root}/root/.ssh"
    # Always replace stale/wrong github.com rows (accept-new cannot heal wrong keys).
    for kh in "$kh" "$kh_root"; do
        if [[ -f "$kh" ]]; then
            grep -vE '^github\.com[[:space:]]' "$kh" >"${kh}.nds.tmp" 2>/dev/null || : >"${kh}.nds.tmp"
            mv "${kh}.nds.tmp" "$kh"
        else
            : >"$kh"
        fi
        while IFS= read -r line; do
            [[ -n "$line" ]] || continue
            printf '%s\n' "$line" >>"$kh"
        done < <(nds_git_github_official_host_keys)
        chmod 644 "$kh"
    done
    nds_install_log "git: github.com official host keys -> ssh_known_hosts"
}

# Description: Write git.map lines for URLs whose deploy keys exist on target.
# Arguments:
# - mount_root: <String> Target mount
# - flake_root: <String|optional> Flake checkout (adds lock/flake URLs)
# Returns:
# - <String> map lines on stdout; count on fd3 as digits when available
_nds_git_write_deploy_map_lines() {
    local mount_root="$1" flake_root="${2:-}"
    local ssh_dir="${mount_root}/root/.ssh"
    local url ssh_url parsed host owner repo base dest want
    declare -A seen=()

    printf '# NDS map: owner/repo<TAB>/root/.ssh/nds_deploy_owner_repo\n'

    while IFS= read -r url; do
        [[ -n "$url" ]] || continue
        ssh_url=$(_nds_git_url_toSsh "$url")
        parsed=$(_nds_git_url_parse "$ssh_url") || continue
        IFS=$'\t' read -r host owner repo <<< "$parsed"
        [[ -n "$owner" && -n "$repo" ]] || continue
        want="$(printf '%s/%s' "${owner,,}" "${repo,,}")"
        [[ -n "${seen[$want]:-}" ]] && continue
        base="$(nds_git_deploy_key_basename "$owner" "$repo")"
        dest="${ssh_dir}/${base}"
        [[ -f "$dest" ]] || continue
        seen[$want]=1
        printf '%s\t/root/.ssh/%s\n' "$want" "$base"
    done < <(
        if [[ -n "$flake_root" && -d "$flake_root" ]]; then
            _nds_git_flake_collect_git_remote_urls "$flake_root" "${NDS_CTX_FLAKE_REPO_URL:-${NDS_FLAKE_REPO_URL:-}}"
        elif [[ -n "${NDS_CTX_FLAKE_REPO_URL:-${NDS_FLAKE_REPO_URL:-}}" ]]; then
            _nds_git_url_toSsh "${NDS_CTX_FLAKE_REPO_URL:-$NDS_FLAKE_REPO_URL}"
        fi
    )

    # Fallback: reconstruct from deployed basenames (simple owner_repo; underscore-safe via URLs above)
    for dest in "${ssh_dir}"/nds_deploy_*; do
        [[ -f "$dest" ]] || continue
        [[ "$dest" == *.pub ]] && continue
        base="$(basename "$dest")"
        want="$(nds_git_owner_repo_from_deploy_basename "$base" 2>/dev/null || true)"
        [[ -n "$want" ]] || continue
        want="${want,,}"
        [[ -n "${seen[$want]:-}" ]] && continue
        seen[$want]=1
        printf '%s\t/root/.ssh/%s\n' "$want" "$base"
    done
}

# Description: Seed TC-Tools host CLI onto the target as /var/lib/tcast (all users via PATH).
# Arguments:
# - mount_root: <String> Target mount (default /mnt)
_nds_git_install_nds_helpers_to_target() {
    local mount_root="${1:-/mnt}"
    local tc_root="${mount_root}/var/lib/tcast"
    local src_root f

    src_root="$(_nds_tc_src "")"
    src_root="${src_root%/}"
    [[ -d "${src_root}/bin" && -d "${src_root}/lib" ]] || {
        warn "TC-Tools source missing: ${src_root}"
        return 0
    }

    mkdir -p "${tc_root}/bin" "${tc_root}/lib" "${tc_root}/commands" \
        "${mount_root}/etc/profile.d"

    for f in tcast tcast-git-ssh; do
        [[ -f "${src_root}/bin/${f}" ]] || continue
        _nds_git_install_exe "${src_root}/bin/${f}" "${tc_root}/bin/${f}"
    done
    cp -a "${src_root}/lib/." "${tc_root}/lib/"
    [[ -d "${src_root}/commands" ]] && cp -a "${src_root}/commands/." "${tc_root}/commands/"
    [[ -f "${src_root}/VERSION" ]] && cp -f "${src_root}/VERSION" "${tc_root}/VERSION"

    printf '%s\n' \
        'export PATH="/var/lib/tcast/bin:${PATH}"' \
        '[ -x /var/lib/tcast/bin/tcast-git-ssh ] && export GIT_SSH_COMMAND=/var/lib/tcast/bin/tcast-git-ssh' \
        'export TCAST_GIT_SSH_MAP="${TCAST_GIT_SSH_MAP:-/var/lib/tcast/git.map}"' \
        >"${mount_root}/etc/profile.d/tcast.sh"
    chmod 644 "${mount_root}/etc/profile.d/tcast.sh"
    nds_install_log "git: tcast -> /var/lib/tcast (host CLI seed, all users)"
    return 0
}

# Description: Write owner/repo → key map and install tcast-git-ssh + GIT_SSH_COMMAND.
# Arguments:
# - mount_root: <String> Target mount (default /mnt)
# - flake_root: <String|optional> Flake checkout for URL→key map
_nds_git_install_ssh_wrapper_to_target() {
    local mount_root="${1:-/mnt}"
    local flake_root="${2:-}"
    local ssh_dir="${mount_root}/root/.ssh"
    local tc_root="${mount_root}/var/lib/tcast"
    local map_file="${tc_root}/git.map"
    local wrap_dst="${tc_root}/bin/tcast-git-ssh"
    local env_file installed_map=0

    mkdir -p "$ssh_dir" "$tc_root" "${mount_root}/etc/environment.d" "${mount_root}/etc/profile.d"
    _nds_git_install_nds_helpers_to_target "$mount_root"
    [[ -x "$wrap_dst" ]] || {
        error "tcast-git-ssh missing after seed: ${wrap_dst}"
        return 1
    }

    _nds_git_write_deploy_map_lines "$mount_root" "$flake_root" >"$map_file"
    installed_map=$(grep -cvE '^(#|$)' "$map_file" 2>/dev/null || echo 0)
    installed_map="${installed_map%%$'\n'*}"
    installed_map="${installed_map:-0}"
    chmod 600 "$map_file"

    env_file="${mount_root}/etc/environment.d/50-tcast-git-ssh.conf"
    printf '%s\n' \
        'GIT_SSH_COMMAND=/var/lib/tcast/bin/tcast-git-ssh' \
        'TCAST_GIT_SSH_MAP=/var/lib/tcast/git.map' \
        >"$env_file"
    chmod 644 "$env_file"

    nds_install_log "git: tcast-git-ssh + map (${installed_map} entries) -> /var/lib/tcast/"
    _nds_git_install_github_known_hosts "$mount_root"
    [[ "$installed_map" -gt 0 ]]
}

# Description: Prove target can ls-remote private flake git inputs via tcast-git-ssh.
# Arguments:
# - mount_root: <String> Target mount (default /mnt)
# - flake_root: <String> Flake checkout on target (e.g. /mnt/etc/nixos)
# Returns:
# - <Bool> 0 when all private SSH remotes probe OK
nds_git_verify_target_ro_access() {
    local mount_root="${1:-/mnt}"
    local flake_root="${2:-}"
    local wrap="${mount_root}/var/lib/tcast/bin/tcast-git-ssh"
    local url ssh_url rc=0 fail=0 probed=0

    [[ -x "$wrap" ]] || {
        error "tcast-git-ssh missing on target (${wrap})"
        return 1
    }
    [[ -n "$flake_root" && -d "$flake_root" ]] || {
        error "Flake root missing for git RO verify: ${flake_root}"
        return 1
    }

    while IFS= read -r url; do
        [[ -n "$url" ]] || continue
        ssh_url=$(_nds_git_url_toSsh "$url")
        if nds_git_probe_public "$ssh_url" 2>/dev/null; then
            debug "Target skip public: ${ssh_url}"
            continue
        fi
        probed=$((probed + 1))
        if command -v timeout &>/dev/null; then
            timeout 20 env GIT_SSH_COMMAND="$wrap" TCAST_GIT_SSH_ROOT="$mount_root" \
                GIT_TERMINAL_PROMPT=0 \
                git -c credential.helper= ls-remote "$ssh_url" &>/dev/null
        else
            env GIT_SSH_COMMAND="$wrap" TCAST_GIT_SSH_ROOT="$mount_root" \
                GIT_TERMINAL_PROMPT=0 \
                git -c credential.helper= ls-remote "$ssh_url" &>/dev/null
        fi || rc=$?
        if [[ "${rc:-0}" -ne 0 ]]; then
            error "Target git RO probe failed: ${ssh_url}"
            fail=$((fail + 1))
        else
            nds_install_log "git: target probe OK ${ssh_url}"
        fi
        rc=0
    done < <(_nds_git_flake_collect_git_remote_urls "$flake_root" "${NDS_CTX_FLAKE_REPO_URL:-${NDS_FLAKE_REPO_URL:-}}")

    [[ "$fail" -eq 0 ]] || return 1
    [[ "$probed" -gt 0 ]] && nds_install_log "git: target RO probes OK (${probed} private)"
    return 0
}

# Description: Install deploy keys under /mnt/root/.ssh and wire tcast host CLI.
# Arguments:
# - mount_root: <String|optional> Target mount (default /mnt)
# - flake_root: <String|optional> Flake checkout (map + verify)
# Returns:
# - <Bool> 0 on success; 1 when private inputs need keys but none installed
nds_install_git_keys_to_target() {
    local mount_root="${1:-/mnt}"
    local flake_root="${2:-${NDS_CTX_FLAKE_INSTALL_PATH:-${NDS_FLAKE_INSTALL_PATH:-}}}"
    local -a keys=()
    local key_path base dest_rel dest installed=0
    local need_private=false url

    [[ -d "$mount_root" ]] || {
        debug "Target mount missing — skip git SSH key install"
        return 0
    }

    if ! nds_git_persist_access; then
        nds_install_log "git: GIT_PERSIST_ACCESS=false — skip keys and tcast on target"
        info "Install-time git access only — SSH keys and tcast will not be copied to the installed machine."
        return 0
    fi

    if [[ -n "$flake_root" && -d "$flake_root" ]]; then
        while IFS= read -r url; do
            [[ -n "$url" ]] || continue
            if ! nds_git_probe_public "$(_nds_git_url_toSsh "$url")" 2>/dev/null; then
                need_private=true
                break
            fi
        done < <(_nds_git_flake_collect_git_remote_urls "$flake_root" "${NDS_CTX_FLAKE_REPO_URL:-${NDS_FLAKE_REPO_URL:-}}")
    else
        # No flake root yet — if deploy keys exist in session, still install them.
        need_private=true
    fi

    mapfile -t keys < <(_nds_git_collect_deploy_key_paths)
    # Prefer only nds_deploy_* files for target wiring
    local -a deploy_keys=()
    for key_path in "${keys[@]}"; do
        [[ -f "$key_path" ]] || continue
        [[ "$(basename "$key_path")" == nds_deploy_* ]] || continue
        deploy_keys+=("$key_path")
    done

    if [[ ${#deploy_keys[@]} -eq 0 ]]; then
        if [[ "$need_private" == "true" ]]; then
            error "No deploy keys to install (need nds_deploy_* under ${NDS_GIT_DEPLOY_KEYS_DIR:-/root/.ssh})"
            return 1
        fi
        nds_install_log "git: no private flake inputs — skip deploy key install"
        return 0
    fi

    mkdir -p "${mount_root}/root/.ssh"
    chmod 700 "${mount_root}/root/.ssh"
    for key_path in "${deploy_keys[@]}"; do
        base="$(basename "$key_path")"
        dest_rel="root/.ssh/${base}"
        dest="${mount_root}/${dest_rel}"
        _nds_git_install_exe "$key_path" "$dest" 600
        [[ -f "${key_path}.pub" ]] && _nds_git_install_exe "${key_path}.pub" "${dest}.pub" 644
        nds_install_log "git: SSH key -> /${dest_rel}"
        installed=$((installed + 1))
    done

    [[ "$installed" -gt 0 ]] || {
        error "No nds_deploy_* keys were copied to target /root/.ssh"
        return 1
    }

    _nds_git_install_ssh_wrapper_to_target "$mount_root" "$flake_root" || return 1

    if [[ "$need_private" == "true" && -n "$flake_root" && -d "$flake_root" ]]; then
        nds_git_verify_target_ro_access "$mount_root" "$flake_root" || return 1
    fi
    return 0
}
