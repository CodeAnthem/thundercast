#!/usr/bin/env bash
# ==================================================================================================
# NDS - Unattended pipeline
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# ==================================================================================================

# shellcheck source=../../setup_TEST.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../setup_TEST.sh"
logger_setMinLevel warn
# shellcheck source=../session/mode.sh
source "$(dirname "${BASH_SOURCE[0]}")/../session/mode.sh"
# shellcheck source=../session/skip.sh
source "$(dirname "${BASH_SOURCE[0]}")/../session/skip.sh"
import_dir "$(dirname "${BASH_SOURCE[0]}")/../actionSelect" --depth 0
import_dir "$(dirname "${BASH_SOURCE[0]}")/../../recipe" --depth 0
import_dir "$(dirname "${BASH_SOURCE[0]}")/../../recipe/schema" --depth 0
# shellcheck source=pipeline.sh
source "$(dirname "${BASH_SOURCE[0]}")/pipeline.sh"
# shellcheck source=confirm.sh
source "$(dirname "${BASH_SOURCE[0]}")/confirm.sh"
# shellcheck source=finish.sh
source "$(dirname "${BASH_SOURCE[0]}")/finish.sh"

_wizard=0
nds_wizard_fill() { _wizard=1; return 0; }
_cook_path=
nds_cook() { _cook_path=$1; return 0; }
nds_bundle() { printf '%s\n' /tmp/nds-bundle.zip; }

_pipe_root=
_pipe_order=()
_pipe_cooked=0

_pipe_schema() {
    nds_schema_hasKey STUB_KEY && return 0
    nds_schema_group zzstub "Stub"
    nds_schema_field zzstub STUB_KEY string --required
    nds_schema_field zzstub STUB_PIN string
}

_pipe_done() { _pipe_order+=("done"); }

_pipe_write_action() {
    local root=$1 name=$2
    mkdir -p "${root}/${name}"
    cat > "${root}/${name}/setup.sh" <<'EOF'
# Description: stub action
action_groups() { printf '%s\n' zzstub; }
action_preview() { :; }
action_pins() { printf '%s\n' STUB_PIN=pinned; }
action_recipe() { _pipe_order+=("cook"); _pipe_cooked=1; }
eventRegister recipe.done _pipe_done
eventRegister recipe.schema _pipe_schema
EOF
}

_pipe_reset() {
    unset NDS_MODE NDS_ACTION NDS_RECIPE_FILE NDS_STUB_KEY NDS_CURRENT_ACTION NDS_YES NDS_SKIP NDS_REBOOT
    _wizard=0
    _cook_path=
    _pipe_order=()
    _pipe_cooked=0
    unset -f action_groups action_preview action_defaults action_pins action_recipe action_plan
}

