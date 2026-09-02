#!/usr/bin/env bash
# ==================================================================================================
# NDS - Flake host discovery (nixosConfigurations)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-31 | Modified: 2026-08-21
# Description:   List nixosConfigurations attrs from a flake root (no pick UI)
# ==================================================================================================

# Description: Resolve flake checkout path for host listing (gate probe, local, or cfg).
# Returns:
# - <String> Absolute flake root (stdout); non-zero when missing
nds_flake_resolve_root() {
    local root loc

    root="${1:-${NDS_FLAKE_GATE_ROOT:-}}"
    if [[ -z "$root" || ! -f "${root}/flake.nix" ]]; then
        root="${ nds_cfg_get FLAKE_LOCAL_PATH 2>/dev/null || true; }"
    fi
    if [[ -z "$root" || ! -f "${root}/flake.nix" ]]; then
        root="${NDS_FLAKE_PROBE_REPO:-}"
    fi
    if [[ -z "$root" || ! -f "${root}/flake.nix" ]]; then
        loc="${ nds_cfg_get FLAKE_LOCATION 2>/dev/null || true; }"
        [[ -n "$loc" && -f "${loc}/flake.nix" ]] && root="$loc"
    fi
    [[ -n "$root" && -f "${root}/flake.nix" ]] || return 1
    readlink -f "$root" 2>/dev/null || printf '%s\n' "$root"
}

# Description: Split nix eval host listing into one name per line.
# nix eval without --raw prints a quoted Nix string ("a\nb") as one line.
# Arguments:
# - eval_out: <String> Raw nix eval stdout
# Returns:
# - <String> host names, one per line
_nds_install_flake_normalize_eval_hosts() {
    local out="$1"

    out="${out#"${out%%[![:space:]]*}"}"
    out="${out%"${out##*[![:space:]]}"}"
    if [[ "$out" == \"*\" && "$out" != *$'\n'* ]]; then
        out="${out#\"}"
        out="${out%\"}"
        out="${out//\\n/$'\n'}"
    fi
    printf '%s\n' "$out" | awk 'NF'
}

# Description: List nixosConfigurations attribute names from a flake checkout.
# Arguments:
# - flake_root: <String> Path to flake directory
# Returns:
# - <String> host names one per line (stdout); non-zero on failure
nds_flake_list_hosts() {
    local flake_root="$1"
    local out errfile flake_ref

    [[ -d "$flake_root" && -f "${flake_root}/flake.nix" ]] || return 1
    flake_root="$(readlink -f "$flake_root" 2>/dev/null || printf '%s' "$flake_root")"
    flake_ref="path:${flake_root}"
    errfile="${NDS_RUNTIME_DIR:-/tmp/nds}/flake_hosts.err"
    mkdir -p "$(dirname "$errfile")"
    : >"$errfile"

    # Successful eval of an empty attrset is 0 hosts — never invent names from folders.
    # 1) Eval from inside the flake (most reliable for locked inputs).
    # --raw is required: default nix eval prints "a\nb" as one quoted string.
    if out=$(
        cd "$flake_root" || exit 1
        nix eval --raw --impure --extra-experimental-features 'nix-command flakes' \
            --expr 'builtins.concatStringsSep "\n" (builtins.attrNames (builtins.getFlake (toString ./.)).nixosConfigurations)' \
            2>>"$errfile"
    ); then
        out="${ _nds_install_flake_normalize_eval_hosts "$out"; }"
        [[ -n "$out" ]] && printf '%s\n' "$out"
        return 0
    fi

    # 2) path: flake URI + apply
    if out=$(nix eval --json --impure \
        --extra-experimental-features 'nix-command flakes' \
        "${flake_ref}#nixosConfigurations" \
        --apply 'c: builtins.attrNames c' 2>>"$errfile"); then
        out="$(printf '%s\n' "$out" | tr -d '[]"' | tr ',' '\n' \
            | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | awk 'NF')"
        [[ -n "$out" ]] && printf '%s\n' "$out"
        return 0
    fi

    # 3) nix flake show --json (lazy; needs jq when present)
    if command -v jq &>/dev/null; then
        if out=$(nix flake show --json --all-systems "$flake_ref" 2>>"$errfile" \
            | jq -r '.nixosConfigurations // {} | keys[]' 2>>"$errfile"); then
            out="$(printf '%s\n' "$out" | awk 'NF')"
            [[ -n "$out" ]] && printf '%s\n' "$out"
            return 0
        fi
    fi

    debug "nixosConfigurations listing failed (see ${errfile})"
    return 1
}

# Description: True when host is in the newline list (exact match).
nds_flake_host_in_list() {
    local host="$1"
    shift
    local h
    for h in "$@"; do
        [[ "$h" == "$host" ]] && return 0
    done
    return 1
}

