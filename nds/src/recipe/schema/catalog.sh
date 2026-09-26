#!/usr/bin/env bash
# ==================================================================================================
# NDS - Schema group catalog
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

nds_schema_group catalog "Catalog"
nds_schema_field catalog CATALOG_URL url --required --label 'Catalog URL'
nds_schema_field catalog CATALOG_ACTION string --required --ask nds_ask_catalogAction --label 'Catalog action'
