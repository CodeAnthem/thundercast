#!/usr/bin/env bash
# ==================================================================================================
# NDS - classicInstall unattended cook
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# ==================================================================================================

# shellcheck source=../../setup_TEST.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../setup_TEST.sh"
logger_setMinLevel warn
# shellcheck source=../../app/session/mode.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../app/session/mode.sh"
# shellcheck source=../../app/session/skip.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../app/session/skip.sh"
import_dir "$(dirname "${BASH_SOURCE[0]}")/../../recipe" --depth 0
import_dir "$(dirname "${BASH_SOURCE[0]}")/../../recipe/schema" --depth 0
# shellcheck source=../../app/pipeline.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../app/pipeline.sh"
# shellcheck source=setup.sh
source "$(dirname "${BASH_SOURCE[0]}")/setup.sh"

nds_detect_firstDisk() { :; }

suite_classicInstall() {
    local sealed text
    nds_test_session
    export NDS_MODE=unattended
    nds_mode_resolve
    export NDS_CURRENT_ACTION=classicInstall
    export NDS_NETWORK_HOSTNAME=host
    export NDS_DISK_STRATEGY=flake
    declare -gA _NDS_COOK=()
    nds_pipeline_cook _NDS_COOK local classicInstall || { bts_fail "unattended cook failed"; return; }
    sealed="${ nds_session_dir recipe; }/sealed.recipe"
    nds_recipe_seal _NDS_COOK "$sealed" || { bts_fail "seal failed"; return; }
    text=$(<"$sealed")
    assert_contains "$text" 'INSTALL_KIND="classic"' "sealed file pins INSTALL_KIND"
    assert_contains "$text" 'INSTALL_ACTION="classicInstall"' "sealed file names the action"
}
