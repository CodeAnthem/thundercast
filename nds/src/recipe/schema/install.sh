#!/usr/bin/env bash
# ==================================================================================================
# NDS - Schema group install
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

nds_schema_group install "Install"
nds_schema_field install INSTALL_MODE choice --default local \
    --choices 'local|remote' --labels 'local=On target|remote=From operator' --label 'Install mode'
nds_schema_field install INSTALL_ACTION string --label 'Install action'
nds_schema_field install REMOTE_TARGET_IP ip --required --when 'INSTALL_MODE=remote' \
    --label 'Target host IP'
