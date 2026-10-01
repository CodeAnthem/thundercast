#!/usr/bin/env bash
# ==================================================================================================
# NDS - Schema group toolkit
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

nds_schema_group toolkit "Toolkit" --when 'INSTALL_ACTION=toolkit'
nds_schema_field toolkit TOOLKIT_CLONE_URL url \
    --default 'https://github.com/CodeAnthem/thundercast.git' --label 'Toolkit source'
nds_schema_field toolkit TOOLKIT_MODE choice --default new \
    --choices 'new|restore' --labels 'new=New toolkit|restore=Restore toolkit' --label 'Toolkit mode'
nds_schema_field toolkit TOOLKIT_BUNDLE file --required --when 'TOOLKIT_MODE=restore' --label 'Toolkit bundle'
nds_schema_field toolkit TOOLKIT_AGE_KEY_FILE secret \
    --generate nds_generate_ageKey --generate-when 'TOOLKIT_MODE=new' --label 'Toolkit age key file'
nds_schema_field toolkit TOOLKIT_SSH_KEY_FILE secret \
    --generate nds_generate_sshHostKey --generate-when 'TOOLKIT_MODE=new' --label 'Toolkit SSH key file'
