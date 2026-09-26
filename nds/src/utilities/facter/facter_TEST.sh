# shellcheck source=../../setup_TEST.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../setup_TEST.sh"
import_dir "$(dirname "${BASH_SOURCE[0]}")" --depth 0

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
    else
        bts_pass "ok"
    fi

    tmp=$(mktemp)
    cp "$sample" "$tmp"
    if facter_sanitize "$tmp"; then
        bts_pass "ok"
    else
        bts_fail "fail"
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
    else
        bts_fail "fail"
    fi

    fixture="$(dirname "${BASH_SOURCE[0]}")/../../../.bundleBackups/backup/config/facter.json"
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
        else
            bts_fail "fail"
        fi
        rm -f "$tmp"
    fi

    rm -f "$sample" "$tmp"
}
