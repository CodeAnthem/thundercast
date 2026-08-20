#!/usr/bin/env bash
# ==================================================================================================
# NDS - Validators: filesystem paths
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-06 | Modified: 2026-07-06
# ==================================================================================================

# Description: True when path looks absolute, home-relative, or dot-relative.
validate_path() {
    local path="$1"
    [[ "$path" =~ ^(/|~|\.) ]]
}

# Description: Classify a path string.
# Returns:
# - <String> absolute | home | relative | other (stdout)
validate_path_classify() {
    local path="$1"
    if [[ "$path" == /* ]]; then
        echo "absolute"
    elif [[ "$path" == "~" ]] || [[ "$path" =~ ^~/ ]]; then
        echo "home"
    elif [[ "$path" == ./* || "$path" == ../* || "$path" == "." ]]; then
        echo "relative"
    else
        echo "other"
    fi
}
