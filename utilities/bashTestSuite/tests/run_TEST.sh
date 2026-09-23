#!/usr/bin/env bash
# ==================================================================================================
# ThunderCast - bashTestSuite - CLI self-tests
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-18 | Modified: 2026-09-20
# ==================================================================================================

_BTS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
_BTS_RUN="${_BTS_ROOT}/main.sh"

_bts_capture() {
    local log="$1"
    shift
    local out err
    out="$(mktemp)"
    err="$(mktemp)"
    _BTS_RC=0
    "$_BTS_RUN" --log "$log" "$@" >"$out" 2>"$err" || _BTS_RC=$?
    _BTS_OUT="$(cat "$out")"
    _BTS_ERR="$(cat "$err")"
    rm -f "$out" "$err"
}

_bts_write() {
    mkdir -p "$(dirname "$1")"
    cat >"$1"
}

_bts_expect_rc() {
    local name="$1" want="$2"
    if [[ "$_BTS_RC" -eq "$want" ]]; then
        bts_pass "$name"
    else
        bts_fail "$name rc=$_BTS_RC want=$want out=$(printf '%q' "$_BTS_OUT") err=$(printf '%q' "$_BTS_ERR")"
    fi
}

_bts_expect_empty() {
    local name="$1" value="$2"
    if [[ -z "$value" ]]; then
        bts_pass "$name"
    else
        bts_fail "$name was $(printf '%q' "$value")"
    fi
}

suite_run_cli() {
    local tmp log
    tmp="$(mktemp -d)"
    log="${tmp}/fail.log"

    _bts_capture "$log"
    _bts_expect_rc "no args exits 2" 2
    if [[ "$_BTS_ERR" == *"Usage:"* ]]; then
        bts_pass "no args prints usage"
    else
        bts_fail "usage missing: $(printf '%q' "$_BTS_ERR")"
    fi
    if [[ ! -f "$log" ]]; then
        bts_pass "usage does not write fail log"
    else
        bts_fail "usage wrote fail log"
    fi

    _bts_capture "$log" "${tmp}/nope_TEST.sh"
    _bts_expect_rc "missing file exits 2" 2

    _bts_write "${tmp}/plain.sh" <<'EOF'
#!/usr/bin/env bash
suite_plain() { :; }
EOF
    _bts_capture "$log" "${tmp}/plain.sh"
    _bts_expect_rc "non _TEST.sh exits 2" 2

    _bts_capture "$log" "$tmp"
    _bts_expect_rc "empty dir exits 2" 2

    _bts_capture "$log" --selftest "${tmp}/ok_TEST.sh"
    _bts_expect_rc "--selftest rejects PATH" 2

    rm -rf "$tmp"
}

suite_run_quiet() {
    local tmp log body
    tmp="$(mktemp -d)"
    log="${tmp}/fail.log"

    _bts_write "${tmp}/ok_TEST.sh" <<'EOF'
suite_ok() {
    bts_pass "ok one"
    bts_pass "ok two"
}
EOF
    _bts_capture "$log" "${tmp}/ok_TEST.sh"
    _bts_expect_rc "pass exits 0" 0
    _bts_expect_empty "pass stdout empty" "$_BTS_OUT"
    if [[ "$_BTS_ERR" == "OK" ]]; then
        bts_pass "pass stderr is OK"
    else
        bts_fail "pass stderr=$(printf '%q' "$_BTS_ERR")"
    fi
    if [[ ! -f "$log" ]]; then
        bts_pass "pass deletes fail log"
    else
        bts_fail "pass left fail log"
    fi

    printf 'stale\n' >"$log"
    _bts_capture "$log" "${tmp}/ok_TEST.sh"
    if [[ ! -f "$log" ]]; then
        bts_pass "pass removes stale fail log"
    else
        bts_fail "stale fail log kept"
    fi

    _bts_write "${tmp}/bad_TEST.sh" <<'EOF'
suite_bad() {
    bts_pass "still counts"
    bts_fail "boom"
}
EOF
    _bts_capture "$log" "${tmp}/bad_TEST.sh"
    _bts_expect_rc "fail exits 1" 1
    _bts_expect_empty "fail stdout empty" "$_BTS_OUT"
    if [[ "$_BTS_ERR" == "FAIL 1 ${log}" ]]; then
        bts_pass "fail stderr is FAIL n path"
    else
        bts_fail "fail stderr=$(printf '%q' "$_BTS_ERR")"
    fi
    if [[ -f "$log" ]]; then
        body="$(cat "$log")"
        if [[ "$body" == failed=1* && "$body" == *"passed=1"* && "$body" == *"FAIL boom"* && "$body" != *"still counts"* ]]; then
            bts_pass "fail log has issues only"
        else
            bts_fail "fail log=$(printf '%q' "$body")"
        fi
    else
        bts_fail "fail log missing"
    fi

    _bts_capture "$log" "${tmp}/ok_TEST.sh" "${tmp}/bad_TEST.sh"
    _bts_expect_rc "mixed exits 1" 1
    if [[ "$_BTS_ERR" == "FAIL 1 ${log}" ]]; then
        bts_pass "mixed FAIL count is assertions"
    else
        bts_fail "mixed stderr=$(printf '%q' "$_BTS_ERR")"
    fi

    rm -rf "$tmp"
}

