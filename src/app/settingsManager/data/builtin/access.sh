#!/usr/bin/env bash
# ==================================================================================================
# NDS - Access preset
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-01 | Modified: 2026-07-03
# ==================================================================================================

access_defaults() {
    nds_cfg_set ACCESS_ADMIN_USER "admin"
    nds_cfg_set ACCESS_ADMIN_PASSWORD_AUTO "true"
    nds_cfg_set ACCESS_ADMIN_PASSWORD_LENGTH "32"
    nds_cfg_set ACCESS_ADMIN_PASSWORD ""
    nds_cfg_set ACCESS_ADMIN_SSH_KEY ""
    nds_cfg_set ACCESS_SUDO_PASSWORD_REQUIRED "true"
    nds_cfg_set ACCESS_SSH_ENABLE "true"
    nds_cfg_set ACCESS_SSH_PORT "22"
    nds_cfg_set ACCESS_SSH_PASSWORD_AUTH "true"
}

access_configure() {
    nds_cfg_section_title "Access"
    nds_cfg_ask_username ACCESS_ADMIN_USER "Admin username" "admin" true
    nds_cfg_ask_toggle ACCESS_ADMIN_PASSWORD_AUTO "Auto-generate admin password" true
    if nds_cfg_true ACCESS_ADMIN_PASSWORD_AUTO; then
        nds_cfg_ask_int ACCESS_ADMIN_PASSWORD_LENGTH "Admin password length (characters)" 32 16 128
    else
        nds_cfg_ask_secret ACCESS_ADMIN_PASSWORD "Admin password" 12 true
    fi
    nds_cfg_ask_string ACCESS_ADMIN_SSH_KEY "Admin SSH public key (optional)" "" false
    nds_cfg_ask_toggle ACCESS_SUDO_PASSWORD_REQUIRED "Sudo requires password" true
    nds_cfg_ask_toggle ACCESS_SSH_ENABLE "Enable SSH" true
    if nds_cfg_true ACCESS_SSH_ENABLE; then
        nds_cfg_ask_port ACCESS_SSH_PORT "SSH port" 22
        nds_cfg_ask_toggle ACCESS_SSH_PASSWORD_AUTH "Allow SSH password login" true
    fi
}

access_summary() {
    nds_cfg_summary_row "Admin user" "$(nds_cfg_get ACCESS_ADMIN_USER)"
    if nds_cfg_true ACCESS_ADMIN_PASSWORD_AUTO; then
        nds_cfg_summary_row "Admin password" "$(nds_cfg_get ACCESS_ADMIN_PASSWORD_LENGTH) chars (auto-generated)"
    else
        nds_cfg_summary_row "Admin password" "manual entry"
    fi
    local ak; ak=$(nds_cfg_get ACCESS_ADMIN_SSH_KEY)
    nds_cfg_summary_row "Admin SSH key" "$([[ -n "$ak" ]] && echo set || echo "(none)")"
    nds_cfg_summary_row "Sudo needs password" "$(nds_cfg_display_toggle "$(nds_cfg_get ACCESS_SUDO_PASSWORD_REQUIRED)")"
    nds_cfg_summary_row "SSH" "$(nds_cfg_display_toggle "$(nds_cfg_get ACCESS_SSH_ENABLE)")"
    if nds_cfg_true ACCESS_SSH_ENABLE; then
        nds_cfg_summary_row "SSH port" "$(nds_cfg_get ACCESS_SSH_PORT)"
        nds_cfg_summary_row "SSH password login" "$(nds_cfg_display_toggle "$(nds_cfg_get ACCESS_SSH_PASSWORD_AUTH)")"
    fi
}

access_prompt_errors() {
    nds_cfg_section_title "Access"
    while ! access_validate &>/dev/null; do
        if nds_cfg_is ACCESS_ADMIN_PASSWORD_AUTO false && [[ -z "$(nds_cfg_get ACCESS_ADMIN_PASSWORD)" ]]; then
            nds_cfg_ask_secret ACCESS_ADMIN_PASSWORD "Admin password" 12 true
            continue
        fi
        if nds_cfg_true ACCESS_SSH_ENABLE && nds_cfg_is ACCESS_SSH_PASSWORD_AUTH false && [[ -z "$(nds_cfg_get ACCESS_ADMIN_SSH_KEY)" ]]; then
            nds_cfg_ask_string ACCESS_ADMIN_SSH_KEY "Admin SSH public key" "" true
            continue
        fi
        break
    done
}

access_validate() {
    if nds_cfg_is ACCESS_ADMIN_PASSWORD_AUTO false && [[ -z "$(nds_cfg_get ACCESS_ADMIN_PASSWORD)" ]]; then
        validation_error "Admin password is required when auto-generate is off"
        return 1
    fi
    if nds_cfg_true ACCESS_SSH_ENABLE && nds_cfg_is ACCESS_SSH_PASSWORD_AUTH false && [[ -z "$(nds_cfg_get ACCESS_ADMIN_SSH_KEY)" ]]; then
        validation_error "SSH password login is off and no admin SSH key is set"
        return 1
    fi
    return 0
}

if declare -f nds_preset_register_hooks &>/dev/null; then
    nds_preset_register_hooks \
        defaults=access_defaults \
        configure=access_configure \
        validate=access_validate \
        summary=access_summary \
        prompt_errors=access_prompt_errors
fi

NDS_PRESET_PRIORITY=15
NDS_PRESET_DISPLAY="Access"
