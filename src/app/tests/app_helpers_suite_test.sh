#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git slug + install helper smoke (no TTY)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-28 | Modified: 2026-08-27
# ==================================================================================================

suite_standalone() {
    local out parsed host owner repo

    out=$(nds_git_owner_slug "https://github.com/CodeAnthem/dp_cluster.git")
    if [[ "$out" == "codeanthem" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ nds_git_owner_slug: extracts owner slug"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ nds_git_owner_slug: expected codeanthem got $out"
    fi

    out=$(nds_git_repo_slug "CodeAnthem" "dp_cluster")
    if [[ "$out" == "codeanthem-dp-cluster" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ nds_git_repo_slug: normalizes owner and repo"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ nds_git_repo_slug: expected codeanthem-dp-cluster got $out"
    fi

    out=$(nds_git_deploy_key_basename "CodeAnthem" "thundercast")
    if [[ "$out" == "nds_deploy_codeanthem_thundercast" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ nds_git_deploy_key_basename"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ nds_git_deploy_key_basename: got $out"
    fi

    out=$(nds_git_owner_repo_from_deploy_basename "nds_deploy_codeanthem_thundercast")
    if [[ "$out" == "codeanthem/thundercast" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ nds_git_owner_repo_from_deploy_basename"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ nds_git_owner_repo_from_deploy_basename: got $out"
    fi

    out=$(nds_git_session_key_title_for "codeanthem" "control-toolkit")
    if [[ "$out" == "nds-codeanthem-control-toolkit" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ nds_git_session_key_title_for"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ nds_git_session_key_title_for: got $out"
    fi

    out=$(nds_install_disk_part "/dev/nvme0n1" 2)
    if [[ "$out" == "/dev/nvme0n1p2" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ nds_install_disk_part: nvme suffix"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ nds_install_disk_part: nvme got $out"
    fi

    out=$(nds_install_disk_part "/dev/sda" 2)
    if [[ "$out" == "/dev/sda2" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ nds_install_disk_part: sd suffix"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ nds_install_disk_part: sd got $out"
    fi

    out=$(nds_install_urandom_chars 16)
    if [[ ${#out} -eq 16 && "$out" =~ ^[A-Za-z0-9]+$ ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ nds_install_urandom_chars"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ nds_install_urandom_chars: bad output"
    fi

    local session_log runtime_keep="" log_keep=""
    session_log=$(mktemp)
    printf 'junk from a previous ISO run\n' >"$session_log"
    runtime_keep="${RUNTIME_DIR:-}"
    log_keep="${NDS_INSTALL_LOG:-}"
    NDS_INSTALL_LOG="$session_log"
    if nds_runtime_init \
        && [[ -f "$session_log" ]] && [[ ! -s "$session_log" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ nds_runtime_init: truncates leftover session log"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ nds_runtime_init: leftover session log not truncated"
    fi
    nds_runtime_purge >/dev/null 2>&1 || true
    if [[ -n "$runtime_keep" ]]; then
        RUNTIME_DIR="$runtime_keep"
        export RUNTIME_DIR
    else
        unset RUNTIME_DIR
    fi
    if [[ -n "$log_keep" ]]; then
        export NDS_INSTALL_LOG="$log_keep"
    else
        export NDS_INSTALL_LOG="/tmp/nds_session.log"
    fi
    rm -f "$session_log"

    tmpdir=$(mktemp -d)
    if nds_install_write_admin_password true 12 "" "$tmpdir/secrets"; then
        if [[ -s "$tmpdir/secrets/admin_password.txt" ]]; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ nds_install_write_admin_password"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ nds_install_write_admin_password: empty file"
        fi
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ nds_install_write_admin_password: failed"
    fi
    rm -rf "$tmpdir"

    if declare -f nds_ui_input_guard_enable >/dev/null \
        && declare -f nds_ui_tty_read >/dev/null; then
        nds_ui_input_guard_disable
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ nds_ui_input_guard: disable is a no-op without enable"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ nds_ui_input_guard: missing input.sh functions"
    fi

    if declare -f nds_ui_read_menu_digit >/dev/null; then
        local _saved_tty _got="" _args="" _prompt
        _saved_tty="$(declare -f nds_ui_tty_read)"
        nds_ui_tty_read() {
            _args="$*"
            local _v="${!#}"
            printf -v "$_v" '%s' "1"
            return 0
        }
        _prompt="$(nds_ui_numbered_prompt 1 3 1 "Make your selection" true)"
        if nds_ui_read_menu_digit _got "$_prompt" 1 3 true \
            && [[ "$_got" == "1" ]] \
            && [[ "$_args" == *n1* || "$_args" == *"-n "* ]] \
            && [[ "$_prompt" != *[Ee]nter* ]]; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ read_menu_digit: single key, no Enter, prompt has no Enter"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ read_menu_digit: expected single-key 1 (got='${_got}' args='${_args}')"
        fi
        eval "$_saved_tty"
        unset _saved_tty _got _args _prompt
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ read_menu_digit: function missing"
    fi

    local _step_keep="${NDS_UI_STEP_NAME:-}" _ok_out _warn_out
    NDS_UI_STEP_NAME="Verifying git input access"
    _ok_out=$(success "Access granted: 3 repositories" 2>&1)
    _warn_out=$(warn "probe hiccup" 2>&1)
    if [[ "$_ok_out" != *"Access granted"* ]] && [[ "$_warn_out" == *"probe hiccup"* ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ logger: success stays off an open step line; warn still prints"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ logger: success glued to step or warn swallowed (ok='${_ok_out}' warn='${_warn_out}')"
    fi
    if [[ -n "$_step_keep" ]]; then
        NDS_UI_STEP_NAME="$_step_keep"
    else
        NDS_UI_STEP_NAME=""
    fi
    unset _step_keep _ok_out _warn_out

    if declare -f _nds_ui_read_wants_cbreak >/dev/null \
        && _nds_ui_read_wants_cbreak -rsp "x" -n 1 confirm \
        && _nds_ui_read_wants_cbreak -rsn1 -p "x" var \
        && ! _nds_ui_read_wants_cbreak -rsp "x" value \
        && grep -q 'stty -icanon min 1' "${SCRIPT_DIR}/ui/input.sh"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ tty_read: single-key -n uses cbreak (no Enter)"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ tty_read: -n still waits for Enter (icanon restore)"
    fi
}
