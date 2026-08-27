#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git auth wizard import menu
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-07 | Modified: 2026-08-28
# Description:   Path and paste key import (cwd/.ssh auto-scan runs before the wizard)
# ==================================================================================================

# Description: Import a private key from an explicit path (or NDS_GIT_IMPORT_KEY_PATH).
# Auto-discovery of cwd / ~/.ssh happens in _nds_git_auth_try_existing_access before menus.
# Arguments:
# - urls: <String...> URLs to probe after import (optional; for messaging)
# Returns:
# - <Bool> 0 on success
nds_git_wizard_menu_import_path() {
    local -a urls=("$@")
    local src mapped=""

    if [[ "${_NDS_GIT_RELATED_IMPORT:-}" != "1" ]]; then
        if [[ -n "${NDS_GIT_IMPORT_KEY_PATH:-}" && -f "${NDS_GIT_IMPORT_KEY_PATH}" ]]; then
            src="${NDS_GIT_IMPORT_KEY_PATH}"
        fi
    fi
    if [[ -z "${src:-}" && ${#urls[@]} -gt 0 ]] && declare -f nds_git_access_get &>/dev/null; then
        mapped="$(nds_git_access_get key_path "${urls[0]}" 2>/dev/null || true)"
        [[ -n "$mapped" && -f "$mapped" ]] && src="$mapped"
    fi
    if [[ -z "${src:-}" ]]; then
        nds_aa_ask_path GIT_IMPORT_KEY_PATH "Private SSH key path" "" true || return 1
        src="$(nds_feat_cfg_get GIT_IMPORT_KEY_PATH)"
    fi

    [[ -f "$src" ]] || {
        error "Private key not found: ${src}"
        return 1
    }

    nds_git_keys_register "$src" || return 1
    nds_git_auth_set_mode imported

    if [[ ${#urls[@]} -gt 0 ]]; then
        if nds_git_discover_probe_urls "$src" "${urls[@]}"; then
            success "SSH key works: ${src}"
            return 0
        fi
        warn "Key loaded but probe failed for one or more URLs — continue after fixing access."
    fi
    success "SSH key loaded from ${src}"
    return 0
}

# Description: Import a private key from hidden paste, NDS_GIT_KEY_BODY[url], or NDS_GIT_IMPORT_KEY.
# Never stores key text in CONFIG_DATA. Env body is optional; a TTY paste still works
# under NDS_AUTO_CONFIRM (git auth is not skipped).
# Arguments:
# - urls: <String...> URLs to probe after import (optional)
# Returns:
# - <Bool> 0 on success
nds_git_wizard_menu_import_paste() {
    local -a urls=("$@")
    local body="" dest="" norm="" strategy="" src_label="pasted key"

    if [[ ${#urls[@]} -gt 0 ]]; then
        norm="$(nds_git_normalize_url "${urls[0]}" 2>/dev/null || true)"
    fi
    if [[ -n "$norm" && -n "${NDS_GIT_KEY_BODY[$norm]:-}" ]]; then
        body="${NDS_GIT_KEY_BODY[$norm]}"
        src_label="NDS_GIT_KEY_BODY"
    elif [[ "${_NDS_GIT_RELATED_IMPORT:-}" != "1" && -n "${NDS_GIT_IMPORT_KEY:-}" ]]; then
        body="${NDS_GIT_IMPORT_KEY}"
        src_label="NDS_GIT_IMPORT_KEY"
    else
        body="$(nds_ui_read_hidden_block "Paste the private SSH key (input is hidden)")" || {
            error "No private key pasted — need a TTY, or NDS_GIT_KEY_BODY[url] / NDS_GIT_IMPORT_KEY"
            return 1
        }
    fi

    strategy=""
    if declare -f nds_feat_cfg_get &>/dev/null; then
        strategy="$(nds_feat_cfg_get GIT_ACCESS_STRATEGY 2>/dev/null || true)"
    fi
    if [[ -n "$norm" && -n "${NDS_GIT_KEY_PATH[$norm]:-}" ]]; then
        dest="${NDS_GIT_KEY_PATH[$norm]}"
    else
        dest="$(nds_git_key_dest_for_import "${urls[0]:-}" "$strategy")"
    fi

    nds_git_key_import_body "$body" "$dest" || return 1
    nds_git_auth_set_mode imported

    if [[ ${#urls[@]} -gt 0 ]]; then
        if nds_git_discover_probe_urls "$dest" "${urls[@]}"; then
            success "SSH key works (${src_label}): ${dest}"
            return 0
        fi
        warn "Key loaded but probe failed for one or more URLs — continue after fixing access."
    fi
    success "SSH key loaded from ${src_label}: ${dest}"
    return 0
}
