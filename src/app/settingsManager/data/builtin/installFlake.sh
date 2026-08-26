#!/usr/bin/env bash
# ==================================================================================================
# NDS - Install from flake preset
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-01 | Modified: 2026-08-26
# ==================================================================================================

installFlake_defaults() {
    nds_cfg_set INSTALL_MODE "local"
    nds_cfg_set REMOTE_TARGET_IP ""
    nds_cfg_set FLAKE_LOCATION ""
    nds_cfg_set FLAKE_SOURCE "remote"
    nds_cfg_set FLAKE_REPO_URL ""
    nds_cfg_set FLAKE_LOCAL_PATH ""
    nds_cfg_set FLAKE_INSTALL_PATH "/mnt/etc/nixos"
    nds_cfg_set FLAKE_HOST ""
    nds_cfg_set FLAKE_HOST_DIR "hosts/x86_64-linux"
    nds_cfg_set FLAKE_HARDWARE_PLACEMENT "host-dir"
    nds_cfg_set GIT_PERSIST_ACCESS ""
    nds_cfg_set GIT_ACCESS_STRATEGY ""
    nds_cfg_set SOPS_AGE_REUSE "generate"
    nds_cfg_set SOPS_AGE_KEY_FILE ""
}

# Description: Prompt for a single flake location and auto-classify it as a remote
# git URL or a local path. Populates FLAKE_SOURCE, FLAKE_REPO_URL and
# FLAKE_LOCAL_PATH so downstream install steps keep their existing contract.
_nds_settings_installFlake_ask_location() {
    local value src current
    current="$(nds_cfg_get FLAKE_REPO_URL)"
    [[ -z "$current" ]] && current="$(nds_cfg_get FLAKE_LOCAL_PATH)"
    nds_cfg_set FLAKE_LOCATION "$current"
    while true; do
        value=$(_nds_settings_prompt_value FLAKE_LOCATION "Flake location" \
            "(git URL, git@host:owner/repo, or /path)" true) || continue
        [[ -z "$value" ]] && value="$current"
        if [[ -z "$value" ]]; then
            validation_error "Flake location is required"
            continue
        fi
        if ! validate_flake_location "$value"; then
            nds_ui_b "  Error: not a valid git URL or local path"
            continue
        fi
        src=$(nds_detect_flake_source "$value")
        nds_cfg_set FLAKE_LOCATION "$value"
        nds_cfg_set FLAKE_SOURCE "$src"
        if [[ "$src" == remote ]]; then
            nds_cfg_set FLAKE_REPO_URL "$value"
            nds_cfg_set FLAKE_LOCAL_PATH ""
        else
            nds_cfg_set FLAKE_LOCAL_PATH "$value"
            nds_cfg_set FLAKE_REPO_URL ""
        fi
        [[ "$current" != "$value" ]] && {
            nds_ui_b "  -> Set: $value"
            nds_ui_b "  -> Detected: $src"
        }
        return 0
    done
}

installFlake_configure() {
    # After early gate, URL/host/mode are usually set — allow review/edit.
    nds_cfg_section_title "Install mode"
    nds_cfg_ask_numbered_choice INSTALL_MODE \
        "local|remote" \
        "local=On target (live ISO)|remote=From operator (nixos-anywhere)" \
        "$(nds_cfg_get INSTALL_MODE)"
    if nds_cfg_is INSTALL_MODE remote; then
        nds_cfg_ask_ip REMOTE_TARGET_IP "Target host IP or hostname" "$(nds_cfg_get REMOTE_TARGET_IP)" true
    fi
    nds_cfg_section_title "Your flake"
    if [[ -z "$(nds_cfg_get FLAKE_REPO_URL)" && -z "$(nds_cfg_get FLAKE_LOCAL_PATH)" ]]; then
        _nds_settings_installFlake_ask_location
    else
        nds_ui_i "Location: $(nds_cfg_get FLAKE_LOCATION)"
        nds_ui_i "Host: $(nds_cfg_get FLAKE_HOST)"
        nds_ui_b ""
        if nds_ask_user_to_proceed "Change flake location or host?"; then
            _nds_settings_installFlake_ask_location
            nds_cfg_set FLAKE_HOST ""
            if declare -f nds_flake_pick_host &>/dev/null; then
                nds_flake_pick_host || return 1
            else
                nds_cfg_ask_hostname FLAKE_HOST "nixosConfigurations host name" "" true
            fi
        fi
    fi
    nds_cfg_ask_path FLAKE_INSTALL_PATH "Flake path on installed disk" "/mnt/etc/nixos" true
    if [[ -z "$(nds_cfg_get FLAKE_HOST)" ]]; then
        if declare -f nds_flake_pick_host &>/dev/null; then
            nds_flake_pick_host || return 1
        else
            nds_cfg_ask_hostname FLAKE_HOST "nixosConfigurations host name" "" true
        fi
    fi
    nds_cfg_ask_path FLAKE_HOST_DIR "Host directory inside flake" "hosts/x86_64-linux" false
    nds_cfg_ask_choice FLAKE_HARDWARE_PLACEMENT "Hardware configuration" "host-dir|etc-nixos|skip" \
        "host-dir=Copy into flake host dir|etc-nixos=Keep in /etc/nixos|skip=Flake handles hardware" "host-dir"
    nds_cfg_ask_choice SOPS_AGE_REUSE "Machine age key" "generate|file" \
        "generate=New key (enroll after install)|file=Reuse keys.txt from a previous bundle" "generate"
    if [[ "$(nds_cfg_get SOPS_AGE_REUSE)" == "file" ]]; then
        nds_cfg_ask_path SOPS_AGE_KEY_FILE "Path to existing age keys.txt" "" true
    fi
}

