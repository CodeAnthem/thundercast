#!/usr/bin/env bash
# ==================================================================================================
# NDS - Restore bundle
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# Description:   Zip a sealed recipe and the session files. No code.
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

eventCreate bundle.collect

_NDS_BUNDLE_STAGE=""

nds_bundle_add() {
    local _bundle_dest=$1 _bundle_src=$2 _bundle_path
    [[ -n "$_NDS_BUNDLE_STAGE" && -f "$_bundle_src" ]] || return 1
    _bundle_path="${_NDS_BUNDLE_STAGE}/${_bundle_dest}"
    mkdir -p "$(dirname "$_bundle_path")" || return 1
    cp "$_bundle_src" "$_bundle_path"
}

_bundle_rewrite_paths() {
    local _bundle_name=$1 _bundle_stage=$2
    local -n _R=$1
    local _bundle_key _bundle_type _bundle_value _bundle_base
    while IFS= read -r _bundle_key; do
        [[ -n "$_bundle_key" ]] || continue
        _bundle_type=${_NDS_SCHEMA_FIELD_TYPE[$_bundle_key]:-}
        _bundle_value=${_R[$_bundle_key]:-}
        [[ -n "$_bundle_value" ]] || continue
        case "$_bundle_type" in
            secret|file)
                [[ -f "$_bundle_value" ]] || continue
                _bundle_base=$(basename "$_bundle_value")
                mkdir -p "${_bundle_stage}/secrets"
                cp "$_bundle_value" "${_bundle_stage}/secrets/${_bundle_base}" || return 1
                nds_recipe_set "$_bundle_name" "$_bundle_key" "secrets/${_bundle_base}"
                ;;
        esac
    done < <(nds_recipe_keys "$_bundle_name")
    if [[ -n ${_R[GIT_KEYS_DIR]:-} && -d ${_R[GIT_KEYS_DIR]} ]]; then
        mkdir -p "${_bundle_stage}/secrets/git"
        cp -a "${_R[GIT_KEYS_DIR]}/." "${_bundle_stage}/secrets/git/" || return 1
        nds_recipe_set "$_bundle_name" GIT_KEYS_DIR secrets/git
    fi
    if [[ -n ${_R[TARGET_SEED_DIR]:-} && -d ${_R[TARGET_SEED_DIR]} ]]; then
        mkdir -p "${_bundle_stage}/seed"
        cp -a "${_R[TARGET_SEED_DIR]}/." "${_bundle_stage}/seed/" || return 1
        nds_recipe_set "$_bundle_name" TARGET_SEED_DIR seed
    fi
    unset '_R[LEAF_PUSH_DIR]' '_R[LEAF_PUSH_MESSAGE]'
}

_bundle_copy_tree() {
    local _bundle_src=$1 _bundle_dest=$2
    [[ -d "$_bundle_src" ]] || return 0
    mkdir -p "$_bundle_dest"
    cp -a "${_bundle_src}/." "$_bundle_dest/" 2>/dev/null || true
}

nds_bundle() {
    local -A R=()
    local _bundle_file=$1 _bundle_stage _bundle_user _bundle_home _bundle_out _bundle_n=0
    nds_schema_enableAll || return 1
    nds_recipe_loadFile R "$_bundle_file" || return 1
    nds_recipe_validate R || _bundle_n=$?
    (( _bundle_n == 0 )) || return 1
    _bundle_stage=$(mktemp -d)
    _NDS_BUNDLE_STAGE=$_bundle_stage
    mkdir -p "${_bundle_stage}/secrets" "${_bundle_stage}/config" "${_bundle_stage}/seed" "${_bundle_stage}/logs"
    _bundle_rewrite_paths R "$_bundle_stage" || return 1
    _bundle_copy_tree "$(nds_session_dir config)" "${_bundle_stage}/config"
    _bundle_copy_tree "$(nds_session_dir logs)" "${_bundle_stage}/logs"
    : > "${_bundle_stage}/logs/nds.log"
    : > "${_bundle_stage}/logs/nixosInstallation.log"
    nds_recipe_export R "${_bundle_stage}/nds-restore.recipe" || return 1
    nds_bundle_quickstart R "${_bundle_stage}/QUICK_START.md" || return 1
    eventRun bundle.collect R || return 1
    _bundle_user=${ nds_session_sshUser; }
    _bundle_home="/home/${_bundle_user}"
    if [[ ! -d "$_bundle_home" || ! -w "$_bundle_home" ]]; then
        mkdir -p "$_bundle_home" 2>/dev/null || _bundle_home="${ nds_session_dir work; }"
    fi
    if command -v zip >/dev/null 2>&1; then
        _bundle_out="${_bundle_home}/nds_bundle.zip"
        rm -f "$_bundle_out"
        (cd "$_bundle_stage" && zip -qr "$_bundle_out" .) || return 1
    else
        _bundle_out="${_bundle_home}/nds_bundle.tar.gz"
        rm -f "$_bundle_out"
        tar -C "$_bundle_stage" -czf "$_bundle_out" . || return 1
    fi
    chmod 600 "$_bundle_out" || return 1
    chown "$_bundle_user" "$_bundle_out" 2>/dev/null || true
    rm -rf "$_bundle_stage"
    _NDS_BUNDLE_STAGE=""
    printf '%s\n' "$_bundle_out"
}
