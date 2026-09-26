#!/usr/bin/env bash
# ==================================================================================================
# Git utility - argument-driven URL, key, clone, and gh helpers
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-29 | Modified: 2026-09-26
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

if (( BASH_VERSINFO[0] < 5 || (BASH_VERSINFO[0] == 5 && BASH_VERSINFO[1] < 3) )); then
    printf 'GIT: requires Bash 5.3 or newer (found %s).\n' "${BASH_VERSION}" >&2
    return 1 2>/dev/null || exit 1
fi

if ! declare -F err >/dev/null 2>&1; then
    err() { error "${FUNCNAME[1]:-git}: $1"; }
fi

_GIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
source "${_GIT_DIR}/helpers/git_url_tryParse.sh"
# shellcheck disable=SC1091
source "${_GIT_DIR}/helpers/git_keys.sh"
# shellcheck disable=SC1091
source "${_GIT_DIR}/providers/git_generic_ssh.sh"
# shellcheck disable=SC1091
source "${_GIT_DIR}/providers/git_github_api.sh"
# shellcheck disable=SC1091
source "${_GIT_DIR}/providers/git_github_bin.sh"
# shellcheck disable=SC1091
source "${_GIT_DIR}/providers/git_github_session.sh"
# shellcheck disable=SC1091
source "${_GIT_DIR}/providers/git_github_gh.sh"

git_url_parse() {
    local -A _git_id=()
    _git_url_tryParse _git_id "${1:-}" || return 1
    printf '%s\t%s\t%s\t%s\n' "${_git_id[host]}" "${_git_id[owner]}" "${_git_id[repoName]}" "${_git_id[provider]}"
}

git_url_safe() {
    local -A _git_id=()
    local _git_safe
    _git_url_tryParse _git_id "${1:-}" || return 1
    _git_safe="${_git_id[host]}_${_git_id[owner]}_${_git_id[repoName]}"
    printf '%s\n' "${_git_safe,,}"
}

git_url_isRemote() {
    local -A _git_id=()
    _git_url_tryParse _git_id "${1:-}"
}

git_sshCommand() {
    local _git_keys=$1 _git_url=$2 _git_safe _git_key
    _git_safe=${ git_url_safe "$_git_url"; } || return 1
    _git_key="${_git_keys}/${_git_safe}"
    [[ -f "$_git_key" ]] || _git_key="${_git_keys}/default"
    printf '%s\n' "ssh -i ${_git_key} -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"
}

git_probe() {
    local _git_cmd
    _git_cmd=${ git_sshCommand "$1" "$2"; } || return 1
    GIT_SSH_COMMAND="$_git_cmd" git ls-remote "$2"
}

git_clone() {
    local _git_keys=$1 _git_url=$2 _git_dest=$3 _git_cmd
    local -a _git_depth=()
    if [[ ${4:-} == --depth && ${5:-} == 1 ]]; then
        _git_depth=(--depth 1)
    fi
    _git_cmd=${ git_sshCommand "$_git_keys" "$_git_url"; } || return 1
    GIT_SSH_COMMAND="$_git_cmd" git clone ${_git_depth[@]+"${_git_depth[@]}"} "$_git_url" "$_git_dest"
}

git_push() {
    local _git_keys=$1 _git_dir=$2 _git_url _git_cmd
    _git_url=$(git -C "$_git_dir" remote get-url origin) || return 1
    _git_cmd=${ git_sshCommand "$_git_keys" "$_git_url"; } || return 1
    GIT_SSH_COMMAND="$_git_cmd" git -C "$_git_dir" push
}

git_commitAll() {
    local _git_dir=$1 _git_msg=$2
    shift 2
    if (( $# )); then
        git -C "$_git_dir" add -- "$@" || return 1
    else
        git -C "$_git_dir" add -A || return 1
    fi
    git -C "$_git_dir" commit -m "$_git_msg"
}

git_key_create() { git_helper_keys_create "$@"; }
git_key_pub() { git_helper_keys_getPublic "$1"; }
git_key_fingerprint() { git_helper_keys_getFingerprint "$1"; }
git_key_bodyLooksValid() { _git_helper_keys_bodyLooksValid "$1"; }

gh_bin() { git_gh_bin; }

gh_deviceLogin() {
    local _git_bin
    _git_bin=${ gh_bin; } || return 1
    "$_git_bin" auth login --hostname github.com --git-protocol ssh --device
}

gh_logout() { git_gh_logout; }

gh_addDeployKey() { git_gh_register_deploy_key "$@"; }

gh_addAccountKey() { git_gh_register_account_key "$@"; }

git_onLoad() { return 0; }
git_onExit() { git_gh_onExit; }
