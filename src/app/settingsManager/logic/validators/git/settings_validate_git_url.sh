#!/usr/bin/env bash
# ==================================================================================================
# NDS - Validators: git and flake URLs
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-06 | Modified: 2026-07-06
# ==================================================================================================

# Description: True for http(s), git, ssh scheme URLs or SCP-style git remotes.
validate_git_url() {
    [[ "$1" =~ ^(https?|git|ssh):// ]] && return 0
    [[ "$1" =~ ^[a-zA-Z0-9._-]+@[a-zA-Z0-9._-]+:.+ ]]
}

# Description: Classify git remote string.
# Returns:
# - <String> https | ssh-scheme | scp | other (stdout)
validate_git_url_classify() {
    local url="$1"
    case "$url" in
        https://*|http://*) echo "https" ;;
        ssh://*|git+ssh://*) echo "ssh-scheme" ;;
        git@*|*@*:*.git|*@*:*/*) echo "scp" ;;
        git://*) echo "git" ;;
        *) echo "other" ;;
    esac
}

# Description: Classify flake location as remote git or local path.
# Returns:
# - <String> remote | local (stdout)
nds_detect_flake_source() {
    local value="$1"
    case "$value" in
        http://*|https://*|git://*|ssh://*) echo "remote"; return 0 ;;
        /*|~*|./*|../*|.) echo "local"; return 0 ;;
    esac
    if [[ "$value" =~ ^[a-zA-Z0-9._-]+@[a-zA-Z0-9._-]+:.+ ]]; then
        echo "remote"; return 0
    fi
    if [[ -e "$value" ]]; then echo "local"; else echo "remote"; fi
}

validate_flake_location() {
    validate_git_url "$1" || validate_path "$1"
}

validate_git_remote() {
    validate_git_url "$1"
}
