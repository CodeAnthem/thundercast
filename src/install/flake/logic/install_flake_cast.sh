#!/usr/bin/env bash
# ==================================================================================================
# NDS - Remote action catalog (remoteAction)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-18 | Modified: 2026-08-27
# Description:   Clone a catalog repo, list .nds/actions, load the selected script
# ==================================================================================================

NDS_CAST_DEFAULT_URL="https://github.com/CodeAnthem/thundercast.git"

# Description: Session directory for the action-catalog clone.
# Returns:
# - <String> Absolute path (stdout)
_nds_cast_probe_dir() {
    printf '%s/cast-actions\n' "${NDS_RUNTIME_DIR:-/tmp/nds}"
}

# Description: True when the catalog URL should be cloned over HTTP(S), not SSH.
# Arguments:
# - repo_url: <String> Git URL
_nds_cast_url_is_http() {
    local url="$1"
    [[ "$url" == https://* || "$url" == http://* ]]
}

# Description: Isolated git HTTPS clone with no credential helper and no TTY prompt.
# Does not send a fake username — GitHub treats that as failed auth.
# Arguments:
# - repo_url: <String> http(s) git URL
# - dest:     <String> Destination directory (must not exist)
# Returns:
# - <Int> git's exit code
_nds_cast_git_http_clone() {
    local repo_url="$1" dest="$2"
    GIT_CONFIG_NOSYSTEM=1 \
        GIT_CONFIG_GLOBAL=/dev/null \
        GIT_CONFIG_SYSTEM=/dev/null \
        GIT_TERMINAL_PROMPT=0 \
        git -c credential.helper= \
        clone --depth 1 "$repo_url" "$dest"
}

# Description: True when an HTTPS catalog is anonymously cloneable (public).
# Private GitHub repos 401 and git prints "could not read Username".
# Arguments:
# - repo_url: <String> http(s) git URL
_nds_cast_https_anonymous_ok() {
    local repo_url="$1"
    GIT_CONFIG_NOSYSTEM=1 \
        GIT_CONFIG_GLOBAL=/dev/null \
        GIT_CONFIG_SYSTEM=/dev/null \
        GIT_TERMINAL_PROMPT=0 \
        git -c credential.helper= \
        ls-remote --symref "$repo_url" HEAD >/dev/null 2>&1
}

# Description: Git SSH wizard for a catalog URL without overwriting FLAKE_REPO_URL
# (that key is the install flake, not the catalog).
# Arguments:
# - repo_url: <String> Catalog git URL
nds_cast_ensure_access() {
    local repo_url="$1"
    local saved_flake saved_loc saved_local saved_src mode
    local saved_env_flake saved_env_src saved_aa rc=0
    local saved_strategy saved_existing saved_ksource saved_route
    local -A cfg=()

    saved_flake="$(nds_cfg_get FLAKE_REPO_URL 2>/dev/null || true)"
    saved_loc="$(nds_cfg_get FLAKE_LOCATION 2>/dev/null || true)"
    saved_local="$(nds_cfg_get FLAKE_LOCAL_PATH 2>/dev/null || true)"
    saved_src="$(nds_cfg_get FLAKE_SOURCE 2>/dev/null || true)"
    saved_strategy="$(nds_cfg_get GIT_ACCESS_STRATEGY 2>/dev/null || true)"
    saved_existing="$(nds_cfg_get GIT_EXISTING_KEY 2>/dev/null || true)"
    saved_ksource="$(nds_cfg_get GIT_KEY_SOURCE 2>/dev/null || true)"
    saved_route="$(nds_cfg_get GIT_AUTH_ROUTE 2>/dev/null || true)"
    saved_env_flake="${NDS_FLAKE_REPO_URL:-}"
    saved_env_src="${NDS_FLAKE_SOURCE:-}"
    saved_aa="${NDS_CFG_AA_NAME:-}"

    nds_mode_resolve || true
    mode="${NDS_MODE:-interactive}"
    nds_cfg_aa_from_store cfg
    cfg[FLAKE_REPO_URL]="$repo_url"
    nds_git_access_run "$mode" cfg read "Clone a private action catalog." || rc=$?
    nds_cfg_aa_to_store cfg
    NDS_CFG_AA_NAME="$saved_aa"
    nds_cfg_set FLAKE_REPO_URL "$saved_flake"
    nds_cfg_set FLAKE_LOCATION "$saved_loc"
    nds_cfg_set FLAKE_LOCAL_PATH "$saved_local"
    nds_cfg_set FLAKE_SOURCE "$saved_src"
    nds_cfg_set GIT_ACCESS_STRATEGY "$saved_strategy"
    nds_cfg_set GIT_EXISTING_KEY "$saved_existing"
    nds_cfg_set GIT_KEY_SOURCE "$saved_ksource"
    nds_cfg_set GIT_AUTH_ROUTE "$saved_route"
    if [[ -n "$saved_env_flake" ]]; then
        export NDS_FLAKE_REPO_URL="$saved_env_flake"
    else
        unset NDS_FLAKE_REPO_URL
    fi
    if [[ -n "$saved_env_src" ]]; then
        export NDS_FLAKE_SOURCE="$saved_env_src"
    else
        unset NDS_FLAKE_SOURCE
    fi
    return "$rc"
}

# Description: Shallow-clone a catalog repo for the action list (not the install flake).
# Public HTTPS stays on HTTP (GitHub SSH is never anonymous). Private catalogs use
# nds_git_clone after nds_cast_ensure_access (SSH identity / wizard).
# Arguments:
# - repo_url: <String> Git URL of a repo that has .nds/actions or .nds/action.sh
# Returns:
# - <String> Checkout path (stdout)
nds_cast_clone() {
    local repo_url="$1"
    local dest err rc=0

    dest="$(_nds_cast_probe_dir)"
    mkdir -p "$(dirname "$dest")"
    rm -rf "$dest"
    if _nds_cast_url_is_http "$repo_url" && _nds_cast_https_anonymous_ok "$repo_url"; then
        err=$(_nds_cast_git_http_clone "$repo_url" "$dest" 2>&1) || rc=$?
    else
        err=$(nds_git_clone "$repo_url" "$dest" 1 2>&1) || rc=$?
    fi
    if [[ "$rc" -ne 0 ]]; then
        error "Could not clone action catalog (${repo_url})"
        [[ -n "$err" ]] && error "$err"
        debug "cast clone failed: ${err}"
        rm -rf "$dest"
        return 1
    fi
    if [[ ! -d "${dest}/.nds/actions" && ! -f "${dest}/.nds/action.sh" ]]; then
        error "Catalog checkout has no .nds/actions or .nds/action.sh"
        rm -rf "$dest"
        return 1
    fi
    export NDS_CAST_PROBE_DIR="$dest"
    nds_install_log "cast: cloned action catalog (${repo_url})"
    printf '%s\n' "$dest"
}

# Description: Pipe-joined user action ids from .nds/actions/*.sh.
# Skips addRole and toolkit — those are built-in NDS actions, not catalog scripts.
# Arguments:
# - cast_root: <String> Catalog checkout
# Returns:
# - <String> Pipe-joined ids (stdout)
nds_cast_list_actions() {
    local cast_root="$1"
    local dir="${cast_root}/.nds/actions"
    local name names=""

    if [[ -d "$dir" ]]; then
        while IFS= read -r name; do
            [[ "$name" == *.sh ]] || continue
            name="${name%.sh}"
            [[ "$name" == "manifest" ]] && continue
            case "$name" in
                addRole|toolkit) continue ;;
            esac
            names="${names:+$names|}${name}"
        done < <(find "$dir" -maxdepth 1 -type f -name '*.sh' -printf '%f\n' 2>/dev/null | sort)
    fi
    printf '%s\n' "$names"
}

# Description: Fail when the catalog has no user actions.
# addRole and toolkit are built-in (NDS_ACTION=addRole / NDS_ACTION=toolkit).
# Arguments:
# - cast_root: <String> Catalog checkout
# Returns:
# - <String> Pipe-joined ids (stdout) when the catalog has at least one user action
nds_cast_require_user_actions() {
    local cast_root="$1"
    local actions
    actions="$(nds_cast_list_actions "$cast_root")"
    if [[ -z "$actions" ]]; then
        error "Catalog has no user actions — addRole and toolkit are built-in NDS actions (NDS_ACTION=addRole or NDS_ACTION=toolkit)"
        return 1
    fi
    printf '%s\n' "$actions"
    return 0
}

# Description: Labels for menus from .nds/actions/manifest (id|description).
# Arguments:
# - cast_root: <String> Catalog checkout
# - actions:   <String> Pipe-joined ids
# Returns:
# - <String> id=description pairs separated by | (stdout)
nds_cast_action_labels() {
    local cast_root="$1"
    local actions="$2"
    local manifest="${cast_root}/.nds/actions/manifest"
    local id desc line labels="" pair
    local -A desc_map=()

    if [[ -f "$manifest" ]]; then
        while IFS= read -r line || [[ -n "$line" ]]; do
            [[ -z "$line" || "$line" == \#* ]] && continue
            id="${line%%|*}"
            desc="${line#*|}"
            desc_map["$id"]="$desc"
        done < "$manifest"
    fi

    IFS='|' read -ra pair <<< "$actions"
    for id in "${pair[@]}"; do
        desc="${desc_map[$id]:-}"
        [[ -n "$desc" ]] || desc="$id"
        labels="${labels:+$labels|}${id}=${desc}"
    done
    printf '%s\n' "$labels"
}

# Description: Path to the selected cast action script.
# Arguments:
# - cast_root: <String> Catalog checkout
# - action_id: <String> Action id (script basename without .sh)
# Returns:
# - <String> Script path (stdout)
nds_cast_action_script() {
    local cast_root="$1"
    local action_id="$2"
    local candidate="${cast_root}/.nds/actions/${action_id}.sh"

    case "$action_id" in
        addRole|toolkit) return 1 ;;
    esac

    if [[ -n "$action_id" && -f "$candidate" ]]; then
        printf '%s\n' "$candidate"
        return 0
    fi
    if [[ -f "${cast_root}/.nds/action.sh" ]]; then
        printf '%s\n' "${cast_root}/.nds/action.sh"
        return 0
    fi
    return 1
}

# Description: Set CAST_ACTION from env/unattended (no TTY). Interactive uses
# nds_cast_ui_pick_action. Requires NDS_CAST_ACTION when unattended.
# Arguments:
# - cast_root: <String> Catalog checkout
nds_cast_select_action() {
    local cast_root="$1"
    local actions current
    actions="$(nds_cast_require_user_actions "$cast_root")" || return 1
    current="$(nds_cfg_get CAST_ACTION 2>/dev/null || true)"
    [[ -n "$current" ]] || current="${NDS_CAST_ACTION:-}"

    if [[ -n "$current" ]]; then
        nds_cfg_set CAST_ACTION "$current"
        case "|${actions}|" in
            *"|${current}|"*) return 0 ;;
        esac
        error "Unknown CAST_ACTION=${current} (have: ${actions//|/, })"
        return 1
    fi

    error "Unattended remoteAction needs NDS_CAST_ACTION (user catalog action id)"
    return 1
}

# Description: Ask catalog URL, warn once, clone, pick an action, source it.
# Sets NDS_CURRENT_ACTION to the catalog action id.
# Returns:
# - 0 on success; NDS_ACTION_BACK when the user backs out; non-zero on clone/load fail
nds_cast_gate() {
    local cast_url cast_root remote_script action_id

    nds_cast_ui_ask_catalog || return "$NDS_ACTION_BACK"
    cast_url="$(nds_cfg_get CAST_REPO_URL)"
    [[ -n "$cast_url" ]] || cast_url="${NDS_CAST_DEFAULT_URL}"
    nds_cfg_set CAST_REPO_URL "$cast_url"

    nds_cast_ui_confirm_fetch "$cast_url" || return $?

    if _nds_cast_url_is_http "$cast_url"; then
        if ! _nds_cast_https_anonymous_ok "$cast_url"; then
            info "This repository is not a public HTTPS repo — git SSH access required"
            nds_cast_ensure_access "$cast_url" || return 14
        fi
    else
        nds_cast_ensure_access "$cast_url" || return 14
    fi

    nds_step_start_spin "Cloning remote actions"
    if ! cast_root=$(nds_cast_clone "$cast_url"); then
        nds_step_fail "Cloning remote actions"
        return 14
    fi
    nds_step_complete "Remote actions cloned"
    export NDS_CAST_PROBE_DIR="$cast_root"

    if ! nds_cast_require_user_actions "$cast_root" >/dev/null; then
        return 14
    fi

    if nds_mode_is_unattended; then
        nds_cast_select_action "$cast_root" || return 14
    else
        nds_cast_ui_pick_action "$cast_root" || {
            local rc=$?
            [[ "$rc" -eq 1 ]] && return "$NDS_ACTION_BACK"
            return "$rc"
        }
    fi

    action_id="$(nds_cfg_get CAST_ACTION)"
    remote_script=$(nds_cast_action_script "$cast_root" "$action_id") || {
        error "No remote action script for CAST_ACTION=${action_id}"
        return 14
    }

    info "Loading remote action: ${action_id}"
    nds_import_file "$remote_script" || return 14
    NDS_CURRENT_ACTION="$action_id"
    export NDS_CURRENT_ACTION
    nds_install_log "cast: loaded ${remote_script}"
    return 0
}
