#!/usr/bin/env bash
# ==================================================================================================
# NDS - Configuration export (restore / grouped / modified)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-01 | Modified: 2026-08-20
# Description:   Concise and restore export of CONFIG_DATA
# ==================================================================================================

# Keys always shown in the concise export even when unchanged, because they are
# auto-detected (not typed by the user) and useful to pin for a repeat install.
_NDS_EXPORT_ALWAYS="DISK_TARGET BOOT_UEFI_MODE BOOT_LOADER PLATFORM_RUN_ON_VM PLATFORM_VM_TYPE"

# Shown in concise export whenever non-empty (even if equal to default).
_NDS_EXPORT_WHEN_SET="INSTALL_MODE FLAKE_REPO_URL FLAKE_LOCAL_PATH FLAKE_HOST FLAKE_INSTALL_PATH FLAKE_HOST_DIR FLAKE_HARDWARE_PLACEMENT CAST_REPO_URL CAST_ACTION CAST_TOOLKIT_MODE SOPS_AGE_REUSE SOPS_AGE_KEY_FILE"

# Machine/hardware-specific keys. The concise export splits these from portable
# policy so a portable profile can be reused across machines untouched.
_NDS_EXPORT_HARDWARE="DISK_TARGET DISK_STRATEGY DISK_FS_TYPE DISK_SWAP_SIZE_MIB DISK_DISKO_CONFIG BOOT_UEFI_MODE BOOT_LOADER PLATFORM_RUN_ON_VM PLATFORM_VM_TYPE PLATFORM_VM_GUEST_TOOLS NETWORK_HOSTNAME NETWORK_IP NETWORK_MASK NETWORK_GATEWAY REMOTE_TARGET_IP"

# Derived keys never shown in the concise export — reconstructed from other keys
# (FLAKE_LOCATION / FLAKE_SOURCE are inferred from FLAKE_REPO_URL / FLAKE_LOCAL_PATH).
_NDS_EXPORT_SKIP="FLAKE_LOCATION FLAKE_SOURCE GIT_AUTH_ROUTE GIT_KEY_SOURCE GIT_EXISTING_KEY GIT_AUTH_MODE GIT_IMPORT_KEY_PATH GIT_SSH_KEY_TYPE GIT_SSH_KEY_REGISTER_METHOD GIT_CLOSURE_ROUTE GIT_SSH_KEY_USE_QR GIT_SSH_KEY_DISPLAY GIT_SSH_KEY_GH_AUTO GIT_SSH_KEY_TITLE_COLLISION GIT_GH_BIN GIT_GH_PREFETCH_DONE GIT_ACCESS_VERIFIED GIT_ACCESS_HOST GIT_ACCESS_OWNER GIT_ACCESS_REPO GIT_ACCESS_METHOD GIT_PERSIST_ACCESS GIT_ACCESS_STRATEGY CURRENT_ACTION RUNTIME_DIR INSTALL_DETAIL_LOG INSTALL_LOG ACTION ACTION_PREVIEW_SKIP SKIP_MENU CONFIG_CONFIRM_SKIP INSTALL_CONFIRM_SKIP REMOTE_CONFIRM_SKIP GIT_AUTH_SKIP DISK_FORMAT_CONFIRM_SKIP BACKUP_CONFIRM_SKIP REBOOT_SKIP SCAFFOLD_OVERWRITE_SKIP HARDWARE_OVERWRITE_SKIP PREFLIGHT_WARN_SKIP PROMPTS_SKIP AUTO_CONFIRM ACCESS_ADMIN_PASSWORD ENCRYPTION_PASSPHRASE TOOLKIT_AGE_KEY TOOLKIT_SSH_KEY"

# Menu skip flags — exported false by default so users can enable selective automation.
_NDS_MENU_SKIP_FLAGS=(
    ACTION_PREVIEW_SKIP
    SKIP_MENU
    CONFIG_CONFIRM_SKIP
    INSTALL_CONFIRM_SKIP
    REMOTE_CONFIRM_SKIP
    GIT_AUTH_SKIP
    DISK_FORMAT_CONFIRM_SKIP
    BACKUP_CONFIRM_SKIP
    REBOOT_SKIP
    SCAFFOLD_OVERWRITE_SKIP
    HARDWARE_OVERWRITE_SKIP
    PREFLIGHT_WARN_SKIP
    PROMPTS_SKIP
    AUTO_CONFIRM
)

_NDS_START_CURL="curl -sSL https://raw.githubusercontent.com/CodeAnthem/thundercast/main/start.sh | bash"

# Description: Emit every CONFIG_DATA value as export NDS_*=.
_nds_cfg_export_settings() {
    local varname
    while IFS= read -r varname; do
        [[ -n "$varname" ]] || continue
        if declare -f nds_sm_secret_is &>/dev/null && nds_sm_secret_is "$varname"; then
            continue
        fi
        echo "export NDS_${varname}=\"${CONFIG_DATA[$varname]}\""
    done < <(printf '%s\n' "${!CONFIG_DATA[@]}" | sort)
}

