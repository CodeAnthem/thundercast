#!/usr/bin/env bash
# ==================================================================================================
# pkg utility - PATH or nixpkgs# resolve/run (no step UI)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-02 | Modified: 2026-09-02
# ==================================================================================================

: "${PKG_NIX_CONFIG:=${NDS_PKG_NIX_CONFIG:-}}"

# Description: Resolve command prefix for a binary via PATH or nixpkgs#attr.
# Arguments:
# - out:  <Nameref> Command array
# - bin:  <String> Binary name on PATH
# - attr: <String|optional> nixpkgs attribute (default: same as bin)
pkg_cmd() {
    local -n _pkg_out=$1
    local bin="$2"
    local attr="${3:-$2}"

    if command -v "$bin" &>/dev/null; then
        _pkg_out=("$bin")
        return 0
    fi
    if command -v nix &>/dev/null; then
        _pkg_out=(
            nix --extra-experimental-features "nix-command flakes"
            shell "nixpkgs#${attr}" -c "$bin"
        )
        return 0
    fi
    _pkg_out=()
    return 1
}

# Description: Run binary with args (PATH or nix shell).
pkg_run() {
    local bin="$1" attr="$2"
    shift 2
    local -a cmd=()

    pkg_cmd cmd "$bin" "$attr" || return 127
    if [[ -n "${PKG_NIX_CONFIG:-}" ]]; then
        env NIX_CONFIG="$PKG_NIX_CONFIG" "${cmd[@]}" "$@"
    else
        "${cmd[@]}" "$@"
    fi
}

# Description: Warm a nix-backed binary (silent).
pkg_warm() {
    local bin="$1" attr="$2"
    local -a cmd=()

    pkg_cmd cmd "$bin" "$attr" || return 1
    if [[ -n "${PKG_NIX_CONFIG:-}" ]]; then
        env NIX_CONFIG="$PKG_NIX_CONFIG" "${cmd[@]}" --version >/dev/null 2>&1 \
            || env NIX_CONFIG="$PKG_NIX_CONFIG" "${cmd[@]}" -h >/dev/null 2>&1 \
            || true
    else
        "${cmd[@]}" --version >/dev/null 2>&1 || "${cmd[@]}" -h >/dev/null 2>&1 || true
    fi
    return 0
}

pkg_onLoad() { return 0; }
pkg_onExit() { return 0; }
