#!/usr/bin/env bash
# ==================================================================================================
# ThunderCast host CLI — status
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-31 | Modified: 2026-08-31
# ==================================================================================================

tc_cmd_status() {
    local flake_root="${TC_FLAKE_ROOT}"
    local host_name="${TC_FLAKE_HOST}"

    echo "host:     ${host_name}"
    echo "hostname: $(hostname 2>/dev/null || true)"
    if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        echo "os:       ${PRETTY_NAME:-$NAME}"
    fi
    if command -v nixos-version >/dev/null 2>&1; then
        echo "nixos:    $(nixos-version 2>/dev/null || true)"
    fi
    if [[ -d "$flake_root/.git" ]]; then
        echo "flake:    ${flake_root}  $(git -C "$flake_root" rev-parse --short HEAD 2>/dev/null || echo '?')"
        git -C "$flake_root" status -sb 2>/dev/null | head -5 | sed 's/^/  /'
    else
        echo "flake:    ${flake_root} (not a git checkout)"
    fi
    if wrap="$(tc_resolve_git_ssh 2>/dev/null)"; then
        echo "git-ssh:  ${wrap}"
        echo "map:      $(tc_git_map_path)"
    else
        echo "git-ssh:  (not on PATH)"
    fi
}
