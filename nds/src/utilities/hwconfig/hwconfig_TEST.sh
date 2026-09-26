# shellcheck source=../../setup_TEST.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../setup_TEST.sh"
import_dir "$(dirname "${BASH_SOURCE[0]}")" --depth 0

#!/usr/bin/env bash
# ==================================================================================================
# hwconfig utility - artifact name units
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-03 | Modified: 2026-09-03
# ==================================================================================================

suite_hwconfig() {
    local out

    _hw_ok() { bts_pass "$1"; }
    _hw_fail() { bts_fail "$1"; }
    _hw_eq() {
        local name="$1" got="$2" want="$3"
        if [[ "$got" == "$want" ]]; then _hw_ok "$name"
        else _hw_fail "$name ($got != $want)"; fi
    }

    if ! declare -f hwconfig_artifactName &>/dev/null; then
        nds_requireUtility hwconfig || {
            _hw_fail "hwconfig not loadable"
            return 0
        }
    fi

    out=${ hwconfig_artifactName classic; }
    _hw_eq "classic → hardware-configuration.nix" "$out" "hardware-configuration.nix"
    out=${ hwconfig_artifactName flake; }
    _hw_eq "flake default → facter.json" "$out" "facter.json"
    out=${ hwconfig_artifactName flake legacy; }
    _hw_eq "flake legacy → hardware-configuration.nix" "$out" "hardware-configuration.nix"

    nds_test_stubBins nixos-generate-config
    local dest
    dest=$(mktemp)
    if hwconfig_generate "$dest" /tmp/hwroot >/dev/null 2>/dev/null \
        && grep -q 'nixos-generate-config --root /tmp/hwroot --show-hardware-config' "$NDS_TEST_BIN_LOG" \
        && [[ -s "$dest" ]]; then
        _hw_ok "hwconfig_generate asks nixos-generate-config for that root"
    else
        _hw_fail "hwconfig_generate log was '$(<"$NDS_TEST_BIN_LOG")'"
    fi
    nds_test_stubBins_drop
    rm -f "$dest"
}
