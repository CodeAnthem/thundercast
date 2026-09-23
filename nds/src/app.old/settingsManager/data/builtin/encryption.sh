#!/usr/bin/env bash
# ==================================================================================================
# NDS - Encryption preset
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-01 | Modified: 2026-08-16
# ==================================================================================================

encryption_defaults() {
    nds_cfg_set ENCRYPTION "true"
    nds_cfg_set ENCRYPTION_PASSWORD "true"
    nds_cfg_set ENCRYPTION_PASSWORD_AUTO "true"
    nds_cfg_set ENCRYPTION_PASSWORD_LENGTH "64"
    nds_cfg_set ENCRYPTION_KEY "false"
    nds_cfg_set ENCRYPTION_KEY_AUTO "true"
    nds_cfg_set ENCRYPTION_KEY_LENGTH "4096"
    nds_cfg_set ENCRYPTION_KEY_BOOT_DEVICE ""
    nds_cfg_set ENCRYPTION_KEY_BOOT_FILE ""
    nds_cfg_set ENCRYPTION_REMOTE_UNLOCK "false"
    nds_cfg_set ENCRYPTION_REMOTE_SSH_KEY ""
    nds_cfg_set ENCRYPTION_REMOTE_NETWORK "dhcp"
    nds_cfg_set ENCRYPTION_REMOTE_PORT "2222"
    nds_cfg_set ENCRYPTION_REMOTE_HINT "true"
    nds_cfg_set ENCRYPTION_REMOTE_SHUTDOWN "0"
}

encryption_configure() {
    nds_cfg_section_title "Encryption"
    nds_cfg_ask_toggle ENCRYPTION "Enable encryption" true
    nds_cfg_true ENCRYPTION || return 0

    nds_cfg_ask_toggle ENCRYPTION_PASSWORD "Use password" true
    nds_cfg_ask_toggle ENCRYPTION_KEY "Use key (USB stick)" false
    nds_cfg_ask_toggle ENCRYPTION_REMOTE_UNLOCK "Enable SSH remote unlock in initrd" false

    if nds_cfg_true ENCRYPTION_PASSWORD; then
        nds_cfg_ask_toggle ENCRYPTION_PASSWORD_AUTO "Auto-generate password" true
        if nds_cfg_true ENCRYPTION_PASSWORD_AUTO; then
            nds_cfg_ask_int ENCRYPTION_PASSWORD_LENGTH "Password length (characters)" 64 16 128
        fi
    fi

    if nds_cfg_true ENCRYPTION_KEY; then
        nds_cfg_ask_toggle ENCRYPTION_KEY_AUTO "Auto-generate key" true
        if nds_cfg_true ENCRYPTION_KEY_AUTO; then
            nds_cfg_ask_int ENCRYPTION_KEY_LENGTH "Key length (bytes)" 4096 512 8192
        fi
        nds_cfg_ask_string ENCRYPTION_KEY_BOOT_DEVICE "USB device path at boot" "" true
        nds_cfg_ask_string ENCRYPTION_KEY_BOOT_FILE "Key file on USB (empty = raw device)" "" false
    fi

    if nds_cfg_true ENCRYPTION_REMOTE_UNLOCK; then
        nds_cfg_ask_string ENCRYPTION_REMOTE_SSH_KEY "Authorized SSH public key" "" true
        nds_cfg_ask_choice ENCRYPTION_REMOTE_NETWORK "Initrd network mode" "dhcp|static" \
            "dhcp=DHCP (automatic)|static=Static IP (from network settings)" "dhcp"
        # Default 2222 keeps the initrd sshd off the booted system's port 22, so
        # the two different host keys never collide in known_hosts.
        nds_cfg_ask_port ENCRYPTION_REMOTE_PORT "Remote unlock SSH port" 2222
        nds_cfg_ask_toggle ENCRYPTION_REMOTE_HINT "Show console hint (port + IP)" true
        local shutdown_sec
        while true; do
            nds_cfg_ask_int ENCRYPTION_REMOTE_SHUTDOWN \
                "Auto power-off if still locked (seconds; 0=off, else 30-3600)" 0 0 3600
            shutdown_sec=${ nds_cfg_get ENCRYPTION_REMOTE_SHUTDOWN; }
            [[ -z "$shutdown_sec" ]] && { nds_cfg_set ENCRYPTION_REMOTE_SHUTDOWN "0"; break; }
            if [[ "$shutdown_sec" =~ ^[0-9]+$ ]] && { [[ "$shutdown_sec" -eq 0 ]] || { [[ "$shutdown_sec" -ge 30 ]] && [[ "$shutdown_sec" -le 3600 ]]; }; }; then
                break
            fi
            nds_ui_b "  Error: Use 0 (off) or 30-3600 seconds"
        done
    fi
}

