#!/usr/bin/env bash
# ==================================================================================================
# NDS - addFleetHost unattended cook
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# ==================================================================================================

_src="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../nds/src" && pwd)"
# shellcheck source=../../../nds/src/setup_TEST.sh
source "${_src}/setup_TEST.sh"
logger_setMinLevel warn
# shellcheck source=../../../nds/src/app/session/mode.sh
source "${_src}/app/session/mode.sh"
# shellcheck source=../../../nds/src/app/session/skip.sh
source "${_src}/app/session/skip.sh"
import_dir "${_src}/recipe" --depth 0
import_dir "${_src}/recipe/schema" --depth 0
# shellcheck source=../../../nds/src/app/pipeline.sh
source "${_src}/app/pipeline.sh"
# shellcheck source=../../../nds/src/utilities/sops/ops/install_sops.sh
source "${_src}/utilities/sops/ops/install_sops.sh"
# shellcheck source=setup.sh
source "$(dirname "${BASH_SOURCE[0]}")/setup.sh"

nds_detect_firstDisk() { :; }
flake_listHosts() { printf '%s\n' webhost; }
flake_probe() { return 0; }
flake_hostHasDisko() { return 1; }
git_probe() { return 0; }

suite_addFleetHost() {
    local flake sealed text leaf portable
    nds_test_session
    mkdir -p "${ nds_session_dir secrets; }/git"
    flake="${_NDS_TEST_SESSION}/flake"
    mkdir -p "${flake}/.roles/web"
    printf '%s\n' role > "${flake}/.roles/web/marker"
    export NDS_MODE=unattended
    nds_mode_resolve
    nds_test_stubBins age-keygen systemd-detect-virt
    export NDS_CURRENT_ACTION=addFleetHost
    export NDS_FLAKE_LOCATION=lab
    export NDS_FLAKE_SOURCE=local
    export NDS_FLAKE_LOCAL_PATH="$flake"
    export NDS_FLAKE_HOST=webhost
    export NDS_SCAFFOLD_ROLE=web
    export NDS_NETWORK_HOSTNAME=webhost
    export NDS_DISK_TARGET=/dev/sda
    export NDS_BOOT_UEFI_MODE=false
    export NDS_BOOT_LOADER=grub
    declare -gA _NDS_RECIPE=()
    nds_pipeline_recipe _NDS_RECIPE local addFleetHost || { bts_fail "unattended cook failed"; return; }
    leaf="${ nds_session_dir work; }/leaf"
    portable="${leaf}/.nds/hosts/webhost.recipe"
    if [[ -f "${leaf}/hosts/x86_64-linux/webhost/marker" && -f "$portable" \
        && -s "${leaf}/.toolkit/machines/webhost/keys/age.pub" ]]; then
        bts_pass "role template and portable recipe are on the leaf"
    else
        bts_fail "leaf scaffold missing"
        return
    fi
    text=$(<"$portable")
    if [[ "$text" == *'FLAKE_HOST="webhost"'* && "$text" != *LEAF_PUSH* && "$text" != *GIT_KEYS_DIR* ]]; then
        bts_pass "portable recipe keeps the host and drops push and keys"
    else
        bts_fail "portable recipe was unexpected"
    fi
    nds_recipe_materialize _NDS_RECIPE || { bts_fail "materialize failed"; return; }
    sealed="${ nds_session_dir recipe; }/sealed.recipe"
    nds_recipe_seal _NDS_RECIPE "$sealed" || { bts_fail "seal failed"; return; }
    text=$(<"$sealed")
    text=${text//${_NDS_TEST_SESSION}/@SESSION@}
    want=$(<"$(dirname "${BASH_SOURCE[0]}")/addFleetHost.sealed")
    if [[ "$text" == "$want" ]]; then
        bts_pass "sealed file is the full addFleetHost recipe"
    else
        bts_fail "sealed file differed"
    fi
    rm -rf "$flake"
}
