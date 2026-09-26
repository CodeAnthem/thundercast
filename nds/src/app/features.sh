#!/usr/bin/env bash
# ==================================================================================================
# NDS - Feature load
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-24 | Modified: 2026-09-26
# Description:   Session, actions, recipe, realize, then wizard when that tree exists.
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

_nds_load_features() {
    local app_dir=$1
    local src_dir="${app_dir%/*}"
    local wizard="${src_dir}/wizard"

    # shellcheck source=../lib/lib_bool.sh
    source "${src_dir}/lib/lib_bool.sh" || return 1
    # shellcheck source=../lib/lib_rand.sh
    source "${src_dir}/lib/lib_rand.sh" || return 1

    import_dir "${app_dir}/session" --depth 0 || return 1
    import_dir "${app_dir}/utility" --depth 0 || return 1
    import_dir "${app_dir}/action" --depth 0 || return 1
    # shellcheck source=confirm.sh
    source "${app_dir}/confirm.sh" || return 1
    # shellcheck source=finish.sh
    source "${app_dir}/finish.sh" || return 1
    # shellcheck source=pipeline.sh
    source "${app_dir}/pipeline.sh" || return 1
    import_dir "${src_dir}/recipe" --depth 0 || return 1
    import_dir "${src_dir}/recipe/schema" --depth 0 || return 1
    import_dir "${src_dir}/realize" --depth 0 || return 1
    if [[ -d "$wizard" ]]; then
        import_dir "$wizard" --depth 0 || return 1
        [[ -d "${wizard}/askers" ]] && import_dir "${wizard}/askers" --depth 0
        [[ -d "${wizard}/git" ]] && import_dir "${wizard}/git" --depth 0
    fi
}