installFlake_summary() {
    nds_cfg_summary_row "Install mode" "$(nds_cfg_display_choice "$(nds_cfg_get INSTALL_MODE)" "local=On target|remote=nixos-anywhere")"
    if nds_cfg_is INSTALL_MODE remote; then
        nds_cfg_summary_row "Target host" "$(nds_cfg_get REMOTE_TARGET_IP)"
    fi
    if nds_cfg_is FLAKE_SOURCE remote; then
        nds_cfg_summary_row "Flake (git)" "$(nds_cfg_get FLAKE_REPO_URL)"
    else
        nds_cfg_summary_row "Flake (path)" "$(nds_cfg_get FLAKE_LOCAL_PATH)"
    fi
    nds_cfg_summary_row "Host name" "$(nds_cfg_get FLAKE_HOST)"
}

installFlake_prompt_errors() {
    local root host hosts_out
    local -a hosts=()

    nds_ui_section_header "Configuration — required fields"
    nds_cfg_section_title "Install mode"
    nds_cfg_ask_numbered_choice INSTALL_MODE \
        "local|remote" \
        "local=On target (live ISO)|remote=From operator (nixos-anywhere)" \
        "local"
    if nds_cfg_is INSTALL_MODE remote; then
        nds_cfg_ask_ip REMOTE_TARGET_IP "Target host IP or hostname" "" true
    fi

    nds_cfg_section_title "Your flake"
    while ! installFlake_validate &>/dev/null; do
        if nds_cfg_is INSTALL_MODE remote && [[ -z "$(nds_cfg_get REMOTE_TARGET_IP)" ]]; then
            nds_cfg_ask_ip REMOTE_TARGET_IP "Target host IP or hostname" "" true
            continue
        fi
        if [[ -z "$(nds_cfg_get FLAKE_REPO_URL)" && -z "$(nds_cfg_get FLAKE_LOCAL_PATH)" ]]; then
            _nds_settings_installFlake_ask_location
            continue
        fi
        if [[ -z "$(nds_cfg_get FLAKE_HOST)" ]] || ! validate_hostname "$(nds_cfg_get FLAKE_HOST)" 2>/dev/null; then
            if declare -f nds_flake_pick_host &>/dev/null; then
                nds_flake_pick_host || return 1
            else
                nds_cfg_ask_hostname FLAKE_HOST "nixosConfigurations host name" "" true
            fi
            continue
        fi
        # Env/config host set but not in flake list — re-pick when we can list.
        if declare -f nds_flake_resolve_root &>/dev/null && declare -f nds_flake_list_hosts &>/dev/null; then
            root="$(nds_flake_resolve_root 2>/dev/null || true)"
            if [[ -n "$root" ]]; then
                hosts_out="$(nds_flake_list_hosts "$root" 2>/dev/null || true)"
                host="$(nds_cfg_get FLAKE_HOST)"
                if [[ -z "$hosts_out" ]]; then
                    error "Flake has 0 nixosConfigurations — a host folder is not a flake attr"
                    return 1
                fi
                mapfile -t hosts <<< "$hosts_out"
                if ! nds_flake_host_in_list "$host" "${hosts[@]}"; then
                    warn "FLAKE_HOST='${host}' is not in nixosConfigurations — pick from the list."
                    nds_cfg_set FLAKE_HOST ""
                    nds_flake_pick_host "$root" || return 1
                    continue
                fi
            fi
        fi
        break
    done
}

installFlake_validate() {
    local root host hosts_out
    local -a hosts=()

    if nds_cfg_is INSTALL_MODE remote && [[ -z "$(nds_cfg_get REMOTE_TARGET_IP)" ]]; then
        validation_error "Target host IP is required for remote install"
        return 1
    fi
    if [[ -z "$(nds_cfg_get FLAKE_REPO_URL)" && -z "$(nds_cfg_get FLAKE_LOCAL_PATH)" ]]; then
        validation_error "Flake location (git URL or local path) is required"
        return 1
    fi
    [[ -n "$(nds_cfg_get FLAKE_HOST)" ]] || { validation_error "Host name is required"; return 1; }
    validate_hostname "$(nds_cfg_get FLAKE_HOST)" || {
        validation_error "$(_nds_settings_error_hostname)"
        return 1
    }
    if declare -f nds_flake_resolve_root &>/dev/null && declare -f nds_flake_list_hosts &>/dev/null; then
        root="$(nds_flake_resolve_root 2>/dev/null || true)"
        host="$(nds_cfg_get FLAKE_HOST)"
        if [[ -n "$root" ]]; then
            if ! hosts_out="$(nds_flake_list_hosts "$root" 2>/dev/null)"; then
                validation_error "Could not eval nixosConfigurations from the flake"
                return 1
            fi
            if [[ -z "$hosts_out" ]]; then
                validation_error "Flake has 0 nixosConfigurations"
                return 1
            fi
            mapfile -t hosts <<< "$hosts_out"
            if ! nds_flake_host_in_list "$host" "${hosts[@]}"; then
                validation_error "FLAKE_HOST '${host}' is not in nixosConfigurations"
                return 1
            fi
        fi
    fi
    return 0
}

if declare -f nds_preset_register_hooks &>/dev/null; then
    nds_preset_register_hooks \
        defaults=installFlake_defaults \
        configure=installFlake_configure \
        validate=installFlake_validate \
        summary=installFlake_summary \
        prompt_errors=installFlake_prompt_errors
fi

NDS_PRESET_PRIORITY=20
NDS_PRESET_DISPLAY="Your flake"
