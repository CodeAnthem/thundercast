#!/usr/bin/env bash
# ==================================================================================================
# Git utility - URL, ssh command, probe, and clone
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# ==================================================================================================

# shellcheck source=../../setup_TEST.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../setup_TEST.sh"
import_dir "$(dirname "${BASH_SOURCE[0]}")" --depth 0

_git_log=()
git() { _git_log+=("${GIT_SSH_COMMAND}|$*"); return 0; }

suite_git() {
    local got keys
    keys=$(mktemp -d)

    bts_section "Safe URL"
    got=${ git_url_safe 'git@github.com:Owner/Repo.git'; }
    if [[ "$got" == github.com_owner_repo ]]; then
        bts_pass "ssh form safe url is host_owner_repo lowercase"
    else
        bts_fail "ssh safe url was '${got}'"
    fi
    got=${ git_url_safe 'https://github.com/Owner/Repo.git'; }
    if [[ "$got" == github.com_owner_repo ]]; then
        bts_pass "https form safe url matches the ssh form"
    else
        bts_fail "https safe url was '${got}'"
    fi
    got=${ git_url_safe 'git@github.com:Owner/Repo'; }
    if [[ "$got" == github.com_owner_repo ]]; then
        bts_pass "scp form safe url matches the ssh form"
    else
        bts_fail "scp safe url was '${got}'"
    fi

    bts_section "SSH command"
    printf '%s\n' key > "${keys}/github.com_owner_repo"
    got=${ git_sshCommand "$keys" 'https://github.com/Owner/Repo.git'; }
    if [[ "$got" == "ssh -i ${keys}/github.com_owner_repo -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new" ]]; then
        bts_pass "ssh command uses the per-url key"
    else
        bts_fail "ssh command was '${got}'"
    fi
    rm -f "${keys}/github.com_owner_repo"
    printf '%s\n' def > "${keys}/default"
    got=${ git_sshCommand "$keys" 'https://github.com/Owner/Repo.git'; }
    if [[ "$got" == "ssh -i ${keys}/default -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new" ]]; then
        bts_pass "ssh command falls back to default"
    else
        bts_fail "default ssh command was '${got}'"
    fi

    bts_section "Probe and clone"
    _git_log=()
    git_probe "$keys" 'https://github.com/Owner/Repo.git'
    if [[ "${_git_log[0]}" == *"ssh -i ${keys}/default"* && "${_git_log[0]}" == *'ls-remote https://github.com/Owner/Repo.git' ]]; then
        bts_pass "git_probe sets GIT_SSH_COMMAND"
    else
        bts_fail "probe log was '${_git_log[0]-}'"
    fi
    _git_log=()
    git_clone "$keys" 'https://github.com/Owner/Repo.git' /tmp/dest --depth 1
    if [[ "${_git_log[0]}" == *"ssh -i ${keys}/default"* && "${_git_log[0]}" == *'clone --depth 1 https://github.com/Owner/Repo.git /tmp/dest' ]]; then
        bts_pass "git_clone sets GIT_SSH_COMMAND"
    else
        bts_fail "clone log was '${_git_log[0]-}'"
    fi
    rm -rf "$keys"
}