# Description: Emit action, mode, and skip flags (not stored in CONFIG_DATA).
_nds_cfg_export_runtime() {
    local flag env_name val
    if [[ -n "${NDS_CURRENT_ACTION:-}" ]]; then
        echo "export NDS_ACTION=\"${NDS_CURRENT_ACTION}\""
    elif [[ -n "${NDS_ACTION:-}" ]]; then
        echo "export NDS_ACTION=\"${NDS_ACTION}\""
    fi
    echo "export NDS_MODE=\"${NDS_MODE:-interactive}\""
    echo "export NDS_AUTO_CONFIRM=\"${NDS_AUTO_CONFIRM:-false}\""
    for flag in "${_NDS_MENU_SKIP_FLAGS[@]}"; do
        [[ "$flag" == "AUTO_CONFIRM" ]] && continue
        env_name="NDS_${flag}"
        val="${!env_name:-false}"
        echo "export ${env_name}=\"${val}\""
    done
}

# Description: Bundle restore recipe: Settings, Runtime, live curl. ASCII only.
# Paste the whole file, or copy only the export blocks and run curl yourself.
nds_cfg_export_restore() {
    local git_block=""
    echo "# Settings"
    _nds_cfg_export_settings
    if declare -f nds_git_export_maps &>/dev/null; then
        git_block="$(nds_git_export_maps --portable)"
        if [[ -n "$git_block" ]]; then
            # Command substitution strips trailing newlines; always end before # Runtime.
            printf '%s\n' "$git_block"
        fi
    fi
    echo "# Runtime"
    _nds_cfg_export_runtime
    echo ""
    echo "${_NDS_START_CURL}"
}

_nds_settings_export_is_always() {
    local key="$1" a
    for a in $_NDS_EXPORT_ALWAYS; do
        [[ "$key" == "$a" ]] && return 0
    done
    return 1
}

_nds_settings_export_is_when_set() {
    local key="$1" a
    for a in $_NDS_EXPORT_WHEN_SET; do
        [[ "$key" == "$a" ]] && return 0
    done
    return 1
}

_nds_settings_export_is_hardware() {
    local key="$1" a
    for a in $_NDS_EXPORT_HARDWARE; do
        [[ "$key" == "$a" ]] && return 0
    done
    return 1
}

# Whether a key belongs in the concise export: auto-detected essentials always,
# otherwise only when the user changed it from the seeded default.
_nds_settings_export_is_skipped() {
    local key="$1" a
    for a in $_NDS_EXPORT_SKIP; do
        [[ "$key" == "$a" ]] && return 0
    done
    return 1
}

_nds_settings_export_should_include() {
    local key="$1" cur="${CONFIG_DATA[$1]}"
    _nds_settings_export_is_skipped "$key" && return 1
    if _nds_settings_export_is_when_set "$key"; then
        [[ -n "$cur" ]]
        return
    fi
    if _nds_settings_export_is_always "$key"; then
        [[ -n "$cur" ]]
        return
    fi
    if [[ -v CONFIG_DEFAULTS[$key] && "$cur" == "${CONFIG_DEFAULTS[$key]}" ]]; then
        return 1
    fi
    [[ -n "$cur" ]]
}

# Description: Print changed (plus always/when-set) keys as export NDS_*= lines.
nds_cfg_export_modified() {
    local varname
    while IFS= read -r varname; do
        [[ -n "$varname" ]] || continue
        _nds_settings_export_should_include "$varname" || continue
        echo "export NDS_${varname}=\"${CONFIG_DATA[$varname]}\""
    done < <(printf '%s\n' "${!CONFIG_DATA[@]}" | sort)
}

# Concise export as grouped sections: portable policy, this-machine hardware,
# git URL maps when set, menu skip flags (default false). Curl is commented.
# Description: Print grouped restore export (portable / machine / git / skip flags).
nds_cfg_export_grouped() {
    local varname git_block
    local -a portable=() hardware=()

    while IFS= read -r varname; do
        [[ -n "$varname" ]] || continue
        _nds_settings_export_should_include "$varname" || continue
        if _nds_settings_export_is_hardware "$varname"; then
            hardware+=("$varname")
        else
            portable+=("$varname")
        fi
    done < <(printf '%s\n' "${!CONFIG_DATA[@]}" | sort)

    echo "# NDS config — source this file, or paste the export lines."
    echo "# Git URL maps (declare -gA) are the only arrays; everything else is export NDS_*."
    echo "#"

    if [[ ${#portable[@]} -gt 0 ]]; then
        echo "# Configuration — portable:"
        for varname in "${portable[@]}"; do
            echo "export NDS_${varname}=\"${CONFIG_DATA[$varname]}\""
        done
        echo ""
    fi
    if [[ ${#hardware[@]} -gt 0 ]]; then
        echo "# This machine only — disk / boot / VM / network:"
        for varname in "${hardware[@]}"; do
            echo "export NDS_${varname}=\"${CONFIG_DATA[$varname]}\""
        done
        echo ""
    fi
    if declare -f nds_git_export_maps &>/dev/null; then
        git_block="$(nds_git_export_maps)"
        if [[ -n "$git_block" ]]; then
            echo "# Git per-repo access (URL-keyed):"
            printf '%s\n' "$git_block"
        fi
    fi

    echo "# Menu control — set any SKIP flag to true to skip that step (false = interactive):"
    if [[ -n "${NDS_CURRENT_ACTION:-}" ]]; then
        echo "export NDS_ACTION=\"${NDS_CURRENT_ACTION}\""
    fi
    local flag
    for flag in "${_NDS_MENU_SKIP_FLAGS[@]}"; do
        echo "export NDS_${flag}=\"false\""
    done
    echo ""
    echo "# Start NDS (uncomment if you sourced this file instead of pasting):"
    echo "# ${_NDS_START_CURL}"
}
