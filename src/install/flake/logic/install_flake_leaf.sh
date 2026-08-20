#!/usr/bin/env bash
# ==================================================================================================
# NDS - Leaf flake helpers for remoteAction (thundercast + .roles)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-17 | Modified: 2026-08-20
# Description:   Resolve thundercast action, role NDS env, hooks, leaf commit/push
# ==================================================================================================

# Portable keys written to .nds/hosts/<name>.env (no secrets, no disk device).
_NDS_LEAF_HOST_ENV_KEYS=(
    FLAKE_HOST
    FLAKE_HOST_DIR
    FLAKE_HARDWARE_PLACEMENT
    FLAKE_REPO_URL
    SCAFFOLD_ROLE
    ENCRYPTION
    DISK_STRATEGY
    DISK_FS_TYPE
    DISK_SWAP_SIZE_MIB
    BOOT_UEFI_MODE
    BOOT_LOADER
    NETWORK_HOSTNAME
)

# Description: True when owner/repo is the install flake (private leaf).
# Arguments:
# - owner: <String> Git owner
# - repo:  <String> Git repo name
_nds_git_is_install_leaf() {
    local owner="$1" repo="$2"
    local url parsed leaf_owner leaf_repo
    url="${NDS_FLAKE_REPO_URL:-}"
    [[ -z "$url" ]] && declare -f nds_cfg_get &>/dev/null \
        && url="$(nds_cfg_get FLAKE_REPO_URL 2>/dev/null || true)"
    [[ -n "$url" ]] || return 1
    url="$(_nds_git_url_toSsh "$url")"
    parsed="$(_nds_git_url_parse "$url")" || return 1
    IFS=$'\t' read -r _ leaf_owner leaf_repo <<< "$parsed"
    [[ "${owner,,}" == "${leaf_owner,,}" && "${repo,,}" == "${leaf_repo,,}" ]]
}

