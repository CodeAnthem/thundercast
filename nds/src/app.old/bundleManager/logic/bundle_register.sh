#!/usr/bin/env bash
# ==================================================================================================
# NDS - Bundle contribution registry (hooks)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-05 | Modified: 2026-09-03
# Description:   Features register files/dirs/text/hooks; create assembles from the registry
# ==================================================================================================

declare -ga NDS_BUNDLE_HOOKS=()
declare -ga NDS_BUNDLE_FILES=()
declare -ga NDS_BUNDLE_DIRS=()
declare -ga NDS_BUNDLE_TEXT_DESTS=()
declare -ga NDS_BUNDLE_TEXT_BODIES=()

# Description: Clear contribution lists (does not unload hooks).
nds_bundle_reset_contribs() {
    NDS_BUNDLE_FILES=()
    NDS_BUNDLE_DIRS=()
    NDS_BUNDLE_TEXT_DESTS=()
    NDS_BUNDLE_TEXT_BODIES=()
}

# Description: Clear hooks and contribs (tests / isolated runs).
nds_bundle_reset() {
    NDS_BUNDLE_HOOKS=()
    nds_bundle_reset_contribs
}

# Description: Register a hook run before bundle assembly (feature contrib entry).
# Arguments:
# - fn: <String> Function name; receives no args; may call nds_bundle_register_*
nds_bundle_register_hook() {
    local fn="${1:?hook function}"
    local h
    for h in "${NDS_BUNDLE_HOOKS[@]:-}"; do
        [[ "$h" == "$fn" ]] && return 0
    done
    NDS_BUNDLE_HOOKS+=("$fn")
}

# Description: Register a file to include in the bundle.
# Arguments:
# - dest: <String> Path inside the archive (relative)
# - src:  <String> Absolute path on disk
nds_bundle_register_file() {
    local dest="${1:?dest}" src="${2:?src}"
    NDS_BUNDLE_FILES+=("${dest}|${src}")
}

# Description: Register a directory tree to merge into the bundle.
# Arguments:
# - dest: <String> Directory path inside the archive
# - src:  <String> Absolute directory on disk
nds_bundle_register_dir() {
    local dest="${1:?dest}" src="${2:?src}"
    NDS_BUNDLE_DIRS+=("${dest}|${src}")
}

# Description: Register inline text content as a file in the bundle.
# Arguments:
# - dest:    <String> Path inside the archive
# - content: <String> File body
nds_bundle_register_text() {
    local dest="${1:?dest}" content="${2-}"
    NDS_BUNDLE_TEXT_DESTS+=("$dest")
    NDS_BUNDLE_TEXT_BODIES+=("$content")
}

# Description: Run all registered hooks (each may add files/dirs/text).
nds_bundle_run_hooks() {
    local fn
    for fn in "${NDS_BUNDLE_HOOKS[@]:-}"; do
        if declare -f "$fn" &>/dev/null; then
            "$fn" || {
                nds_install_log "bundle hook failed: $fn" 2>/dev/null || true
                debug "bundle hook failed: $fn"
            }
        else
            debug "bundle hook missing: $fn"
        fi
    done
}

# Description: Core install contributions (config, secrets, logs, quickstart).
# Registered as the default hook; features add more via nds_bundle_register_hook.
nds_bundle_contrib_core() {
    local nds_log nixos_log
    local item

    if declare -f nds_sm_export &>/dev/null; then
        nds_bundle_register_text "nds-restore.recipe" "${ nds_sm_export; }"
    fi

    if [[ -f "${NDS_RUNTIME_DIR:-}/config/configuration.nix" ]]; then
        nds_bundle_register_file "config/configuration.nix" \
            "${NDS_RUNTIME_DIR}/config/configuration.nix"
    fi
    if [[ -f "${NDS_RUNTIME_DIR:-}/config/hardware-configuration.nix" ]]; then
        nds_bundle_register_file "config/hardware-configuration.nix" \
            "${NDS_RUNTIME_DIR}/config/hardware-configuration.nix"
    fi
    if [[ -f "${NDS_RUNTIME_DIR:-}/config/facter.json" ]]; then
        nds_bundle_register_file "config/facter.json" \
            "${NDS_RUNTIME_DIR}/config/facter.json"
    fi

    nds_log="${NDS_RUNTIME_DIR:-/tmp}/nds.log"
    if declare -f nds_install_logs_compose &>/dev/null; then
        nds_install_logs_compose "$nds_log"
        nds_bundle_register_file "logs/nds.log" "$nds_log"
    fi
    nixos_log="${NDS_NIXOS_INSTALL_LOG:-}"
    if [[ -n "$nixos_log" && -f "$nixos_log" ]]; then
        nds_bundle_register_file "logs/nixosInstallation.log" "$nixos_log"
    fi

    if [[ -d "${NDS_RUNTIME_DIR:-}/secrets" ]]; then
        for item in "${NDS_RUNTIME_DIR}/secrets"/*; do
            [[ -f "$item" ]] || continue
            nds_bundle_register_file "secrets/$(basename "$item")" "$item"
        done
    fi
}

# Seed core hook once at load time.
nds_bundle_register_hook nds_bundle_contrib_core
if declare -f nds_git_bundle_contrib &>/dev/null; then
    nds_bundle_register_hook nds_git_bundle_contrib
fi
