#!/usr/bin/env bash
# ==================================================================================================
# NDS - Repository closure
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-30 | Modified: 2026-09-30
# ==================================================================================================

# shellcheck source=../../setup_TEST.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../setup_TEST.sh"
logger_setMinLevel warn
# shellcheck source=../../app/session/mode.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../app/session/mode.sh"
import_dir "$(dirname "${BASH_SOURCE[0]}")/../../recipe" --depth 0
# shellcheck source=closure.sh
source "$(dirname "${BASH_SOURCE[0]}")/closure.sh"

_cl_cloned=()
action_access() { printf '%s\n' 'read FLAKE_LOCATION'; }
git_url_isRemote() { return 0; }
git_url_safe() { printf '%s\n' "${1//[^A-Za-z0-9]/_}"; }
git_probe() { return 0; }
git_clone() {
    local _cl_url=$2 _cl_dest=$3
    mkdir -p "$_cl_dest"
    case "$_cl_url" in
        https://example.com/root.git) printf '%s\n' b > "$_cl_dest/flake.lock" ;;
        https://example.com/b.git) printf '%s\n' c > "$_cl_dest/flake.lock" ;;
    esac
    _cl_cloned+=("$_cl_url")
}
flake_listLockGitEntries() {
    local _cl_mark
    [[ -f "$1" ]] || return 0
    _cl_mark=$(<"$1")
    case "$_cl_mark" in
        b) printf '%s\n' $'https://example.com/b.git\t1' ;;
        c) printf '%s\n' $'https://example.com/c.git\t1' ;;
    esac
}

suite_closure() {
    local -A R=()
    nds_test_session
    export NDS_MODE=unattended
    nds_mode_resolve
    nds_recipe_set R FLAKE_LOCATION https://example.com/root.git
    if nds_access_run R \
        && [[ "${_cl_cloned[*]}" == 'https://example.com/root.git https://example.com/b.git https://example.com/c.git' ]]; then
        bts_pass "read access clones the root and each nested input"
    else
        bts_fail "cloned '${_cl_cloned[*]}'"
    fi

    git_probe() { return 1; }
    nds_recipe_set R FLAKE_LOCATION https://example.com/missing.git
    if nds_access_run R >/dev/null 2>&1; then
        bts_fail "unattended missing key returned success"
    else
        bts_pass "unattended missing key stops and names the url"
    fi

    local _cl_keys _cl_b _cl_c
    _cl_cloned=()
    _cl_keys="${ nds_session_dir secrets; }/git"
    mkdir -p "$_cl_keys"
    _cl_b=${ git_url_safe "https://example.com/b.git"; }
    _cl_c=${ git_url_safe "https://example.com/c.git"; }
    printf '%s\n' key > "${_cl_keys}/${_cl_b}"
    printf '%s\n' key > "${_cl_keys}/${_cl_c}"
    git_probe() {
        local _cl_safe
        [[ "$2" == *root.git ]] && return 0
        _cl_safe=${ git_url_safe "$2"; }
        [[ -f "$1/${_cl_safe}" ]]
    }
    nds_recipe_set R FLAKE_LOCATION https://example.com/root.git
    nds_recipe_set R GIT_KEYS_DIR "$_cl_keys"
    if nds_access_run R \
        && [[ "${_cl_cloned[*]}" == *'https://example.com/c.git'* ]]; then
        bts_pass "a key stored before the walk unlocks a nested repo"
    else
        bts_fail "prestored cloned '${_cl_cloned[*]}'"
    fi

    action_access() { printf '%s\n' 'write FLAKE_LOCATION'; }
    git_probe() { return 0; }
    git_clone() { mkdir -p "$3/.git"; _cl_cloned+=("$2"); }
    git() {
        [[ "$*" == *remote\ get-url\ origin* ]] && return 0
        [[ "$*" == *push* ]] && return 1
        return 0
    }
    nds_recipe_set R FLAKE_LOCATION https://example.com/root.git
    if nds_access_run R >/dev/null 2>&1; then
        bts_fail "denied push returned success"
    else
        bts_pass "a denied push stops a write action"
    fi
}
