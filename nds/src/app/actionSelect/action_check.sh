#!/usr/bin/env bash
# ==================================================================================================
# NDS - Action script check
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-24 | Modified: 2026-09-25
# Description:   Reads a script once. Does not source it. A hit is name() at the start of a line.
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

# Prints the description. Fails when the contract functions or the description are missing.
_nds_action_check() {
    local setup="$1" line description="" n=0
    local has_groups=false has_preview=false saw_description=false retired=false
    while IFS= read -r line; do
        case "$line" in
            'action_'"groups()"*) has_groups=true ;;
            'action_'"preview()"*) has_preview=true ;;
            'action_'"setup()"*|'action_'"config()"*|'action_'"presets()"*| \
            'action_'"presets_paths()"*|'action_'"on_accept()"*| \
            'action_'"extend_settings_manager()"*)
                retired=true
                ;;
        esac
        if [[ "$saw_description" == false && "$n" -lt 20 && "$line" == "# Description:"* ]]; then
            line="${line#\# Description:}"
            line="${line#"${line%%[![:space:]]*}"}"
            [[ -n "$line" ]] || return 1
            description="$line"
            saw_description=true
        fi
        n=$((n + 1))
    done <"$setup"
    [[ "$retired" == false && "$has_groups" == true && "$has_preview" == true && "$saw_description" == true ]] || return 1
    printf '%s\n' "$description"
}

_nds_action_store_validate() {
    local store="$1" name setup description
    local -a names=()
    while IFS= read -r name; do
        [[ -n "$name" ]] || continue
        names+=("$name")
    done <<< "${ _nds_action_store_names "$store"; }"
    for name in "${names[@]+"${names[@]}"}"; do
        setup="${ _nds_action_store_path "$store" "$name"; }"
        if description="${ _nds_action_check "$setup"; }"; then
            _nds_action_store_set_description "$store" "$name" "$description"
        else
            warn "Skipping invalid action: ${name}"
            _nds_action_store_remove "$store" "$name"
        fi
    done
}
