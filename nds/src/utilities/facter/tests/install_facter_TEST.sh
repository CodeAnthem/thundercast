#!/usr/bin/env bash
# ==================================================================================================
# NDS - Facter report sanitizer tests (read-only — no disk install)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-08 | Modified: 2026-07-08
# Description:   Isolate the VMware null-cpu facter bug without a full install cycle
# ==================================================================================================

suite_facter() {
    local fixture sample tmp cleaned

    if ! declare -f facter_sanitize &>/dev/null; then
        bts_fail "fail"
        console "  ✗ sanitize helper missing"
        return 0
    fi

    sample=$(mktemp)
    cat >"$sample" <<'JSON'
{"virtualisation":"vmware","hardware":{"cpu":[null,null,{"architecture":"x86_64","features":["vmx"]}],"disk":[{"name":"sda"}]}}
JSON

    # Unsanitized shape must fail the nixpkgs-style CPU fold (documents the bug).
    if nix-instantiate --eval -E "
let
  report = builtins.fromJSON (builtins.readFile \"${sample}\");
  has = builtins.any ({ features ? [], ... }: builtins.elem \"vmx\" features)
        (report.hardware.cpu or []);
in has
" &>/dev/null; then
        bts_fail "fail"
        console "  ✗ fixture should fail nixpkgs-style cpu fold before sanitize"
    else
        bts_pass "ok"
        console "  ✓ dirty facter.json triggers set-vs-null (known VMware shape)"
    fi

    tmp=$(mktemp)
    cp "$sample" "$tmp"
    if facter_sanitize "$tmp"; then
        bts_pass "ok"
        console "  ✓ sanitize rewrites report"
    else
        bts_fail "fail"
        console "  ✗ sanitize failed"
        rm -f "$sample" "$tmp"
        return 0
    fi

    cleaned=$(nix --extra-experimental-features 'nix-command flakes' eval --impure --json --expr "
let
  report = builtins.fromJSON (builtins.readFile \"${tmp}\");
  has = builtins.any ({ features ? [], ... }: builtins.elem \"vmx\" features)
        (report.hardware.cpu or []);
in { ok = has; n = builtins.length report.hardware.cpu; }
" 2>/dev/null) || cleaned=""

    if [[ "$cleaned" == *'"ok":true'* ]] && [[ "$cleaned" == *'"n":1'* ]]; then
        bts_pass "ok"
        console "  ✓ sanitized cpu list is non-null and nix-foldable"
    else
        bts_fail "fail"
        console "  ✗ sanitized fold failed: ${cleaned:-empty}"
    fi

    fixture="${SCRIPT_DIR}/../.bundleBackups/backup/config/facter.json"
    if [[ ! -f "$fixture" ]]; then
        fixture="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)/.bundleBackups/backup/config/facter.json"
    fi
    if [[ -f "$fixture" ]]; then
        tmp=$(mktemp)
        cp "$fixture" "$tmp"
        if facter_sanitize "$tmp" \
            && nix-instantiate --eval -E "
let
  report = builtins.fromJSON (builtins.readFile \"${tmp}\");
  has = builtins.any ({ features ? [], ... }: true) (report.hardware.cpu or []);
in has
" &>/dev/null; then
            bts_pass "ok"
            console "  ✓ real VMware backup facter.json sanitize + fold ok"
        else
            bts_fail "fail"
            console "  ✗ real VMware backup facter.json still broken after sanitize"
        fi
        rm -f "$tmp"
    else
        console "  · skip real-backup fixture (not present)"
    fi

    rm -f "$sample" "$tmp"
}
