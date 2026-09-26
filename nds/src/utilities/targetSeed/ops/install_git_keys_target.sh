#!/usr/bin/env bash
# ==================================================================================================
# targetSeed - copy a file tree and git keys onto a mount root
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-07 | Modified: 2026-09-26
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

targetSeed_copy() {
    local _ts_src=$1 _ts_mnt=$2
    [[ -d "$_ts_src" ]] || return 1
    mkdir -p "$_ts_mnt" || return 1
    cp -a "${_ts_src}/." "$_ts_mnt/"
}

_targetSeed_owner_repo() {
    local _ts_name=$1 _ts_host _ts_rest _ts_owner _ts_repo
    _ts_host=${_ts_name%%_*}
    [[ "$_ts_host" == *.* ]] || return 1
    _ts_rest=${_ts_name#"${_ts_host}_"}
    [[ "$_ts_rest" == *_* ]] || return 1
    _ts_owner=${_ts_rest%%_*}
    _ts_repo=${_ts_rest#*_}
    [[ -n "$_ts_owner" && -n "$_ts_repo" ]] || return 1
    printf '%s/%s\n' "${_ts_owner,,}" "${_ts_repo,,}"
}

_targetSeed_install_wrapper() {
    local _ts_mnt=$1 _ts_src _ts_bin _ts_lib
    _ts_src=$(cd "${BASH_SOURCE[0]%/*}/../../../../../tcast" && pwd) || return 0
    [[ -f "${_ts_src}/bin/tcast-git-ssh" ]] || return 0
    _ts_bin="${_ts_mnt}/var/lib/tcast/bin"
    _ts_lib="${_ts_mnt}/var/lib/tcast/lib"
    mkdir -p "$_ts_bin" "$_ts_lib" "${_ts_mnt}/etc/profile.d" "${_ts_mnt}/etc/environment.d" || return 1
    install -m 755 "${_ts_src}/bin/tcast-git-ssh" "${_ts_bin}/tcast-git-ssh" || return 1
    cp "${_ts_src}/lib/tcast_common.sh" "${_ts_src}/lib/tcast_git_ssh.sh" "$_ts_lib/" || return 1
    printf '%s\n' \
        'export PATH="/var/lib/tcast/bin:${PATH}"' \
        '[ -x /var/lib/tcast/bin/tcast-git-ssh ] && export GIT_SSH_COMMAND=/var/lib/tcast/bin/tcast-git-ssh' \
        'export TCAST_GIT_SSH_MAP="${TCAST_GIT_SSH_MAP:-/var/lib/tcast/git.map}"' \
        > "${_ts_mnt}/etc/profile.d/tcast.sh"
    printf '%s\n' \
        'GIT_SSH_COMMAND=/var/lib/tcast/bin/tcast-git-ssh' \
        'TCAST_GIT_SSH_MAP=/var/lib/tcast/git.map' \
        > "${_ts_mnt}/etc/environment.d/50-tcast-git-ssh.conf"
}

targetSeed_gitKeys() {
    local _ts_keys=$1 _ts_mnt=$2
    local _ts_dest="${_ts_mnt}/root/.ssh/nds"
    local _ts_cfg="${_ts_mnt}/root/.ssh/config" _ts_file _ts_base _ts_repo
    [[ -d "$_ts_keys" ]] || return 1
    mkdir -p "$_ts_dest" "${_ts_mnt}/root/.ssh" "${_ts_mnt}/var/lib/tcast" || return 1
    chmod 700 "${_ts_mnt}/root/.ssh" "$_ts_dest" || return 1
    cp -a "${_ts_keys}/." "$_ts_dest/" || return 1
    if [[ ! -f "$_ts_cfg" ]] || ! grep -q 'nds/config' "$_ts_cfg"; then
        printf '%s\n' 'Include nds/config' >> "$_ts_cfg"
    fi
    chmod 600 "$_ts_cfg" || return 1
    {
        printf '%s\n' '# NDS map: owner/repo<TAB>/root/.ssh/nds/<safeurl>'
        for _ts_file in "${_ts_dest}"/*; do
            [[ -f "$_ts_file" && "$_ts_file" != *.pub ]] || continue
            _ts_base=$(basename "$_ts_file")
            _ts_repo=$(_targetSeed_owner_repo "$_ts_base") || continue
            printf '%s\t/root/.ssh/nds/%s\n' "$_ts_repo" "$_ts_base"
        done
    } > "${_ts_mnt}/var/lib/tcast/git.map"
    chmod 600 "${_ts_mnt}/var/lib/tcast/git.map"
    _targetSeed_install_wrapper "$_ts_mnt"
}
