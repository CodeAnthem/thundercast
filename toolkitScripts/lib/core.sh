# ==================================================================================================
# Thundercast - toolkit core (paths, leaf clone, logging)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-19 | Modified: 2026-08-20
# Description:   Leaf git lives under TCAST_LEAF_DIR — not /etc/nixos
# ==================================================================================================

TCAST_TOOLKIT_OP_KEY="${SOPS_AGE_KEY_FILE:-/etc/sops/age/operator.txt}"
TCAST_LEAF_DIR="${TCAST_LEAF_DIR:-/var/lib/nds-toolkit/leaf}"
TCAST_LEAF_BRANCH="${TCAST_LEAF_BRANCH:-main}"
TCAST_REGISTER_REL=".nds/toolkit-register"

tcast_die() {
    echo "toolkit: $*" >&2
    exit 1
}

tcast_info() {
    echo "toolkit: $*" >&2
}

tcast_toolkit_version() {
    local root="${TCAST_TOOLKIT_ROOT:-}"
    if [[ -n "$root" && -f "${root}/VERSION" ]]; then
        tr -d '[:space:]' < "${root}/VERSION"
        return 0
    fi
    printf 'unknown'
}

tcast_now() {
    date -u +%Y-%m-%dT%H:%M:%SZ
}

tcast_leaf() {
    printf '%s\n' "${TCAST_LEAF_DIR}"
}

tcast_register_dir() {
    printf '%s/%s\n' "$(tcast_leaf)" "$TCAST_REGISTER_REL"
}

tcast_git_ssh_env() {
    if command -v tc-git-ssh >/dev/null 2>&1; then
        export GIT_SSH_COMMAND="tc-git-ssh"
    elif command -v nds-git-ssh >/dev/null 2>&1; then
        export GIT_SSH_COMMAND="nds-git-ssh"
    elif [[ -x /root/.ssh/nds-git-ssh ]]; then
        export GIT_SSH_COMMAND="/root/.ssh/nds-git-ssh"
    fi
}

