#!/usr/bin/env bash
# ==================================================================================================
# NDS - Session paths, live-ISO user, and host address
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

nds_session_dir() {
    runtime_getPath "$1"
}

nds_session_sshUser() {
    local _nds_user=${SUDO_USER:-nixos}
    [[ "$_nds_user" == root ]] && _nds_user=nixos
    printf '%s\n' "$_nds_user"
}

nds_session_hostIp() {
    local _nds_host=""
    if [[ -n ${SSH_CONNECTION:-} ]]; then
        read -r _ _nds_host _ <<< "$SSH_CONNECTION"
    elif command -v ip >/dev/null 2>&1; then
        _nds_host=$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for (i=1;i<=NF;i++) if ($i=="src") print $(i+1); exit}')
    fi
    _nds_host=${_nds_host:-$(hostname -I 2>/dev/null | awk '{print $1}')}
    printf '%s\n' "$_nds_host"
}