encryption_summary() {
    nds_cfg_summary_row "Encryption" "${ nds_cfg_display_toggle "${ nds_cfg_get ENCRYPTION; }"; }"
    nds_cfg_true ENCRYPTION || return 0

    nds_cfg_summary_row "Password" "${ nds_cfg_display_toggle "${ nds_cfg_get ENCRYPTION_PASSWORD; }"; }"
    if nds_cfg_true ENCRYPTION_PASSWORD; then
        if nds_cfg_true ENCRYPTION_PASSWORD_AUTO; then
            nds_cfg_summary_row "Password length" "${ nds_cfg_get ENCRYPTION_PASSWORD_LENGTH; } chars (auto-generated)"
        else
            nds_cfg_summary_row "Password source" "manual entry"
        fi
    fi

    nds_cfg_summary_row "USB key" "${ nds_cfg_display_toggle "${ nds_cfg_get ENCRYPTION_KEY; }"; }"
    if nds_cfg_true ENCRYPTION_KEY; then
        if nds_cfg_true ENCRYPTION_KEY_AUTO; then
            nds_cfg_summary_row "Key length" "${ nds_cfg_get ENCRYPTION_KEY_LENGTH; } bytes (auto-generated)"
        fi
        nds_cfg_summary_row "USB device" "${ nds_cfg_get ENCRYPTION_KEY_BOOT_DEVICE; }"
        local kf; kf=${ nds_cfg_get ENCRYPTION_KEY_BOOT_FILE; }
        nds_cfg_summary_row "Key file" "${kf:-(raw device)}"
    fi

    nds_cfg_summary_row "Remote unlock" "${ nds_cfg_display_toggle "${ nds_cfg_get ENCRYPTION_REMOTE_UNLOCK; }"; }"
    if nds_cfg_true ENCRYPTION_REMOTE_UNLOCK; then
        local rk; rk=${ nds_cfg_get ENCRYPTION_REMOTE_SSH_KEY; }
        nds_cfg_summary_row "Authorized key" "$([[ -n "$rk" ]] && echo set || echo "(not set)")"
        nds_cfg_summary_row "Initrd network" "${ nds_cfg_display_choice "${ nds_cfg_get ENCRYPTION_REMOTE_NETWORK; }" "dhcp=DHCP|static=Static IP"; }"
        nds_cfg_summary_row "Unlock SSH port" "${ nds_cfg_get ENCRYPTION_REMOTE_PORT; }"
        nds_cfg_summary_row "Unlock console hint" "${ nds_cfg_display_toggle "${ nds_cfg_get ENCRYPTION_REMOTE_HINT; }"; }"
        local shutdown_sec
        shutdown_sec=${ nds_cfg_get ENCRYPTION_REMOTE_SHUTDOWN; }
        [[ -n "$shutdown_sec" ]] || shutdown_sec=0
        if [[ "$shutdown_sec" == "0" ]]; then
            nds_cfg_summary_row "Unlock auto power-off" "off"
        else
            nds_cfg_summary_row "Unlock auto power-off" "${shutdown_sec}s"
        fi
    fi
}

