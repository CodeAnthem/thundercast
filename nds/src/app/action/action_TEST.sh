#!/usr/bin/env bash
# ==================================================================================================
# NDS - Action store, check, and select tests
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-24 | Modified: 2026-09-27
# ==================================================================================================

# shellcheck source=../../setup_TEST.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../setup_TEST.sh"
# shellcheck source=../session/mode.sh
source "$(dirname "${BASH_SOURCE[0]}")/../session/mode.sh"
# shellcheck source=../session/skip.sh
source "$(dirname "${BASH_SOURCE[0]}")/../session/skip.sh"
import_dir "$(dirname "${BASH_SOURCE[0]}")" --depth 0

_action_has() {
    local store="$1" name="$2" found
    while IFS= read -r found; do
        [[ "$found" == "$name" ]] && return 0
    done <<< "${ _nds_action_store_names "$store"; }"
    return 1
}

_action_menu=0
_action_preview=0
_nds_action_ui_select() { _action_menu=1; return 1; }
_nds_action_ui_preview() { _action_preview=1; return 0; }

_action_dirs=()
_action_keep() { _action_dirs+=("$1"); }
_action_drop() {
    local dir
    for dir in "${_action_dirs[@]+"${_action_dirs[@]}"}"; do
        [[ -n "$dir" && -d "$dir" ]] && rm -rf "$dir"
    done
    _action_dirs=()
}
_action_write() {
    local root="$1" name="$2" description="$3"
    mkdir -p "${root}/${name}"
    printf '%s\n' "# Description: ${description}" 'action_groups() { printf "%s\n" install; }' 'action_preview() { :; }' >"${root}/${name}/setup.sh"
}

