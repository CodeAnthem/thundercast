# shellcheck source=../../setup_TEST.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../setup_TEST.sh"
import_dir "$(dirname "${BASH_SOURCE[0]}")" --depth 0

#!/usr/bin/env bash
# ==================================================================================================
# nixos - install progress phase doors
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-28 | Modified: 2026-09-28
# ==================================================================================================

_np_is() {
    local want=$1 label=$2 phase
    phase=${ nixos_progressPhase; }
    if [[ "$phase" == "$want" ]]; then
        bts_pass "$label"
    else
        bts_fail "${label} (phase ${phase})"
    fi
}

suite_nixos_progress() {
    local install_path rc body

    bts_section "Phase doors"
    nixos_progressReset
    nixos_progressConsider "copying path '/nix/store/early'"
    _np_is 0 "copying path before a start line stays at 0"

    nixos_progressReset
    nixos_progressConsider "=== nix eval nixosConfigurations.host ==="
    _np_is 1 "nix eval header opens evaluating"
    nixos_progressReset
    nixos_progressConsider "=== Installing NixOS ==="
    _np_is 1 "nixos-install header opens evaluating"
    nixos_progressReset
    nixos_progressConsider "### Installing NixOS ###"
    _np_is 1 "nixos-anywhere banner opens evaluating"

    nixos_progressReset
    nixos_progressConsider "=== Installing NixOS ==="
    nixos_progressConsider "copying path '/nix/store/a'"
    _np_is 2 "copying path opens copying files"
    nixos_progressConsider "copying path '/nix/store/b'"
    _np_is 2 "another copying path stays on copying files"

    nixos_progressReset
    nixos_progressConsider "=== nix eval ==="
    nixos_progressConsider "these 12 derivations will be built"
    _np_is 1 "plan line before copying stays on evaluating"
    nixos_progressConsider "copying channel 'nixos'"
    nixos_progressConsider "these 3 derivations will be built:"
    _np_is 3 "plan line opens planning"

    nixos_progressReset
    nixos_progressConsider "=== Installing ==="
    nixos_progressConsider "copying path '/nix/store/a'"
    nixos_progressConsider "these 1 derivations will be built"
    nixos_progressConsider "note: building '/nix/store/not-a-build'"
    _np_is 3 "building later in the line does not open building"
    nixos_progressConsider "building '/nix/store/abc.drv'"
    _np_is 4 "a building line opens building"
    nixos_progressReset
    nixos_progressConsider "=== Installing ==="
    nixos_progressConsider "copying path '/nix/store/a'"
    nixos_progressConsider "these 1 derivations will be built"
    nixos_progressConsider $'\e[1mbuilding \'/nix/store/abc.drv\'\e[0m'
    _np_is 4 "a colored building line opens building"

    nixos_progressReset
    nixos_progressConsider "=== Installing ==="
    nixos_progressConsider "copying path '/nix/store/a'"
    nixos_progressConsider "these 1 derivations will be built"
    nixos_progressConsider "building '/nix/store/abc.drv'"
    nixos_progressConsider "copying path '/nix/store/late'"
    _np_is 4 "copying path after planning does not move the phase"
    nixos_progressConsider "setting up /etc..."
    _np_is 5 "setting up /etc opens setting up"
    nixos_progressReset
    nixos_progressConsider "=== Installing ==="
    nixos_progressConsider "copying path '/nix/store/a'"
    nixos_progressConsider "these 1 derivations will be built"
    nixos_progressConsider "building '/nix/store/abc.drv'"
    nixos_progressConsider "activating the configuration..."
    _np_is 5 "activating opens setting up"
    nixos_progressConsider "installing the boot loader..."
    _np_is 6 "boot loader opens the last phase"

    nixos_progressReset
    nixos_progressConsider "=== nix eval ==="
    nixos_progressConsider "Installation finished"
    _np_is 6 "Installation finished jumps to the last phase"

    bts_section "Logged command"
    logger_scopeExists install || logger_scopeCreate "NixOS install" install nixosInstallation.log
    install_path=${ nixos_installLog; }
    : >"$install_path"
    nixos_progressReset
    rc=0
    nixos_runLogged printf '%s\n' 'hello-from-nix' || rc=$?
    body=$(<"$install_path")
    if [[ "$rc" -eq 0 && "$body" == "hello-from-nix" ]]; then
        bts_pass "runLogged appends the command output to the install log"
    else
        bts_fail "runLogged rc=${rc} body='${body}'"
    fi
    rc=0
    nixos_runLogged false || rc=$?
    if [[ "$rc" -eq 1 ]]; then
        bts_pass "runLogged returns the command status"
    else
        bts_fail "runLogged false rc=${rc}"
    fi
}
