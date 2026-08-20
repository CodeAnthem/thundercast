#!/usr/bin/env bash
# ==================================================================================================
# NDS - Region preset
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-01 | Modified: 2026-07-03
# ==================================================================================================

region_defaults() {
    nds_cfg_set REGION_TIMEZONE "UTC"
    nds_cfg_set REGION_LOCALE_MAIN "en_US.UTF-8"
    nds_cfg_set REGION_LOCALE_EXTRA ""
    nds_cfg_set REGION_KEYBOARD_LAYOUT "us"
    nds_cfg_set REGION_KEYBOARD_VARIANT ""
}

region_configure() {
    nds_cfg_section_title "Region"
    nds_cfg_ask_timezone REGION_TIMEZONE "Timezone" "UTC"
    nds_cfg_ask_locale REGION_LOCALE_MAIN "Primary locale" "en_US.UTF-8"
    nds_cfg_ask_string REGION_LOCALE_EXTRA "Additional locales" "" false
    nds_cfg_ask_keyboard REGION_KEYBOARD_LAYOUT "Keyboard layout" "us"
    nds_cfg_ask_string REGION_KEYBOARD_VARIANT "Keyboard variant (optional)" "" false
}

region_summary() {
    nds_cfg_summary_row "Timezone" "$(nds_cfg_get REGION_TIMEZONE)"
    nds_cfg_summary_row "Locale" "$(nds_cfg_get REGION_LOCALE_MAIN)"
    local extra; extra=$(nds_cfg_get REGION_LOCALE_EXTRA)
    [[ -n "$extra" ]] && nds_cfg_summary_row "Extra locales" "$extra"
    nds_cfg_summary_row "Keyboard" "$(nds_cfg_get REGION_KEYBOARD_LAYOUT)"
    local kv; kv=$(nds_cfg_get REGION_KEYBOARD_VARIANT)
    [[ -n "$kv" ]] && nds_cfg_summary_row "Keyboard variant" "$kv"
    return 0
}

region_validate() {
    validate_timezone "$(nds_cfg_get REGION_TIMEZONE)" || { validation_error "Invalid timezone"; return 1; }
    validate_locale "$(nds_cfg_get REGION_LOCALE_MAIN)" || { validation_error "Invalid locale"; return 1; }
    return 0
}

if declare -f nds_preset_register_hooks &>/dev/null; then
    nds_preset_register_hooks \
        defaults=region_defaults \
        configure=region_configure \
        validate=region_validate \
        summary=region_summary
fi

NDS_PRESET_PRIORITY=50
NDS_PRESET_DISPLAY="Region"
