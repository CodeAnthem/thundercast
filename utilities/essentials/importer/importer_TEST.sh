#!/usr/bin/env bash
# ==================================================================================================
# Thundercast - Bash Essentials - Importer tests
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-24 | Modified: 2026-09-24
# ==================================================================================================
#
# Capture with ${ import_file …; } is unused: these calls return status, not a value.
# A failing import prints logger and Bash diagnostics; swallow them on the call.
#
# ==================================================================================================

# shellcheck source=../testEnvironment/testEnvironment.sh
source "$(dirname "${BASH_SOURCE[0]}")/../testEnvironment/testEnvironment.sh"

_imp_newroot() {
    _IMP_ROOT=$(mktemp -d)
}

_imp_write() {
    local rel="$1"
    local body="$2"
    local path="${_IMP_ROOT}/${rel}"
    mkdir -p "$(dirname -- "$path")"
    printf '%s\n' "$body" >"$path"
}

_imp_drop() {
    [[ -n "${_IMP_ROOT:-}" && -d "$_IMP_ROOT" ]] && rm -rf "$_IMP_ROOT"
    _IMP_ROOT=""
}

_imp_bad_init() {
    local rc=0
    bash -c '
        source "$1" || exit 2
        essentials_test_load logger || exit 2
        essentials_config[IMPORTER_INCLUDE_TESTS]=yes
        essentials_test_load importer && exit 0
        exit 1
    ' _ "$(dirname "${BASH_SOURCE[0]}")/../testEnvironment/testEnvironment.sh" 2>/dev/null || rc=$?
    printf '%s\n' "$rc"
}