encryption_prompt_errors() {
    nds_cfg_section_title "Encryption"
    while ! encryption_validate &>/dev/null; do
        if ! nds_cfg_true ENCRYPTION_PASSWORD && ! nds_cfg_true ENCRYPTION_KEY; then
            nds_cfg_ask_toggle ENCRYPTION_PASSWORD "Use password" true
            continue
        fi
        if nds_cfg_true ENCRYPTION_KEY && [[ -z "${ nds_cfg_get ENCRYPTION_KEY_BOOT_DEVICE; }" ]]; then
            nds_cfg_ask_string ENCRYPTION_KEY_BOOT_DEVICE "USB device path at boot" "" true
            continue
        fi
        if nds_cfg_true ENCRYPTION_REMOTE_UNLOCK && [[ -z "${ nds_cfg_get ENCRYPTION_REMOTE_SSH_KEY; }" ]]; then
            nds_cfg_ask_string ENCRYPTION_REMOTE_SSH_KEY "Authorized SSH public key" "" true
            continue
        fi
        if nds_cfg_true ENCRYPTION_REMOTE_UNLOCK; then
            local shutdown_sec
            shutdown_sec=${ nds_cfg_get ENCRYPTION_REMOTE_SHUTDOWN; }
            [[ -n "$shutdown_sec" ]] || shutdown_sec=0
            if ! [[ "$shutdown_sec" =~ ^[0-9]+$ ]] || { [[ "$shutdown_sec" -ne 0 ]] && { [[ "$shutdown_sec" -lt 30 ]] || [[ "$shutdown_sec" -gt 3600 ]]; }; }; then
                nds_cfg_ask_int ENCRYPTION_REMOTE_SHUTDOWN \
                    "Auto power-off if still locked (seconds; 0=off, else 30-3600)" 0 0 3600
                continue
            fi
        fi
        break
    done
}

encryption_validate() {
    nds_cfg_true ENCRYPTION || return 0

    if ! nds_cfg_true ENCRYPTION_PASSWORD && ! nds_cfg_true ENCRYPTION_KEY; then
        validation_error "At least one unlock method (password or key) must be enabled"
        return 1
    fi

    if nds_cfg_true ENCRYPTION_KEY && [[ -z "${ nds_cfg_get ENCRYPTION_KEY_BOOT_DEVICE; }" ]]; then
        validation_error "USB device path is required when key unlock is enabled"
        return 1
    fi

    if nds_cfg_true ENCRYPTION_KEY && ! nds_cfg_true ENCRYPTION_PASSWORD; then
        warn "Key-only mode: if the USB is lost, the system cannot boot."
    fi

    if nds_cfg_true ENCRYPTION_REMOTE_UNLOCK; then
        [[ -n "${ nds_cfg_get ENCRYPTION_REMOTE_SSH_KEY; }" ]] || {
            validation_error "Authorized SSH public key is required for remote unlock"
            return 1
        }
        if nds_cfg_is ENCRYPTION_REMOTE_NETWORK static && [[ -z "${ nds_cfg_get NETWORK_IP; }" ]]; then
            validation_error "Static remote unlock needs NETWORK_IP — set it in Network, or use DHCP"
            return 1
        fi
        if ! nds_cfg_true ENCRYPTION_PASSWORD; then
            warn "Remote unlock needs a password slot — SSH cannot unlock key-only disks."
        fi
        local shutdown_sec
        shutdown_sec=${ nds_cfg_get ENCRYPTION_REMOTE_SHUTDOWN; }
        [[ -n "$shutdown_sec" ]] || shutdown_sec=0
        if ! [[ "$shutdown_sec" =~ ^[0-9]+$ ]] || { [[ "$shutdown_sec" -ne 0 ]] && { [[ "$shutdown_sec" -lt 30 ]] || [[ "$shutdown_sec" -gt 3600 ]]; }; }; then
            validation_error "Unlock auto power-off must be 0 (off) or 30-3600 seconds"
            return 1
        fi
    fi
    return 0
}

if declare -f nds_preset_register_hooks &>/dev/null; then
    nds_preset_register_hooks \
        defaults=encryption_defaults \
        configure=encryption_configure \
        validate=encryption_validate \
        summary=encryption_summary \
        prompt_errors=encryption_prompt_errors
fi

NDS_PRESET_PRIORITY=21
NDS_PRESET_DISPLAY="Encryption"
