#!/usr/bin/env bash
# ==================================================================================================
# ThunderCast host CLI — status
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-31 | Modified: 2026-09-01
# ==================================================================================================

# Description: Shorten a full git sha for display.
# Arguments:
# - rev: <String> Full or short revision
# Returns:
# - <String> Up to 12 hex chars (stdout)
_tcast_status_short_rev() {
    local rev="$1"
    printf '%s\n' "${rev:0:12}"
}

# Description: Print running-system flake revision (embedded at build time).
# Prefer /etc/tcast/system-revision over any checkout path — no comin coupling.
_tcast_status_print_system_rev() {
    local rev_file="/etc/tcast/system-revision"
    local rev=""
    if [[ -r "$rev_file" ]]; then
        rev="$(tr -d '[:space:]' <"$rev_file" 2>/dev/null || true)"
    fi
    if [[ -n "$rev" ]]; then
        echo "system:   $(_tcast_status_short_rev "$rev")  (running configurationRevision)"
    else
        echo "system:   (no configurationRevision — leaf should set system.configurationRevision)"
    fi
}

# Description: Print optional local flake checkout tip (operator workspace only).
_tcast_status_print_checkout() {
    local flake_root="$1"
    if [[ ! -d "$flake_root/.git" ]]; then
        echo "checkout: ${flake_root} (not a git checkout)"
        return 0
    fi
    echo "checkout: ${flake_root}  $(git -C "$flake_root" rev-parse --short HEAD 2>/dev/null || echo '?')"
    # head closes early → SIGPIPE under pipefail; do not fail status
    git -C "$flake_root" status -sb 2>/dev/null | head -5 | sed 's/^/  /' || true
}

tcast_cmd_status() {
    local flake_root="${TCAST_FLAKE_ROOT}"
    local host_name="${TCAST_FLAKE_HOST}"

    echo "host:     ${host_name}"
    echo "hostname: $(hostname 2>/dev/null || true)"
    echo "config:   ${TCAST_CONFIG_DIR:-/var/lib/tcast}"
    if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        echo "os:       ${PRETTY_NAME:-${NAME:-unknown}}"
    fi
    if command -v nixos-version >/dev/null 2>&1; then
        echo "nixos:    $(nixos-version 2>/dev/null || true)"
    fi
    _tcast_status_print_system_rev
    _tcast_status_print_checkout "$flake_root"
    if wrap="$(tcast_resolve_git_ssh 2>/dev/null)"; then
        echo "git-ssh:  ${wrap}"
        echo "map:      $(tcast_git_map_path)"
    else
        echo "git-ssh:  (not on PATH)"
    fi
}
