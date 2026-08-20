#!/usr/bin/env bash
# ==================================================================================================
# Thundercast - NDS remote action dispatcher
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-15 | Modified: 2026-08-18
# Description:   Source .nds/actions/<CAST_ACTION>.sh (default addRole)
# ==================================================================================================

# Sourced by NDS remoteAction. The install flake is the private leaf, not this repo.

_nds_cast_action_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_nds_cast_action_id="$(nds_cfg_get CAST_ACTION 2>/dev/null || true)"
_nds_cast_action_id="${_nds_cast_action_id:-addRole}"
_nds_cast_action_file="${_nds_cast_action_root}/actions/${_nds_cast_action_id}.sh"

if [[ -f "$_nds_cast_action_file" ]]; then
    nds_import_file "$_nds_cast_action_file" || return 1
else
    error "Unknown CAST_ACTION=${_nds_cast_action_id} (missing ${_nds_cast_action_file})"
    return 1
fi
