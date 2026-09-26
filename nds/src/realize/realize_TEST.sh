#!/usr/bin/env bash
# ==================================================================================================
# NDS - Realize plans
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# ==================================================================================================

# shellcheck source=../setup_TEST.sh
. "$(dirname "${BASH_SOURCE[0]}")/../setup_TEST.sh"
logger_setMinLevel warn
_gap=
_realize_load() { "import_${_gap}dir" "$@"; }
_realize_load "$(dirname "${BASH_SOURCE[0]}")/../recipe" --depth 0
_realize_load "$(dirname "${BASH_SOURCE[0]}")/../recipe/schema" --depth 0
_realize_load "$(dirname "${BASH_SOURCE[0]}")" --depth 0

_FIX="$(cd "$(dirname "${BASH_SOURCE[0]}")/../recipe/fixtures" && pwd)"
_log=()

mountpoint() { _log+=("mountpoint $*"); return 0; }
disk_unmountTarget() { _log+=("disk_unmountTarget $*"); }
disk_canUse() { _log+=("disk_canUse $*"); }
disk_partition() { _log+=("disk_partition $*"); }
disk_mountRoot() { _log+=("disk_mountRoot $*"); }
disk_luksFormat() { _log+=("disk_luksFormat $*"); }
disk_diskoApply() { _log+=("disk_diskoApply $*"); }
disk_setupInitrdSshKeys() { _log+=("disk_setupInitrdSshKeys $*"); }
disk_efiRegister() { _log+=("disk_efiRegister $*"); }
nixcfg_writeClassic() { _log+=("nixcfg_writeClassic $*"); }
nixcfg_writeGeneratedHost() { _log+=("nixcfg_writeGeneratedHost $*"); }
hwconfig_write() { _log+=("hwconfig_write $*"); }
nixos_copyConfigs() { _log+=("nixos_copyConfigs $*"); }
nixos_installClassic() { _log+=("nixos_installClassic $*"); }
nixos_prefetchFlake() { _log+=("nixos_prefetchFlake $*"); }
nixos_flakeEval() { _log+=("nixos_flakeEval $*"); }
nixos_installFlake() { _log+=("nixos_installFlake $*"); }
nixos_anywhere() { _log+=("nixos_anywhere $*"); }
nixos_verify() { _log+=("nixos_verify $*"); }
targetSeed_copy() { _log+=("targetSeed_copy $*"); }
targetSeed_gitKeys() { _log+=("targetSeed_gitKeys $*"); }
sops_installKey() { _log+=("sops_installKey $*"); }
git_commitAll() { _log+=("git_commitAll $*"); return 0; }
git_push() { _log+=("git_push $*"); return 0; }
flake_copyTree() { _log+=("flake_copyTree $*"); }
flake_listHosts() { return 0; }
flake_probe() { return 0; }
flake_hostHasDisko() { return 1; }
git_probe() { return 0; }
git_clone() { _log+=("git_clone $*"); }

_realize_text() {
    local IFS=$'\n'
    printf '%s' "${_log[*]-}"
}

