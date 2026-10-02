#!/usr/bin/env bash
# ==================================================================================================
# NDS - Schema group bundle
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-10-02 | Modified: 2026-10-02
# Description:   The one bundle choice a person can make. Cook internals stay in cook.
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

nds_schema_group bundle "Bundle"
nds_schema_field bundle BUNDLE_SAVE_ON_TARGET bool --default false \
    --label 'Copy the bundle into the installed admin home'
