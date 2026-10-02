#!/usr/bin/env bash
# ==================================================================================================
# NDS - Schema group region
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

nds_schema_group region "Region"
nds_schema_field region REGION_COUNTRY country --ask nds_ask_country --label 'Country Preset'
nds_schema_field region REGION_TIMEZONE timezone --default UTC --label 'Timezone'
nds_schema_field region REGION_LOCALE_MAIN locale --default 'en_US.UTF-8' --label 'Primary locale'
nds_schema_field region REGION_LOCALE_EXTRA string --label 'Additional locales'
nds_schema_field region REGION_KEYBOARD_LAYOUT keyboard --default us --label 'Keyboard layout'
nds_schema_field region REGION_KEYBOARD_VARIANT string --label 'Keyboard variant'
