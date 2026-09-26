#!/usr/bin/env bash
# ==================================================================================================
# NDS - Obtain one key when a probe fails
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

_nds_git_write_key() {
    local _git_dest=$1 _git_body=$2
    mkdir -p "$(dirname "$_git_dest")"
    printf '%s\n' "$_git_body" > "$_git_dest"
    chmod 600 "$_git_dest"
}

_nds_git_obtain() {
    local _git_name=$1 _git_url=$2 _git_dir _git_safe _git_dest _git_rc=0 _git_pub
    _git_dir=$(nds_recipe_get "$_git_name" GIT_KEYS_DIR)
    _git_safe=$(_nds_git_safe "$_git_url")
    _git_dest="${_git_dir}/${_git_safe}"
    ui_h "Git access"
    ui_b "$_git_url"
    _nds_wiz_opts=('existing|I have a key' 'new|Create a new key')
    prompt --type select --options _nds_wiz_opts --back "Key for ${_git_url}" || _git_rc=$?
    [[ "$_git_rc" -eq 0 ]] || return "$_git_rc"
    if [[ "$UI_PROMPT_RESULT" == existing ]]; then
        _nds_wiz_opts=('path|Path to a private key' 'paste|Paste a private key')
        _git_rc=0
        prompt --type select --options _nds_wiz_opts --back "How to read the key" || _git_rc=$?
        [[ "$_git_rc" -eq 0 ]] || return "$_git_rc"
        if [[ "$UI_PROMPT_RESULT" == path ]]; then
            _git_rc=0
            prompt --type text --back "Private key path" || _git_rc=$?
            [[ "$_git_rc" -eq 0 ]] || return "$_git_rc"
            cp "$UI_PROMPT_RESULT" "$_git_dest" || return 1
            chmod 600 "$_git_dest"
        else
            _git_rc=0
            prompt --type multiline --end END --back "Paste the private key" || _git_rc=$?
            [[ "$_git_rc" -eq 0 ]] || return "$_git_rc"
            _nds_git_write_key "$_git_dest" "$UI_PROMPT_RESULT"
        fi
    else
        git_key_create "$_git_dest" "$_git_safe" || return 1
        _nds_wiz_opts=('gh|Register with gh' 'manual|Show the public key')
        _git_rc=0
        prompt --type select --options _nds_wiz_opts --back "Register the new key" || _git_rc=$?
        [[ "$_git_rc" -eq 0 ]] || return "$_git_rc"
        if [[ "$UI_PROMPT_RESULT" == gh ]]; then
            gh_deviceLogin || return 1
            gh_addDeployKey "$_git_dest" "$_git_url" || gh_addAccountKey "$_git_dest" || return 1
        else
            if declare -f git_key_pub >/dev/null; then
                _git_pub=$(git_key_pub "$_git_dest") || _git_pub=""
            else
                _git_pub=$(cat "${_git_dest}.pub" 2>/dev/null || true)
            fi
            ui_i "$_git_pub"
            declare -f qr_print >/dev/null && qr_print "$_git_pub" || true
            _git_rc=0
            prompt --type confirm --back "I added this key" || _git_rc=$?
            [[ "$_git_rc" -eq 0 && "$UI_PROMPT_RESULT" == y ]] || return 1
        fi
    fi
    if declare -f git_probe >/dev/null; then
        git_probe "$_git_dir" "$_git_url" || {
            error "GIT_KEYS_DIR: probe failed"
            return 1
        }
    fi
}
