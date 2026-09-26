#!/usr/bin/env bash
# ==================================================================================================
# NDS - Schema group git
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

nds_detect_gitKeysDir() {
    printf '%s\n' "${ nds_session_dir secrets; }/git"
}

nds_schema_group git "Git"
nds_schema_field git GIT_KEYS_DIR dir --detect nds_detect_gitKeysDir --ask nds_ask_gitAccess \
    --label 'Git keys directory'
nds_schema_field git GIT_PERSIST_ACCESS bool --default true --label 'Persist git access'
