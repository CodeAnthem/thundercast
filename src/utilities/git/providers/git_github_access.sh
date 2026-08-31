#!/usr/bin/env bash
# ==================================================================================================
# Git utility - GitHub provider access prompt
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-29 | Modified: 2026-08-31
# ==================================================================================================

# Description: Generic options plus GitHub CLI for this account.
# Arguments:
# - safeUrl: <String> Indexed safeUrl
# - reason:  <String|optional>
# Returns:
# - <Bool> 0 when access was satisfied
git_github_promptAccess() {
    local safeUrl="$1"
    local reason="${2:-}"
    local choice dest host owner key_path display
    dest=${ git_store_getKeyPath "$safeUrl"; } || return 1
    host=${ git_store_get "$safeUrl" host; }
    owner=${ git_store_get "$safeUrl" owner; }
    display=${ git_store_getUrlHttps "$safeUrl"; }

    if [[ -n "$reason" ]]; then
        printf '\nRepo %s (GitHub) needs access: %s\n' "$display" "$reason" >&2
    else
        printf '\nRepo %s (GitHub) needs access.\n' "$display" >&2
    fi
    printf '  1) Path to existing private key\n' >&2
    printf '  2) Paste private key\n' >&2
    printf '  3) Generate a new key (print public key; add it on GitHub yourself)\n' >&2
    printf '  4) GitHub CLI (gh) — used for every repo of %s/%s\n' "$host" "$owner" >&2
    printf 'Choice [1-4]: ' >&2
    read -r choice

    case "$choice" in
        1|2|3)
            _git_generic_applyAccessChoice "$safeUrl" "$choice"
            return $?
            ;;
        4)
            if ! git_gh_isAvailable; then
                err "gh is not on PATH"
                return 1
            fi
            if ! git_gh_isAuthenticated; then
                git_gh_login || {
                    err "gh login failed"
                    return 1
                }
            fi
            git_gh_setAccountUsingGh "$safeUrl"
            if ! git_store_hasKey "$safeUrl"; then
                git_helper_keys_create "$dest" "git-key" || return 1
                git_store_set "$safeUrl" keyPath "$dest"
                git_github_addDeployKey "$safeUrl" "${dest}.pub" || {
                    err "deploy key add failed; public key:"
                    git_helper_keys_prompt_showPublicKey "$dest"
                    return 1
                }
            fi
            key_path=${ git_store_get "$safeUrl" keyPath; }
            git_generic_probeWithKey "$safeUrl" "$key_path"
            ;;
        *)
            err "invalid choice: $choice"
            return 1
            ;;
    esac
}
