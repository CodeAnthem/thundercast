#!/usr/bin/env bash
# ==================================================================================================
# NDS - Shared network helpers
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-16 | Modified: 2026-08-16
# Description:   Host IP and live-ISO SSH user (no feature policy)
# ==================================================================================================

# Description: SSH user on this live ISO for scp/ssh copy hints.
# Returns:
# - <String> Username (stdout)
nds_lib_getSshUser() {
    local user="${SUDO_USER:-nixos}"
    [[ "$user" == root ]] && user=nixos
    printf '%s' "$user"
}

# Description: IPv4 this machine is reachable on (SSH client view, else default route, else hostname -I).
# Returns:
# - <String> IPv4 or empty (stdout)
nds_lib_getHostIP() {
    local host=""
    if [[ -n "${SSH_CONNECTION:-}" ]]; then
        read -r _ _ host _ <<< "$SSH_CONNECTION"
    elif command -v ip &>/dev/null; then
        host=$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for (i=1;i<=NF;i++) if ($i=="src") print $(i+1); exit}')
    fi
    host="${host:-$(hostname -I 2>/dev/null | awk '{print $1}')}"
    printf '%s' "$host"
}