suite_importer() {
    local rc seen
    essentials_test_load importer

    # --- import_file ------------------------------------------------------------------------------
    bts_section "import_file"

    _imp_newroot
    _imp_write "one.sh" '_imp_from_file() { printf yes; }'
    rc=0
    import_file "${_IMP_ROOT}/one.sh" || rc=$?
    seen=""
    if declare -f _imp_from_file >/dev/null; then
        seen=${ _imp_from_file; }
    fi
    if [[ "$rc" -eq 0 && "$seen" == yes ]]; then
        bts_pass "import_file defines a function in this shell"
    else
        bts_fail "import_file rc=${rc} got='${seen}'"
    fi
    unset -f _imp_from_file
    _imp_drop

    logger_resetCounts
    rc=0
    import_file "/no/such/importer-file.sh" 2>/dev/null || rc=$?  # Importer: file not found
    if [[ "$rc" -eq 1 ]] && logger_hasError; then
        bts_pass "missing file returns 1 and logs error"
    else
        bts_fail "missing file rc=${rc}"
    fi

    # --- Depth ------------------------------------------------------------------------------------
    bts_section "Depth"

    _imp_newroot
    _imp_write "top.sh" '_IMP_SEEN+=("top")'
    _imp_write "l1/a.sh" '_IMP_SEEN+=("l1")'
    _imp_write "l1/l2/b.sh" '_IMP_SEEN+=("l2")'
    _imp_write "l1/l2/l3/c.sh" '_IMP_SEEN+=("l3")'

    _IMP_SEEN=()
    import_dir "$_IMP_ROOT" --depth 0
    if [[ "${_IMP_SEEN[*]}" == "top" ]]; then
        bts_pass "depth 0 sources the root only"
    else
        bts_fail "depth 0 saw '${_IMP_SEEN[*]}'"
    fi

    _IMP_SEEN=()
    import_dir "$_IMP_ROOT" --depth 2
    if [[ "${_IMP_SEEN[*]}" == "top l1 l2" ]]; then
        bts_pass "depth 2 sources two levels down and skips the third"
    else
        bts_fail "depth 2 saw '${_IMP_SEEN[*]}'"
    fi

    _IMP_SEEN=()
    import_dir "$_IMP_ROOT"
    if [[ "${_IMP_SEEN[*]}" == "top l1 l2 l3" ]]; then
        bts_pass "omitted depth sources every level"
    else
        bts_fail "omitted depth saw '${_IMP_SEEN[*]}'"
    fi
    _imp_drop

    # --- Order ------------------------------------------------------------------------------------
    bts_section "Order"

    _imp_newroot
    _imp_write "b.sh" '_IMP_SEEN+=("b")'
    _imp_write "a.sh" '_IMP_SEEN+=("a")'
    _imp_write "m/z.sh" '_IMP_SEEN+=("mz")'
    _imp_write "m/a.sh" '_IMP_SEEN+=("ma")'
    _imp_write "d/a.sh" '_IMP_SEEN+=("da")'
    _IMP_SEEN=()
    import_dir "$_IMP_ROOT"
    if [[ "${_IMP_SEEN[*]}" == "a b da ma mz" ]]; then
        bts_pass "omitted depth walks the tree, files before children, basenames alphabetically"
    else
        bts_fail "order was '${_IMP_SEEN[*]}'"
    fi
    _imp_drop

    _imp_newroot
    _imp_write "a.sh" 'not_defined_yet'
    _imp_write "z.sh" '_imp_defined_later() { :; }'
    logger_resetCounts
    rc=0
    import_dir "$_IMP_ROOT" 2>/dev/null || rc=$?  # command not found; Importer: failed to source
    if [[ "$rc" -eq 1 ]] && ! declare -f _imp_defined_later >/dev/null; then
        bts_pass "a later file is not sourced to satisfy an earlier call"
    else
        bts_fail "reorder rc=${rc}"
    fi
    unset -f _imp_defined_later
    _imp_drop

    # --- Ignore -----------------------------------------------------------------------------------
    bts_section "Ignore"

    _imp_newroot
    _imp_write "keep.sh" '_IMP_SEEN+=("keep")'
    _imp_write "tests.sh" '_IMP_SEEN+=("tests.sh")'
    _imp_write "skip_TEST.sh" '_IMP_SEEN+=("skip")'
    _imp_write "tests/no.sh" '_IMP_SEEN+=("hidden")'
    _IMP_SEEN=()
    import_dir "$_IMP_ROOT" --ignore '*_TEST.sh' --ignore 'tests'
    if [[ "${_IMP_SEEN[*]}" == "keep tests.sh" ]]; then
        bts_pass "--ignore skips a matching file and does not enter a matching directory"
    else
        bts_fail "ignore saw '${_IMP_SEEN[*]}'"
    fi

    rc=0
    import_file "${_IMP_ROOT}/skip_TEST.sh" || rc=$?
    if [[ "$rc" -eq 0 && "${_IMP_SEEN[*]}" == "keep tests.sh skip" ]]; then
        bts_pass "import_file does not use the ignore list"
    else
        bts_fail "import_file ignore rc=${rc} saw '${_IMP_SEEN[*]}'"
    fi
    _imp_drop

    # --- Test files -------------------------------------------------------------------------------
    bts_section "Test files"

    _imp_newroot
    _imp_write "keep.sh" '_IMP_SEEN+=("keep")'
    _imp_write "keep_TEST.sh" '_IMP_SEEN+=("test")'
    _imp_write "nested_TEST.sh/in.sh" '_IMP_SEEN+=("in")'
    _IMP_SEEN=()
    import_dir "$_IMP_ROOT"
    if [[ "${_IMP_SEEN[*]}" == "keep in" ]]; then
        bts_pass "default skips *_TEST.sh files and still enters that directory name"
    else
        bts_fail "default tests saw '${_IMP_SEEN[*]}'"
    fi

    rc=0
    import_file "${_IMP_ROOT}/keep_TEST.sh" || rc=$?
    if [[ "$rc" -eq 0 && "${_IMP_SEEN[*]}" == "keep in test" ]]; then
        bts_pass "import_file sources a test file even when the walk skips them"
    else
        bts_fail "import_file test rc=${rc} saw '${_IMP_SEEN[*]}'"
    fi

    essentials_config[IMPORTER_INCLUDE_TESTS]=true
    _IMP_SEEN=()
    import_dir "$_IMP_ROOT"
    if [[ "${_IMP_SEEN[*]}" == "keep test in" ]]; then
        bts_pass "IMPORTER_INCLUDE_TESTS=true sources *_TEST.sh"
    else
        bts_fail "include tests saw '${_IMP_SEEN[*]}'"
    fi

    essentials_config[IMPORTER_INCLUDE_TESTS]=yes
    logger_resetCounts
    rc=0
    import_dir "$_IMP_ROOT" 2>/dev/null || rc=$?  # Importer: invalid IMPORTER_INCLUDE_TESTS
    if [[ "$rc" -eq 1 ]] && logger_hasError; then
        bts_pass "invalid IMPORTER_INCLUDE_TESTS returns 1 and logs error"
    else
        bts_fail "invalid include rc=${rc}"
    fi
    unset 'essentials_config[IMPORTER_INCLUDE_TESTS]'

    rc=${ _imp_bad_init; }
    if [[ "$rc" -eq 1 ]]; then
        bts_pass "invalid IMPORTER_INCLUDE_TESTS aborts init"
    else
        bts_fail "invalid init rc=${rc}"
    fi
    _imp_drop

    # --- Walk -------------------------------------------------------------------------------------
    bts_section "Walk"

    _imp_newroot
    _imp_write "ok.sh" '_IMP_SEEN+=("ok")'
    _imp_write "sub/b.sh" '_IMP_SEEN+=("b")'
    ln -s . "${_IMP_ROOT}/loop"
    ln -s sub "${_IMP_ROOT}/again"
    _IMP_SEEN=()
    import_dir "$_IMP_ROOT"
    if [[ "${_IMP_SEEN[*]}" == "ok b" ]]; then
        bts_pass "directory symlinks are not entered"
    else
        bts_fail "symlink walk saw '${_IMP_SEEN[*]}'"
    fi
    _imp_drop

    _imp_newroot
    _imp_write "a.sh" 'cd /'
    _imp_write "b.sh" '_IMP_SEEN+=("b")'
    _IMP_SEEN=()
    rc=0
    _imp_prev="$PWD"
    cd "${_IMP_ROOT%/*}"
    import_dir "${_IMP_ROOT##*/}" || rc=$?
    cd "$_imp_prev"
    if [[ "$rc" -eq 0 && "${_IMP_SEEN[*]}" == b ]]; then
        bts_pass "a later file still sources after an earlier file changes directory"
    else
        bts_fail "cd during source rc=${rc} saw '${_IMP_SEEN[*]}'"
    fi
    _imp_drop

    _imp_newroot
    _imp_write "only.sh" '_IMP_SEEN+=("only")'
    shopt -s failglob
    _IMP_SEEN=()
    rc=0
    import_dir "$_IMP_ROOT" || rc=$?
    if shopt -q failglob && [[ "$rc" -eq 0 && "${_IMP_SEEN[*]}" == only ]]; then
        bts_pass "failglob does not abort a directory with no children"
    else
        bts_fail "failglob rc=${rc} saw '${_IMP_SEEN[*]}'"
    fi
    shopt -u failglob
    _imp_drop

    _imp_newroot
    _imp_write "top.sh" '_IMP_SEEN+=("top")'
    _imp_write "l1/a.sh" '_IMP_SEEN+=("l1")'
    set -f
    _IMP_SEEN=()
    rc=0
    import_dir "$_IMP_ROOT" --depth 1 || rc=$?
    if [[ -o noglob && "$rc" -eq 0 && "${_IMP_SEEN[*]}" == "top l1" ]]; then
        bts_pass "noglob does not freeze the walk"
    else
        bts_fail "noglob rc=${rc} saw '${_IMP_SEEN[*]}'"
    fi
    set +f
    _imp_drop

    # --- Failures ---------------------------------------------------------------------------------
    bts_section "Failures"

    logger_resetCounts
    rc=0
    import_dir "/no/such/importer-dir" 2>/dev/null || rc=$?  # Importer: directory not found
    if [[ "$rc" -eq 1 ]] && logger_hasError; then
        bts_pass "missing directory returns 1 and logs error"
    else
        bts_fail "missing directory rc=${rc}"
    fi

    logger_resetCounts
    rc=0
    import_dir /tmp --depth recursive 2>/dev/null || rc=$?  # Importer: invalid depth
    if [[ "$rc" -eq 1 ]] && logger_hasError; then
        bts_pass "depth keyword recursive is rejected"
    else
        bts_fail "depth keyword rc=${rc}"
    fi

    logger_resetCounts
    rc=0
    import_dir /tmp --depth nope 2>/dev/null || rc=$?  # Importer: invalid depth
    if [[ "$rc" -eq 1 ]] && logger_hasError; then
        bts_pass "bad depth returns 1 and logs error"
    else
        bts_fail "bad depth rc=${rc}"
    fi

    logger_resetCounts
    rc=0
    import_dir /tmp --nope 2>/dev/null || rc=$?  # Importer: unknown argument
    if [[ "$rc" -eq 1 ]] && logger_hasError; then
        bts_pass "unknown argument returns 1 and logs error"
    else
        bts_fail "unknown argument rc=${rc}"
    fi

    _imp_newroot
    _imp_write "a_ok.sh" '_IMP_OK=1'
    _imp_write "b_bad.sh" 'if [['
    _imp_write "c_later.sh" '_IMP_LATER=1'
    _imp_write "sub/d.sh" '_IMP_DEEP=1'
    unset _IMP_OK _IMP_LATER _IMP_DEEP
    logger_resetCounts
    rc=0
    import_dir "$_IMP_ROOT" 2>/dev/null || rc=$?  # syntax error; Importer: failed to source
    if [[ "$rc" -eq 1 && "${_IMP_OK:-}" == 1 && -z "${_IMP_LATER:-}" && -z "${_IMP_DEEP:-}" ]] && logger_hasError; then
        bts_pass "a syntax error stops the walk and leaves earlier files sourced"
    else
        bts_fail "syntax stop rc=${rc} ok=${_IMP_OK:-} later=${_IMP_LATER:-} deep=${_IMP_DEEP:-}"
    fi
    unset _IMP_OK _IMP_LATER _IMP_DEEP
    _imp_drop
}
