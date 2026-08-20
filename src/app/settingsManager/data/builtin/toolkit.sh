#!/usr/bin/env bash
# ==================================================================================================
# NDS - toolkit composer preset (ops VM create / restore)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-20 | Modified: 2026-08-20
# ==================================================================================================

toolkit_defaults() {
    nds_cfg_set INSTALL_KIND "flake"
    nds_cfg_set INSTALL_COMPOSER "toolkit"
    nds_cfg_set CAST_TOOLKIT_MODE "new"
    nds_cfg_set CAST_TOOLKIT_BUNDLE ""
    nds_cfg_set SCAFFOLD_MODE "existing"
    nds_cfg_set FLAKE_HOST "control-toolkit"
    nds_cfg_set FLAKE_INSTALL_PATH "/mnt/etc/nixos"
    nds_cfg_set FLAKE_HOST_DIR "hosts/x86_64-linux"
    nds_cfg_set FLAKE_HARDWARE_PLACEMENT "host-dir"
    nds_cfg_set ENCRYPTION "false"
    nds_cfg_set DISK_STRATEGY "nds"
    nds_cfg_set TOOLKIT_AGE_KEY_FILE ""
    nds_cfg_set TOOLKIT_SSH_KEY_FILE ""
    [[ -n "$(nds_cfg_get FLAKE_REPO_URL)" ]] || nds_cfg_set FLAKE_REPO_URL ""
}

toolkit_configure() {
    nds_cfg_section_title "Toolkit VM"
    nds_cfg_ask_choice CAST_TOOLKIT_MODE "Toolkit" "new|restore" \
        "new=Create operator key and deploy write access|restore=Inject a previous bundle zip" \
        "new"
    if nds_cfg_is CAST_TOOLKIT_MODE restore; then
        nds_cfg_ask_path CAST_TOOLKIT_BUNDLE "Path to toolkit bundle zip" "" true
    fi
    nds_cfg_ask_url FLAKE_REPO_URL "Install flake Git URL" "" true
    nds_cfg_ask_hostname FLAKE_HOST "Toolkit host name" "control-toolkit" true
}

toolkit_summary() {
    nds_cfg_summary_row "Toolkit" "$(nds_cfg_get CAST_TOOLKIT_MODE)"
    if nds_cfg_is CAST_TOOLKIT_MODE restore; then
        nds_cfg_summary_row "Bundle" "$(nds_cfg_get CAST_TOOLKIT_BUNDLE)"
    fi
    nds_cfg_summary_row "Install flake" "$(nds_cfg_get FLAKE_REPO_URL)"
    nds_cfg_summary_row "Host" "$(nds_cfg_get FLAKE_HOST)"
}

toolkit_prompt_errors() {
    nds_cfg_section_title "Toolkit VM"
    while ! toolkit_validate &>/dev/null; do
        if [[ -z "$(nds_cfg_get FLAKE_REPO_URL)" ]]; then
            nds_cfg_ask_url FLAKE_REPO_URL "Install flake Git URL" "" true
            continue
        fi
        if nds_cfg_is CAST_TOOLKIT_MODE restore && [[ -z "$(nds_cfg_get CAST_TOOLKIT_BUNDLE)" ]]; then
            nds_cfg_ask_path CAST_TOOLKIT_BUNDLE "Path to toolkit bundle zip" "" true
            continue
        fi
        if [[ -z "$(nds_cfg_get FLAKE_HOST)" ]]; then
            nds_cfg_ask_hostname FLAKE_HOST "Toolkit host name" "control-toolkit" true
            continue
        fi
        break
    done
}

toolkit_validate() {
    [[ -n "$(nds_cfg_get FLAKE_REPO_URL)" ]] || {
        validation_error "Install flake Git URL is required"
        return 1
    }
    [[ -n "$(nds_cfg_get FLAKE_HOST)" ]] || {
        validation_error "Toolkit host name is required"
        return 1
    }
    if nds_cfg_is CAST_TOOLKIT_MODE restore; then
        local bundle
        bundle="$(nds_cfg_get CAST_TOOLKIT_BUNDLE)"
        [[ -n "$bundle" ]] || {
            validation_error "CAST_TOOLKIT_BUNDLE is required for toolkit restore"
            return 1
        }
        if declare -f validate_secret_file &>/dev/null; then
            [[ -f "$bundle" || -d "$bundle" ]] || {
                validation_error "Toolkit bundle not found: ${bundle}"
                return 1
            }
        fi
    fi
    return 0
}

if declare -f nds_preset_register_hooks &>/dev/null; then
    nds_preset_register_hooks \
        defaults=toolkit_defaults \
        configure=toolkit_configure \
        validate=toolkit_validate \
        summary=toolkit_summary \
        prompt_errors=toolkit_prompt_errors
fi

NDS_PRESET_PRIORITY=19
NDS_PRESET_DISPLAY="Toolkit"
