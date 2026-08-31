#!/usr/bin/env bash
# ==================================================================================================
# NDS - System variables (NDS_* env bridge)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-28 | Modified: 2026-08-31
# Description:   Map process env NDS_* into settings store; sync derived flake keys
# ==================================================================================================

# Description: List exported NDS_* names (portable; no compgen required).
# Returns:
# - <String> One env name per line (stdout)
_nds_cfg_list_nds_env_names() {
    export -p | sed -n 's/^declare -x \(NDS_[A-Za-z0-9_]*\)=.*/\1/p'
}

# Description: Sync FLAKE_LOCATION / FLAKE_SOURCE from FLAKE_REPO_URL or FLAKE_LOCAL_PATH.
nds_cfg_sync_derived_flake() {
    local loc repo local_path src
    loc="$(nds_cfg_get FLAKE_LOCATION)"
    repo="$(nds_cfg_get FLAKE_REPO_URL)"
    local_path="$(nds_cfg_get FLAKE_LOCAL_PATH)"

    if [[ -n "$loc" && -z "$repo" && -z "$local_path" ]]; then
        src=$(nds_detect_flake_source "$loc")
        nds_cfg_set FLAKE_SOURCE "$src"
        if [[ "$src" == remote ]]; then
            nds_cfg_set FLAKE_REPO_URL "$loc"
            nds_cfg_set FLAKE_LOCAL_PATH ""
        else
            nds_cfg_set FLAKE_LOCAL_PATH "$loc"
            nds_cfg_set FLAKE_REPO_URL ""
        fi
        return 0
    fi

    if [[ -n "$repo" ]]; then
        nds_cfg_set FLAKE_LOCATION "$repo"
        nds_cfg_set FLAKE_SOURCE "remote"
        nds_cfg_set FLAKE_LOCAL_PATH ""
    elif [[ -n "$local_path" ]]; then
        nds_cfg_set FLAKE_LOCATION "$local_path"
        nds_cfg_set FLAKE_SOURCE "local"
        nds_cfg_set FLAKE_REPO_URL ""
    fi
}

# Description: Apply every scalar NDS_* environment variable to CONFIG_DATA, then sync derived keys.
# Optional NDS_SCOPED_CONFIG_FILE is sourced first (export NDS_*= plus optional git declare -gA).
# Runtime flags (NDS_ACTION, NDS_MODE, NDS_GH_*, NDS_*_SKIP, …) stay out of CONFIG_DATA.
nds_cfg_apply_env_all() {
    local env_name key

    if [[ -n "${NDS_SCOPED_CONFIG_FILE:-}" && -f "${NDS_SCOPED_CONFIG_FILE}" ]]; then
        if declare -f nds_cfg_load_scoped_file &>/dev/null; then
            nds_cfg_load_scoped_file
        fi
    fi

    while IFS= read -r env_name; do
        [[ "$env_name" == NDS_* ]] || continue
        case "$env_name" in
            NDS_SCOPED_CONFIG_FILE|NDS_RUNTIME_DIR|NDS_INSTALL_LOG|NDS_INSTALL_DETAIL_LOG|NDS_INSTALL_DIAG_LOG|NDS_NIXOS_INSTALL_LOG|\
            NDS_ACTION|NDS_MODE|NDS_UNATTENDED|NDS_AUTO_CONFIRM|NDS_TEST|NDS_CURRENT_ACTION|\
            NDS_RECIPE_FILE|NDS_SECRETS_DIR|\
            NDS_REBOOT_FORCE|NDS_REBOOT_SKIP|NDS_SKIP_MENU|\
            NDS_NIXOS_STATE_VERSION|NDS_PRESET_EXTRA_DIR|NDS_PRESET_EXTRA_PATHS|\
            NDS_GH_*|NDS_GIT_GH_*|\
            NDS_GIT_METHOD|NDS_GIT_KEY_PATH|NDS_GIT_KEY_KIND|NDS_GIT_KEY_BODY|NDS_GIT_IMPORT_KEY|\
            NDS_GIT_ACCESS_VERIFIED|NDS_FLAKE_PROBE_REPO|NDS_FLAKE_PROBE_REPO_URL|NDS_CAST_PROBE_DIR|\
            NDS_GIT_INSTALL_SUCCEEDED|NDS_GIT_CLOSURE_URLS)
                continue
                ;;
            NDS_*_SKIP)
                continue
                ;;
        esac
        if declare -f _nds_cfg_is_assoc_array &>/dev/null && _nds_cfg_is_assoc_array "$env_name"; then
            continue
        fi
        key="${env_name#NDS_}"
        [[ -n "${!env_name:-}" ]] || continue
        CONFIG_DATA["$key"]="${!env_name}"
        debug "Env: ${env_name}=${!env_name}"
    done < <(_nds_cfg_list_nds_env_names || true)

    nds_cfg_sync_derived_flake
}

# True when name is a declare -A, not a scalar env value.
_nds_cfg_is_assoc_array() {
    local n="$1" d
    d="$(declare -p "$n" 2>/dev/null)" || return 1
    [[ "$d" =~ ^declare\ -[a-zA-Z]*A ]]
}

# Description: Source NDS_SCOPED_CONFIG_FILE when set (export NDS_*= and optional git declare -gA).
nds_cfg_load_scoped_file() {
    local path="${NDS_SCOPED_CONFIG_FILE:-}"
    [[ -n "$path" && -f "$path" ]] || return 0
    # shellcheck disable=SC1090
    source "$path"
}

