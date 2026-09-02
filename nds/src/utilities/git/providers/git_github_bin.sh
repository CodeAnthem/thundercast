#!/usr/bin/env bash
# ==================================================================================================
# Git utility - GitHub CLI binary download / cache (no step UI)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-05 | Modified: 2026-09-02
# Description:   Prefetch + cache gh via nix; silent (wizard chrome lives in wizard/git/lib).
# ==================================================================================================

if [[ -z "${GIT_GH_BIN_CACHE_FILE:-}" ]]; then
    if [[ -n "${NDS_GH_BIN_CACHE_FILE:-}" ]]; then
        GIT_GH_BIN_CACHE_FILE="${NDS_GH_BIN_CACHE_FILE}"
    elif [[ -n "${NDS_GIT_GH_BIN_CACHE_FILE:-}" ]]; then
        GIT_GH_BIN_CACHE_FILE="${NDS_GIT_GH_BIN_CACHE_FILE}"
    else
        GIT_GH_BIN_CACHE_FILE="/tmp/nds-gh-bin"
    fi
fi
export GIT_GH_BIN_CACHE_FILE

_git_gh_nix() {
    nix --extra-experimental-features "nix-command flakes" "$@"
}

_git_gh_persist_bin_cache() {
    local bin="${NDS_GH_BIN:-${NDS_GIT_GH_BIN:-}}"
    [[ -n "$bin" && -x "$bin" ]] || return 1
    NDS_GH_BIN="$bin"
    NDS_GIT_GH_BIN="$bin"
    GH_BIN="$bin"
    export NDS_GH_BIN NDS_GIT_GH_BIN GH_BIN
    printf '%s\n' "$bin" >"${GIT_GH_BIN_CACHE_FILE}" 2>/dev/null || true
    if [[ -n "${NDS_GH_BIN_CACHE_FILE:-}" && "${NDS_GH_BIN_CACHE_FILE}" != "${GIT_GH_BIN_CACHE_FILE}" ]]; then
        printf '%s\n' "$bin" >"${NDS_GH_BIN_CACHE_FILE}" 2>/dev/null || true
    fi
    if [[ -n "${NDS_GIT_GH_BIN_CACHE_FILE:-}" \
        && "${NDS_GIT_GH_BIN_CACHE_FILE}" != "${GIT_GH_BIN_CACHE_FILE}" \
        && "${NDS_GIT_GH_BIN_CACHE_FILE}" != "${NDS_GH_BIN_CACHE_FILE:-}" ]]; then
        printf '%s\n' "$bin" >"${NDS_GIT_GH_BIN_CACHE_FILE}" 2>/dev/null || true
    fi
}

_git_gh_restore_bin_cache() {
    local p f
    for f in "${GIT_GH_BIN_CACHE_FILE}" \
        "${NDS_GH_BIN_CACHE_FILE:-}" \
        "${NDS_GIT_GH_BIN_CACHE_FILE:-}"; do
        [[ -n "$f" && -f "$f" ]] || continue
        p="$(<"$f")"
        [[ -n "$p" && -x "$p" ]] || continue
        NDS_GH_BIN="$p"
        NDS_GIT_GH_BIN="$p"
        GH_BIN="$p"
        export NDS_GH_BIN NDS_GIT_GH_BIN GH_BIN
        return 0
    done
    return 1
}

# Description: Realize gh in the Nix store. Prefer ISO/channel <nixpkgs> (already
# unpacked) so the live ISO does not fetch a second nixpkgs flake from the registry.
# Returns:
# - stdout: nix-build / nix build output (last /nix/store line is the gh path)
_git_gh_realize() {
    if command -v nix-build >/dev/null 2>&1 && [[ "${NIX_PATH:-}" == *nixpkgs* ]]; then
        if nix-build --no-out-link '<nixpkgs>' -A gh; then
            return 0
        fi
    fi
    _git_gh_nix build --no-link --print-out-paths nixpkgs#gh
}

# Description: Last /nix/store path in mixed nix stdout+stderr.
_git_gh_store_path_from_output() {
    local line=""
    line=$(printf '%s\n' "${1:-}" | grep -E '^/nix/store/' | tail -1) || true
    if [[ -z "$line" ]]; then
        line=$(printf '%s\n' "${1:-}" | tail -1)
    fi
    printf '%s\n' "$line"
}