suite_run_discover() {
    local tmp log
    tmp="$(mktemp -d)"
    log="${tmp}/fail.log"

    _bts_write "${tmp}/setup_TEST.sh" <<'EOF'
suite_setup_only() {
    bts_fail "setup suite ran from dir"
}
EOF
    _bts_write "${tmp}/leaf/a_TEST.sh" <<'EOF'
suite_a() { bts_pass "a"; }
EOF
    _bts_write "${tmp}/leaf/b_TEST.sh" <<'EOF'
suite_b() { bts_pass "b"; }
EOF

    _bts_capture "$log" "$tmp"
    _bts_expect_rc "dir run skips setup_TEST.sh" 0
    if [[ "$_BTS_ERR" == "OK" ]]; then
        bts_pass "dir pass is OK"
    else
        bts_fail "dir stderr=$(printf '%q' "$_BTS_ERR")"
    fi

    _bts_write "${tmp}/onlysetup/setup_TEST.sh" <<'EOF'
# harness only
EOF
    _bts_capture "$log" "${tmp}/onlysetup"
    _bts_expect_rc "dir of only setup_TEST.sh exits 2" 2

    rm -rf "$tmp"
}

suite_run_setup() {
    local tmp log body
    tmp="$(mktemp -d)"
    log="${tmp}/fail.log"

    _bts_write "${tmp}/setup_TEST.sh" <<'EOF'
BTS_MARK=poison
EOF
    _bts_write "${tmp}/leaf/mark_TEST.sh" <<'EOF'
suite_mark() {
    if [[ -z "${BTS_MARK:-}" ]]; then
        bts_pass "setup_TEST.sh is not auto-sourced"
    else
        bts_fail "mark=${BTS_MARK}"
    fi
}
EOF

    _bts_capture "$log" "${tmp}/leaf/mark_TEST.sh"
    _bts_expect_rc "no walk-up setup" 0

    _bts_write "${tmp}/leaf/nosuite_TEST.sh" <<'EOF'
# no suite_* on purpose
EOF
    _bts_capture "$log" "${tmp}/leaf/nosuite_TEST.sh"
    _bts_expect_rc "no suite_* exits 1" 1
    body="$(cat "$log" 2>/dev/null || true)"
    if [[ "$body" == *"no suite_* functions"* ]]; then
        bts_pass "no suite_* is a FAIL"
    else
        bts_fail "no suite log=$(printf '%q' "$body")"
    fi

    rm -rf "$tmp"
}

suite_run_isolate() {
    local tmp log
    tmp="$(mktemp -d)"
    log="${tmp}/fail.log"

    _bts_write "${tmp}/pollute_TEST.sh" <<'EOF'
suite_pollute() {
    declare -g BTS_POLLUTE=1
    bts_pass "polluted self"
}
EOF
    _bts_write "${tmp}/clean_TEST.sh" <<'EOF'
suite_clean() {
    if [[ -n "${BTS_POLLUTE:-}" ]]; then
        bts_fail "saw BTS_POLLUTE"
    else
        bts_pass "isolated"
    fi
}
EOF

    _bts_capture "$log" "${tmp}/pollute_TEST.sh" "${tmp}/clean_TEST.sh"
    _bts_expect_rc "per-file isolate" 0

    rm -rf "$tmp"
}

