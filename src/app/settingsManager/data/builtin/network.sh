#!/usr/bin/env bash
# ==================================================================================================
# NDS - Network preset
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-01 | Modified: 2026-07-02
# ==================================================================================================

network_defaults() {
    nds_cfg_set NETWORK_HOSTNAME ""
    nds_cfg_set NETWORK_METHOD "dhcp"
    nds_cfg_set NETWORK_IP ""
    nds_cfg_set NETWORK_MASK "255.255.255.0"
    nds_cfg_set NETWORK_GATEWAY ""
    nds_cfg_set NETWORK_DNS_PRIMARY "1.1.1.1"
    nds_cfg_set NETWORK_DNS_SECONDARY "1.0.0.1"
}

network_configure() {
    nds_cfg_section_title "Network"
    nds_cfg_ask_hostname NETWORK_HOSTNAME "Hostname" "" true
    nds_cfg_ask_choice NETWORK_METHOD "Network method" "dhcp|static" "dhcp=DHCP|static=Static IP" "dhcp"
    nds_cfg_ask_ip NETWORK_DNS_PRIMARY "Primary DNS" "1.1.1.1" true
    nds_cfg_ask_ip NETWORK_DNS_SECONDARY "Secondary DNS" "1.0.0.1" true
    if nds_cfg_is NETWORK_METHOD static; then
        nds_cfg_ask_ip NETWORK_IP "IP address" "" true
        nds_cfg_ask_mask NETWORK_MASK "Network mask" "255.255.255.0"
        nds_cfg_ask_ip NETWORK_GATEWAY "Gateway" "" true
    fi
}

network_summary() {
    nds_cfg_summary_row "Hostname" "$(nds_cfg_get NETWORK_HOSTNAME)"
    nds_cfg_summary_row "Network method" "$(nds_cfg_display_choice "$(nds_cfg_get NETWORK_METHOD)" "dhcp=DHCP|static=Static IP")"
    if nds_cfg_is NETWORK_METHOD static; then
        nds_cfg_summary_row "IP address" "$(nds_cfg_get NETWORK_IP)"
        nds_cfg_summary_row "Gateway" "$(nds_cfg_get NETWORK_GATEWAY)"
    fi
    nds_cfg_summary_row "Primary DNS" "$(nds_cfg_get NETWORK_DNS_PRIMARY)"
}

network_prompt_errors() {
    nds_cfg_section_title "Network"
    while ! network_validate &>/dev/null; do
        local hostname
        hostname=$(nds_cfg_get NETWORK_HOSTNAME)
        if [[ -z "$hostname" ]] || ! validate_hostname "$hostname" 2>/dev/null; then
            nds_cfg_ask_hostname NETWORK_HOSTNAME "Hostname" "" true
            continue
        fi
        if nds_cfg_is NETWORK_METHOD static; then
            if [[ -z "$(nds_cfg_get NETWORK_IP)" ]] || ! validate_ip "$(nds_cfg_get NETWORK_IP)" 2>/dev/null; then
                nds_cfg_ask_ip NETWORK_IP "IP address" "" true
                continue
            fi
            if [[ -z "$(nds_cfg_get NETWORK_MASK)" ]] || ! validate_mask "$(nds_cfg_get NETWORK_MASK)" 2>/dev/null; then
                nds_cfg_ask_mask NETWORK_MASK "Network mask" "255.255.255.0"
                continue
            fi
            if [[ -z "$(nds_cfg_get NETWORK_GATEWAY)" ]] || ! validate_ip "$(nds_cfg_get NETWORK_GATEWAY)" 2>/dev/null; then
                nds_cfg_ask_ip NETWORK_GATEWAY "Gateway" "" true
                continue
            fi
        fi
        break
    done
}

network_validate() {
    local hostname
    hostname=$(nds_cfg_get NETWORK_HOSTNAME)
    if [[ -z "$hostname" ]]; then
        validation_error "Hostname is required"
        return 1
    fi
    validate_hostname "$hostname" || {
        validation_error "$(_nds_settings_error_hostname)"
        return 1
    }

    if nds_cfg_is NETWORK_METHOD static; then
        local ip mask gateway
        ip=$(nds_cfg_get NETWORK_IP)
        mask=$(nds_cfg_get NETWORK_MASK)
        gateway=$(nds_cfg_get NETWORK_GATEWAY)
        [[ -n "$ip" && -n "$gateway" ]] || { validation_error "Static network needs IP and gateway"; return 1; }
        if [[ "$ip" == "$gateway" ]]; then
            validation_error "Gateway cannot be the same as IP address"
            return 1
        fi
        if [[ -n "$ip" && -n "$mask" && -n "$gateway" ]]; then
            validate_ip_same_subnet "$ip" "$mask" "$gateway" || {
                validation_error "Gateway must be in the same subnet as $ip/$mask"
                return 1
            }
        fi
    fi
    return 0
}

if declare -f nds_preset_register_hooks &>/dev/null; then
    nds_preset_register_hooks \
        defaults=network_defaults \
        configure=network_configure \
        validate=network_validate \
        summary=network_summary \
        prompt_errors=network_prompt_errors
fi

NDS_PRESET_PRIORITY=10
NDS_PRESET_DISPLAY="Network"