_git_gh_cache_bin_from_nix() {
    local out_path="${1:-}"
    local gh_path

    if [[ -n "$out_path" && -x "${out_path}/bin/gh" ]]; then
        NDS_GH_BIN="${out_path}/bin/gh"
        NDS_GIT_GH_BIN="$NDS_GH_BIN"
        GH_BIN="$NDS_GH_BIN"
        export NDS_GH_BIN NDS_GIT_GH_BIN GH_BIN
        return 0
    fi
    gh_path=${ _git_gh_nix shell nixpkgs#gh -c command -v gh 2>/dev/null | tail -1; } || gh_path=""
    if [[ -n "$gh_path" && -x "$gh_path" ]]; then
        NDS_GH_BIN="$gh_path"
        NDS_GIT_GH_BIN="$gh_path"
        GH_BIN="$gh_path"
        export NDS_GH_BIN NDS_GIT_GH_BIN GH_BIN
        return 0
    fi
    return 1
}

# Description: True when a real gh binary is ready (git utility, PATH, or cache).
git_gh_bin_ready() {
    if declare -f git_gh_isAvailable &>/dev/null && git_gh_isAvailable; then
        return 0
    fi
    if command -v gh &>/dev/null; then
        return 0
    fi
    if [[ -n "${NDS_GH_BIN:-${NDS_GIT_GH_BIN:-${GH_BIN:-}}}" \
        && -x "${NDS_GH_BIN:-${NDS_GIT_GH_BIN:-${GH_BIN}}}" ]]; then
        return 0
    fi
    _git_gh_restore_bin_cache
}

# Description: Resolve gh without downloading (prefer git_gh_bin, else PATH/cache).
# Arguments:
# - out: <Nameref> Command prefix array
git_gh_cmd_nofetch() {
    local -n _git_gh_nofetch_out=$1
    local bin=""
    if declare -f git_gh_bin &>/dev/null; then
        bin=${ git_gh_bin; } || bin=""
        if [[ -n "$bin" ]]; then
            _git_gh_nofetch_out=("$bin")
            return 0
        fi
    fi
    if command -v gh &>/dev/null; then
        _git_gh_nofetch_out=(gh)
        return 0
    fi
    if [[ -z "${NDS_GH_BIN:-${NDS_GIT_GH_BIN:-${GH_BIN:-}}}" \
        || ! -x "${NDS_GH_BIN:-${NDS_GIT_GH_BIN:-${GH_BIN}}}" ]]; then
        _git_gh_restore_bin_cache || true
    fi
    bin="${NDS_GH_BIN:-${NDS_GIT_GH_BIN:-${GH_BIN:-}}}"
    if [[ -n "$bin" && -x "$bin" ]]; then
        _git_gh_nofetch_out=("$bin")
        return 0
    fi
    _git_gh_nofetch_out=()
    return 1
}

# Description: Prefetch / download gh via nix once (silent; optional detail log).
git_gh_prefetch() {
    local logfile="${NDS_INSTALL_DETAIL_LOG:-}"
    local prefetch_log="${NDS_RUNTIME_DIR:-/tmp/nds}/gh_prefetch.out"
    local out_path build_out rc=0

    if command -v gh &>/dev/null; then
        NDS_GH_PREFETCH_DONE=true
        NDS_GIT_GH_PREFETCH_DONE=true
        export NDS_GH_PREFETCH_DONE NDS_GIT_GH_PREFETCH_DONE
        return 0
    fi
    if [[ -n "${NDS_GH_BIN:-${NDS_GIT_GH_BIN:-}}" && -x "${NDS_GH_BIN:-${NDS_GIT_GH_BIN}}" ]]; then
        _git_gh_persist_bin_cache
        NDS_GH_PREFETCH_DONE=true
        NDS_GIT_GH_PREFETCH_DONE=true
        export NDS_GH_PREFETCH_DONE NDS_GIT_GH_PREFETCH_DONE
        return 0
    fi
    if _git_gh_restore_bin_cache; then
        NDS_GH_PREFETCH_DONE=true
        NDS_GIT_GH_PREFETCH_DONE=true
        export NDS_GH_PREFETCH_DONE NDS_GIT_GH_PREFETCH_DONE
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

    mkdir -p "$(dirname "$prefetch_log")" 2>/dev/null || true
    build_out=${ _git_gh_realize 2>&1; } || rc=$?
    printf '%s\n' "$build_out" >"$prefetch_log" 2>/dev/null || true
    if [[ -n "$logfile" ]]; then
        {
            printf '\n=== Downloading GitHub CLI (gh) ===\n'
            printf '%s\n' "$build_out"
        } >>"$logfile" 2>/dev/null || true
    fi
    out_path=${ _git_gh_store_path_from_output "$build_out"; }
    if [[ "$rc" -ne 0 ]]; then
        unset NDS_GH_PREFETCH_IN_PROGRESS NDS_GIT_GH_PREFETCH_IN_PROGRESS 2>/dev/null || true
        debug "gh prefetch failed"
        return 1
    fi
    if _git_gh_cache_bin_from_nix "$out_path"; then
        unset NDS_GH_PREFETCH_IN_PROGRESS NDS_GIT_GH_PREFETCH_IN_PROGRESS 2>/dev/null || true
        _git_gh_persist_bin_cache
        NDS_GH_PREFETCH_DONE=true
        NDS_GIT_GH_PREFETCH_DONE=true
        export NDS_GH_PREFETCH_DONE NDS_GIT_GH_PREFETCH_DONE
        return 0
    fi
    unset NDS_GH_PREFETCH_IN_PROGRESS NDS_GIT_GH_PREFETCH_IN_PROGRESS 2>/dev/null || true
    debug "gh prefetch failed"
    return 1
}

# Description: Ensure a real gh binary (PATH or cached nix). Silent.
git_gh_ensure() {
    git_gh_bin_ready && return 0
    git_gh_prefetch
}

# Description: Resolve gh command (prefetch if needed). Falls back to pkg_cmd.
# Arguments:
# - out: <Nameref> Command prefix array
git_gh_ensure_cmd() {
    local -n _git_gh_ensure_cmd_out=$1
    local -a _resolved=()
    if git_gh_cmd_nofetch _resolved; then
        _git_gh_ensure_cmd_out=("${_resolved[@]}")
        return 0
    fi
    if git_gh_prefetch && git_gh_cmd_nofetch _resolved; then
        _git_gh_ensure_cmd_out=("${_resolved[@]}")
        return 0
    fi
    if ! declare -f pkg_cmd &>/dev/null; then
        declare -f nds_requireUtility &>/dev/null && nds_requireUtility pkg || true
    fi
    if declare -f pkg_cmd &>/dev/null && pkg_cmd _resolved gh gh; then
        _git_gh_ensure_cmd_out=("${_resolved[@]}")
        return 0
    fi
    _git_gh_ensure_cmd_out=()
    return 1
}