# Description: Clone or reuse TCAST_LEAF_DIR. Never the NixOS or comin checkout.
tcast_leaf_assert_separate() {
    local dir
    dir="$(readlink -f "$(tcast_leaf)" 2>/dev/null || tcast_leaf)"
    case "$dir" in
        /etc/nixos|/mnt/etc/nixos|/var/lib/comin|/var/lib/comin/*)
            tcast_die "toolkit leaf must not be ${dir} (nds-switch uses /etc/nixos, comin uses /var/lib/comin/repository)"
            ;;
    esac
}

# Description: Clone or reuse TCAST_LEAF_DIR. Never edit /etc/nixos in place.
tcast_leaf_ensure() {
    local dir repo src_url
    dir="$(tcast_leaf)"
    tcast_leaf_assert_separate
    repo="${TCAST_LEAF_REPO:-}"
    mkdir -p "$(dirname "$dir")"
    if [[ -d "${dir}/.git" ]]; then
        return 0
    fi
    tcast_git_ssh_env
    if [[ -n "$repo" ]]; then
        tcast_info "cloning leaf ${repo} -> ${dir}"
        git clone --branch "$TCAST_LEAF_BRANCH" --single-branch "$repo" "$dir" \
            || git clone "$repo" "$dir" \
            || tcast_die "could not clone leaf ${repo}"
        return 0
    fi
    if [[ -d /etc/nixos/.git && "$dir" != /etc/nixos ]]; then
        tcast_info "seeding leaf clone from /etc/nixos (workspace stays ${dir})"
        git clone /etc/nixos "$dir" || tcast_die "could not clone /etc/nixos -> ${dir}"
        src_url="$(git -C /etc/nixos remote get-url origin 2>/dev/null || true)"
        if [[ -n "$src_url" ]]; then
            git -C "$dir" remote set-url origin "$src_url" || true
        fi
        return 0
    fi
    tcast_die "leaf clone missing at ${dir} (set TCAST_LEAF_REPO)"
}

tcast_leaf_require() {
    tcast_leaf_ensure
    local dir
    dir="$(tcast_leaf)"
    [[ -d "${dir}/.git" ]] || tcast_die "leaf is not a git checkout: ${dir}"
    [[ -f "${dir}/flake.nix" || -f "${dir}/.sops.yaml" ]] \
        || tcast_info "warning: ${dir} has no flake.nix / .sops.yaml yet"
}

tcast_leaf_fetch() {
    local dir
    tcast_leaf_require
    dir="$(tcast_leaf)"
    tcast_git_ssh_env
    git -C "$dir" remote get-url origin >/dev/null 2>&1 || return 0
    git -C "$dir" fetch origin 2>/dev/null || true
}

tcast_leaf_remote_ref() {
    printf 'origin/%s\n' "${TCAST_LEAF_BRANCH:-main}"
}

# Description: Files dirty locally that origin also changed (merge would overwrite).
tcast_leaf_collision_files() {
    local dir remote
    dir="$(tcast_leaf)"
    remote="$(tcast_leaf_remote_ref)"
    git -C "$dir" rev-parse --verify "$remote" >/dev/null 2>&1 || return 0
    comm -12 \
        <({
            git -C "$dir" diff --name-only HEAD
            git -C "$dir" diff --cached --name-only
            git -C "$dir" ls-files --others --exclude-standard
        } | sort -u) \
        <(git -C "$dir" diff --name-only "HEAD...${remote}" | sort -u)
}

tcast_leaf_is_dirty() {
    local dir
    dir="$(tcast_leaf)"
    if ! git -C "$dir" diff --quiet || ! git -C "$dir" diff --cached --quiet; then
        return 0
    fi
    [[ -n "$(git -C "$dir" ls-files --others --exclude-standard)" ]]
}

tcast_leaf_reset_to_origin() {
    local dir remote
    dir="$(tcast_leaf)"
    remote="$(tcast_leaf_remote_ref)"
    tcast_git_ssh_env
    git -C "$dir" reset --hard "$remote"
}

# Description: Fetch origin and fast-forward when that would not overwrite local edits.
# Sets TCAST_LEAF_BEHIND, TCAST_LEAF_COLLISIONS, TCAST_LEAF_SYNC_NEED_PROMPT.
# Always returns 0 (callers must not rely on status under set -e).
tcast_leaf_sync() {
    local dir remote behind f
    TCAST_LEAF_BEHIND=0
    TCAST_LEAF_COLLISIONS=""
    TCAST_LEAF_SYNC_NEED_PROMPT=0
    tcast_leaf_require
    tcast_leaf_assert_separate
    dir="$(tcast_leaf)"
    remote="$(tcast_leaf_remote_ref)"
    tcast_git_ssh_env
    git -C "$dir" remote get-url origin >/dev/null 2>&1 || return 0
    git -C "$dir" fetch origin --quiet 2>/dev/null || {
        tcast_info "leaf fetch failed"
        return 0
    }
    git -C "$dir" rev-parse --verify "$remote" >/dev/null 2>&1 || return 0
    behind="$(git -C "$dir" rev-list --count "HEAD..${remote}" 2>/dev/null || echo 0)"
    TCAST_LEAF_BEHIND="$behind"
    [[ "$behind" == 0 ]] && return 0
    while IFS= read -r f; do
        [[ -n "$f" ]] || continue
        case "$f" in
            .nds/toolkit-register/*) ;;
            *) continue ;;
        esac
        if [[ -e "${dir}/${f}" ]] && ! git -C "$dir" ls-files --error-unmatch "$f" >/dev/null 2>&1; then
            rm -f "${dir}/${f}"
        fi
    done < <(git -C "$dir" ls-tree -r --name-only "$remote")
    TCAST_LEAF_COLLISIONS="$(tcast_leaf_collision_files || true)"
    if [[ -n "$TCAST_LEAF_COLLISIONS" ]]; then
        TCAST_LEAF_SYNC_NEED_PROMPT=1
        return 0
    fi
    if git -C "$dir" merge --ff-only "$remote" >/dev/null 2>&1; then
        tcast_info "leaf fast-forwarded ${behind} commit(s) to ${remote}"
        TCAST_LEAF_BEHIND=0
        return 0
    fi
    TCAST_LEAF_SYNC_NEED_PROMPT=1
    TCAST_LEAF_COLLISIONS="$(git -C "$dir" diff --name-only HEAD | sort -u)"
}

tcast_leaf_status_line() {
    local dir short remote behind extra=""
    dir="$(tcast_leaf)"
    remote="$(tcast_leaf_remote_ref)"
    short="$(git -C "$dir" rev-parse --short HEAD 2>/dev/null || echo none)"
    tcast_leaf_is_dirty && extra=", unsaved"
    if git -C "$dir" rev-parse --verify "$remote" >/dev/null 2>&1; then
        behind="$(git -C "$dir" rev-list --count "HEAD..${remote}" 2>/dev/null || echo 0)"
        if [[ "$behind" != 0 ]]; then
            printf '%s (%s behind %s%s)\n' "$short" "$behind" "$remote" "$extra"
            return 0
        fi
    fi
    if [[ -n "$extra" ]]; then
        printf '%s (unsaved)\n' "$short"
        return 0
    fi
    printf '%s\n' "$short"
}

# Description: True when this console's key matches register and Init has run.
tcast_operator_ready() {
    local pub have init_at
    [[ -f "${TCAST_TOOLKIT_OP_KEY}" ]] || return 1
    init_at="$(tcast_register_meta_get initialized_at 2>/dev/null || true)"
    [[ -n "$init_at" ]] || return 1
    pub="$(tcast_register_meta_get operator_age_pub 2>/dev/null || true)"
    [[ "$pub" == age1* ]] || return 1
    have="$(tcast_operator_pub_from_key 2>/dev/null || true)"
    [[ "$have" == "$pub" ]] || return 1
    return 0
}

tcast_operator_require() {
    [[ -f "${TCAST_TOOLKIT_OP_KEY}" ]] \
        || tcast_die "operator age private key missing: ${TCAST_TOOLKIT_OP_KEY} (Sops → Operator → Init)"
    export SOPS_AGE_KEY_FILE="${TCAST_TOOLKIT_OP_KEY}"
}

tcast_operator_pub_from_key() {
    [[ -f "${TCAST_TOOLKIT_OP_KEY}" ]] || return 1
    command -v age-keygen >/dev/null || return 1
    age-keygen -y "${TCAST_TOOLKIT_OP_KEY}" 2>/dev/null
}
