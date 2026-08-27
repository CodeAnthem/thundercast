#!/usr/bin/env bash
# ==================================================================================================
# NDS - toolkit composer preset (ops VM create / restore)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-20 | Modified: 2026-08-27
# ==================================================================================================

toolkit_defaults() {
    nds_cfg_set INSTALL_KIND "flake"
    nds_cfg_set INSTALL_COMPOSER "toolkit"
    nds_cfg_set INSTALL_MODE "local"
    nds_cfg_set CAST_TOOLKIT_MODE "new"
    nds_cfg_set CAST_TOOLKIT_RESTORE "false"
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

# Description: Pin FLAKE_HOST to control-toolkit unless already set (env/recipe).
_nds_toolkit_cfg_ensure_host() {
    [[ -n "$(nds_cfg_get FLAKE_HOST)" ]] || nds_cfg_set FLAKE_HOST "control-toolkit"
}

# Description: Mirror CAST_TOOLKIT_MODE=restore onto the UI toggle.
_nds_toolkit_cfg_load_restore_flag() {
    if nds_cfg_is CAST_TOOLKIT_MODE restore; then
        nds_cfg_set CAST_TOOLKIT_RESTORE true
    else
        [[ -n "$(nds_cfg_get CAST_TOOLKIT_RESTORE)" ]] || nds_cfg_set CAST_TOOLKIT_RESTORE false
    fi
}

# Description: Keep CAST_TOOLKIT_MODE in sync with the restore toggle.
_nds_toolkit_cfg_apply_restore() {
    if nds_cfg_true CAST_TOOLKIT_RESTORE; then
        nds_cfg_set CAST_TOOLKIT_MODE restore
    else
        nds_cfg_set CAST_TOOLKIT_MODE new
        nds_cfg_set CAST_TOOLKIT_BUNDLE ""
    fi
}

toolkit_configure() {
    nds_cfg_section_title "Toolkit VM"
    _nds_toolkit_cfg_ensure_host
    _nds_toolkit_cfg_load_restore_flag
    nds_cfg_ask_toggle CAST_TOOLKIT_RESTORE "Restore existing toolkit" false
    _nds_toolkit_cfg_apply_restore
    if nds_cfg_true CAST_TOOLKIT_RESTORE; then
        nds_cfg_ask_path CAST_TOOLKIT_BUNDLE "Path to toolkit bundle zip" "" true
    fi
    nds_cfg_ask_url FLAKE_REPO_URL "Install flake Git URL" "" true
}

toolkit_summary() {
    _nds_toolkit_cfg_load_restore_flag
    nds_cfg_summary_row "Restore" "$(nds_cfg_display_toggle "$(nds_cfg_get CAST_TOOLKIT_RESTORE)")"
    if nds_cfg_true CAST_TOOLKIT_RESTORE; then
        nds_cfg_summary_row "Bundle" "$(nds_cfg_get CAST_TOOLKIT_BUNDLE)"
    fi
    nds_cfg_summary_row "Flake" "$(nds_cfg_get FLAKE_REPO_URL)"
}

toolkit_prompt_errors() {
    nds_cfg_section_title "Toolkit VM"
    _nds_toolkit_cfg_ensure_host
    _nds_toolkit_cfg_load_restore_flag
    _nds_toolkit_cfg_apply_restore
    while ! toolkit_validate &>/dev/null; do
        if [[ -z "$(nds_cfg_get FLAKE_REPO_URL)" ]]; then
            nds_cfg_ask_url FLAKE_REPO_URL "Install flake Git URL" "" true
            continue
        fi
        if nds_cfg_is CAST_TOOLKIT_MODE restore && [[ -z "$(nds_cfg_get CAST_TOOLKIT_BUNDLE)" ]]; then
            nds_cfg_ask_path CAST_TOOLKIT_BUNDLE "Path to toolkit bundle zip" "" true
            continue
        fi
        break
    done
}

toolkit_validate() {
    _nds_toolkit_cfg_ensure_host
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
