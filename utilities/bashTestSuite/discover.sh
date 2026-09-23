#!/usr/bin/env bash
# ==================================================================================================
# ThunderCast - bashTestSuite discover *_TEST.sh
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-20 | Modified: 2026-09-20
# ==================================================================================================

_bts_collectFiles() {
    local -n _bts_files="$1"
    shift
    local p f abs
    for p in "$@"; do
        if [[ -f "$p" ]]; then
            if [[ "$p" != *_TEST.sh ]]; then
                bts_error "not a *_TEST.sh: $p"
                return 2
            fi
            abs="$(cd "$(dirname "$p")" && pwd -P)/$(basename "$p")"
            _bts_files+=("$abs")
        elif [[ -d "$p" ]]; then
            while IFS= read -r f; do
                [[ -n "$f" ]] || continue
                abs="$(cd "$(dirname "$f")" && pwd -P)/$(basename "$f")"
                _bts_files+=("$abs")
            done < <(find "$p" -type f -name '*_TEST.sh' ! -name 'setup_TEST.sh' | sort)
        else
            bts_error "not found: $p"
            return 2
        fi
    done
    if ((${#_bts_files[@]} == 0)); then
        bts_error "no *_TEST.sh found"
        return 2
    fi
    return 0
}
