#!/usr/bin/env bash
# ==================================================================================================
# NDS - Feature tag on logger lines
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-28 | Modified: 2026-09-28
# Description:   Puts the calling feature name in front of every logger message.
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

# Folder of the caller, uppercased. utilities/disk -> DISK, cook -> COOK.
_nds_log_tag_from() {
    local src=$1 name
    case "$src" in
        */utilities/essentials/*/*)
            name=${src#*/utilities/essentials/}
            name=${name%%/*}
            ;;
        */nds/src/utilities/*/*)
            name=${src#*/nds/src/utilities/}
            name=${name%%/*}
            ;;
        */nds/src/actions/*/*)
            name=${src#*/nds/src/actions/}
            name=${name%%/*}
            ;;
        */nds-actions/*/*)
            name=${src#*/nds-actions/}
            name=${name%%/*}
            ;;
        */nds/src/app/pipeline/*) name=pipeline ;;
        */nds/src/app/session/*) name=session ;;
        */nds/src/app/actionSelect/*) name=action ;;
        */nds/src/app/*) name=nds ;;
        */nds/src/cook/*) name=cook ;;
        */nds/src/recipe/*) name=recipe ;;
        */nds/src/wizard/*) name=wizard ;;
        *)
            name=${src##*/}
            name=${name%.*}
            ;;
    esac
    printf '%s' "${name^^}"
}

# Called by the logger writers. Skips err(), which is a shared helper, so the tag is the real caller.
logger_callerTag() {
    local i src
    for ((i = 2; i < ${#BASH_SOURCE[@]}; i++)); do
        case "${FUNCNAME[i]:-}" in
            err|logger_callerTag) continue ;;
        esac
        src=${BASH_SOURCE[i]:-}
        [[ -n "$src" ]] || continue
        _nds_log_tag_from "$src"
        return 0
    done
    return 0
}
