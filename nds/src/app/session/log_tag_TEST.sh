#!/usr/bin/env bash
# ==================================================================================================
# NDS - Logger feature tag
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-28 | Modified: 2026-09-28
# ==================================================================================================

# shellcheck source=../../setup_TEST.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../setup_TEST.sh"
# shellcheck source=log_tag.sh
source "$(dirname "${BASH_SOURCE[0]}")/log_tag.sh"

_tag_via_err() { err "via-err"; }

suite_log_tag() {
    local got out
    bts_section "Path"
    got=$(_nds_log_tag_from "/tmp/nds/src/utilities/disk/ops/disk_partition.sh")
    [[ "$got" == DISK ]] && bts_pass "disk folder is DISK" || bts_fail "disk tag '${got}'"
    got=$(_nds_log_tag_from "/tmp/nds/src/cook/steps_disk.sh")
    [[ "$got" == COOK ]] && bts_pass "cook folder is COOK" || bts_fail "cook tag '${got}'"
    got=$(_nds_log_tag_from "/tmp/nds/src/utilities/nixos/ops/nixos_classic.sh")
    [[ "$got" == NIXOS ]] && bts_pass "nixos folder is NIXOS" || bts_fail "nixos tag '${got}'"
    got=$(_nds_log_tag_from "/tmp/nds/src/app/pipeline/pipeline.sh")
    [[ "$got" == PIPELINE ]] && bts_pass "pipeline folder is PIPELINE" || bts_fail "pipeline tag '${got}'"
    got=$(_nds_log_tag_from "/tmp/nds/src/actions/classicInstall/setup.sh")
    [[ "$got" == CLASSICINSTALL ]] && bts_pass "action folder is CLASSICINSTALL" || bts_fail "action tag '${got}'"

    bts_section "Logger"
    logger_setMinLevel info
    out=$(info "hello" 2>/dev/null)
    [[ "$out" == *"SESSION: hello"* ]] && bts_pass "info carries the caller feature" || bts_fail "info out '${out}'"
    err() { error "$1"; }
    out=$( _tag_via_err 2>&1 )
    [[ "$out" == *"SESSION: via-err"* ]] && bts_pass "err helper keeps the real caller" || bts_fail "err out '${out}'"
}
