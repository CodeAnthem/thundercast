#!/usr/bin/env bash
# ==================================================================================================
# Flake utility - host list and one-shot probe clone
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

_flake_normalize_hosts() {
    local _flake_out=$1
    _flake_out="${_flake_out#"${_flake_out%%[![:space:]]*}"}"
    _flake_out="${_flake_out%"${_flake_out##*[![:space:]]}"}"
    if [[ "$_flake_out" == \"*\" && "$_flake_out" != *$'\n'* ]]; then
        _flake_out="${_flake_out#\"}"
        _flake_out="${_flake_out%\"}"
        _flake_out="${_flake_out//\\n/$'\n'}"
    fi
    printf '%s\n' "$_flake_out" | awk 'NF'
}

flake_listHosts() {
    local _flake_root=$1 _flake_out _flake_err _flake_ref
    [[ -d "$_flake_root" && -f "${_flake_root}/flake.nix" ]] || return 1
    _flake_root=$(readlink -f "$_flake_root" 2>/dev/null || printf '%s' "$_flake_root")
    _flake_ref="path:${_flake_root}"
    _flake_err=$(mktemp)
    if _flake_out=$(
        cd "$_flake_root" || exit 1
        nix eval --raw --impure --extra-experimental-features 'nix-command flakes' \
            --expr 'builtins.concatStringsSep "\n" (builtins.attrNames (builtins.getFlake (toString ./.)).nixosConfigurations)' \
            2>>"$_flake_err"
    ); then
        _flake_out=${ _flake_normalize_hosts "$_flake_out"; }
        rm -f "$_flake_err"
        [[ -n "$_flake_out" ]] && printf '%s\n' "$_flake_out"
        return 0
    fi
    if _flake_out=$(nix eval --json --impure \
        --extra-experimental-features 'nix-command flakes' \
        "${_flake_ref}#nixosConfigurations" \
        --apply 'c: builtins.attrNames c' 2>>"$_flake_err"); then
        _flake_out=$(printf '%s\n' "$_flake_out" | tr -d '[]"' | tr ',' '\n' \
            | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | awk 'NF')
        rm -f "$_flake_err"
        [[ -n "$_flake_out" ]] && printf '%s\n' "$_flake_out"
        return 0
    fi
    rm -f "$_flake_err"
    return 1
}

flake_probe() {
    local _flake_keys=$1 _flake_url=$2 _flake_dest=$3
    if [[ -d "${_flake_dest}/.git" ]]; then
        return 0
    fi
    git_clone "$_flake_keys" "$_flake_url" "$_flake_dest" --depth 1
}
