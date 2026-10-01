#!/usr/bin/env bash
# ==================================================================================================
# NDS - remoteAction unattended cook
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# ==================================================================================================

# shellcheck source=../../../setup_TEST.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../../setup_TEST.sh"
logger_setMinLevel warn
# shellcheck source=../../../app/session/mode.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../../app/session/mode.sh"
# shellcheck source=../../../app/session/skip.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../../app/session/skip.sh"
import_dir "$(dirname "${BASH_SOURCE[0]}")/../../../app/actionSelect" --depth 0
import_dir "$(dirname "${BASH_SOURCE[0]}")/../../../recipe" --depth 0
import_dir "$(dirname "${BASH_SOURCE[0]}")/../../../recipe/schema" --depth 0
# shellcheck source=../../../app/pipeline/pipeline.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../../app/pipeline/pipeline.sh"
# shellcheck source=../setup.sh
source "$(dirname "${BASH_SOURCE[0]}")/../setup.sh"

_cat_fix=
_warns=()
warn() { _warns+=("$*"); }

git_clone() {
    mkdir -p "$3"
    cp -a "${_cat_fix}/." "$3/"
}

_cat_write() {
    _cat_fix=$(mktemp -d)
    mkdir -p "${_cat_fix}/.nds/actions/good" "${_cat_fix}/.nds/actions/bad"
    cat > "${_cat_fix}/.nds/actions/good/setup.sh" <<'EOF'
# Description: catalog action
_cat_pre() { :; }
_cat_schema() {
    [[ -n ${_NDS_SCHEMA_GROUP_TITLE[zzcat]:-} ]] && return 0
    nds_schema_group zzcat "Catalog note"
    nds_schema_field zzcat CAT_NOTE string
}
eventRegister cook.pre_install _cat_pre
eventRegister recipe.schema _cat_schema
action_groups() { printf '%s\n' zzcat; }
action_preview() { :; }
EOF
    printf '%s\n' '# Description: broken' > "${_cat_fix}/.nds/actions/bad/setup.sh"
}

suite_remoteAction() {
    local sealed text before after joined
    nds_test_session
    _cat_write
    export NDS_MODE=unattended
    nds_mode_resolve
    export NDS_CURRENT_ACTION=remoteAction
    export NDS_CATALOG_URL=https://example.com/catalog.git
    export NDS_CATALOG_ACTION=good
    before=${ eventHookCount cook.pre_install; }
    if [[ "$before" == 0 && -z ${_NDS_SCHEMA_GROUP_TITLE[zzcat]:-} ]]; then
        bts_pass "hook and group are absent before the pick"
    else
        bts_fail "before the pick hook=${before} group='${_NDS_SCHEMA_GROUP_TITLE[zzcat]:-}'"
    fi
    declare -gA _NDS_RECIPE=()
    nds_pipeline_recipe _NDS_RECIPE local remoteAction || { bts_fail "unattended cook failed"; return; }
    after=${ eventHookCount cook.pre_install; }
    if [[ "$after" == 1 && -n ${_NDS_SCHEMA_GROUP_TITLE[zzcat]:-} ]]; then
        bts_pass "hook and group exist after the pick"
    else
        bts_fail "after the pick hook=${after} group='${_NDS_SCHEMA_GROUP_TITLE[zzcat]:-}'"
    fi
    if _nds_action_store_has remote bad; then
        bts_fail "invalid catalog action stayed in the store"
    else
        bts_pass "invalid catalog action was removed"
    fi
    joined=$(printf '%s\n' "${_warns[@]}")
    assert_contains "$joined" "Skipping invalid action: bad" "invalid catalog action warns"
    sealed="${ nds_session_dir recipe; }/sealed.recipe"
    nds_recipe_seal _NDS_RECIPE "$sealed" || { bts_fail "seal failed"; return; }
    text=$(<"$sealed")
    if [[ "$text" == *INSTALL_KIND* ]]; then
        bts_fail "sealed file still has INSTALL_KIND"
    else
        bts_pass "sealed file has no install kind"
    fi
    assert_contains "$text" 'INSTALL_ACTION="remoteAction"' "sealed file keeps remoteAction"
    assert_contains "$text" 'CATALOG_ACTION="good"' "sealed file keeps the catalog action"
    rm -rf "$_cat_fix"
}
