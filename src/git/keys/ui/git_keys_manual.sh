#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git auth wizard manual registration menu
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-07 | Modified: 2026-08-26
# ==================================================================================================

_NDS_GIT_WIZARD_KV_WIDTH=20

# Description: Labeled field on the add-key card.
# Arguments:
# - label: <String> Field name
# - value: <String> Field value
_nds_git_wizard_kv() {
    nds_ui_kv_row "$1" "$2" "$_NDS_GIT_WIZARD_KV_WIDTH"
}

# Description: Resolve QR vs printed copy (env or one-time prompt).
# Do not call from command substitution — TTY read must stay in the current shell.
# Arguments:
# - display: <Nameref> Receives qr or copy
nds_git_wizard_resolve_key_display() {
    local -n _nds_git_key_display=${1:?display_nameref}
    local from_env="${NDS_GIT_SSH_KEY_DISPLAY:-${NDS_GIT_DEPLOY_KEY_DISPLAY:-}}"
    case "${from_env,,}" in
        qr) _nds_git_key_display=qr; return 0 ;;
        copy) _nds_git_key_display=copy; return 0 ;;
    esac
    if nds_env_is_true "${NDS_GIT_SSH_KEY_USE_QR:-${NDS_GIT_DEPLOY_KEY_USE_QR:-false}}"; then
        _nds_git_key_display=qr
        return 0
    fi
    if [[ "${NDS_GIT_SSH_KEY_USE_QR:-${NDS_GIT_DEPLOY_KEY_USE_QR:-}}" == "false" ]]; then
        _nds_git_key_display=copy
        return 0
    fi
    if nds_ask_user_to_proceed "Show QR codes?" n; then
        _nds_git_key_display=qr
    else
        _nds_git_key_display=copy
    fi
    return 0
}

# Description: Print a labeled add-key card, then optional QR codes.
# Arguments:
# - pub_path:     <String> Public key file
# - title:        <String> Key title to paste on the host
# - register_url: <String> Registration page URL
# - intro:        <String> Lead sentence
# - extra_label:  <String|optional> Extra field label (empty to skip)
# - extra_value:  <String|optional> Extra field value
# Returns:
# - <Bool> 0 on success
nds_git_wizard_show_add_key_card() {
    local pub_path="$1" title="$2" register_url="$3" intro="$4"
    local extra_label="${5:-}" extra_value="${6:-}"
    local pub display

    [[ -f "$pub_path" ]] || return 1
    pub="$(tr -d '\n' < "$pub_path")"

    nds_ui_section_header "Git access"
    nds_ui_b ""
    nds_ui_b "$intro"
    nds_ui_b ""
    _nds_git_wizard_kv "Url" "$register_url"
    _nds_git_wizard_kv "Title" "$title"
    _nds_git_wizard_kv "Public Key" "$pub"
    if [[ -n "$extra_label" ]]; then
        _nds_git_wizard_kv "$extra_label" "$extra_value"
    fi

    display=""
    nds_git_wizard_resolve_key_display display || return 1
    if [[ "$display" == "qr" ]]; then
        nds_ui_b ""
        if ! nds_qr_print "$register_url"; then
            warn "QR unavailable — use the printed copy above"
            return 0
        fi
        nds_ui_b ""
        nds_qr_print "$pub" || true
    fi
    return 0
}

# Description: Wait until user confirms manual deploy key registration.
# Arguments:
# - owner: <String> Repository owner
# - repo:  <String> Repository name
# Returns:
# - <Bool> 0 when user confirms
nds_git_wizard_confirm_manual_deploy() {
    local owner="$1" repo="$2"

    [[ -n "$owner" && -n "$repo" ]] || return 1
    nds_ui_b ""
    nds_ask_user_to_proceed "I added this deploy key?" || return 1
    return 0
}

# Description: Wait until user confirms manual account SSH key registration.
# Returns:
# - <Bool> 0 when user confirms
nds_git_wizard_confirm_manual_account() {
    nds_ui_b ""
    nds_ask_user_to_proceed "I added this SSH key?" || return 1
    return 0
}

# Description: Manual deploy key registration for one repository.
# Arguments:
# - owner:     <String> Repository owner
# - repo:      <String> Repository name
# - host:      <String> Git host
# - read_only: <String> true (default) or false
# Returns:
# - <Bool> 0 on success
nds_git_wizard_menu_manual_deploy() {
    local owner="$1" repo="$2" host="${3:-github.com}" read_only="${4:-true}"
    local pub_path register_url title write_value

    nds_git_deploy_key_generate "$owner" "$repo" || return 1
    pub_path="$(nds_git_deploy_key_pubkey_path "$owner" "$repo")"
    title="$(nds_git_deploy_key_register_title "$owner" "$repo" "$read_only")"
    register_url="$(nds_git_deploy_key_register_url "$host" "$owner" "$repo")"

    if [[ "$read_only" == "false" ]]; then
        write_value="yes (tick the checkbox)"
    else
        write_value="no (leave the checkbox off)"
    fi

    nds_git_wizard_show_add_key_card "$pub_path" "$title" "$register_url" \
        "Please add this key, see info below:" \
        "Allow write access" "$write_value" || return 1
    nds_git_wizard_confirm_manual_deploy "$owner" "$repo" || return 1
    return 0
}

# Description: Manual account SSH key registration.
# Returns:
# - <Bool> 0 on success
nds_git_wizard_menu_manual_account() {
    local pub_path register_url

    if [[ ! -f "$(nds_git_session_pubkey_path)" ]]; then
        nds_git_key_generate "$(nds_git_session_key_path)" || return 1
    fi
    nds_git_keys_register "$(nds_git_session_key_path)" || true
    nds_git_auth_set_mode account

    pub_path="$(nds_git_session_pubkey_path)"
    register_url="$(nds_git_account_ssh_register_url github.com)"
    nds_git_wizard_show_add_key_card "$pub_path" "$(nds_git_ssh_key_title)" "$register_url" \
        "Please add this key, see info below:" \
        || return 1
    nds_git_wizard_confirm_manual_account || return 1
    return 0
}
