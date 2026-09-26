#!/usr/bin/env bash
# ==================================================================================================
# NDS - toolkit unattended cook
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

nds_detect_firstDisk() { :; }
flake_listHosts() { printf '%s\n' control-toolkit; }
flake_probe() { return 0; }
flake_hostHasDisko() { return 1; }
git_probe() { return 0; }

suite_toolkit() {
    local sealed text leaf seed files hooks
    nds_test_session
    mkdir -p "${ nds_session_dir secrets; }/git"
    # shellcheck source=setup.sh
    source "$(dirname "${BASH_SOURCE[0]}")/setup.sh"
    hooks=${ eventHookCount realize.post_install; }
    if [[ "$hooks" == 1 ]]; then
        bts_pass "realize.post_install is registered"
    else
        bts_fail "realize.post_install count was ${hooks}"
    fi
    export NDS_MODE=unattended
    nds_mode_resolve
    export NDS_CURRENT_ACTION=toolkit
    export NDS_FLAKE_LOCATION=lab
    export NDS_DISK_STRATEGY=flake
    declare -gA _NDS_COOK=()
    nds_pipeline_cook _NDS_COOK local toolkit || { bts_fail "unattended cook failed"; return; }
    leaf="${ nds_session_dir work; }/leaf"
    seed="${ nds_session_dir seed; }"
    if [[ -f "${leaf}/.toolkit/operator/keys/operator_age.pub" && -f "${leaf}/.sops.yaml" \
        && -f "${leaf}/.nds/hosts/control-toolkit.recipe" ]]; then
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
    nds_recipe_seal _NDS_COOK "$sealed" || { bts_fail "seal failed"; return; }
    text=$(<"$sealed")
    assert_contains "$text" 'INSTALL_KIND="flake"' "sealed file pins INSTALL_KIND"
    assert_contains "$text" 'INSTALL_MODE="local"' "sealed file pins INSTALL_MODE"
    assert_contains "$text" 'INSTALL_ACTION="toolkit"' "sealed file names the action"
    assert_contains "$text" "LEAF_PUSH_DIR=\"${leaf}\"" "sealed file sets LEAF_PUSH_DIR"
    assert_contains "$text" "TARGET_SEED_DIR=\"${seed}\"" "sealed file sets TARGET_SEED_DIR"
}
