#!/usr/bin/env bash
# ==================================================================================================
# NDS - GitHub CLI binary ensure (PATH / nix cache)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-05 | Modified: 2026-08-16
# Description:   Prefetch + cache gh; may show step UI + logs on first download.
#                Session → gh_session.sh; API → gh_api.sh; git only orchestrates.
# ==================================================================================================

: "${NDS_GH_BIN_CACHE_FILE:=/tmp/nds-gh-bin}"
# Compat with prior git-scoped cache path env.
: "${NDS_GIT_GH_BIN_CACHE_FILE:=${NDS_GH_BIN_CACHE_FILE}}"

_nds_gh_nix() {
    nix --extra-experimental-features "nix-command flakes" "$@"
}

_nds_gh_persist_bin_cache() {
    local bin="${NDS_GH_BIN:-${NDS_GIT_GH_BIN:-}}"
    [[ -n "$bin" && -x "$bin" ]] || return 1
    NDS_GH_BIN="$bin"
    NDS_GIT_GH_BIN="$bin"
    export NDS_GH_BIN NDS_GIT_GH_BIN
    printf '%s\n' "$bin" >"${NDS_GH_BIN_CACHE_FILE}" 2>/dev/null || true
    printf '%s\n' "$bin" >"${NDS_GIT_GH_BIN_CACHE_FILE}" 2>/dev/null || true
}

_nds_gh_restore_bin_cache() {
    local p f
    for f in "${NDS_GH_BIN_CACHE_FILE}" "${NDS_GIT_GH_BIN_CACHE_FILE}"; do
        [[ -f "$f" ]] || continue
        p="$(<"$f")"
        [[ -n "$p" && -x "$p" ]] || continue
        NDS_GH_BIN="$p"
        NDS_GIT_GH_BIN="$p"
        export NDS_GH_BIN NDS_GIT_GH_BIN
        return 0
    done
    return 1
}

# Description: Realize gh in the Nix store. Prefer ISO/channel <nixpkgs> (already
# unpacked) so the live ISO does not fetch a second nixpkgs flake from the registry.
# Returns:
# - stdout: nix-build / nix build output (last /nix/store line is the gh path)
_nds_gh_realize() {
    if command -v nix-build >/dev/null 2>&1 && [[ "${NIX_PATH:-}" == *nixpkgs* ]]; then
        if nix-build --no-out-link '<nixpkgs>' -A gh; then
            return 0
        fi
    fi
    _nds_gh_nix build --no-link --print-out-paths nixpkgs#gh
}

# Description: Last /nix/store path in mixed nix stdout+stderr.
_nds_gh_store_path_from_output() {
    local line=""
    line=$(printf '%s\n' "${1:-}" | grep -E '^/nix/store/' | tail -1) || true
    if [[ -z "$line" ]]; then
        line=$(printf '%s\n' "${1:-}" | tail -1)
    fi
    printf '%s\n' "$line"
}

