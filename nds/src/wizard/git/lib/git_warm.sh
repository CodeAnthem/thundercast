#!/usr/bin/env bash
# ==================================================================================================
# NDS - Wizard chrome for warming gh / qrencode (step UI only)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-02 | Modified: 2026-09-02
# Description:   Wraps utilities/git git_gh_* and pkg/qr with nds_step_* chrome.
# ==================================================================================================

# Description: Prefetch gh with step UI when not already ready.
nds_git_warm_gh() {
    if declare -f git_gh_bin_ready &>/dev/null && git_gh_bin_ready; then
        return 0
    fi
    declare -f nds_install_log &>/dev/null \
        && nds_install_log "gh: realizing CLI via Nix (ISO <nixpkgs> if NIX_PATH has it, else nixpkgs#gh)" \
        || true
    if declare -f nds_step_exec &>/dev/null; then
        nds_step_exec "Downloading GitHub CLI (gh)" git_gh_prefetch || return 1
    else
        git_gh_prefetch || return 1
    fi
    declare -f nds_install_log &>/dev/null \
        && nds_install_log "gh: CLI ready (${NDS_GH_BIN:-${NDS_GIT_GH_BIN:-}})" \
        || true
    return 0
}

# Description: Warm gh then resolve command via git_gh_ensure_cmd.
# Arguments:
# - out: <Nameref> Command prefix array
nds_git_warm_gh_cmd() {
    nds_git_warm_gh || true
    git_gh_ensure_cmd "$@"
}

# Description: Ensure qrencode + qr utility, then print payload.
# Arguments:
# - payload: <String> Text to encode
nds_git_qr_print() {
    local payload="${1:-}"
    local bin
    [[ -n "$payload" ]] || return 0

    nds_requireUtility pkg || return 1
    if ! command -v qrencode &>/dev/null; then
        if declare -f nds_step_warm_pkg &>/dev/null; then
            nds_step_warm_pkg qrencode qrencode || return 1
        elif declare -f nds_step_exec &>/dev/null; then
            nds_step_exec "Preparing qrencode" pkg_warm qrencode qrencode || return 1
        else
            pkg_warm qrencode qrencode || return 1
        fi
    fi
    if declare -f pkg_cmd &>/dev/null; then
        local -a _qr=()
        if pkg_cmd _qr qrencode qrencode && [[ -n "${_qr[0]:-}" ]]; then
            bin=$(command -v "${_qr[0]}" 2>/dev/null || true)
            [[ -x "$bin" ]] && export QR_BIN="$bin"
        fi
    fi
    nds_requireUtility qr || return 1
    qr_print "$payload"
}
