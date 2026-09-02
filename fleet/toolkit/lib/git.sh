# ==================================================================================================
# Thundercast - leaf git validate + commit/push
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-19 | Modified: 2026-08-20
# Description:   Refuse to commit private keys or plaintext secrets/
# ==================================================================================================

tcast_git_scan_private() {
    local leaf="$1" f
    while IFS= read -r f; do
        [[ -f "${leaf}/${f}" ]] || continue
        [[ "$f" == *.md ]] && continue
        [[ "${f##*/}" == .gitkeep ]] && continue
        if grep -qE 'AGE-SECRET-KEY-|BEGIN OPENSSH PRIVATE KEY|BEGIN RSA PRIVATE KEY|BEGIN EC PRIVATE KEY' "${leaf}/${f}" 2>/dev/null; then
            printf '%s\n' "$f"
        fi
    done < <(git -C "$leaf" ls-files -co --exclude-standard)
}

tcast_git_scan_plain_secrets() {
    local leaf="$1" f
    while IFS= read -r f; do
        [[ "$f" == secrets/* ]] || continue
        [[ "$f" == *.md ]] && continue
        [[ "${f##*/}" == .gitkeep ]] && continue
        [[ "$f" == *.yaml || "$f" == *.yml ]] || continue
        [[ -f "${leaf}/${f}" ]] || continue
        if ! grep -q '^sops:' "${leaf}/${f}" 2>/dev/null; then
            printf '%s\n' "$f"
        fi
    done < <(git -C "$leaf" ls-files -co --exclude-standard -- secrets)
}

tcast_git_validate() {
    local leaf hit
    leaf="$(tcast_leaf)"
    hit="$(tcast_git_scan_private "$leaf" || true)"
    if [[ -n "$hit" ]]; then
        echo "REFUSE: private key material would be committed:" >&2
        echo "$hit" >&2
        return 1
    fi
    hit="$(tcast_git_scan_plain_secrets "$leaf" || true)"
    if [[ -n "$hit" ]]; then
        echo "REFUSE: unencrypted secrets/ files:" >&2
        echo "$hit" >&2
        return 1
    fi
    return 0
}

tcast_git_status_short() {
    git -C "$(tcast_leaf)" status -sb
}

tcast_git_commit_push() {
    local leaf msg="${1:-toolkit: apply sops/register}"
    leaf="$(tcast_leaf)"
    tcast_git_validate || return 1
    tcast_git_ssh_env
    git -C "$leaf" add -A
    if git -C "$leaf" diff --cached --quiet; then
        tcast_info "nothing to commit"
        return 0
    fi
    git -C "$leaf" -c user.email="${TCAST_GIT_EMAIL:-toolkit@localhost}" \
        -c user.name="${TCAST_GIT_NAME:-toolkit}" \
        commit -m "$msg" || return 1
    if [[ "${TCAST_GIT_PUSH:-1}" == "0" ]]; then
        tcast_info "commit only (TCAST_GIT_PUSH=0)"
        return 0
    fi
    git -C "$leaf" push origin HEAD || return 1
    tcast_info "pushed — nodes pick this up via comin"
}
