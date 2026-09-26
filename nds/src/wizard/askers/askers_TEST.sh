#!/usr/bin/env bash
# ==================================================================================================
# NDS - Custom askers
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# ==================================================================================================

# shellcheck source=../../setup_TEST.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../setup_TEST.sh"
logger_setMinLevel warn
# shellcheck source=../../app/session/mode.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../app/session/mode.sh"
# shellcheck source=../../app/session/skip.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../app/session/skip.sh"
import_dir "$(dirname "${BASH_SOURCE[0]}")/../../recipe" --depth 0
import_dir "$(dirname "${BASH_SOURCE[0]}")/../../recipe/schema" --depth 0
# shellcheck source=../ask.sh
source "$(dirname "${BASH_SOURCE[0]}")/../ask.sh"
import_dir "$(dirname "${BASH_SOURCE[0]}")" --depth 0
import_dir "$(dirname "${BASH_SOURCE[0]}")/../git" --depth 0

_prompts=0
_probes=0
git_probe() { _probes=$((_probes + 1)); return 0; }

suite_askers() {
    local _root _joined _got
    nds_test_session
    declare -gA R=()

    bts_section "Git access"
    nds_recipe_set R FLAKE_REPO_URL https://example.com/flake.git
    nds_recipe_set R GIT_KEYS_DIR "${ nds_session_dir secrets; }/git"
    _prompts=0
    _probes=0
    prompt() { _prompts=$((_prompts + 1)); return 3; }
    nds_ask_gitAccess R GIT_KEYS_DIR 2>/dev/null || true
    if [[ "$_probes" -ge 1 && "$_prompts" -eq 0 ]]; then
        bts_pass "git access returns without prompting when every probe passes"
    else
        bts_fail "probes=${_probes} prompts=${_prompts}"
    fi
    git_probe() { _probes=$((_probes + 1)); return 1; }
    _prompts=0
    nds_ask_gitAccess R GIT_KEYS_DIR 2>/dev/null || true # git access heading
    if [[ "$_prompts" -ge 1 ]]; then
        bts_pass "git access is entered when a probe fails"
    else
        bts_fail "failed probe did not prompt"
    fi

    bts_section "Flake host"
    _root=$(mktemp -d)
    mkdir -p "$_root"
    nds_recipe_set R FLAKE_LOCAL_PATH "$_root"
    flake_listHosts() { printf '%s\n' control edge; }
    _joined=
    prompt() {
        _joined=$(printf '%s ' "${_nds_wiz_opts[@]}")
        UI_PROMPT_RESULT=control
    }
    nds_ask_flakeHost R FLAKE_HOST || { bts_fail "host asker failed"; return; }
    if [[ "$_joined" == *control* && "$_joined" == *edge* ]]; then
        bts_pass "flake host lists the stubbed hosts"
    else
        bts_fail "host options were '${_joined}'"
    fi

    bts_section "Role"
    mkdir -p "${_root}/.roles/web" "${_root}/.nds/hosts"
    printf '%s\n' 'NETWORK_HOSTNAME="restored"' > "${_root}/.nds/hosts/webhost.recipe"
    nds_schema_enable network
    nds_recipe_set R FLAKE_HOST webhost
    prompt() {
        _joined=$(printf '%s ' "${_nds_wiz_opts[@]}")
        UI_PROMPT_RESULT=restore
    }
    nds_ask_role R SCAFFOLD_ROLE || { bts_fail "role asker failed"; return; }
    _got=$(nds_recipe_get R NETWORK_HOSTNAME)
    if [[ "$_joined" == *restore* && "$_got" == restored ]]; then
        bts_pass "role offers restore when the host recipe exists"
    else
        bts_fail "options='${_joined}' hostname='${_got}'"
    fi
    rm -rf "$_root"
}
