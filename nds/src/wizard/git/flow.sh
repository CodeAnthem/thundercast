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

_nds_git_owner_repo() {
    local _git_parsed _git_host _git_owner _git_repo
    _git_parsed=$(_nds_git_url_parse "$1") || return 1
    IFS=$'\t' read -r _git_host _git_owner _git_repo <<< "$_git_parsed"
    printf '%s\n' "$_git_host" "$_git_owner" "$_git_repo"
}

_nds_git_collision() {
    local _git_rc=0
    _nds_wiz_opts=('overwrite|Remove the old key and register this one' \
        'alternate|Use an alternate title' 'cancel|Cancel')
    prompt --type select --options _nds_wiz_opts --back "A key with this title already exists" || _git_rc=$?
    [[ "$_git_rc" -eq 0 ]] || return "$_git_rc"
    [[ "$UI_PROMPT_RESULT" == cancel ]] && return 1
    printf '%s\n' "$UI_PROMPT_RESULT"
}

_nds_git_show_card() {
    local _git_pub=$1 _git_title=$2 _git_url=$3 _git_write=$4 _git_rc=0
    ui_h "Git access"
    ui_b "Add this key, then confirm."
    ui_kv "Url" "$_git_url"
    ui_kv "Title" "$_git_title"
    ui_kv "Public Key" "$_git_pub"
    [[ -n "$_git_write" ]] && ui_kv "Allow write access" "$_git_write"
    prompt --type confirm --default n --back "Show QR codes?" || _git_rc=$?
    if [[ "$_git_rc" -eq 0 && "$UI_PROMPT_RESULT" == y ]] && declare -f qr_print >/dev/null; then
        qr_print "$_git_url" || true
        qr_print "$_git_pub" || true
    fi
    prompt --type confirm --back "I added this key" || return $?
    [[ "$UI_PROMPT_RESULT" == y ]]
}

_nds_git_register_new() {
    local _git_name=$1 _git_url=$2 _git_dest=$3
    local _git_host _git_owner _git_repo _git_kind _git_how _git_rc=0
    local _git_title _git_pub _git_read _git_collision="" _git_write="no"
    local -a _git_parts=()
    mapfile -t _git_parts < <(_nds_git_owner_repo "$_git_url")
    _git_host=${_git_parts[0]:-github.com}
    _git_owner=${_git_parts[1]:-}
    _git_repo=${_git_parts[2]:-}
    export NDS_FLAKE_REPO_URL
    NDS_FLAKE_REPO_URL=${ nds_recipe_get "$_git_name" FLAKE_REPO_URL; }
    git_key_create "$_git_dest" "${_git_owner}_${_git_repo}" || return 1
    _nds_wiz_opts=('deploy|Deploy key for this repository' 'account|Account key for every repository')
    prompt --type select --options _nds_wiz_opts --back "Which key should GitHub hold?" || _git_rc=$?
    [[ "$_git_rc" -eq 0 ]] || return "$_git_rc"
    _git_kind=$UI_PROMPT_RESULT
    _nds_wiz_opts=('gh|Register with gh' 'manual|Show the public key')
    _git_rc=0
    prompt --type select --options _nds_wiz_opts --back "How should the key be registered?" || _git_rc=$?
    [[ "$_git_rc" -eq 0 ]] || return "$_git_rc"
    _git_how=$UI_PROMPT_RESULT
    _git_pub=${ git_key_pub "$_git_dest"; }
    [[ -n "$_git_pub" ]] || _git_pub=$(<"${_git_dest}.pub")
    _git_title="nds ${_git_owner}/${_git_repo}"
    if nds_git_access_is_need_target "$_git_owner" "$_git_repo"; then
        _git_read=false
        _git_write="yes (tick the checkbox)"
    else
        _git_read=true
    fi
    if [[ "$_git_how" == manual ]]; then
        if [[ "$_git_kind" == deploy ]]; then
            _nds_git_show_card "$_git_pub" "$_git_title" \
                "https://${_git_host}/${_git_owner}/${_git_repo}/settings/keys" "$_git_write" || return 1
        else
            _nds_git_show_card "$_git_pub" "$_git_title" \
                "https://${_git_host}/settings/keys" "" || return 1
        fi
        return 0
    fi
    gh_deviceLogin || return 1
    while true; do
        _git_rc=0
        if [[ "$_git_kind" == deploy ]]; then
            gh_addDeployKey "${_git_dest}.pub" "$_git_owner" "$_git_repo" "$_git_title" \
                "$_git_collision" "$_git_read" || _git_rc=$?
        else
            gh_addAccountKey "${_git_dest}.pub" "$_git_title" "$_git_collision" || _git_rc=$?
        fi
        if [[ "$_git_rc" -eq 0 ]]; then
            return 0
        fi
        if [[ "$_git_rc" -eq 41 ]]; then
            _git_collision=$(_nds_git_collision) || return 1
            [[ "$_git_collision" == alternate ]] && _git_title="${_git_title}-2"
            continue
        fi
        return "$_git_rc"
    done
}

_nds_git_obtain() {
    local _git_name=$1 _git_url=$2 _git_again=${3:-}
    local _git_dir _git_safe _git_dest _git_rc=0
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
        _nds_git_register_new "$_git_name" "$_git_url" "$_git_dest" || _git_rc=$?
        [[ "$_git_rc" -eq 0 ]] || return "$_git_rc"
    fi
    if declare -f git_probe >/dev/null && ! git_probe "$_git_dir" "$_git_url"; then
        if [[ -n "$_git_again" ]]; then
            error "GIT_KEYS_DIR: probe failed"
            return 1
        fi
        _git_rc=0
        prompt --type confirm --back "Try this URL again?" || _git_rc=$?
        [[ "$_git_rc" -eq 0 && "$UI_PROMPT_RESULT" == y ]] || return 1
        _nds_git_obtain "$_git_name" "$_git_url" again
        return $?
    fi
}