suite_run_crash() {
    local tmp log body
    tmp="$(mktemp -d)"
    log="${tmp}/fail.log"

    _bts_write "${tmp}/crash_TEST.sh" <<'EOF'
suite_crash() {
    unset -v BTS_NO_SUCH
    echo "$BTS_NO_SUCH"
}
EOF
    _bts_capture "$log" "${tmp}/crash_TEST.sh"
    _bts_expect_rc "crash exits 1" 1
    body="$(cat "$log" 2>/dev/null || true)"
    if [[ "$body" == *$'\nCRASH rc='* ]]; then
        bts_pass "crash logged as CRASH"
    else
        bts_fail "crash log=$(printf '%q' "$body")"
    fi

    _bts_write "${tmp}/crashkeep_TEST.sh" <<'EOF'
suite_crashkeep() {
    bts_pass "before crash"
    unset -v BTS_NO_SUCH
    echo "$BTS_NO_SUCH"
}
EOF
    _bts_capture "$log" "${tmp}/crashkeep_TEST.sh"
    _bts_expect_rc "crash after pass exits 1" 1
    body="$(cat "$log" 2>/dev/null || true)"
    if [[ "$body" == failed=1* && "$body" == *"passed=1"* && "$body" == *$'\nCRASH rc='* ]]; then
        bts_pass "crash keeps prior passes"
    else
        bts_fail "crashkeep log=$(printf '%q' "$body")"
    fi

    _bts_write "${tmp}/crashfail_TEST.sh" <<'EOF'
suite_crashfail() {
    bts_fail "boom"
    unset -v BTS_NO_SUCH
    echo "$BTS_NO_SUCH"
}
EOF
    _bts_capture "$log" "${tmp}/crashfail_TEST.sh"
    _bts_expect_rc "crash after fail exits 1" 1
    if [[ "$_BTS_ERR" == "FAIL 2 ${log}" ]]; then
        bts_pass "crash after fail is FAIL 2"
    else
        bts_fail "crashfail stderr=$(printf '%q' "$_BTS_ERR")"
    fi
    body="$(cat "$log" 2>/dev/null || true)"
    if [[ "$body" == *"FAIL boom"* && "$body" == *$'\nCRASH rc='* ]]; then
        bts_pass "crash after fail keeps FAIL and CRASH"
    else
        bts_fail "crashfail log=$(printf '%q' "$body")"
    fi

    rm -rf "$tmp"
}

suite_run_errexit() {
    local tmp log body
    tmp="$(mktemp -d)"
    log="${tmp}/fail.log"

    _bts_write "${tmp}/nonzero_TEST.sh" <<'EOF'
suite_nonzero() {
    bts_pass "before"
    return 1
}
EOF
    _bts_capture "$log" "${tmp}/nonzero_TEST.sh"
    _bts_expect_rc "suite return 1 exits 1" 1
    body="$(cat "$log" 2>/dev/null || true)"
    if [[ "$body" == *"returned non-zero"* && "$body" != *$'\nCRASH rc='* ]]; then
        bts_pass "suite return 1 is FAIL not CRASH"
    else
        bts_fail "nonzero log=$(printf '%q' "$body")"
    fi

    _bts_write "${tmp}/cmdsub_TEST.sh" <<'EOF'
suite_cmdsub() {
    local got
    got=$(false)
    bts_pass "survived rc 1"
}
EOF
    _bts_capture "$log" "${tmp}/cmdsub_TEST.sh"
    _bts_expect_rc "cmdsub rc 1 does not crash" 0

    rm -rf "$tmp"
}

suite_run_format() {
    local tmp log
    tmp="$(mktemp -d)"
    log="${tmp}/fail.log"

    _bts_write "${tmp}/ok_TEST.sh" <<'EOF'
suite_ok() { bts_pass "visible"; }
EOF
    _BTS_RC=0
    local out err
    out="$(mktemp)"
    err="$(mktemp)"
    "$_BTS_RUN" -f --log "$log" "${tmp}/ok_TEST.sh" >"$out" 2>"$err" || _BTS_RC=$?
    _BTS_OUT="$(cat "$out")"
    _BTS_ERR="$(cat "$err")"

    _bts_expect_rc "format pass exits 0" 0
    if [[ "$_BTS_ERR" == *visible* && "$_BTS_ERR" == *"All tests passed"* && "$_BTS_ERR" == *"===="* ]]; then
        bts_pass "format prints pass, summary, equals borders"
    else
        bts_fail "format err=$(printf '%q' "$_BTS_ERR")"
    fi

    _BTS_RC=0
    BTS_COLOR=1 "$_BTS_RUN" -f --log "$log" "${tmp}/ok_TEST.sh" >"$out" 2>"$err" || _BTS_RC=$?
    _BTS_ERR="$(cat "$err")"
    if [[ "$_BTS_RC" -eq 0 && "$_BTS_ERR" == *$'\033[1;32mOK\033[0m'* ]]; then
        bts_pass "format colors OK when COLOR=1"
    else
        bts_fail "color err=$(printf '%q' "$_BTS_ERR")"
    fi
    rm -f "$out" "$err"

    rm -rf "$tmp"
}

