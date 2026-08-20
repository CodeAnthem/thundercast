#!/usr/bin/env bash
# ==================================================================================================
# NDS - GitHub CLI session (login state / cleanup)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-07 | Modified: 2026-08-05
# Description:   Session helpers for the gh CLI — no git key/repo policy
# ==================================================================================================

# Description: Candidate gh hosts.yml paths (root + live-ISO user + sudo user).
_nds_gh_hosts_yml_candidates() {
    local -A seen=()
    local f h
    local -a candidates=()

    [[ -n "${GH_CONFIG_DIR:-}" ]] && candidates+=("${GH_CONFIG_DIR}/hosts.yml")
    [[ -n "${XDG_CONFIG_HOME:-}" ]] && candidates+=("${XDG_CONFIG_HOME}/gh/hosts.yml")
    candidates+=("${HOME:-/root}/.config/gh/hosts.yml")
    candidates+=("/root/.config/gh/hosts.yml")
    candidates+=("/home/nixos/.config/gh/hosts.yml")

    if [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
        h="$(getent passwd "$SUDO_USER" 2>/dev/null | cut -d: -f6 || true)"
        [[ -n "$h" ]] && candidates+=("${h}/.config/gh/hosts.yml")
    fi

    for f in "${candidates[@]}"; do
        [[ -n "$f" ]] || continue
        [[ -n "${seen[$f]:-}" ]] && continue
        seen[$f]=1
        printf '%s\n' "$f"
    done
}

# Description: True when gh hosts.yml still lists github.com (leftover ISO login).
nds_gh_hosts_yml_has_github() {
    local f
    while IFS= read -r f; do
        [[ -f "$f" ]] || continue
        grep -qE '^[[:space:]]*['\''"]?github\.com['\''"]?:' "$f" 2>/dev/null && return 0
    done < <(_nds_gh_hosts_yml_candidates)
    return 1
}

_nds_gh_wipe_hosts_yml() {
    local f
    while IFS= read -r f; do
        [[ -f "$f" ]] && rm -f "$f"
    done < <(_nds_gh_hosts_yml_candidates)
}

_nds_gh_auth_status_home() {
    local home="$1"
    local -a gh_cmd=()
    local status_out

    nds_gh_cmd_nofetch gh_cmd || return 1
    status_out="$(HOME="$home" "${gh_cmd[@]}" auth status -h github.com 2>&1)" || status_out=""
    if grep -qiE 'Logged in to github\.com|✓.*github\.com|github\.com account' <<<"$status_out"; then
        return 0
    fi
    HOME="$home" "${gh_cmd[@]}" auth status -h github.com &>/dev/null
}

