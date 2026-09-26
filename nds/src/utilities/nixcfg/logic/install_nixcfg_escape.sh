#!/usr/bin/env bash
# ==================================================================================================
# NDS - Nix string escaping for nixWriter blocks
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-06 | Modified: 2026-07-06
# ==================================================================================================

# Description: Escape a string for safe embedding in a Nix double-quoted string.
# Arguments:
# - s: <String> Raw value
# Returns:
# - <String> Escaped value on stdout
_nixcfg_nix_escape() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//\$\{/\\\$\{}"
    printf '%s' "$s"
}
