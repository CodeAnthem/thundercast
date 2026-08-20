#!/usr/bin/env bash
# ==================================================================================================
# NDS - Bundle registry unit checks
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-05 | Modified: 2026-08-16
# ==================================================================================================

nds_test_bundle_register_api() {
    nds_bundle_reset
    nds_bundle_register_hook nds_bundle_contrib_core

    local tmp staging extra_dir
    tmp=$(mktemp)
    printf 'secret-body' >"$tmp"
    nds_bundle_register_file "secrets/extra.txt" "$tmp"
    nds_bundle_register_text "hello.txt" "world"

    _test_contrib_extra() {
        nds_bundle_register_text "from-hook.txt" "hooked"
    }
    nds_bundle_register_hook _test_contrib_extra

    nds_bundle_reset_contribs
    nds_bundle_run_hooks
    nds_bundle_register_file "secrets/extra.txt" "$tmp"
    nds_bundle_register_text "hello.txt" "world"

    extra_dir=$(mktemp -d)
    printf 'dir-body' >"${extra_dir}/nested.txt"
    nds_bundle_register_dir "extra-dir" "$extra_dir"

    staging=$(mktemp -d)
    nds_bundle_apply_contribs "$staging" || {
        rm -f "$tmp"
        rm -rf "$staging" "$extra_dir"
        return 1
    }

    [[ -f "${staging}/hello.txt" ]] || return 1
    [[ "$(<"${staging}/hello.txt")" == "world" ]] || return 1
    [[ -f "${staging}/from-hook.txt" ]] || return 1
    [[ -f "${staging}/secrets/extra.txt" ]] || return 1
    [[ -f "${staging}/extra-dir/nested.txt" ]] || return 1
    [[ "$(<"${staging}/extra-dir/nested.txt")" == "dir-body" ]] || return 1

    rm -f "$tmp"
    rm -rf "$staging" "$extra_dir"
    nds_bundle_reset
    nds_bundle_register_hook nds_bundle_contrib_core
    if declare -f nds_git_bundle_contrib &>/dev/null; then
        nds_bundle_register_hook nds_git_bundle_contrib
    fi
    return 0
}
