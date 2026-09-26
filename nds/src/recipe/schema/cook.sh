#!/usr/bin/env bash
# ==================================================================================================
# NDS - Schema group cook
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# Description:   Keys set by action_recipe. Always enabled. Never asked.
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

nds_schema_group cook "Cook"
nds_schema_field cook LEAF_PUSH_DIR dir
nds_schema_field cook LEAF_PUSH_MESSAGE string
nds_schema_field cook TARGET_SEED_DIR dir
nds_schema_enable cook
