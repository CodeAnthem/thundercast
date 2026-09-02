#!/usr/bin/env bash
# ==================================================================================================
# ThunderCast host CLI — common helpers (NDS-free)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-31 | Modified: 2026-08-31
# ==================================================================================================

# Host-shared install + config (any user/sudo; not root-home only).
: "${TCAST_STATE_DIR:=/var/lib/tcast}"
: "${TCAST_BIN_DIR:=${TCAST_STATE_DIR}/bin}"
: "${TCAST_GIT_SSH_BIN:=ssh}"

tcast_die() {
    printf 'tcast: %s\n' "$*" >&2
    exit 1
}

tcast_info() {
    printf 'tcast: %s\n' "$*"
}

# Description: Require root (or effective uid 0) for rebuild / generation ops.
tcast_need_root() {
    [[ "$(id -u)" -eq 0 ]] || tcast_die "run as root (e.g. sudo tcast $*)"
}

# Description: Load switch.conf then apply built-in defaults (env already set wins).
tcast_env_init() {
    declare -f tcast_conf_apply_switch_env >/dev/null && tcast_conf_apply_switch_env
    : "${TCAST_FLAKE_ROOT:=/etc/nixos}"
    : "${TCAST_FLAKE_HOST:=$(hostname -s 2>/dev/null || echo nixos)}"
    : "${TCAST_FLAKE_REF:=origin/main}"
}

# Description: Path to deploy-key map (owner/repo → absolute key path).
tcast_git_map_path() {
    if [[ -n "${TCAST_GIT_SSH_MAP:-}" ]]; then
        printf '%s\n' "$TCAST_GIT_SSH_MAP"
        return 0
    fi
    printf '%s\n' "${TCAST_CONFIG_DIR:-${TCAST_STATE_DIR}}/git.map"
}

# Description: Resolve tcast-git-ssh executable for GIT_SSH_COMMAND.
tcast_resolve_git_ssh() {
    local wrap="${TCAST_GIT_SSH_WRAPPER:-}"
    if [[ -n "$wrap" && -x "$wrap" ]]; then
        printf '%s\n' "$wrap"
        return 0
    fi
    if [[ -x "${TCAST_BIN_DIR}/tcast-git-ssh" ]]; then
        printf '%s\n' "${TCAST_BIN_DIR}/tcast-git-ssh"
        return 0
    fi
    if command -v tcast-git-ssh &>/dev/null; then
        command -v tcast-git-ssh
        return 0
    fi
    return 1
}