_nds_gh_cache_bin_from_nix() {
    local out_path="${1:-}"
    local gh_path

    if [[ -n "$out_path" && -x "${out_path}/bin/gh" ]]; then
        NDS_GH_BIN="${out_path}/bin/gh"
        NDS_GIT_GH_BIN="$NDS_GH_BIN"
        export NDS_GH_BIN NDS_GIT_GH_BIN
        return 0
    fi
    gh_path=$(_nds_gh_nix shell nixpkgs#gh -c command -v gh 2>/dev/null | tail -1) || gh_path=""
    if [[ -n "$gh_path" && -x "$gh_path" ]]; then
        NDS_GH_BIN="$gh_path"
        NDS_GIT_GH_BIN="$gh_path"
        export NDS_GH_BIN NDS_GIT_GH_BIN
        return 0
    fi
    return 1
}

# Description: True when a real gh binary is ready (PATH or cached store path).
nds_gh_bin_ready() {
    if command -v gh &>/dev/null; then
        return 0
    fi
    if [[ -n "${NDS_GH_BIN:-${NDS_GIT_GH_BIN:-}}" && -x "${NDS_GH_BIN:-${NDS_GIT_GH_BIN}}" ]]; then
        return 0
    fi
    _nds_gh_restore_bin_cache
}

# Description: Resolve gh without downloading (PATH or cache).
# Arguments:
# - out: <Nameref> Command prefix array
nds_gh_cmd_nofetch() {
    local -n _nds_gh_out=$1
    if command -v gh &>/dev/null; then
        _nds_gh_out=(gh)
        return 0
    fi
    if [[ -z "${NDS_GH_BIN:-${NDS_GIT_GH_BIN:-}}" || ! -x "${NDS_GH_BIN:-${NDS_GIT_GH_BIN}}" ]]; then
        _nds_gh_restore_bin_cache || true
    fi
    local bin="${NDS_GH_BIN:-${NDS_GIT_GH_BIN:-}}"
    if [[ -n "$bin" && -x "$bin" ]]; then
        _nds_gh_out=("$bin")
        return 0
    fi
    _nds_gh_out=()
    return 1
}

# Description: Prefetch / download gh via nix once; step UI + logs on first use.
nds_gh_prefetch() {
    local label="Downloading GitHub CLI (gh)"
    local logfile="${NDS_INSTALL_DETAIL_LOG:-/tmp/nds_install.log}"
    local prefetch_log="${NDS_RUNTIME_DIR:-/tmp/nds}/gh_prefetch.out"
    local out_path build_out rc=0

    if command -v gh &>/dev/null; then
        NDS_GH_PREFETCH_DONE=true
        NDS_GIT_GH_PREFETCH_DONE=true
        export NDS_GH_PREFETCH_DONE NDS_GIT_GH_PREFETCH_DONE
        return 0
    fi
    if [[ -n "${NDS_GH_BIN:-${NDS_GIT_GH_BIN:-}}" && -x "${NDS_GH_BIN:-${NDS_GIT_GH_BIN}}" ]]; then
        _nds_gh_persist_bin_cache
        NDS_GH_PREFETCH_DONE=true
        NDS_GIT_GH_PREFETCH_DONE=true
        export NDS_GH_PREFETCH_DONE NDS_GIT_GH_PREFETCH_DONE
        return 0
    fi
    if _nds_gh_restore_bin_cache; then
        NDS_GH_PREFETCH_DONE=true
        NDS_GIT_GH_PREFETCH_DONE=true
        export NDS_GH_PREFETCH_DONE NDS_GIT_GH_PREFETCH_DONE
        if declare -f nds_step_start &>/dev/null; then
            nds_step_start "GitHub CLI (gh)"
            nds_step_complete "GitHub CLI ready (cached)"
        fi
        declare -f nds_install_log &>/dev/null \
            && nds_install_log "gh: CLI restored from cache (${NDS_GH_BIN})"
        return 0
    fi
    if ! command -v nix &>/dev/null; then
        return 1
    fi
    unset NDS_GH_PREFETCH_DONE NDS_GIT_GH_PREFETCH_DONE 2>/dev/null || true

    if [[ "${NDS_GH_PREFETCH_IN_PROGRESS:-${NDS_GIT_GH_PREFETCH_IN_PROGRESS:-}}" == "true" ]]; then
        return 1
    fi
    NDS_GH_PREFETCH_IN_PROGRESS=true
    NDS_GIT_GH_PREFETCH_IN_PROGRESS=true

    declare -f nds_install_log &>/dev/null \
        && nds_install_log "gh: realizing CLI via Nix (ISO <nixpkgs> if NIX_PATH has it, else nixpkgs#gh)" \
        || true

    if declare -f nds_step_start &>/dev/null; then
        nds_step_start "$label"
        mkdir -p "$(dirname "$prefetch_log")"
        (
            _nds_gh_realize
        ) >"$prefetch_log" 2>&1 &
        local pid=$!
        declare -f nds_step_spinner &>/dev/null && nds_step_spinner "$pid" "$label"
        wait "$pid" || rc=$?
        build_out=$(<"$prefetch_log")
        {
            printf '\n=== %s ===\n' "$label"
            printf '%s\n' "$build_out"
        } >>"$logfile"
    else
        declare -f info &>/dev/null && info "${label} — one-time download..." || true
        build_out=$(_nds_gh_realize 2>&1) || rc=$?
        {
            printf '\n=== %s ===\n' "$label"
            printf '%s\n' "$build_out"
        } >>"$logfile"
    fi
    out_path=$(_nds_gh_store_path_from_output "$build_out")
    if [[ "$rc" -ne 0 ]]; then
        unset NDS_GH_PREFETCH_IN_PROGRESS NDS_GIT_GH_PREFETCH_IN_PROGRESS 2>/dev/null || true
        declare -f nds_step_fail &>/dev/null && nds_step_fail "$label"
        debug "gh prefetch failed"
        return 1
    fi
    if _nds_gh_cache_bin_from_nix "$out_path"; then
        unset NDS_GH_PREFETCH_IN_PROGRESS NDS_GIT_GH_PREFETCH_IN_PROGRESS 2>/dev/null || true
        _nds_gh_persist_bin_cache
        declare -f nds_step_complete &>/dev/null && nds_step_complete "$label"
        NDS_GH_PREFETCH_DONE=true
        NDS_GIT_GH_PREFETCH_DONE=true
        export NDS_GH_PREFETCH_DONE NDS_GIT_GH_PREFETCH_DONE
        declare -f nds_install_log &>/dev/null \
            && nds_install_log "gh: CLI ready (${NDS_GH_BIN})"
        return 0
    fi
    unset NDS_GH_PREFETCH_IN_PROGRESS NDS_GIT_GH_PREFETCH_IN_PROGRESS 2>/dev/null || true
    declare -f nds_step_fail &>/dev/null && nds_step_fail "$label"
    debug "gh prefetch failed"
    return 1
}

# Description: Ensure a real gh binary (PATH or cached nix). Animates on first download.
nds_gh_ensure() {
    nds_gh_bin_ready && return 0
    nds_gh_prefetch
}

# Description: Resolve gh command (prefetch if needed). Falls back to nds_pkg_cmd.
# Arguments:
# - out: <Nameref> Command prefix array
nds_gh_cmd() {
    local -n _nds_gh_cmd_out=$1
    local -a _resolved=()
    if nds_gh_cmd_nofetch _resolved; then
        _nds_gh_cmd_out=("${_resolved[@]}")
        return 0
    fi
    if nds_gh_prefetch && nds_gh_cmd_nofetch _resolved; then
        _nds_gh_cmd_out=("${_resolved[@]}")
        return 0
    fi
    if declare -f nds_pkg_cmd &>/dev/null && nds_pkg_cmd _resolved gh gh; then
        _nds_gh_cmd_out=("${_resolved[@]}")
        return 0
    fi
    _nds_gh_cmd_out=()
    return 1
}

