#!/usr/bin/env bash
# ==================================================================================================
# NDS - classicInstall unattended cook
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# ==================================================================================================

# shellcheck source=../../../setup_TEST.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../../setup_TEST.sh"
logger_setMinLevel warn
# shellcheck source=../../../app/session/mode.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../../app/session/mode.sh"
# shellcheck source=../../../app/session/skip.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../../app/session/skip.sh"
import_dir "$(dirname "${BASH_SOURCE[0]}")/../../../recipe" --depth 0
import_dir "$(dirname "${BASH_SOURCE[0]}")/../../../recipe/schema" --depth 0
# shellcheck source=../../../app/pipeline/pipeline.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../../app/pipeline/pipeline.sh"
# shellcheck source=../setup.sh
source "$(dirname "${BASH_SOURCE[0]}")/../setup.sh"

suite_classicInstall() {
    local sealed text want session
    nds_test_session
    nds_test_stubBins systemd-detect-virt
    export NDS_MODE=unattended
    nds_mode_resolve
    export NDS_CURRENT_ACTION=classicInstall
    export NDS_NETWORK_HOSTNAME=host
    export NDS_DISK_TARGET=/dev/sda
    export NDS_BOOT_UEFI_MODE=false
    export NDS_BOOT_LOADER=grub
    declare -gA _NDS_RECIPE=()
    nds_pipeline_recipe _NDS_RECIPE local classicInstall || { bts_fail "unattended cook failed"; return; }
    sealed="${ nds_session_dir recipe; }/sealed.recipe"
    nds_recipe_seal _NDS_RECIPE "$sealed" || { bts_fail "seal failed"; return; }
    session=$_NDS_TEST_SESSION
    text=$(<"$sealed")
    text=${text//${session}/@SESSION@}
    want=$(<"$(dirname "${BASH_SOURCE[0]}")/classicInstall.sealed")
    if [[ "$text" == "$want" ]]; then
        bts_pass "sealed file is the full classic recipe"
    else
        bts_fail "sealed file differed: '${text}'"
    fi
    if [[ -f "${session}/secrets/ACCESS_ADMIN_PASSWORD" && $(stat -c '%a' "${session}/secrets/ACCESS_ADMIN_PASSWORD") == 600 \
        && -f "${session}/secrets/ENCRYPTION_PASSPHRASE" && $(stat -c '%a' "${session}/secrets/ENCRYPTION_PASSPHRASE") == 600 ]]; then
        bts_pass "generated secret files are mode 600"
    else
        bts_fail "generated secret mode was wrong"
    fi
    nds_test_stubBins_drop
}
