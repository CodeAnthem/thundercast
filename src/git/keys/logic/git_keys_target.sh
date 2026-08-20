#!/usr/bin/env bash
# ==================================================================================================
# NDS - Install git SSH keys and nds-git-ssh onto the target
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-07 | Modified: 2026-08-20
# Description:   Copy deploy keys, known_hosts, and helper CLIs under /mnt
# ==================================================================================================

# Description: Absolute path of a helper script in this NDS tools tree.
_nds_git_tool_src() {
    printf '%s/scripts/%s\n' "${SCRIPT_DIR}" "$1"
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

# Description: Append NDS bin PATH tip to a root home dotfile under mount_root.
_nds_git_append_root_path_snippet() {
    local mount_root="$1" dotfile="$2"
    local target="${mount_root}/root/${dotfile}"
    local snippet='# NDS helpers
export PATH="/root/.nds/bin:/root/bin:$PATH"
[ -x /root/.nds/bin/nds-git-ssh ] && export GIT_SSH_COMMAND=/root/.nds/bin/nds-git-ssh
'
    grep -q '/root/.nds/bin' "$target" 2>/dev/null && return 0
    if [[ -f "$target" ]]; then
        printf '\n%s' "$snippet" >>"$target"
    else
        printf '%s' "$snippet" >"$target"
    fi
    chmod 644 "$target"
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

# Description: Write nds-git.map lines for URLs whose deploy keys exist on target.
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

# Description: Install nds-switch / nds-clean onto the target (no private keys).
# Arguments:
# - mount_root: <String> Target mount (default /mnt)
_nds_git_install_nds_helpers_to_target() {
    local mount_root="${1:-/mnt}"
    local switch_src switch_dst wrap_src clean_src clean_dst status_src

    mkdir -p "${mount_root}/root/bin" "${mount_root}/root/.nds/bin" \
        "${mount_root}/etc/profile.d"
    switch_src="$(_nds_git_tool_src nds-switch.sh)"
    switch_dst="${mount_root}/root/.nds/bin/nds-switch"
    wrap_src="$(_nds_git_tool_src nds-git-ssh.sh)"
    clean_src="$(_nds_git_tool_src nds-clean.sh)"
    clean_dst="${mount_root}/root/.nds/bin/nds-clean"
    [[ -f "$switch_src" ]] || {
        warn "nds-switch source missing: ${switch_src}"
        return 0
    }
    _nds_git_install_exe "$switch_src" "$switch_dst"
    if [[ -f "$wrap_src" ]]; then
        _nds_git_install_exe "$wrap_src" "${mount_root}/root/.nds/bin/nds-git-ssh"
    fi
    if [[ -f "$clean_src" ]]; then
        _nds_git_install_exe "$clean_src" "$clean_dst"
        cp -f "$clean_dst" "${mount_root}/root/bin/nds-clean"
        chmod 755 "${mount_root}/root/bin/nds-clean"
    fi
    cp -f "$switch_dst" "${mount_root}/root/bin/nds-switch"
    chmod 755 "${mount_root}/root/bin/nds-switch"
    ln -sfn nds-switch "${mount_root}/root/.nds/bin/tc-switch"
    ln -sfn nds-switch "${mount_root}/root/bin/tc-switch"
    if [[ -f "$clean_dst" ]]; then
        ln -sfn nds-clean "${mount_root}/root/.nds/bin/tc-clean"
        ln -sfn nds-clean "${mount_root}/root/bin/tc-clean"
    fi
    if [[ -x "${mount_root}/root/.nds/bin/nds-git-ssh" ]]; then
        ln -sfn nds-git-ssh "${mount_root}/root/.nds/bin/tc-git-ssh"
    fi
    status_src="$(_nds_git_tool_src tc-status.sh)"
    if [[ -f "$status_src" ]]; then
        _nds_git_install_exe "$status_src" "${mount_root}/root/.nds/bin/tc-status"
        cp -f "${mount_root}/root/.nds/bin/tc-status" "${mount_root}/root/bin/tc-status"
        chmod 755 "${mount_root}/root/bin/tc-status"
    fi
    printf 'export PATH="/root/.nds/bin:/root/bin:${PATH}"\n' \
        >"${mount_root}/etc/profile.d/nds-root-bin.sh"
    chmod 644 "${mount_root}/etc/profile.d/nds-root-bin.sh"
    _nds_git_append_root_path_snippet "$mount_root" .bash_profile
    _nds_git_append_root_path_snippet "$mount_root" .profile
    _nds_git_append_root_path_snippet "$mount_root" .bashrc
    nds_install_log "git: nds-switch -> /root/.nds/bin/nds-switch"
    [[ -f "$clean_src" ]] && nds_install_log "git: nds-clean -> /root/.nds/bin/nds-clean"
    return 0
}

# Description: Write owner/repo → key map and install nds-git-ssh + GIT_SSH_COMMAND.
# Arguments:
# - mount_root: <String> Target mount (default /mnt)
# - flake_root: <String|optional> Flake checkout for URL→key map
_nds_git_install_ssh_wrapper_to_target() {
    local mount_root="${1:-/mnt}"
    local flake_root="${2:-}"
    local ssh_dir="${mount_root}/root/.ssh"
    local map_file="${ssh_dir}/nds-git.map"
    local wrap_dst="${ssh_dir}/nds-git-ssh"
    local wrap_src env_file installed_map=0

    # NixOS: prefer /root/.nds/bin (survives self-update); keep profile.d PATH tip.
    mkdir -p "$ssh_dir" "${mount_root}/etc/environment.d" \
        "${mount_root}/root/bin" "${mount_root}/root/.nds/bin" "${mount_root}/etc/profile.d"
    wrap_src="$(_nds_git_tool_src nds-git-ssh.sh)"
    [[ -f "$wrap_src" ]] || {
        error "nds-git-ssh source missing: ${wrap_src}"
        return 1
    }
    _nds_git_install_exe "$wrap_src" "$wrap_dst"
    _nds_git_install_nds_helpers_to_target "$mount_root"
    if [[ -x "${mount_root}/root/.nds/bin/nds-switch" ]]; then
        cp -f "${mount_root}/root/.nds/bin/nds-switch" "${ssh_dir}/nds-switch"
        chmod 755 "${ssh_dir}/nds-switch"
    fi

    _nds_git_write_deploy_map_lines "$mount_root" "$flake_root" >"$map_file"
    installed_map=$(grep -cvE '^(#|$)' "$map_file" 2>/dev/null || echo 0)
    # grep can print "0\n0" on some versions when file is empty-ish — take first integer
    installed_map="${installed_map%%$'\n'*}"
    installed_map="${installed_map:-0}"
    chmod 600 "$map_file"
    ln -sfn nds-git.map "${ssh_dir}/tc-git.map"

    env_file="${mount_root}/etc/environment.d/50-nds-git-ssh.conf"
    printf 'GIT_SSH_COMMAND=/root/.ssh/nds-git-ssh\n' >"$env_file"
    chmod 644 "$env_file"

    mkdir -p "${mount_root}/etc/profile.d"
    printf 'export GIT_SSH_COMMAND=/root/.ssh/nds-git-ssh\n' \
        >"${mount_root}/etc/profile.d/nds-git-ssh.sh"
    chmod 644 "${mount_root}/etc/profile.d/nds-git-ssh.sh"

    # Login shells / nixos-rebuild as root
    if [[ ! -f "${ssh_dir}/.nds-git-ssh-profile" ]]; then
        printf 'export GIT_SSH_COMMAND=/root/.ssh/nds-git-ssh\n' >"${ssh_dir}/.nds-git-ssh-profile"
        chmod 644 "${ssh_dir}/.nds-git-ssh-profile"
    fi
    mkdir -p "${mount_root}/root"
    if [[ -f "${mount_root}/root/.bash_profile" ]]; then
        grep -q 'nds-git-ssh-profile' "${mount_root}/root/.bash_profile" 2>/dev/null \
            || printf '\n# NDS git+ssh deploy keys\n[ -f /root/.ssh/.nds-git-ssh-profile ] && . /root/.ssh/.nds-git-ssh-profile\n' \
                >>"${mount_root}/root/.bash_profile"
    else
        printf '# NDS git+ssh deploy keys\n[ -f /root/.ssh/.nds-git-ssh-profile ] && . /root/.ssh/.nds-git-ssh-profile\n' \
            >"${mount_root}/root/.bash_profile"
        chmod 644 "${mount_root}/root/.bash_profile"
    fi

    nds_install_log "git: nds-git-ssh + map (${installed_map} entries) -> /root/.ssh/"
    _nds_git_install_github_known_hosts "$mount_root"
    [[ "$installed_map" -gt 0 ]]
}

# Description: Prove target can ls-remote private flake git inputs via nds-git-ssh.
# Arguments:
# - mount_root: <String> Target mount (default /mnt)
# - flake_root: <String> Flake checkout on target (e.g. /mnt/etc/nixos)
# Returns:
# - <Bool> 0 when all private SSH remotes probe OK
nds_git_verify_target_ro_access() {
    local mount_root="${1:-/mnt}"
    local flake_root="${2:-}"
    local wrap="${mount_root}/root/.ssh/nds-git-ssh"
    local url ssh_url rc=0 fail=0 probed=0

    [[ -x "$wrap" ]] || {
        error "nds-git-ssh missing on target (${wrap})"
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
            timeout 20 env GIT_SSH_COMMAND="$wrap" NDS_GIT_SSH_ROOT="$mount_root" \
                GIT_TERMINAL_PROMPT=0 \
                git -c credential.helper= ls-remote "$ssh_url" &>/dev/null
        else
            env GIT_SSH_COMMAND="$wrap" NDS_GIT_SSH_ROOT="$mount_root" \
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

# Description: Install deploy keys under /mnt/root/.ssh and wire nds-git-ssh.
# Arguments:
# - mount_root: <String|optional> Target mount (default /mnt)
# - flake_root: <String|optional> Flake checkout (map + verify)
# Returns:
# - <Bool> 0 on success; 1 when private inputs need keys but none installed
nds_git_install_keys_to_target() {
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
        nds_install_log "git: GIT_PERSIST_ACCESS=false — skip keys and nds-switch on target"
        info "Install-time git access only — SSH keys and nds-switch will not be copied to the installed machine."
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