suite_pipeline() {
    local sealed got rc root
    nds_test_session
    _pipe_root=$(mktemp -d)
    _pipe_write_action "$_pipe_root" stub
    export NDS_MODE=unattended
    export NDS_ACTION=stub
    export NDS_FLEET_ACTIONS_DIR=/tmp/nds-no-fleet
    nds_mode_resolve

    bts_section "Run"
    export NDS_STUB_KEY=from-env
    _pipe_reset
    export NDS_MODE=unattended NDS_ACTION=stub NDS_STUB_KEY=from-env NDS_CURRENT_ACTION=stub
    declare -gA _NDS_RECIPE=()
    eventRegister recipe.schema _pipe_schema
    action_groups() { printf '%s\n' zzstub; }
    action_preview() { :; }
    action_pins() { printf '%s\n' STUB_PIN=pinned; }
    action_recipe() { _pipe_order+=("cook"); _pipe_cooked=1; }
    eventRegister recipe.done _pipe_done
    export NDS_CURRENT_ACTION=stub
    nds_pipeline_recipe _NDS_RECIPE local stub || { bts_fail "unattended cook failed"; return; }
    if [[ "$_wizard" -eq 0 ]]; then
        bts_pass "unattended cook never calls the wizard"
    else
        bts_fail "wizard was called"
    fi
    if nds_schema_isLocked INSTALL_ACTION && [[ "$(nds_recipe_get _NDS_RECIPE INSTALL_ACTION)" == stub ]]; then
        bts_pass "INSTALL_ACTION is set and locked"
    else
        bts_fail "INSTALL_ACTION was '$(nds_recipe_get _NDS_RECIPE INSTALL_ACTION)'"
    fi
    if [[ "${_pipe_order[0]:-}" == cook && "${_pipe_order[1]:-}" == done ]]; then
        bts_pass "action_recipe runs and recipe.done runs after it"
    else
        bts_fail "order was '${_pipe_order[0]:-} ${_pipe_order[1]:-}'"
    fi
    if [[ "$(nds_recipe_get _NDS_RECIPE STUB_PIN)" == pinned ]] && nds_schema_isLocked STUB_PIN; then
        bts_pass "pins are applied and locked"
    else
        bts_fail "pin was '$(nds_recipe_get _NDS_RECIPE STUB_PIN)'"
    fi

    _cook_path=
    declare -gA _NDS_RECIPE=()
    nds_pipeline_recipe _NDS_RECIPE local stub || { bts_fail "second cook failed"; return; }
    nds_recipe_materialize _NDS_RECIPE
    sealed="${ nds_session_dir recipe; }/sealed.recipe"
    nds_recipe_seal _NDS_RECIPE "$sealed" || { bts_fail "seal failed"; return; }
    nds_cook "$sealed"
    if [[ -f "$sealed" && "$_cook_path" == "$sealed" ]]; then
        bts_pass "the sealed file is what cook receives"
    else
        bts_fail "cook path was '${_cook_path}'"
    fi

    bts_section "Failure and order"
    unset NDS_STUB_KEY
    declare -gA _NDS_RECIPE=()
    _cook_path=
    rc=0
    nds_pipeline_recipe _NDS_RECIPE local stub 2>/dev/null || rc=$?
    if [[ "$rc" -ne 0 && -z "$_cook_path" ]]; then
        bts_pass "a missing required key returns 1 before cook"
    else
        bts_fail "missing key rc=${rc} cook='${_cook_path}'"
    fi

    printf '%s\n' 'STUB_KEY=from-file' > "$(nds_session_dir recipe)/in.recipe"
    export NDS_RECIPE_FILE="$(nds_session_dir recipe)/in.recipe"
    export NDS_STUB_KEY=from-env
    export NDS_CURRENT_ACTION=stub
    declare -gA _NDS_RECIPE=()
    nds_pipeline_recipe _NDS_RECIPE local stub || { bts_fail "override cook failed"; return; }
    got=$(nds_recipe_get _NDS_RECIPE STUB_KEY)
    if [[ "$got" == from-env ]]; then
        bts_pass "environment overrides the recipe file"
    else
        bts_fail "override value was '${got}'"
    fi

    bts_section "Remote"
    unset NDS_STUB_KEY NDS_RECIPE_FILE
    export NDS_STUB_KEY=remote-env
    export NDS_CURRENT_ACTION=other
    action_groups() { printf '%s\n' zzstub; }
    action_preview() { :; }
    unset -f action_recipe action_pins
    declare -gA _NDS_RECIPE=()
    nds_pipeline_recipe _NDS_RECIPE remote remoteaction || { bts_fail "remote cook failed"; return; }
    if [[ "$(nds_recipe_get _NDS_RECIPE STUB_KEY)" == remote-env && "$(nds_recipe_get _NDS_RECIPE INSTALL_ACTION)" == remoteaction ]]; then
        bts_pass "a remote cook does not load the top-level recipe file"
    else
        bts_fail "remote cook key='$(nds_recipe_get _NDS_RECIPE STUB_KEY)'"
    fi

    nds_test_loadUtilities || { bts_fail "utilities failed to load"; return; }
    nds_test_assertResolved

    rm -rf "$_pipe_root"
    nds_test_session_drop
}