# Description: Read a locked flake.lock node field (rev, url, type, owner, repo).
# Arguments:
# - lock_file: <String> Path to flake.lock
# - node:      <String> Node name (e.g. thundercast)
# - field:     <String> locked field
# Returns:
# - <String> Field value (stdout), empty when missing
_nds_install_flake_lock_node_field() {
    local lock_file="$1" node="$2" field="$3"
    [[ -f "$lock_file" ]] || return 0
    awk -v node="$node" -v field="$field" '
        $0 ~ "^    \"" node "\": \\{$" { innode=1; next }
        innode && $0 ~ /^    "[^"]+": \{/ { innode=0 }
        innode && $0 ~ "\"" field "\": " {
            line=$0
            sub(/^[[:space:]]*"[^"]+":[[:space:]]*/, "", line)
            gsub(/^"/, "", line)
            gsub(/",?$/, "", line)
            print line
            exit
        }
    ' "$lock_file"
}

# Description: Git URL for a flake.lock input (git url or github owner/repo).
# Arguments:
# - flake_root: <String> Checked-out flake
# - node:       <String> Input node name
# Returns:
# - <String> SSH git URL (stdout)
_nds_install_flake_lock_input_url() {
    local flake_root="$1" node="$2"
    local lock="${flake_root}/flake.lock"
    local url type owner repo
    url="$(_nds_install_flake_lock_node_field "$lock" "$node" url)"
    if [[ -n "$url" ]]; then
        _nds_git_url_toSsh "$url"
        return 0
    fi
    type="$(_nds_install_flake_lock_node_field "$lock" "$node" type)"
    owner="$(_nds_install_flake_lock_node_field "$lock" "$node" owner)"
    repo="$(_nds_install_flake_lock_node_field "$lock" "$node" repo)"
    if [[ "$type" == "github" && -n "$owner" && -n "$repo" ]]; then
        printf 'git@github.com:%s/%s.git\n' "$owner" "$repo"
        return 0
    fi
    return 1
}

# Description: Clone (or reuse) the leaf's pinned thundercast input.
# Arguments:
# - flake_root: <String> Private leaf checkout
# Returns:
# - <String> Path to thundercast source (stdout)
nds_flake_resolve_thundercast_src() {
    local flake_root="$1"
    local dest url rev
    dest="${NDS_RUNTIME_DIR:-/tmp/nds}/thundercast-src"

    if [[ -f "${dest}/.nds/action.sh" ]]; then
        printf '%s\n' "$dest"
        return 0
    fi

    url="$(_nds_install_flake_lock_input_url "$flake_root" thundercast)" || {
        error "Leaf flake.lock has no thundercast input — remoteAction needs thundercast (or a leaf .nds/action.sh override)"
        return 1
    }
    rev="$(_nds_install_flake_lock_node_field "${flake_root}/flake.lock" thundercast rev)"

    rm -rf "$dest"
    mkdir -p "$(dirname "$dest")"
    if ! nds_git_clone "$url" "$dest" 1; then
        error "Cannot clone thundercast input (${url})"
        return 1
    fi
    if [[ -n "$rev" ]]; then
        _nds_install_flake_git_for_url "$url" -C "$dest" fetch --depth 1 origin "$rev" &>/dev/null \
            && _nds_install_flake_git_for_url "$url" -C "$dest" checkout "$rev" --quiet \
            || warn "Could not pin thundercast to ${rev} — using cloned default branch"
    fi
    if [[ ! -f "${dest}/.nds/action.sh" ]]; then
        error "thundercast checkout has no .nds/action.sh"
        return 1
    fi
    printf '%s\n' "$dest"
}

# Description: Run git with the SSH identity mapped to a remote URL.
_nds_install_flake_git_for_url() {
    local url="$1"
    shift
    local -a envv=()
    while IFS= read -r line; do
        envv+=("$line")
    done < <(_nds_git_ssh_env_for_url "$url")
    env "${envv[@]}" git -c credential.helper= "$@"
}

# Description: Source leaf and role hook scripts for one lifecycle name.
# Arguments:
# - flake_root: <String> Leaf checkout
# - hook:       <String> post_scaffold | pre_install | post_install
nds_install_flake_run_hooks() {
    local flake_root="$1"
    local hook="$2"
    local role script
    role="$(nds_cfg_get SCAFFOLD_ROLE 2>/dev/null || true)"
    export NDS_LEAF_HOOK="$hook"
    for script in \
        "${flake_root}/.nds/hooks/${hook}.sh" \
        "${flake_root}/.roles/${role}/hooks/${hook}.sh"; do
        [[ -f "$script" ]] || continue
        info "Leaf hook: ${script#"$flake_root"/}"
        # shellcheck disable=SC1090
        nds_import_file "$script" || {
            error "Hook failed: $script"
            return 1
        }
    done
    return 0
}

# Description: Write portable NDS knobs for a host into the leaf repo.
# Arguments:
# - flake_root: <String> Leaf checkout
# - hostname:   <String> Host name
nds_flake_write_host_nds_env() {
    local flake_root="$1"
    local hostname="$2"
    local dest key val
    [[ -n "$hostname" ]] || return 1
    dest="${flake_root}/.nds/hosts/${hostname}.env"
    mkdir -p "$(dirname "$dest")"
    {
        echo "# NDS host restore for ${hostname} — no secrets. Written by NDS compose."
        for key in "${_NDS_LEAF_HOST_ENV_KEYS[@]}"; do
            val="$(nds_cfg_get "$key" 2>/dev/null || true)"
            [[ -n "$val" ]] || continue
            val="${val//\\/\\\\}"
            val="${val//\"/\\\"}"
            printf 'export NDS_%s="%s"\n' "$key" "$val"
        done
    } >"$dest"
    _nds_flake_write_host_inventory "$flake_root" "$hostname"
    if declare -f nds_sm_export &>/dev/null; then
        nds_sm_export --git "${flake_root}/.nds/hosts/${hostname}.recipe" || return 1
    fi
    nds_install_log "leaf: wrote ${dest#"$flake_root"/}"
}

# Description: Write .nds/hosts/<name>.inventory (hostname, role, age pub path).
# Arguments:
# - flake_root: <String> Leaf checkout
# - hostname:   <String> Host name
_nds_flake_write_host_inventory() {
    local flake_root="$1"
    local hostname="$2"
    local dest role ssh
    dest="${flake_root}/.nds/hosts/${hostname}.inventory"
    role="$(nds_cfg_get SCAFFOLD_ROLE 2>/dev/null || true)"
    ssh="$(nds_cfg_get NETWORK_IP 2>/dev/null || true)"
    {
        echo "host=${hostname}"
        echo "role=${role}"
        echo "ssh=${ssh}"
        echo "age_pub=.nds/hosts/${hostname}.age.pub"
    } >"$dest"
}

# Description: Load .nds/hosts/<name>.env into CONFIG_DATA.
# Arguments:
# - env_file: <String> Path to env file
nds_flake_load_host_nds_env() {
    local env_file="$1"
    local line key val
    [[ -f "$env_file" ]] || return 1
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ "$line" == export\ NDS_* ]] || continue
        key="${line#export NDS_}"
        key="${key%%=*}"
        val="${line#export NDS_${key}=}"
        val="${val#\"}"
        val="${val%\"}"
        nds_cfg_set "$key" "$val"
    done < "$env_file"
    info "Loaded NDS restore env from ${env_file}"
}

