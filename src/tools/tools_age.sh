#!/usr/bin/env bash
# ==================================================================================================
# NDS - age-keygen helper (decoupled)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-05 | Modified: 2026-08-05
# Description:   Run age-keygen via PATH or nixpkgs#age — no sops/UI policy
# ==================================================================================================

# Description: Invoke age-keygen with the given arguments.
# Honors NDS_PKG_NIX_CONFIG when resolving through nix.
nds_age_keygen() {
    nds_pkg_run age-keygen age "$@"
}
