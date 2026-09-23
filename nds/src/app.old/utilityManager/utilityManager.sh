#!/usr/bin/env bash
# ==================================================================================================
# NDS - Utility loader (source + onLoad/onExit hooks)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-31 | Modified: 2026-09-02
# Description:   Load src/utilities/<name>/main.sh; register hooks; never run work on source
#                (app/utilityManager — NDS core, not a shared lib helper)
# ==================================================================================================

declare -gA NDS_UTILITIES_LOADED=()
declare -ga NDS_UTILITY_ONLOAD=()
declare -ga NDS_UTILITY_ONEXIT=()
declare -g NDS_UTILITY_LOAD_HOOKS_RAN=false

# Description: Source a utility main.sh once and register <name>_onLoad / <name>_onExit.
# Does not run onLoad — call nds_utilities_runLoadHooks after feature sourcing.
# Arguments:
# - name: <String> Utility directory under src/utilities/ (e.g. git)
# Returns:
# - <Bool> 0 when sourced (or already loaded)
nds_requireUtility() {
    local name="${1:-}"
    local main onLoad onExit
    local script_dir="${SCRIPT_DIR:-}"

    if [[ -z "$name" ]]; then
        error "nds_requireUtility: name is empty"
        return 1
    fi
    if [[ -z "$script_dir" ]]; then
        error "nds_requireUtility: SCRIPT_DIR is unset"
        return 1
    fi
    if [[ -n "${NDS_UTILITIES_LOADED[$name]:-}" ]]; then
        return 0
    fi

    main="${script_dir}/utilities/${name}/main.sh"
    if [[ ! -f "$main" ]]; then
        error "nds_requireUtility: missing ${main}"
        return 1
    fi

    # shellcheck disable=SC1090
    source "$main" || {
        error "nds_requireUtility: failed to source ${main}"
        return 1
    }

    onLoad="${name}_onLoad"
    onExit="${name}_onExit"
    if declare -f "$onLoad" >/dev/null; then
        NDS_UTILITY_ONLOAD+=("$onLoad")
    fi
    if declare -f "$onExit" >/dev/null; then
        NDS_UTILITY_ONEXIT+=("$onExit")
    fi

    NDS_UTILITIES_LOADED["$name"]="1"
}

# Description: Run every registered utility onLoad once (after feature sourcing).
# Returns:
# - <Bool> 0 when all onLoads succeed (or already ran)
nds_utilities_runLoadHooks() {
    local fn
    [[ "${NDS_UTILITY_LOAD_HOOKS_RAN}" == "true" ]] && return 0
    for fn in "${NDS_UTILITY_ONLOAD[@]+"${NDS_UTILITY_ONLOAD[@]}"}"; do
        [[ -n "$fn" ]] || continue
        declare -f "$fn" >/dev/null || {
            error "nds_utilities_runLoadHooks: ${fn} is not a function"
            return 1
        }
        "$fn" || {
            error "nds_utilities_runLoadHooks: ${fn} failed"
            return 1
        }
    done
    NDS_UTILITY_LOAD_HOOKS_RAN=true
}

# Description: Run every registered utility onExit (best-effort; continue on failure).
# Returns:
# - <Bool> 0 always
nds_utilities_runExitHooks() {
    local fn
    for fn in "${NDS_UTILITY_ONEXIT[@]+"${NDS_UTILITY_ONEXIT[@]}"}"; do
        [[ -n "$fn" ]] || continue
        declare -f "$fn" >/dev/null || continue
        "$fn" || true
    done
    return 0
}