# Description: Restore a host session from the leaf. Prefers .recipe, then legacy .env.
# Arguments:
# - flake_root: <String> Leaf checkout
# - hostname:   <String> Host name
nds_flake_load_host_restore() {
    local flake_root="$1"
    local hostname="$2"
    local recipe env_file
    [[ -n "$hostname" ]] || return 1
    recipe="${flake_root}/.nds/hosts/${hostname}.recipe"
    env_file="${flake_root}/.nds/hosts/${hostname}.env"
    if [[ -f "$recipe" ]] && declare -f nds_sm_load &>/dev/null; then
        nds_sm_load "$recipe" || return 1
        info "Loaded NDS recipe from ${recipe}"
        return 0
    fi
    if [[ -f "$env_file" ]]; then
        nds_flake_load_host_nds_env "$env_file"
        return $?
    fi
    warn "No .nds/hosts/${hostname}.recipe or .env — using current NDS settings"
    return 0
}

# Description: Source .roles/<role>/nds.sh or .nds/<role>/nds.sh when present.
# Arguments:
# - flake_root: <String> Leaf checkout
# - role:       <String> Role id
nds_flake_apply_role_nds() {
    local flake_root="$1"
    local role="$2"
    local script="${flake_root}/.roles/${role}/nds.sh"
    [[ -f "$script" ]] || script="${flake_root}/.nds/${role}/nds.sh"
    [[ -n "$role" && -f "$script" ]] || return 0
    info "Applying role NDS defaults: ${script#"${flake_root}/"}"
    # shellcheck disable=SC1090
    nds_import_file "$script"
}

# Description: Commit host + NDS env and push to the leaf origin (write access).
# Arguments:
# - flake_root: <String> Leaf checkout
# - message:    <String> Commit message
nds_install_flake_commit_push_leaf() {
    local flake_root="$1"
    local message="$2"
    local url branch
    url="${NDS_FLAKE_REPO_URL:-$(nds_cfg_get FLAKE_REPO_URL 2>/dev/null || true)}"

    [[ -d "${flake_root}/.git" ]] || {
        warn "Leaf checkout is not a git repo — skip push"
        return 0
    }
    [[ -n "$url" ]] || {
        error "FLAKE_REPO_URL missing — cannot push host files"
        return 1
    }

    git -C "$flake_root" add -- "hosts" ".nds" ".sops.yaml" "secrets" 2>/dev/null || true
    if git -C "$flake_root" diff --cached --quiet 2>/dev/null; then
        info "No new host files to commit"
        return 0
    fi

    git -C "$flake_root" \
        -c user.name=NDS \
        -c user.email=nds@localhost \
        commit -m "$message" || return 1

    branch="$(git -C "$flake_root" symbolic-ref --short HEAD 2>/dev/null || true)"
    [[ -n "$branch" ]] || branch="main"

    if ! _nds_install_flake_git_for_url "$url" -C "$flake_root" push origin "HEAD:refs/heads/${branch}"; then
        error "git push to leaf failed — remoteAction needs write access on ${url}"
        error "Re-register the leaf deploy key with write, or use an account key that can push"
        return 1
    fi
    success "Pushed host files to ${url} (${branch})"
    return 0
}

# Description: Dry-run push so a read-only deploy key fails before role/settings.
# Arguments:
# - flake_root: <String> Leaf checkout
nds_install_flake_probe_leaf_write() {
    local flake_root="$1"
    local url branch err rc=0
    url="${NDS_FLAKE_REPO_URL:-$(nds_cfg_get FLAKE_REPO_URL 2>/dev/null || true)}"

    [[ -d "${flake_root}/.git" ]] || {
        warn "Leaf checkout is not a git repo — skip write probe"
        return 0
    }
    [[ -n "$url" ]] || {
        error "FLAKE_REPO_URL missing — cannot verify leaf write access"
        return 1
    }

    branch="$(git -C "$flake_root" symbolic-ref --short HEAD 2>/dev/null || true)"
    [[ -n "$branch" ]] || branch="main"

    err=$(_nds_install_flake_git_for_url "$url" -C "$flake_root" \
        push --dry-run origin "HEAD:refs/heads/${branch}" 2>&1) || rc=$?
    if [[ "$rc" -ne 0 ]]; then
        error "Leaf git key cannot push — GitHub deploy keys are read-only unless Allow write access is on"
        error "Re-register the leaf key with write, or use an account key that can push: ${url}"
        [[ -n "$err" ]] && error "$err"
        return 1
    fi
    return 0
}
