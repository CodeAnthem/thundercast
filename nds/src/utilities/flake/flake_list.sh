#!/usr/bin/env bash
# ==================================================================================================
# Flake utility - list git input URLs and lock entries from a flake path
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-31 | Modified: 2026-09-01
# ==================================================================================================

# Description: Extract git SSH-ish remote URLs from flake.lock text.
# Arguments:
# - lock_file: <String> Path to flake.lock
# Returns:
# - <String> One URL per line (stdout)
_flake_lock_ssh_urls() {
    local lock_file="$1"
    [[ -f "$lock_file" ]] || return 0
    {
        grep -oE '(git\+ssh|ssh)://[^"[:space:]]+' "$lock_file" 2>/dev/null || true
        grep -oE '"url": "(git\+ssh|ssh)://[^"]+"' "$lock_file" 2>/dev/null \
            | sed -e 's/^"url": "//' -e 's/"$//' || true
    } | sort -u
}

# Description: Print unique normalized git remote URLs for a flake directory.
# Arguments:
# - flake_root: <String> Directory with flake.nix / flake.lock
# - root_url:   <String|optional> Always include this URL
# Returns:
# - <String> One SSH URL per line (stdout)
flake_listGitUrls() {
    local flake_root="${1:-}" root_url="${2:-}"
    local lock flake_nix url norm
    declare -A seen=()

    [[ -n "$flake_root" && -d "$flake_root" ]] || {
        err "flake_root is missing or not a directory"
        return 1
    }

    _flake_add() {
        local u="$1"
        [[ -n "$u" ]] || return 0
        norm=${ _flake_url_toSsh "$u"; }
        [[ -n "$norm" ]] || return 0
        [[ -n "${seen[$norm]:-}" ]] && return 0
        seen[$norm]=1
        printf '%s\n' "$norm"
    }

    [[ -n "$root_url" ]] && _flake_add "$root_url"

    lock="${flake_root}/flake.lock"
    if [[ -f "$lock" ]]; then
        while IFS= read -r url; do
            _flake_add "$url"
        done < <(_flake_lock_ssh_urls "$lock")
    fi

    flake_nix="${flake_root}/flake.nix"
    if [[ -f "$flake_nix" ]]; then
        while IFS= read -r url; do
            _flake_add "$url"
        done < <(grep -oE 'git\+ssh://[^"[:space:]]+|git@[^"[:space:]]+\.git' "$flake_nix" 2>/dev/null \
            | sort -u || true)
    fi
}

# Description: List git lock nodes as url<TAB>rev<TAB>narHash.
# Arguments:
# - lock_file: <String> Path to flake.lock
# Returns:
# - <String> TSV lines (stdout)
# - <Bool> 0 when listed (empty ok); 1 when jq and nix both unavailable
flake_listLockGitEntries() {
    local lock_file="${1:-}"
    local lock_quoted entries

    [[ -f "$lock_file" ]] || return 0
    if command -v jq &>/dev/null; then
        entries=$(jq -r '
            .nodes[]?.locked?
            | select(.type == "git" and .url != null and .rev != null)
            | [.url, .rev, (.narHash // "")] | @tsv
        ' "$lock_file" 2>/dev/null || true)
    elif command -v nix &>/dev/null; then
        printf -v lock_quoted '%q' "$lock_file"
        entries=$(nix eval --impure --raw --expr "
            let
              lock = builtins.fromJSON (builtins.readFile ${lock_quoted});
              nodes = lock.nodes or {};
              names = builtins.attrNames nodes;
              line = name:
                let l = nodes.\${name}.locked or {};
                in if l.type or \"\" == \"git\" && l ? url && l ? rev
                   then l.url + \"\t\" + l.rev + \"\t\" + (l.narHash or \"\")
                   else \"\";
            in builtins.concatStringsSep \"\n\" (map line names)
        " 2>/dev/null || true)
    else
        err "jq and nix unavailable — cannot list git lock entries"
        return 1
    fi
    printf '%s\n' "$entries" | awk -F'\t' 'NF >= 2 && !seen[$1 "\t" $2]++'
}

# Description: Read one locked field from a named flake.lock node.
# Arguments:
# - lock_file: <String> Path to flake.lock
# - node:      <String> Node name (e.g. thundercast)
# - field:     <String> locked field (rev, url, type, owner, repo, …)
# Returns:
# - <String> Field value (stdout), empty when missing
flake_lockNodeField() {
    local lock_file="${1:-}" node="${2:-}" field="${3:-}"
    local lock_quoted val=""

    [[ -f "$lock_file" && -n "$node" && -n "$field" ]] || return 0
    if command -v jq &>/dev/null; then
        val=$(jq -r --arg n "$node" --arg f "$field" '
            .nodes[$n].locked[$f] // empty
        ' "$lock_file" 2>/dev/null || true)
    elif command -v nix &>/dev/null; then
        printf -v lock_quoted '%q' "$lock_file"
        val=$(nix eval --impure --raw --expr "
            let
              lock = builtins.fromJSON (builtins.readFile ${lock_quoted});
              l = lock.nodes.\"${node}\".locked or {};
            in toString (l.${field} or \"\")
        " 2>/dev/null || true)
    else
        val=$(awk -v node="$node" -v field="$field" '
            $0 ~ "^    \"" node "\": \\{$" { innode=1; next }
            innode && $0 ~ /^    "[^"]+": \{/ { innode=0 }
            innode && $0 ~ "\"" field "\": " {
                line=$0
                sub(/^[[:space:]]*"[^"]+":[[:space:]]*/, "", line)
                gsub(/^"/, "", line)
                gsub(/",?$/, "", line)
                print line
                exit
            }
        ' "$lock_file")
    fi
    [[ -n "$val" && "$val" != "null" ]] && printf '%s\n' "$val"
}

# Description: SSH git URL for a named flake.lock input (git url or github owner/repo).
# Arguments:
# - flake_root: <String> Directory with flake.lock
# - node:       <String> Input node name
# Returns:
# - <String> SSH URL (stdout)
# - <Bool> 0 when resolved
flake_lockInputUrl() {
    local flake_root="${1:-}" node="${2:-}"
    local lock url type owner repo

    [[ -n "$flake_root" && -n "$node" ]] || return 1
    lock="${flake_root}/flake.lock"
    [[ -f "$lock" ]] || return 1

    url=${ flake_lockNodeField "$lock" "$node" url; }
    if [[ -n "$url" ]]; then
        _flake_url_toSsh "$url"
        return 0
    fi
    type=${ flake_lockNodeField "$lock" "$node" type; }
    owner=${ flake_lockNodeField "$lock" "$node" owner; }
    repo=${ flake_lockNodeField "$lock" "$node" repo; }
    if [[ "$type" == "github" && -n "$owner" && -n "$repo" ]]; then
        printf 'git@github.com:%s/%s.git\n' "$owner" "$repo"
        return 0
    fi
    return 1
}
