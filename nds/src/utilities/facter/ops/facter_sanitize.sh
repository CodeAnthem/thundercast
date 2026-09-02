#!/usr/bin/env bash
# ==================================================================================================
# facter - sanitize nixos-facter JSON (drop null list holes)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-02 | Modified: 2026-09-02
# ==================================================================================================

# Description: Drop null holes from a nixos-facter JSON report (in place).
# Arguments:
# - dest: <String> Absolute path to facter.json
facter_sanitize() {
    local dest="$1"
    local tmp detail_log="${NDS_INSTALL_DETAIL_LOG:-/tmp/nds_install.log}"

    [[ -s "$dest" ]] || return 1
    tmp=$(mktemp)
    if ! nix --extra-experimental-features 'nix-command flakes' eval --impure --json \
        --expr "
let
  report = builtins.fromJSON (builtins.readFile \"${dest}\");
  scrub = v:
    if builtins.isList v then
      map scrub (builtins.filter (x: x != null) v)
    else if builtins.isAttrs v then
      builtins.mapAttrs (_: scrub) v
    else
      v;
in scrub report
" >"$tmp" 2>>"$detail_log"; then
        rm -f "$tmp"
        return 1
    fi
    mv -f "$tmp" "$dest"
    return 0
}

# Compatibility wrappers for shot callers still using install names.
_nds_install_sanitize_facter_report() {
    facter_sanitize "$1" || {
        error "Failed to sanitize facter.json (null scrub) — see install log"
        return 1
    }
}
