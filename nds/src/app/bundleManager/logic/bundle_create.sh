#!/usr/bin/env bash
# ==================================================================================================
# NDS - Bundle archive creation (core feature)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-30 | Modified: 2026-08-14
# Description:   Gather registered contribs + hooks, write zip/tar backup
# ==================================================================================================

# Description: Materialize registered contribs into a staging directory.
# Arguments:
# - staging: <String> Absolute staging root
nds_bundle_apply_contribs() {
    local staging="${1:?staging}"
    local entry dest src i

    mkdir -p "${staging}/config" "${staging}/secrets" "${staging}/logs"

    for entry in "${NDS_BUNDLE_DIRS[@]+"${NDS_BUNDLE_DIRS[@]}"}"; do
        [[ -n "$entry" ]] || continue
        dest="${entry%%|*}"
        src="${entry#*|}"
        [[ -d "$src" ]] || continue
        mkdir -p "${staging}/${dest}"
        cp -a "${src}/." "${staging}/${dest}/" 2>/dev/null || true
    done

    for entry in "${NDS_BUNDLE_FILES[@]+"${NDS_BUNDLE_FILES[@]}"}"; do
        [[ -n "$entry" ]] || continue
        dest="${entry%%|*}"
        src="${entry#*|}"
        [[ -f "$src" ]] || continue
        mkdir -p "${staging}/$(dirname "$dest")"
        cp "$src" "${staging}/${dest}"
    done

    if ((${#NDS_BUNDLE_TEXT_DESTS[@]})); then
        for i in "${!NDS_BUNDLE_TEXT_DESTS[@]}"; do
            dest="${NDS_BUNDLE_TEXT_DESTS[$i]}"
            [[ -n "$dest" ]] || continue
            mkdir -p "${staging}/$(dirname "$dest")"
            printf '%s' "${NDS_BUNDLE_TEXT_BODIES[$i]}" > "${staging}/${dest}"
        done
    fi
}

# Description: Create the install backup bundle from registry + hooks.
# Sets NDS_INSTALL_BUNDLE / NDS_SECRETS_BUNDLE. Idempotent when already set.
nds_bundle_create() {
    local staging bundle_path user
    local dest_dir

    if [[ -n "${NDS_INSTALL_BUNDLE:-}" && -f "$NDS_INSTALL_BUNDLE" ]]; then
        return 0
    fi

    user=${ nds_lib_getSshUser; }
    bundle_path=${ nds_bundle_path; }
    staging=$(mktemp -d "${TMPDIR:-/tmp}/nds-bundle-staging.XXXXXX") || return 1

    nds_bundle_reset_contribs
    nds_bundle_run_hooks
    nds_bundle_apply_contribs "$staging" || {
        rm -rf "$staging"
        return 1
    }

    if declare -f _nds_bundle_quickstart &>/dev/null; then
        _nds_bundle_quickstart "${staging}/QUICK_START.md"
    fi

    dest_dir="/home/${user}"
    mkdir -p "$dest_dir"
    if command -v zip &>/dev/null; then
        (cd "$staging" && zip -r -q "$bundle_path" .) || {
            rm -rf "$staging"
            error "Failed to create install backup: $bundle_path"
            return 1
        }
    else
        bundle_path="${bundle_path%.zip}.tar.gz"
        tar czf "$bundle_path" -C "$staging" . || {
            rm -rf "$staging"
            error "Failed to create install backup: $bundle_path"
            return 1
        }
    fi
    rm -rf "$staging"

    chown "$user" "$bundle_path" 2>/dev/null || true
    chmod 600 "$bundle_path"

    export NDS_INSTALL_BUNDLE="$bundle_path"
    export NDS_SECRETS_BUNDLE="$bundle_path"
    nds_install_log "install backup bundle: $bundle_path"
    return 0
}
