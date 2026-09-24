#!/usr/bin/env bash
# ==================================================================================================
# Thundercast - Bash Essentials - Importer
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-24 | Modified: 2026-09-24
# Description:   Source *.sh files from one directory into the current shell.
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

# 0 include *_TEST.sh, 1 skip them, 2 invalid IMPORTER_INCLUDE_TESTS.
_essentials_importer_includeTests() {
    local _im_value="${essentials_config[IMPORTER_INCLUDE_TESTS]:-false}"
    case "$_im_value" in
        true) return 0 ;;
        false) return 1 ;;
        *)
            error "Importer: invalid IMPORTER_INCLUDE_TESTS: ${_im_value}"
            return 2
            ;;
    esac
}

# Case pattern on the basename. Caller skips this when the list is empty.
_essentials_importer_ignored() {
    local _im_base="$1"
    local -n _im_pats="$2"
    local _im_pat
    for _im_pat in "${_im_pats[@]}"; do
        # shellcheck disable=SC2254
        case "$_im_base" in
            $_im_pat) return 0 ;;
        esac
    done
    return 1
}

# Files in this directory, then its subdirectories. Empty _im_depth has no limit.
_essentials_importer_walk() {
    local _im_dir="$1"
    local _im_depth="$2"
    local _im_ignore_name="$3"
    local _im_skip_tests="$4"
    local _im_path _im_base _im_entry _im_next
    local _im_nullglob=0 _im_failglob=0 _im_noglob=0
    local -a _im_files=() _im_dirs=()

    if shopt -q nullglob; then _im_nullglob=1; fi
    if shopt -q failglob; then _im_failglob=1; fi
    if [[ -o noglob ]]; then _im_noglob=1; fi
    shopt -s nullglob
    shopt -u failglob
    set +f
    for _im_path in "${_im_dir}"/*.sh; do
        [[ -f "$_im_path" ]] || continue
        _im_base="${_im_path##*/}"
        if [[ "$_im_skip_tests" -eq 1 ]]; then
            case "$_im_base" in
                *_TEST.sh) continue ;;
            esac
        fi
        if [[ -n "$_im_ignore_name" ]] && _essentials_importer_ignored "$_im_base" "$_im_ignore_name"; then
            continue
        fi
        _im_files+=("$_im_path")
    done
    if [[ -z "$_im_depth" || "$_im_depth" -gt 0 ]]; then
        for _im_path in "${_im_dir}"/*/; do
            _im_entry="${_im_path%/}"
            [[ -L "$_im_entry" ]] && continue
            [[ -d "$_im_entry" ]] || continue
            _im_base="${_im_entry##*/}"
            if [[ -n "$_im_ignore_name" ]] && _essentials_importer_ignored "$_im_base" "$_im_ignore_name"; then
                continue
            fi
            _im_dirs+=("$_im_entry")
        done
    fi
    if [[ "$_im_nullglob" -eq 0 ]]; then shopt -u nullglob; fi
    if [[ "$_im_failglob" -eq 1 ]]; then shopt -s failglob; fi
    if [[ "$_im_noglob" -eq 1 ]]; then set -f; fi

    for _im_path in "${_im_files[@]}"; do
        import_file "$_im_path" || return 1
    done

    if [[ -z "$_im_depth" ]]; then
        _im_next=""
    elif [[ "$_im_depth" -gt 0 ]]; then
        _im_next=$((_im_depth - 1))
    else
        return 0
    fi
    for _im_path in "${_im_dirs[@]}"; do
        _essentials_importer_walk "$_im_path" "$_im_next" "$_im_ignore_name" "$_im_skip_tests" || return 1
    done
}

import_file() {
    local _im_path="${1-}"
    if [[ -z "$_im_path" || ! -f "$_im_path" ]]; then
        error "Importer: file not found: ${_im_path}"
        return 1
    fi
    # shellcheck disable=SC1090
    if ! source -- "$_im_path"; then
        error "Importer: failed to source: ${_im_path}"
        return 1
    fi
}

import_dir() {
    local _im_dir="${1-}"
    local _im_depth=""
    local _im_rc=0 _im_skip_tests=1
    local -a _im_ignores=()
    if [[ -z "$_im_dir" ]]; then
        error "Importer: import_dir requires a directory"
        return 1
    fi
    shift
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --depth)
                shift
                if [[ $# -eq 0 ]]; then
                    error "Importer: --depth requires a value"
                    return 1
                fi
                _im_depth="$1"
                ;;
            --ignore)
                shift
                if [[ $# -eq 0 ]]; then
                    error "Importer: --ignore requires a pattern"
                    return 1
                fi
                _im_ignores+=("$1")
                ;;
            *)
                error "Importer: unknown argument: ${1}"
                return 1
                ;;
        esac
        shift
    done
    if [[ -n "$_im_depth" ]]; then
        if [[ "$_im_depth" =~ ^[0-9]+$ ]]; then
            _im_depth=$((10#${_im_depth}))
        else
            error "Importer: invalid depth: ${_im_depth}"
            return 1
        fi
    fi
    if [[ ! -d "$_im_dir" ]]; then
        error "Importer: directory not found: ${_im_dir}"
        return 1
    fi
    if [[ "$_im_dir" != /* ]]; then
        _im_dir="${PWD}/${_im_dir}"
    fi
    _essentials_importer_includeTests || _im_rc=$?
    if [[ "$_im_rc" -eq 2 ]]; then
        return 1
    fi
    [[ "$_im_rc" -eq 0 ]] && _im_skip_tests=0
    # Empty name: no --ignore patterns, so the walk does not nameref the list.
    if [[ ${#_im_ignores[@]} -eq 0 ]]; then
        _essentials_importer_walk "$_im_dir" "$_im_depth" "" "$_im_skip_tests"
    else
        _essentials_importer_walk "$_im_dir" "$_im_depth" _im_ignores "$_im_skip_tests"
    fi
}

_essentials_importer_init() {
    _essentials_init_isDone importer && return 0
    local _im_rc=0
    _essentials_importer_includeTests || _im_rc=$?
    [[ "$_im_rc" -le 1 ]] || return 1
    _essentials_init_mark importer
}
_essentials_importer_init || return 1
