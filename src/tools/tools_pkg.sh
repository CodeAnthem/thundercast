#!/usr/bin/env bash
# ==================================================================================================
# NDS - Package binary resolve (PATH or nixpkgs#)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-05 | Modified: 2026-08-05
# Description:   Shared helper — ensure may show step UI + logs on first nix warm
# ==================================================================================================

# Optional NIX_CONFIG applied when running via nix shell / nix run.
: "${NDS_PKG_NIX_CONFIG:=}"

# Description: Resolve command prefix for a binary via PATH or nixpkgs#attr.
# Arguments:
# - out:   <Nameref> Command array (e.g. (qrencode) or (nix shell … -c qrencode))
# - bin:   <String>  Binary name on PATH
# - attr:  <String|optional> nixpkgs attribute (default: same as bin)
# Returns:
# - 0 when resolvable
nds_pkg_cmd() {
    local -n _nds_pkg_out=$1
    local bin="$2"
    local attr="${3:-$2}"

    if command -v "$bin" &>/dev/null; then
        _nds_pkg_out=("$bin")
        return 0
    fi
    if command -v nix &>/dev/null; then
        _nds_pkg_out=(
            nix --extra-experimental-features "nix-command flakes"
            shell "nixpkgs#${attr}" -c "$bin"
        )
        return 0
    fi
    _nds_pkg_out=()
    return 1
}

# Description: Run binary with args (PATH or nix shell). Honors NDS_PKG_NIX_CONFIG.
# Arguments:
# - bin:  <String> Binary name
# - attr: <String> nixpkgs attribute
# - ...:  args passed to the binary
nds_pkg_run() {
    local bin="$1" attr="$2"
    shift 2
    local -a cmd=()

    nds_pkg_cmd cmd "$bin" "$attr" || return 127
    if [[ -n "${NDS_PKG_NIX_CONFIG:-}" ]]; then
        env NIX_CONFIG="$NDS_PKG_NIX_CONFIG" "${cmd[@]}" "$@"
    else
        "${cmd[@]}" "$@"
    fi
}

# Description: Warm a nix-backed binary (silent; used under step spinner).
# Arguments:
# - bin:  <String> Binary name
# - attr: <String> nixpkgs attribute
nds_pkg_warm() {
    local bin="$1" attr="$2"
    local -a cmd=()

    nds_pkg_cmd cmd "$bin" "$attr" || return 1
    if [[ -n "${NDS_PKG_NIX_CONFIG:-}" ]]; then
        env NIX_CONFIG="$NDS_PKG_NIX_CONFIG" "${cmd[@]}" --version >/dev/null 2>&1 \
            || env NIX_CONFIG="$NDS_PKG_NIX_CONFIG" "${cmd[@]}" -h >/dev/null 2>&1 \
            || true
    else
        "${cmd[@]}" --version >/dev/null 2>&1 || "${cmd[@]}" -h >/dev/null 2>&1 || true
    fi
    return 0
}

# Description: Ensure binary is callable. Uses step animation + logs when nix must warm
# on first use; PATH hits stay quiet.
# Arguments:
# - bin:  <String> Binary name
# - attr: <String|optional> nixpkgs attribute
nds_pkg_ensure() {
    local bin="$1" attr="${2:-$1}"
    local label="Preparing ${bin}"
    local logfile="${NDS_INSTALL_DETAIL_LOG:-/tmp/nds_install.log}"

    if command -v "$bin" &>/dev/null; then
        debug "pkg: ${bin} already on PATH"
        return 0
    fi
    if ! command -v nix &>/dev/null; then
        return 1
    fi

    declare -f nds_install_log &>/dev/null \
        && nds_install_log "pkg: ensuring ${bin} via nixpkgs#${attr}" \
        || true
    {
        printf '\n=== Preparing package %s (nixpkgs#%s) ===\n' "$bin" "$attr"
    } >>"$logfile" 2>/dev/null || true

    if declare -f nds_step_exec &>/dev/null; then
        nds_step_exec "$label" nds_pkg_warm "$bin" "$attr" || return 1
    elif declare -f nds_step_start &>/dev/null; then
        nds_step_start "$label"
        if nds_pkg_warm "$bin" "$attr"; then
            declare -f nds_step_complete &>/dev/null && nds_step_complete "$label"
        else
            declare -f nds_step_fail &>/dev/null && nds_step_fail "$label"
            return 1
        fi
    else
        declare -f info &>/dev/null && info "${label} via nix (first use)..." || true
        nds_pkg_warm "$bin" "$attr" || return 1
    fi
    return 0
}
