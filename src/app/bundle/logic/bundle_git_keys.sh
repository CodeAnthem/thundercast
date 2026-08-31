#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git SSH keys for the install bundle
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-15 | Modified: 2026-08-31
# Description:   Copy session git keys into secrets/git/; restore KEY_PATH → /root/.ssh/<name>
# ==================================================================================================

# Description: True when path is a private key file (not .pub, ssh config, or helper).
# Arguments:
# - path: <String> Candidate file
# Returns:
# - <Bool> 0 when it should go in the bundle
nds_git_bundle_is_private_key() {
    local path="$1" base
    [[ -f "$path" ]] || return 1
    base="$(basename "$path")"
    case "$base" in
        *.pub|authorized_keys*|known_hosts*|config|nds-git.map|nds-git-ssh)
            return 1
            ;;
    esac
    return 0
}

# Description: Archive/restore basename for a private key path.
# Arguments:
# - path: <String> Absolute private key path
# Returns:
# - <String> basename (stdout)
nds_git_bundle_key_dest_name() {
    local path="$1" base
    [[ -n "$path" ]] || return 1
    base="$(basename "$path")"
    [[ "$base" != *.pub ]] || return 1
    printf '%s\n' "$base"
}

# Description: Unique private key files used for git access this session.
# Returns:
# - <String> Absolute paths (stdout, one per line)
nds_git_bundle_key_paths() {
    local url path deploy_dir
    local -a paths=()

    if declare -p NDS_GIT_KEY_PATH &>/dev/null && [[ ${#NDS_GIT_KEY_PATH[@]} -gt 0 ]]; then
        for url in "${!NDS_GIT_KEY_PATH[@]}"; do
            path="${NDS_GIT_KEY_PATH[$url]}"
            if nds_git_bundle_is_private_key "$path"; then
                paths+=("$path")
            fi
        done
    fi
    if declare -f nds_git_keys_list &>/dev/null; then
        while IFS= read -r path; do
            if nds_git_bundle_is_private_key "$path"; then
                paths+=("$path")
            fi
        done < <(nds_git_keys_list 2>/dev/null || true)
    fi
    deploy_dir="${NDS_GIT_DEPLOY_KEYS_DIR:-/root/.ssh}"
    if [[ -d "$deploy_dir" ]]; then
        for path in "${deploy_dir}"/nds_deploy_* "${deploy_dir}"/nds_imported_*; do
            if nds_git_bundle_is_private_key "$path"; then
                paths+=("$path")
            fi
        done
    fi

    if [[ ${#paths[@]} -gt 0 ]]; then
        printf '%s\n' "${paths[@]}" | awk 'NF' | sort -u
    fi
    return 0
}

# Description: Restore-time path for a key file (/root/.ssh/<basename> when the file exists).
# Arguments:
# - path: <String> Absolute path recorded in NDS_GIT_KEY_PATH
# Returns:
# - <String> Path to use on the next ISO (stdout)
nds_git_bundle_restore_key_path() {
    local path="$1" dest
    if [[ -n "$path" ]] && nds_git_bundle_is_private_key "$path"; then
        dest="$(nds_git_bundle_key_dest_name "$path")"
        printf '/root/.ssh/%s\n' "$dest"
        return 0
    fi
    printf '%s\n' "$path"
}

# Description: Register session git private keys (and .pub) under secrets/git/ in the bundle.
nds_git_bundle_contrib() {
    local path dest pub
    declare -f nds_bundle_register_file &>/dev/null || return 0

    while IFS= read -r path; do
        [[ -n "$path" ]] || continue
        dest="$(nds_git_bundle_key_dest_name "$path")" || continue
        nds_bundle_register_file "secrets/git/${dest}" "$path"
        pub="${path}.pub"
        if [[ -f "$pub" ]]; then
            nds_bundle_register_file "secrets/git/${dest}.pub" "$pub"
        fi
    done < <(nds_git_bundle_key_paths)
}

if declare -f nds_bundle_register_hook &>/dev/null; then
    nds_bundle_register_hook nds_git_bundle_contrib
fi
