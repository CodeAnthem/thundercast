#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git key registration screens
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# ==================================================================================================

# shellcheck source=../../setup_TEST.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../setup_TEST.sh"
logger_setMinLevel warn
import_dir "$(dirname "${BASH_SOURCE[0]}")/../../recipe" --depth 0
import_dir "$(dirname "${BASH_SOURCE[0]}")" --depth 0

_reg_i=0
_reg_calls=0
_reg_collision=
prompt() {
    UI_PROMPT_RESULT=${_reg_answers[_reg_i]}
    _reg_i=$((_reg_i + 1))
}
gh_deviceLogin() { return 0; }
gh_addDeployKey() {
    _reg_calls=$((_reg_calls + 1))
    _reg_collision=$5
    [[ "$_reg_calls" -eq 1 ]] && return 41
    return 0
}
git_key_create() { printf '%s\n' 'ssh-ed25519 AAAAC3 test' > "$1.pub"; }
git_key_pub() { printf '%s' 'ssh-ed25519 AAAAC3 test'; }

suite_git_register() {
    local _reg_answers dest
    declare -gA R=()
    nds_recipe_set R FLAKE_REPO_URL git@github.com:CodeAnthem/dp_cluster.git
    nds_recipe_set R GIT_KEYS_DIR /tmp
    export NDS_FLAKE_REPO_URL=git@github.com:CodeAnthem/dp_cluster.git
    dest=$(mktemp -d)/key
    _reg_answers=(deploy gh overwrite)
    _reg_i=0
    _reg_calls=0
    _nds_git_register_new R "https://github.com/CodeAnthem/other.git" "$dest" \
        || { bts_fail "register failed"; return; }
    if [[ "$_reg_calls" -eq 2 && "$_reg_collision" == overwrite ]]; then
        bts_pass "a title collision asks overwrite, alternate, or cancel"
    else
        bts_fail "calls=${_reg_calls} collision='${_reg_collision}'"
    fi
    rm -rf "$(dirname "$dest")"
}
