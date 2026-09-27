#!/usr/bin/env bash
# ==================================================================================================
# NDS - toolkit unattended cook
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# ==================================================================================================

_src="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../nds/src" && pwd)"
# shellcheck source=../../../../nds/src/setup_TEST.sh
source "${_src}/setup_TEST.sh"
logger_setMinLevel warn
# shellcheck source=../../../../nds/src/app/session/mode.sh
source "${_src}/app/session/mode.sh"
# shellcheck source=../../../../nds/src/app/session/skip.sh
source "${_src}/app/session/skip.sh"
import_dir "${_src}/recipe" --depth 0
import_dir "${_src}/recipe/schema" --depth 0
# shellcheck source=../../../../nds/src/app/pipeline/pipeline.sh
source "${_src}/app/pipeline/pipeline.sh"
# shellcheck source=../../../nds/src/utilities/sops/ops/install_sops.sh
source "${_src}/utilities/sops/ops/install_sops.sh"

nds_detect_firstDisk() { :; }
flake_listHosts() { printf '%s\n' control-toolkit; }
flake_probe() { return 0; }
flake_hostHasDisko() { return 1; }
git_probe() { return 0; }

suite_toolkit() {
    local sealed text leaf seed files hooks
    nds_test_session
    mkdir -p "${ nds_session_dir secrets; }/git"
    # shellcheck source=../setup.sh
    source "$(dirname "${BASH_SOURCE[0]}")/../setup.sh"
    hooks=${ eventHookCount cook.post_install; }
    if [[ "$hooks" == 1 ]]; then
        bts_pass "cook.post_install is registered"
    else
        bts_fail "cook.post_install count was ${hooks}"
    fi
    export NDS_MODE=unattended
    nds_mode_resolve
    nds_test_stubBins age-keygen ssh-keygen systemd-detect-virt
    export NDS_CURRENT_ACTION=toolkit
    export NDS_FLAKE_LOCATION=lab
    export NDS_DISK_TARGET=/dev/sda
    export NDS_BOOT_UEFI_MODE=false
    export NDS_BOOT_LOADER=grub
    export NDS_NETWORK_HOSTNAME=control-toolkit
    declare -gA _NDS_RECIPE=()
    nds_pipeline_recipe _NDS_RECIPE local toolkit || { bts_fail "unattended cook failed"; return; }
    nds_recipe_materialize _NDS_RECIPE || { bts_fail "materialize failed"; return; }
    sealed="${ nds_session_dir recipe; }/sealed.recipe"
    nds_recipe_seal _NDS_RECIPE "$sealed" || { bts_fail "seal failed"; return; }
    leaf="${ nds_session_dir work; }/leaf"
    seed="${ nds_session_dir seed; }"
    if [[ -s "${leaf}/.toolkit/operator/keys/age.pub" \
        && -s "${leaf}/.toolkit/operator/keys/ssh.pub" && -f "${leaf}/.sops.yaml" \
        && -f "${leaf}/.nds/hosts/control-toolkit.recipe" \
        && -s "${leaf}/.toolkit/machines/control-toolkit/keys/age.pub" ]]; then
        bts_pass "operator pubs, sops file, and portable recipe are on the leaf"
    else
        bts_fail "leaf toolkit files missing"
        return
    fi
    text=$(<"${leaf}/.nds/hosts/control-toolkit.recipe")
    if [[ "$text" != *LEAF_PUSH* && "$text" != *TARGET_SEED_DIR* && "$text" != *TOOLKIT_AGE_KEY_FILE* ]]; then
        bts_pass "portable recipe drops push, seed, and secret keys"
    else
        bts_fail "portable recipe kept a local path"
    fi
    files=$(cd "$seed" && find . -type f | sort)
    if [[ "$files" == $'./etc/sops/age/operator_sops.key\n./root/.ssh/id_ed25519\n./root/.ssh/id_ed25519.pub' ]]; then
        bts_pass "seed tree is only the operator key and the ssh key pair"
    else
        bts_fail "seed tree was '${files}'"
    fi
    sealed="${ nds_session_dir recipe; }/sealed.recipe"
    nds_recipe_seal _NDS_RECIPE "$sealed" || { bts_fail "seal failed"; return; }
    text=$(<"$sealed")
    text=${text//${_NDS_TEST_SESSION}/@SESSION@}
    want=$(<"$(dirname "${BASH_SOURCE[0]}")/toolkit.sealed")
    if [[ "$text" == "$want" ]]; then
        bts_pass "sealed file is the full toolkit recipe"
    else
        bts_fail "sealed file differed"
    fi
}