suite_run_leak() {
    local tmp log body
    tmp="$(mktemp -d)"
    log="${tmp}/fail.log"

    _bts_write "${tmp}/ok_TEST.sh" <<'EOF'
suite_ok() {
    echo "product boom" >&2
    bts_pass "still asserts"
}
EOF
    _bts_capture "$log" "${tmp}/ok_TEST.sh"
    _bts_expect_rc "leaked stderr exits 1" 1
    if [[ "$_BTS_ERR" == "FAIL 1 ${log}" ]]; then
        bts_pass "leak is FAIL 1"
    else
        bts_fail "leak stderr=$(printf '%q' "$_BTS_ERR")"
    fi
    body="$(cat "$log" 2>/dev/null || true)"
    if [[ "$body" == *$'\nLEAK\n'* && "$body" == *"product boom"* ]]; then
        bts_pass "leak log has the line"
    else
        bts_fail "leak log=$(printf '%q' "$body")"
    fi

    _BTS_RC=0
    local out err
    out="$(mktemp)"
    err="$(mktemp)"
    "$_BTS_RUN" -f --log "$log" "${tmp}/ok_TEST.sh" >"$out" 2>"$err" || _BTS_RC=$?
    _BTS_ERR="$(cat "$err")"
    if [[ "$_BTS_RC" -eq 1 && "$_BTS_ERR" == *"leaked: product boom"* ]]; then
        bts_pass "format prints leaked as FAIL"
    else
        bts_fail "format leak rc=$_BTS_RC err=$(printf '%q' "$_BTS_ERR")"
    fi
    rm -f "$out" "$err"

    _bts_write "${tmp}/swallowed_TEST.sh" <<'EOF'
suite_swallowed() {
    echo "expected" >/dev/null 2>&1
    bts_pass "quiet"
}
EOF
    _bts_capture "$log" "${tmp}/swallowed_TEST.sh"
    _bts_expect_rc "swallowed stderr is OK" 0

    _bts_write "${tmp}/indented_TEST.sh" <<'EOF'
suite_indented() {
    echo '  [ERROR] - product boom' >&2
    bts_pass "still asserts"
}
EOF
    _bts_capture "$log" "${tmp}/indented_TEST.sh"
    _bts_expect_rc "indented product [ERROR] is a leak" 1
    body="$(cat "$log" 2>/dev/null || true)"
    if [[ "$body" == *$'\nLEAK\n'* && "$body" == *'[ERROR] - product boom'* ]]; then
        bts_pass "indented [ERROR] is in the leak log"
    else
        bts_fail "indented leak log=$(printf '%q' "$body")"
    fi

    _bts_capture "$log" --debug "${tmp}/swallowed_TEST.sh"
    _bts_expect_rc "--debug does not leak" 0

    _bts_write "${tmp}/debug_TEST.sh" <<'EOF'
suite_debug() {
    bts_debug "probe"
    bts_pass "ok"
}
EOF
    _bts_capture "$log" --debug "${tmp}/debug_TEST.sh"
    _bts_expect_rc "--debug with bts_debug exits 0" 0
    if [[ "$_BTS_ERR" == *"DEBUG"*"probe"* && "$_BTS_ERR" == *$'\nOK' ]]; then
        bts_pass "--debug prints suite debug then OK"
    else
        bts_fail "debug stderr=$(printf '%q' "$_BTS_ERR")"
    fi

    _bts_capture "$log" "${tmp}/debug_TEST.sh"
    _bts_expect_rc "debug off is not a leak" 0
    if [[ "$_BTS_ERR" == "OK" ]]; then
        bts_pass "without --debug bts_debug is silent"
    else
        bts_fail "quiet debug stderr=$(printf '%q' "$_BTS_ERR")"
    fi

    rm -rf "$tmp"
}
