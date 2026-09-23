#!/usr/bin/env bash
# ==================================================================================================
# NDS - Module import utilities
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-29 | Modified: 2026-09-02
# Description:   Validate and source NDS modules (moduleLoader)
# ==================================================================================================

declare -g NDS_IMPORT_ERRORS=""

# Syntax-check then source. Never execute the file as a new process: libraries call
# NDS functions and may `return` at top level (legal only when sourced).
_nds_import_validate_file() {
    local filepath="$1"
    local err_output

    if ! err_output=$(bash -n "$filepath" 2>&1); then
        local cleaned=""
        local line
        while IFS= read -r line; do
            if [[ "$line" == "$filepath:"* ]]; then
                line="${line#"$filepath: "}"
            fi
            cleaned+=$'\n'" -> $line"
        done <<< "$err_output"

        if [[ -z "$NDS_IMPORT_ERRORS" ]]; then
            NDS_IMPORT_ERRORS="Error: Failed to validate: $filepath${cleaned}"
        else
            NDS_IMPORT_ERRORS+=$'\n'"Error: Failed to validate: $filepath${cleaned}"
        fi
        return 1
    fi

    # shellcheck disable=SC1090
    if ! source "$filepath"; then
        if [[ -z "$NDS_IMPORT_ERRORS" ]]; then
            NDS_IMPORT_ERRORS="Error: Failed to source: $filepath"
        else
            NDS_IMPORT_ERRORS+=$'\n'"Error: Failed to source: $filepath"
        fi
        return 1
    fi

    return 0
}

_nds_import_show_errors() {
    if [[ -n "$NDS_IMPORT_ERRORS" ]]; then
        echo "$NDS_IMPORT_ERRORS" >&2
        NDS_IMPORT_ERRORS=""
        return 1
    fi
    return 0
}

# Description: Source one NDS file after validating it has no syntax errors.
nds_import_file() {
    local filepath="$1"

    [[ -f "$filepath" ]] || {
        echo "Error: File not found: $filepath" >&2
        return 1
    }

    NDS_IMPORT_ERRORS=""
    _nds_import_validate_file "$filepath"
    _nds_import_show_errors
}

# Load .sh files in a directory (non-recursive), alphabetical, skip _* and load.sh.
_nds_import_dir_files() {
    local directory="$1"
    local item basename
    local had_error=false
    local -a files=()

    [[ -d "$directory" ]] || return 0
    for item in "$directory"/*; do
        [[ -f "$item" ]] || continue
        basename="$(basename "$item")"
        [[ "${basename:0:1}" == "_" ]] && continue
        [[ "$basename" == "load.sh" ]] && continue
        [[ "$basename" == *_TEST.sh ]] && continue
        [[ "${basename: -3}" == ".sh" ]] || continue
        files+=("$item")
    done
    if ((${#files[@]} == 0)); then
        return 0
    fi
    local _save_ifs="$IFS"
    IFS=$'\n'
    # shellcheck disable=SC2207
    files=($(printf '%s\n' "${files[@]}" | sort))
    IFS="$_save_ifs"
    for item in "${files[@]}"; do
        if ! _nds_import_validate_file "$item"; then
            had_error=true
        fi
    done
    [[ "$had_error" == "true" ]] && return 1
    return 0
}

# Description: Recursively load a feature tree without nested load.sh.
# Order: preferred dirs (lib → logic → ui) then other dirs alpha; files alpha within.
# Skips: tests/, data/, fixtures/, specs/, load.sh, _*, *_TEST.sh
# Arguments:
# - root: <String> Feature directory
nds_import_tree() {
    local root="${1:?feature root}"
    local -a preferred=(lib logic state ui)
    local -a other_dirs=()
    local d name preferred_set=" lib logic state ui "
    local had_error=false

    [[ -d "$root" ]] || {
        echo "Error: Directory not found: $root" >&2
        return 1
    }

    NDS_IMPORT_ERRORS=""
    _nds_import_dir_files "$root" || had_error=true

    for name in "${preferred[@]}"; do
        d="${root}/${name}"
        [[ -d "$d" ]] || continue
        if ! nds_import_tree "$d"; then
            had_error=true
        fi
    done

    for d in "$root"/*; do
        [[ -d "$d" ]] || continue
        name="$(basename "$d")"
        [[ "${name:0:1}" == "_" ]] && continue
        case "$name" in
            tests|data|fixtures|specs) continue ;;
        esac
        [[ "$preferred_set" == *" $name "* ]] && continue
        other_dirs+=("$d")
    done
    if ((${#other_dirs[@]})); then
        local _save_ifs="$IFS"
        IFS=$'\n'
        # shellcheck disable=SC2207
        other_dirs=($(printf '%s\n' "${other_dirs[@]}" | sort))
        IFS="$_save_ifs"
        for d in "${other_dirs[@]}"; do
            if ! nds_import_tree "$d"; then
                had_error=true
            fi
        done
    fi

    if [[ "$had_error" == "true" ]]; then
        _nds_import_show_errors
        return 1
    fi
    return 0
}
