#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git auth wizard manual registration menu
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-07 | Modified: 2026-08-26
# ==================================================================================================

# Description: Resolve QR vs printed copy (env or one-time prompt).
# Returns:
# - <String> qr or copy (stdout)
nds_git_wizard_resolve_key_display() {
    local from_env="${NDS_GIT_SSH_KEY_DISPLAY:-${NDS_GIT_DEPLOY_KEY_DISPLAY:-}}"
    case "${from_env,,}" in
        qr) printf 'qr\n'; return 0 ;;
        copy) printf 'copy\n'; return 0 ;;
    esac
    if nds_env_is_true "${NDS_GIT_SSH_KEY_USE_QR:-${NDS_GIT_DEPLOY_KEY_USE_QR:-false}}"; then
        printf 'qr\n'
        return 0
    fi
    if [[ "${NDS_GIT_SSH_KEY_USE_QR:-${NDS_GIT_DEPLOY_KEY_USE_QR:-}}" == "false" ]]; then
        printf 'copy\n'
        return 0
    fi
    local confirm=""
    while true; do
        nds_ui_tty_read -rsn1 -p "${NDS_UI_INDENT_I}Generate QR codes for URL and public key? [n] (y/n): " confirm
        echo >&2
        case "${confirm,,}" in
            y) printf 'qr\n'; return 0 ;;
            n|"") printf 'copy\n'; return 0 ;;
            *) nds_ui_b "Press y or n" ;;
        esac
    done
}

# Description: Show public key and optional QR bundle for manual registration.
# Arguments:
# - display:     <String> qr or copy
# - pub_path:    <String> Public key file
# - title:       <String> Key title for display
# - register_url: <String> Registration page URL
# Returns:
# - <Bool> 0 on success
nds_git_wizard_show_manual_key_at() {
    local display="${1:-copy}"
    local pub_path="$2"
    local title="$3"
    local register_url="$4"

    [[ -f "$pub_path" ]] || return 1

    nds_ui_b ""
    nds_ui_h "SSH public key (${title}):"
    nds_ui_b ""
    console "$(cat "$pub_path")"
    nds_ui_b ""
    nds_ui_i "Add it at: ${register_url}"

    if [[ "$display" == "qr" ]]; then
        local pub
        pub="$(tr -d '\n' < "$pub_path")"
        nds_ui_b ""
        nds_ui_h "SSH key registration page"
        nds_ui_b ""
        if nds_qr_print "$register_url"; then
            nds_ui_i "$register_url"
            nds_ui_b ""
            nds_ui_h "Public key (paste on registration page)"
            nds_ui_b ""
            nds_qr_print "$pub" || true
        else
            warn "QR unavailable — use printed copy above"
        fi
    fi
    return 0
}

# Description: Wait until user confirms manual deploy key registration.
# Arguments:
# - owner:     <String> Repository owner
# - repo:      <String> Repository name
# - read_only: <String> true (default) or false
# Returns:
# - <Bool> 0 when user confirms
nds_git_wizard_confirm_manual_deploy() {
    local owner="$1" repo="$2"
    local read_only="${3:-true}"

    if [[ "$read_only" == "false" ]]; then
        nds_ui_b "Add this deploy key on GitHub — enable \"Allow write access\" (this action pushes the host)."
    else
        nds_ui_b "Add this deploy key on GitHub — leave \"Allow write access\" unchecked."
    fi
    nds_ui_i "Repository: ${owner}/${repo}"
    nds_ui_i "Title: $(nds_git_deploy_key_title "$owner" "$repo")"
    nds_ui_b ""
    nds_ask_user_to_proceed "Added the deploy key on ${owner}/${repo}?" || return 1
    return 0
}

# Description: Wait until user confirms manual account SSH key registration.
# Returns:
# - <Bool> 0 when user confirms
nds_git_wizard_confirm_manual_account() {
    nds_ui_b "Register the public key on your machine GitHub user account."
    nds_ui_b "The key has full account SSH access — repo reach is set by GitHub permissions."
    nds_ui_b ""
    nds_ui_i "GitHub: github.com/settings/ssh/new"
    nds_ui_i "Title: $(nds_git_ssh_key_title)"
    nds_ui_b ""
    nds_ask_user_to_proceed "Added this SSH key to the machine user account?" || return 1
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
    local display pub_path register_url title

    nds_git_deploy_key_generate "$owner" "$repo" || return 1
    pub_path="$(nds_git_deploy_key_pubkey_path "$owner" "$repo")"
    title="$(nds_git_deploy_key_title "$owner" "$repo")"
    register_url="$(nds_git_deploy_key_register_url "$host" "$owner" "$repo")"

    display="$(nds_git_wizard_resolve_key_display)" || return 1
    nds_git_wizard_show_manual_key_at "$display" "$pub_path" "$title" "$register_url" || return 1
    nds_git_wizard_confirm_manual_deploy "$owner" "$repo" "$read_only" || return 1
    return 0
}

# Description: Manual account SSH key registration.
# Returns:
# - <Bool> 0 on success
nds_git_wizard_menu_manual_account() {
    local display pub_path register_url

    if [[ ! -f "$(nds_git_session_pubkey_path)" ]]; then
        nds_git_key_generate "$(nds_git_session_key_path)" || return 1
    fi
    nds_git_keys_register "$(nds_git_session_key_path)" || true
    nds_git_auth_set_mode account

    pub_path="$(nds_git_session_pubkey_path)"
    register_url="$(nds_git_account_ssh_register_url github.com)"
    display="$(nds_git_wizard_resolve_key_display)" || return 1
    nds_git_wizard_show_manual_key_at "$display" "$pub_path" "$(nds_git_ssh_key_title)" "$register_url" \
        || return 1
    nds_git_wizard_confirm_manual_account || return 1
    return 0
}
