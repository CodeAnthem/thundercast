#!/usr/bin/env bash
# ==================================================================================================
# NDS - Tools capability layer
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-06 | Modified: 2026-08-06
# ==================================================================================================
#
# Sourcable helpers only: nds_pkg_*, nds_qr_*, nds_gh_*, nds_age_*, nds_facter_*.
# No domain policy (keys paths, “when to register”, install decisions).
#
# Progress / logging on first nix warm is intentional and optional:
# - If stepAnimation / logger are loaded, ensure may animate + write install log.
# - Every progress call is `declare -f … &>/dev/null` guarded — tools stay usable
#   in unit tests without sourcing src/ui/.
# - PATH hits and no-op paths stay quiet.
#
# Domain features (git/, install/) call these; they must not re-own CLI ensure.
