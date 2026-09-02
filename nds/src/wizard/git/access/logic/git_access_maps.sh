#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git URL maps for restore export
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-31 | Modified: 2026-08-16
# Description:   Emit declare -gA NDS_GIT_METHOD / KEY_PATH / KEY_KIND / EXISTING_KEY / KEY_MODE
#                (never KEY_BODY)
# ==================================================================================================

_nds_git_shell_quote() {
    local s="$1"
    s=${s//\'/\'\\\'\'}
    printf "'%s'" "$s"
}

_nds_git_is_assoc() {
    local n="$1" d
    d="$(declare -p "$n" 2>/dev/null)" || return 1
    [[ "$d" =~ ^declare\ -[a-zA-Z]*A ]]
}

# Description: Emit git URL-keyed maps as declare -gA blocks (-g so source-from-function keeps them).
# Arguments:
# - --portable: <Flag|optional> Rewrite KEY_PATH to /root/.ssh/<basename> for files in the zip
nds_git_export_maps() {
    local url path portable=false
    [[ "${1:-}" == "--portable" ]] && portable=true

    if _nds_git_is_assoc NDS_GIT_METHOD && [[ ${#NDS_GIT_METHOD[@]} -gt 0 ]]; then
        echo "declare -gA NDS_GIT_METHOD=("
        for url in "${!NDS_GIT_METHOD[@]}"; do
            printf '  [%s]=%s\n' "${ _nds_git_shell_quote "$url"; }" \
                "${ _nds_git_shell_quote "${NDS_GIT_METHOD[$url]}"; }"
        done
        echo ")"
        echo ""
    fi
    if _nds_git_is_assoc NDS_GIT_KEY_PATH && [[ ${#NDS_GIT_KEY_PATH[@]} -gt 0 ]]; then
        if [[ "$portable" == "true" ]] && declare -f nds_git_bundle_key_paths &>/dev/null \
            && [[ -n "${ nds_git_bundle_key_paths; }" ]]; then
            echo "# Copy secrets/git/* from the install zip to /root/.ssh/ (chmod 600) before starting NDS."
        fi
        echo "declare -gA NDS_GIT_KEY_PATH=("
        for url in "${!NDS_GIT_KEY_PATH[@]}"; do
            path="${NDS_GIT_KEY_PATH[$url]}"
            if [[ "$portable" == "true" ]] && declare -f nds_git_bundle_restore_key_path &>/dev/null; then
                path="${ nds_git_bundle_restore_key_path "$path"; }"
            fi
            printf '  [%s]=%s\n' "${ _nds_git_shell_quote "$url"; }" \
                "${ _nds_git_shell_quote "$path"; }"
        done
        echo ")"
        echo ""
    fi
    if _nds_git_is_assoc NDS_GIT_KEY_KIND && [[ ${#NDS_GIT_KEY_KIND[@]} -gt 0 ]]; then
        echo "declare -gA NDS_GIT_KEY_KIND=("
        for url in "${!NDS_GIT_KEY_KIND[@]}"; do
            printf '  [%s]=%s\n' "${ _nds_git_shell_quote "$url"; }" \
                "${ _nds_git_shell_quote "${NDS_GIT_KEY_KIND[$url]}"; }"
        done
        echo ")"
        echo ""
    fi
    if _nds_git_is_assoc NDS_GIT_EXISTING_KEY && [[ ${#NDS_GIT_EXISTING_KEY[@]} -gt 0 ]]; then
        echo "declare -gA NDS_GIT_EXISTING_KEY=("
        for url in "${!NDS_GIT_EXISTING_KEY[@]}"; do
            printf '  [%s]=%s\n' "${ _nds_git_shell_quote "$url"; }" \
                "${ _nds_git_shell_quote "${NDS_GIT_EXISTING_KEY[$url]}"; }"
        done
        echo ")"
        echo ""
    fi
    if _nds_git_is_assoc NDS_GIT_KEY_MODE && [[ ${#NDS_GIT_KEY_MODE[@]} -gt 0 ]]; then
        echo "declare -gA NDS_GIT_KEY_MODE=("
        for url in "${!NDS_GIT_KEY_MODE[@]}"; do
            printf '  [%s]=%s\n' "${ _nds_git_shell_quote "$url"; }" \
                "${ _nds_git_shell_quote "${NDS_GIT_KEY_MODE[$url]}"; }"
        done
        echo ")"
        echo ""
    fi
}