_realize_variant() {
    local src=$1 dest=$2
    shift 2
    declare -gA RECIPE=()
    nds_schema_enableAll
    nds_recipe_loadFile RECIPE "$src"
    while (( $# )); do
        nds_recipe_set RECIPE "$1" "$2"
        shift 2
    done
    nds_recipe_seal RECIPE "$dest"
}

suite_realize() {
    local cfg stage leaf keys seed out got rc
    nds_test_session
    cfg=${ nds_session_dir config; }
    stage="${ nds_session_dir work; }/flake-stage"

    bts_section "Plans"
    _log=()
    rc=0
    nds_realize "${_FIX}/incomplete.recipe" 2>/dev/null || rc=$?
    if [[ "$rc" -eq 1 && ${#_log[@]} -eq 0 ]]; then
        bts_pass "incomplete recipe returns 1 with no tool call"
    else
        bts_fail "incomplete rc was ${rc} log '${_log[*]-}'"
    fi

    _log=()
    nds_realize "${_FIX}/classic_min.recipe"
    got=$(_realize_text)
    if [[ "$got" == "mountpoint -q /mnt
nixcfg_writeClassic R ${cfg}/configuration.nix
hwconfig_write ${cfg}
nixos_copyConfigs ${cfg} /mnt
nixos_installClassic /mnt
disk_efiRegister 
nixos_verify classic" ]]; then
        bts_pass "classic plan calls tools in order"
    else
        bts_fail "classic log was '${got}'"
    fi

    _log=()
    nds_realize "${_FIX}/flake_local.recipe"
    got=$(_realize_text)
    if [[ "$got" == "mountpoint -q /mnt
flake_copyTree /var/flake /mnt/etc/nixos
hwconfig_write /mnt/etc/nixos/hosts/x86_64-linux/control
nixcfg_writeGeneratedHost R /mnt/etc/nixos/hosts/x86_64-linux/control control  false /mnt/etc/nixos
nixos_prefetchFlake /mnt/etc/nixos
nixos_flakeEval /mnt/etc/nixos control
nixos_installFlake /mnt/etc/nixos control
disk_efiRegister 
nixos_verify flake /mnt/etc/nixos" ]]; then
        bts_pass "flake local plan calls tools in order"
    else
        bts_fail "flake local log was '${got}'"
    fi

    leaf=$(mktemp -d)
    keys=$(mktemp -d)
    out=$(mktemp)
    _realize_variant "${_FIX}/flake_local.recipe" "$out" \
        LEAF_PUSH_DIR "$leaf" LEAF_PUSH_MESSAGE 'add host' GIT_KEYS_DIR "$keys"
    _log=()
    nds_realize "$out"
    got=$(_realize_text)
    if [[ "$got" == "git_commitAll ${leaf} add host hosts .nds .toolkit .sops.yaml
git_push ${keys} ${leaf}
mountpoint -q /mnt"* ]]; then
        bts_pass "flake local with a leaf push commits before disk"
    else
        bts_fail "leaf push log was '${got}'"
    fi

    seed=$(mktemp -d)
    _realize_variant "${_FIX}/flake_local.recipe" "$out" TARGET_SEED_DIR "$seed"
    _log=()
    nds_realize "$out"
    got=$(_realize_text)
    if [[ "$got" == *"nixos_installFlake /mnt/etc/nixos control
targetSeed_copy ${seed} /mnt
disk_efiRegister "* ]]; then
        bts_pass "flake local with a seed copies it after install"
    else
        bts_fail "seed log was '${got}'"
    fi

    _realize_variant "${_FIX}/flake_local.recipe" "$out" \
        INSTALL_MODE remote REMOTE_TARGET_IP 10.1.1.1
    _log=()
    nds_realize "$out"
    got=$(_realize_text)
    if [[ "$got" == "flake_copyTree /var/flake ${stage}
nixos_prefetchFlake ${stage}
nixos_flakeEval ${stage} control
nixos_anywhere 10.1.1.1 ${stage} control" && "$got" != *--extra-files* ]]; then
        bts_pass "flake remote omits --extra-files without a seed"
    else
        bts_fail "remote log was '${got}'"
    fi

    _realize_variant "${_FIX}/flake_local.recipe" "$out" \
        INSTALL_MODE remote REMOTE_TARGET_IP 10.1.1.1 TARGET_SEED_DIR "$seed"
    _log=()
    nds_realize "$out"
    got=$(_realize_text)
    if [[ "$got" == *"nixos_anywhere 10.1.1.1 ${stage} control --extra-files ${seed}" ]]; then
        bts_pass "flake remote passes --extra-files when a seed is set"
    else
        bts_fail "remote seed log was '${got}'"
    fi

    bts_section "Hooks"
    _hook_name=
    _hook_pre() { _hook_name=$1; }
    eventRegister realize.pre_install _hook_pre
    _log=()
    nds_realize "${_FIX}/flake_local.recipe"
    got=$(_realize_text)
    if [[ "$_hook_name" == R && "$got" == *"nixcfg_writeGeneratedHost "* && "$got" == *"nixos_prefetchFlake "* \
        && "$got" != *"nixos_prefetchFlake"*"nixcfg_writeGeneratedHost"* ]]; then
        bts_pass "pre_install hook receives the recipe and runs before the build"
    else
        bts_fail "hook name was '${_hook_name}' log '${got}'"
    fi
    eventUnregister realize.pre_install _hook_pre

    _hook_fail() { return 1; }
    eventRegister realize.pre_install _hook_fail
    _log=()
    rc=0
    nds_realize "${_FIX}/flake_local.recipe" 2>/dev/null || rc=$?
    got=$(_realize_text)
    if [[ "$rc" -eq 1 && "$got" == *"nixcfg_writeGeneratedHost "* && "$got" != *nixos_prefetchFlake* ]]; then
        bts_pass "a failing pre_install hook aborts before the build"
    else
        bts_fail "failing hook rc was ${rc} log '${got}'"
    fi
    eventUnregister realize.pre_install _hook_fail

    git_push() { _log+=("git_push $*"); return 1; }
    _realize_variant "${_FIX}/flake_local.recipe" "$out" \
        LEAF_PUSH_DIR "$leaf" LEAF_PUSH_MESSAGE 'add host' GIT_KEYS_DIR "$keys"
    _log=()
    rc=0
    nds_realize "$out" 2>/dev/null || rc=$?
    got=$(_realize_text)
    if [[ "$rc" -eq 1 && "$got" == *"git_push ${keys} ${leaf}" && "$got" != *mountpoint* ]]; then
        bts_pass "a failed leaf push aborts before disk"
    else
        bts_fail "leaf fail rc was ${rc} log '${got}'"
    fi

    rm -rf "$leaf" "$keys" "$seed" "$out"
    nds_test_session_drop
}