suite_action() {
    local rc=0 description first_path src second clash only_broken

    bts_section "Store"
    rc=0
    nds_action_discover nope /tmp 2>/dev/null || rc=$? # Unknown action store
    if [[ "$rc" -ne 0 ]]; then
        bts_pass "an unknown store name fails"
    else
        bts_fail "unknown store was accepted"
    fi

    second=$(mktemp -d)
    _action_keep "$second"
    _action_write "$second" kept "Kept action"
    nds_action_discover local "$second" || { bts_fail "seed discover failed"; _action_drop; return; }
    rc=0
    nds_action_discover local "${second}/missing" 2>/dev/null || rc=$? # Actions directory not found
    if [[ "$rc" -ne 0 ]] && _action_has local kept; then
        bts_pass "a missing directory fails and leaves the store"
    else
        bts_fail "missing directory rc=${rc} names='${ _nds_action_joined local; }'"
    fi

    only_broken=$(mktemp -d)
    _action_keep "$only_broken"
    mkdir -p "${only_broken}/broken"
    printf '%s\n' 'echo hi' >"${only_broken}/broken/setup.sh"
    rc=0
    nds_action_discover local "$only_broken" 2>/dev/null || rc=$? # Skipping invalid action
    if [[ "$rc" -eq 0 ]] && ! _action_has local broken && _action_has local kept; then
        bts_pass "a directory with no valid actions returns 0 and does not clear"
    else
        bts_fail "empty-valid rc=${rc} names='${ _nds_action_joined local; }'"
    fi

    _action_root=$(mktemp -d)
    _action_keep "$_action_root"
    mkdir -p "${_action_root}/broken" "${_action_root}/blank"
    printf '%s\n' 'echo hi' >"${_action_root}/broken/setup.sh"
    printf '%s\n' '# Description:' 'action_groups() { :; }' 'action_preview() { :; }' >"${_action_root}/blank/setup.sh"
    _action_write "$_action_root" ok "Fixture action"
    nds_action_discover local "$_action_root" 2>/dev/null || { bts_fail "fixture discover failed"; _action_drop; return; } # Skipping invalid action
    description="${ _nds_action_store_description local ok; }"
    if _action_has local ok && ! _action_has local broken && ! _action_has local blank && [[ "$description" == "Fixture action" ]]; then
        bts_pass "a folder with setup.sh is kept only when the script matches"
    else
        bts_fail "local store description='${description}'"
    fi

    bts_section "Discover"
    clash=$(mktemp -d)
    _action_keep "$clash"
    _action_write "$clash" extra "Extra action"
    nds_action_discover local "$clash" || { bts_fail "second discover failed"; _action_drop; return; }
    if _action_has local ok && _action_has local extra && _action_has local kept; then
        bts_pass "a second discover adds names and does not wipe the first"
    else
        bts_fail "second discover names='${ _nds_action_joined local; }'"
    fi

    first_path="${ _nds_action_store_path local ok; }"
    _action_write "$clash" ok "Other action"
    nds_action_discover local "$clash" || { bts_fail "clash discover failed"; _action_drop; return; }
    if [[ "${ _nds_action_store_path local ok; }" == "$first_path" ]]; then
        bts_pass "the same name twice keeps the first path"
    else
        bts_fail "ok path changed from '${first_path}'"
    fi

    nds_action_discover remote "$clash" || { bts_fail "remote discover failed"; _action_drop; return; }
    if _action_has local ok && _action_has local extra && _action_has remote extra; then
        bts_pass "discover into remote does not wipe local"
    else
        bts_fail "local='${ _nds_action_joined local; }' remote='${ _nds_action_joined remote; }'"
    fi
    _action_drop

    unset NDS_TEST
    src=$(mktemp -d)
    _action_keep "$src"
    _action_write "$src" test "Debug test"
    _action_write "$src" uiSmoke "Debug smoke"
    nds_action_discover local "$src" 2>/dev/null || { bts_fail "debug discover failed"; _action_drop; return; }
    if _action_has local test && _action_has local uiSmoke; then
        bts_pass "discover does not hide test or uiSmoke"
    else
        bts_fail "debug names were '${ _nds_action_joined local; }'"
    fi
    _nds_action_hide_debug
    if ! _action_has local test && ! _action_has local uiSmoke; then
        bts_pass "hide removes test and uiSmoke when NDS_TEST is unset"
    else
        bts_fail "hide left '${ _nds_action_joined local; }'"
    fi
    nds_action_discover local "$src" 2>/dev/null || { bts_fail "rediscover failed"; _action_drop; return; }
    export NDS_TEST=true
    _nds_action_hide_debug
    if _action_has local test && _action_has local uiSmoke; then
        bts_pass "hide keeps test and uiSmoke when NDS_TEST is true"
    else
        bts_fail "NDS_TEST hide names were '${ _nds_action_joined local; }'"
    fi
    unset NDS_TEST

    bts_section "Select"
    export NDS_MODE=unattended
    unset NDS_ACTION
    _action_menu=0
    _action_preview=0
    rc=0
    nds_action_select 2>/dev/null || rc=$? # Unattended mode requires NDS_ACTION
    if [[ "$rc" -ne 0 && "$_action_menu" -eq 0 && "$_action_preview" -eq 0 ]]; then
        bts_pass "unattended without NDS_ACTION fails and does not open a screen"
    else
        bts_fail "unattended select rc=${rc} menu=${_action_menu} preview=${_action_preview}"
    fi

    export NDS_MODE=interactive
    unset NDS_ACTION
    _action_menu=0
    rc=0
    nds_action_select </dev/null 2>/dev/null || rc=$? # No terminal. Set NDS_ACTION
    if [[ "$rc" -ne 0 && "$_action_menu" -eq 0 ]]; then
        bts_pass "no terminal without NDS_ACTION fails and does not open the menu"
    else
        bts_fail "no-tty select rc=${rc} menu=${_action_menu}"
    fi

    export NDS_ACTION=not_a_real_action
    rc=0
    nds_action_select 2>/dev/null || rc=$? # NDS_ACTION is not valid
    if [[ "$rc" -ne 0 ]]; then
        bts_pass "an unknown NDS_ACTION fails"
    else
        bts_fail "unknown NDS_ACTION was accepted"
    fi

    _action_write "$src" picked "Picked action"
    nds_action_discover local "$src" || { bts_fail "picked discover failed"; _action_drop; return; }
    export NDS_ACTION=picked
    export NDS_MODE=unattended
    _action_menu=0
    _action_preview=0
    nds_action_select || { bts_fail "unattended action select failed"; _action_drop; return; }
    if [[ "$NDS_CURRENT_ACTION" == picked && "$_action_menu" -eq 0 && "$_action_preview" -eq 0 ]] \
        && declare -f action_groups >/dev/null && declare -f action_preview >/dev/null; then
        bts_pass "unattended NDS_ACTION sources the setup and skips the preview"
    else
        bts_fail "unattended current='${NDS_CURRENT_ACTION}' preview=${_action_preview}"
    fi

    export NDS_MODE=interactive
    export NDS_SKIP_ACTION_PREVIEW=true
    _action_preview=0
    nds_action_select || { bts_fail "skip-preview select failed"; _action_drop; return; }
    if [[ "$_action_preview" -eq 0 && "$_action_menu" -eq 0 ]]; then
        bts_pass "NDS_SKIP_ACTION_PREVIEW accepts without the preview"
    else
        bts_fail "skip-preview menu=${_action_menu} preview=${_action_preview}"
    fi

    unset NDS_SKIP_ACTION_PREVIEW
    export NDS_MODE=interactive
    _action_menu=0
    _action_preview=0
    nds_action_select || { bts_fail "interactive select failed"; _action_drop; return; }
    if [[ "$NDS_CURRENT_ACTION" == picked && "$_action_menu" -eq 0 && "$_action_preview" -eq 1 ]]; then
        bts_pass "NDS_ACTION on a terminal still runs the preview"
    else
        bts_fail "interactive current='${NDS_CURRENT_ACTION}' menu=${_action_menu} preview=${_action_preview}"
    fi

    _nds_action_ui_preview() { return 2; }
    rc=0
    nds_action_select 2>/dev/null || rc=$? # Cannot go back — NDS_ACTION is set
    if [[ "$rc" -ne 0 ]]; then
        bts_pass "back is refused when NDS_ACTION is set"
    else
        bts_fail "back was accepted with NDS_ACTION set"
    fi
    _action_drop
}