# Description: True when gh reports a logged-in github.com host, or leftover hosts.yml.
nds_gh_host_logged_in() {
    local home h
    local -a gh_cmd=()

    if nds_gh_cmd_nofetch gh_cmd; then
        for home in "${HOME:-/root}" /root /home/nixos; do
            [[ -d "$home" ]] || continue
            _nds_gh_auth_status_home "$home" && return 0
        done
        if [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
            h="$(getent passwd "$SUDO_USER" 2>/dev/null | cut -d: -f6 || true)"
            if [[ -n "$h" && -d "$h" ]]; then
                _nds_gh_auth_status_home "$h" && return 0
            fi
        fi
    fi
    nds_gh_hosts_yml_has_github
}

# Description: True when this process already has an active gh login.
nds_gh_session_active() {
    [[ "${NDS_GH_SESSION_ACTIVE:-${NDS_GIT_GH_SESSION_ACTIVE:-}}" == "true" ]] && return 0
    if nds_gh_host_logged_in; then
        NDS_GH_SESSION_ACTIVE=true
        NDS_GIT_GH_SESSION_ACTIVE=true
        export NDS_GH_SESSION_ACTIVE NDS_GIT_GH_SESSION_ACTIVE
        nds_gh_probe_registration_scopes && nds_gh_session_mark_scopes_ok || true
        return 0
    fi
    return 1
}

# Description: Mark gh as logged in for this NDS session (cleanup later).
nds_gh_session_mark_active() {
    NDS_GH_SESSION_ACTIVE=true
    NDS_GIT_GH_SESSION_ACTIVE=true
    export NDS_GH_SESSION_ACTIVE NDS_GIT_GH_SESSION_ACTIVE
    NDS_GH_LEFTOVER=true
    NDS_GIT_GH_LEFTOVER=true
    export NDS_GH_LEFTOVER NDS_GIT_GH_LEFTOVER
}

# Description: Record that gh has admin:public_key (or equivalent) scope.
nds_gh_session_mark_scopes_ok() {
    NDS_GH_HAS_KEY_SCOPE=true
    NDS_GIT_GH_HAS_KEY_SCOPE=true
    export NDS_GH_HAS_KEY_SCOPE NDS_GIT_GH_HAS_KEY_SCOPE
    nds_gh_session_mark_active
}

# Description: Probe gh auth status for admin:public_key / repo scopes.
nds_gh_probe_registration_scopes() {
    local -a gh_cmd=()
    local out

    nds_gh_cmd gh_cmd || return 1
    out=$("${gh_cmd[@]}" auth status --show-token-scopes 2>&1) || true
    if grep -qiE 'admin:public_key|\brepo\b' <<< "$out"; then
        return 0
    fi
    out=$("${gh_cmd[@]}" auth status 2>&1) || return 1
    grep -qiE 'admin:public_key|\brepo\b|Token scopes:.*repo' <<< "$out"
}

# Description: True when gh can register SSH keys (cached or probed).
nds_gh_has_key_scope() {
    [[ "${NDS_GH_HAS_KEY_SCOPE:-${NDS_GIT_GH_HAS_KEY_SCOPE:-}}" == "true" ]] && return 0
    if nds_gh_probe_registration_scopes; then
        nds_gh_session_mark_scopes_ok
        return 0
    fi
    return 1
}

# Description: End temporary gh auth on the live ISO (SSH keys on GitHub are kept).
nds_gh_session_cleanup() {
    local -a gh_cmd=()
    local home h
    local had_session=false

    if nds_gh_host_logged_in || [[ "${NDS_GH_LEFTOVER:-${NDS_GIT_GH_LEFTOVER:-}}" == "true" ]] \
        || [[ "${NDS_GH_SESSION_ACTIVE:-${NDS_GIT_GH_SESSION_ACTIVE:-}}" == "true" ]]; then
        had_session=true
    else
        return 0
    fi

    unset NDS_GH_SESSION_ACTIVE NDS_GIT_GH_SESSION_ACTIVE 2>/dev/null || true
    unset NDS_GH_HAS_KEY_SCOPE NDS_GIT_GH_HAS_KEY_SCOPE 2>/dev/null || true
    unset NDS_GH_LEFTOVER NDS_GIT_GH_LEFTOVER 2>/dev/null || true

    if ! nds_gh_cmd_nofetch gh_cmd; then
        if nds_gh_ensure; then
            nds_gh_cmd_nofetch gh_cmd || true
        fi
    fi

    if [[ ${#gh_cmd[@]} -gt 0 ]]; then
        for home in "${HOME:-/root}" /root /home/nixos; do
            [[ -d "$home" ]] || continue
            HOME="$home" "${gh_cmd[@]}" auth logout --hostname github.com --yes &>/dev/null \
                || HOME="$home" "${gh_cmd[@]}" auth logout --hostname github.com -y &>/dev/null \
                || printf 'y\n' | HOME="$home" "${gh_cmd[@]}" auth logout --hostname github.com &>/dev/null \
                || true
        done
        if [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
            h="$(getent passwd "$SUDO_USER" 2>/dev/null | cut -d: -f6 || true)"
            if [[ -n "$h" && -d "$h" ]]; then
                HOME="$h" "${gh_cmd[@]}" auth logout --hostname github.com --yes &>/dev/null \
                    || HOME="$h" "${gh_cmd[@]}" auth logout --hostname github.com -y &>/dev/null \
                    || true
            fi
        fi
    fi

    _nds_gh_wipe_hosts_yml

    if nds_gh_host_logged_in; then
        warn "Could not clear gh session on this ISO"
        return 1
    fi

    if [[ "$had_session" == "true" ]]; then
        success "Cleared gh session from this live ISO (SSH keys on GitHub were kept)"
        declare -f nds_install_log &>/dev/null \
            && nds_install_log "gh: session cleared from live ISO (SSH key left on GitHub)"
    fi
    return 0
}

# Description: True when gh is logged in and has key-registration scope.
nds_gh_session_ready() {
    nds_gh_session_active && nds_gh_has_key_scope
}

# Description: Unset GITHUB_TOKEN / GH_TOKEN so device login is not blocked.
nds_gh_unset_blocking_tokens() {
    if [[ -n "${GITHUB_TOKEN:-}" ]]; then
        warn "GITHUB_TOKEN is set — clearing for gh device login (invalid tokens cause 401 errors)"
        unset GITHUB_TOKEN
    fi
    if [[ -n "${GH_TOKEN:-}" ]]; then
        warn "GH_TOKEN is set — clearing for gh device login"
        unset GH_TOKEN
    fi
}

