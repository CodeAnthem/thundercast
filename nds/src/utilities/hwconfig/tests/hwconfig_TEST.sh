#!/usr/bin/env bash
# ==================================================================================================
# hwconfig utility - artifact name units
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-03 | Modified: 2026-09-03
# ==================================================================================================

suite_hwconfig() {
    local out

    _hw_ok() {
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ hwconfig: $1"
    }
    _hw_fail() {
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ hwconfig: $1"
    }
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
}
