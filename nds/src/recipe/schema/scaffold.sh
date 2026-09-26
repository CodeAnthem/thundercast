#!/usr/bin/env bash
# ==================================================================================================
# NDS - Schema group scaffold
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

nds_schema_group scaffold "Scaffold" --when 'INSTALL_ACTION=addFleetHost'
nds_schema_field scaffold SCAFFOLD_MODE choice --default new \
    --choices 'new|existing' --labels 'new=Scaffold from a role|existing=Reuse a host folder' \
    --label 'Host'
nds_schema_field scaffold SCAFFOLD_ROLE string --required --ask nds_ask_role \
    --when 'SCAFFOLD_MODE=new' --label 'Role'
