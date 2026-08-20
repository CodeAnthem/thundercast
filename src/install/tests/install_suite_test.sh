#!/usr/bin/env bash
# ==================================================================================================
# NDS - Install pipeline tests (read-only / mocked)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-07 | Modified: 2026-08-20
# ==================================================================================================

suite_install() {
    local out

    if nds_import_file "${SCRIPT_DIR}/install/tests/install_aa_test.sh" 2>/dev/null \
        && nds_install_aa_bridge_selfcheck; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ install AA bridge + mode helpers present"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ install AA bridge + mode helpers"
    fi

    NDS_CURRENT_ACTION=classicInstall
    unset NDS_HARDWARE_GEN
    out=$(_nds_install_hardware_artifact_name)
    if [[ "$out" == "hardware-configuration.nix" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ classicInstall hardware artifact: hardware-configuration.nix"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ classicInstall hardware artifact: expected hardware-configuration.nix got $out"
    fi

    NDS_CURRENT_ACTION=installFlake
    unset NDS_HARDWARE_GEN
    out=$(_nds_install_hardware_artifact_name)
    if [[ "$out" == "facter.json" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ installFlake hardware artifact: facter.json (default)"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ installFlake hardware artifact: expected facter.json got $out"
    fi

    NDS_HARDWARE_GEN=legacy
    out=$(_nds_install_hardware_artifact_name)
    if [[ "$out" == "hardware-configuration.nix" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ installFlake hardware artifact: legacy override"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ installFlake hardware artifact: expected hardware-configuration.nix got $out"
    fi
    unset NDS_CURRENT_ACTION NDS_HARDWARE_GEN

    NDS_CURRENT_ACTION=remoteAction
    unset NDS_HARDWARE_GEN
    out=$(_nds_install_hardware_artifact_name)
    if [[ "$out" == "facter.json" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ remoteAction hardware artifact: facter.json"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ remoteAction hardware artifact: expected facter.json got $out"
    fi
    unset NDS_CURRENT_ACTION

    if grep -q 'NDS_ACTION:-' \
        "${SCRIPT_DIR}/install/verify/logic/install_verify.sh"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ verify: uses NDS_ACTION so addRole still flake-checks"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ verify: still keys only off NDS_CURRENT_ACTION (addRole would classic-check)"
    fi

    # Regression: stdout of --show-hardware-config must land in dest, not the detail log.
    local hw_tmp detail_tmp
    hw_tmp=$(mktemp)
    detail_tmp=$(mktemp)
    nixos-generate-config() {
        echo "stderr noise" >&2
        printf '%s\n' '{ boot.kernelModules = [ ]; }'
    }
    export NDS_INSTALL_DETAIL_LOG="$detail_tmp"
    if _nds_install_generate_legacy_hardware "$hw_tmp" \
        && [[ -s "$hw_tmp" ]] \
        && grep -q 'boot.kernelModules' "$hw_tmp" \
        && ! grep -q 'boot.kernelModules' "$detail_tmp"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ legacy hardware: writes dest, stderr only to detail log"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ legacy hardware: dest/log redirect broken"
        console "    dest=$(printf '%q' "$(cat "$hw_tmp" 2>/dev/null)")"
        console "    log=$(printf '%q' "$(cat "$detail_tmp" 2>/dev/null)")"
    fi
    unset -f nixos-generate-config
    unset NDS_INSTALL_DETAIL_LOG
    rm -f "$hw_tmp" "$detail_tmp"

    _nds_install_nix_store_free_mb() { echo 100; }
    out=$(_nds_install_nix_combined_nix_config "experimental-features = nix-command flakes")
    if [[ "$out" == "experimental-features = nix-command flakes" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ nix config: no store override before target root is mounted"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ nix config: expected no store override before /mnt is mounted"
        console "    got: $(printf '%q' "$out")"
    fi
    assert_not_contains "$out" "flakes store" "nix config"

    local fake_root
    fake_root=$(mktemp -d)
    mkdir -p "${fake_root}/nix/store"
    export NDS_NIX_TARGET_ROOT="$fake_root"
    export NDS_NIX_INSTALL_STORE_FORCE=1
    out=$(_nds_install_nix_combined_nix_config "experimental-features = nix-command flakes")
    if [[ "$out" == *$'\n'"store = ${fake_root}"* ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ nix config: chroot store when target root is mounted"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ nix config: expected chroot store ${fake_root}"
        console "    got: $(printf '%q' "$out")"
    fi
    unset NDS_NIX_TARGET_ROOT NDS_NIX_INSTALL_STORE_FORCE
    rm -rf "$fake_root"

    _nds_install_nix_store_free_mb() { echo 8192; }
    out=$(_nds_install_nix_combined_nix_config "experimental-features = nix-command flakes")
    if [[ "$out" == "experimental-features = nix-command flakes" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ nix config: large store unchanged"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ nix config: large store should pass through base config"
    fi
    unset -f _nds_install_nix_store_free_mb

    _nds_install_nix_store_free_mb() { echo 100; }
    if _nds_install_nix_ensure_live_store_space 64; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ live store space: enough free, skip GC"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ live store space: should pass when free >= need"
    fi
    unset -f _nds_install_nix_store_free_mb

    nds_test_snapshot_config
    CONFIG_DATA[BOOT_LOADER]=grub
    out=$(_nds_install_efi_loader_path)
    if [[ "$out" == '\\EFI\\nixos\\grubx64.efi' ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ EFI loader path: grub"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ EFI loader path: grub expected, got $out"
    fi

    CONFIG_DATA[BOOT_LOADER]=systemd-boot
    out=$(_nds_install_efi_loader_path)
    if [[ "$out" == '\\EFI\\systemd\\systemd-bootx64.efi' ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ EFI loader path: systemd-boot"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ EFI loader path: systemd-boot expected, got $out"
    fi
    nds_test_reset_config

    if [[ ! -f /mnt/boot/grub/grub.cfg ]]; then
        if _nds_install_verify_grub_bios /dev/null; then
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ verify grub bios: should fail without grub.cfg on /mnt"
        else
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ verify grub bios: requires grub.cfg on /mnt"
        fi
    else
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ verify grub bios: skipped (live /mnt layout)"
    fi

    if declare -f _nds_sops_run_age_keygen &>/dev/null; then
        if grep -qE 'env NIX_CONFIG=.*_nds_sops_run_age_keygen' "${SCRIPT_DIR}/install/nix/logic/install_sops.sh" 2>/dev/null; then
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ sops: age-keygen must not be invoked via env as external command"
        else
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ sops: age-keygen invoked as shell function"
        fi
    fi

    if declare -f _nds_install_disk_has_bios_grub &>/dev/null; then
        if _nds_install_disk_has_bios_grub /dev/null; then
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ bios_grub detect: /dev/null should not match"
        else
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ bios_grub detect: rejects invalid disk"
        fi
    fi

    if declare -f _nds_install_nix_canonical_store_path &>/dev/null; then
        out=$(_nds_install_nix_canonical_store_path /mnt /mnt/nix/store/abc-nixos-system-host)
        if [[ "$out" == '/nix/store/abc-nixos-system-host' ]]; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ canonical store path: strips /mnt prefix"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ canonical store path: expected /nix/store/… got $out"
        fi
    fi

    if declare -f _nds_install_nix_flake_system_ref &>/dev/null; then
        out=$(_nds_install_nix_flake_system_ref "control-toolkit")
        if [[ "$out" == 'nixosConfigurations."control-toolkit".config.system.build.toplevel' ]]; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ flake system ref: nixosConfigurations host attr"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ flake system ref: expected toplevel attr, got $out"
        fi
    fi

    if declare -f nds_install_diag_snapshot &>/dev/null; then
        local diag_log
        diag_log=$(mktemp)
        export NDS_INSTALL_DIAG_LOG="$diag_log"
        nds_install_diag_snapshot "test"
        if grep -q '=== test @' "$diag_log" && grep -q 'system_profile=' "$diag_log"; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ install_diag: compact snapshot in diag log"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ install_diag: compact snapshot"
        fi
        rm -f "$diag_log"
        unset NDS_INSTALL_DIAG_LOG
    fi

    if declare -f nds_install_logs_compose &>/dev/null; then
        local session_tmp detail_tmp diag_tmp composed_tmp
        session_tmp=$(mktemp)
        detail_tmp=$(mktemp)
        diag_tmp=$(mktemp)
        composed_tmp=$(mktemp)
        printf 'session-event\n' >"$session_tmp"
        printf '=== Partitioning disk ===\nmkfs.ext4\n=== Installing NixOS ===\n(see logs/nixosInstallation.log)\n' >"$detail_tmp"
        printf 'system_profile=ok\n' >"$diag_tmp"
        nds_install_logs_compose "$composed_tmp" "$session_tmp" "$detail_tmp" "$diag_tmp"
        if grep -q 'session-event' "$composed_tmp" \
            && grep -q 'mkfs.ext4' "$composed_tmp" \
            && grep -q 'system_profile=ok' "$composed_tmp" \
            && grep -q 'see logs/nixosInstallation.log' "$composed_tmp" \
            && ! grep -q 'copying path' "$composed_tmp"; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ install_logs_compose: merged nds.log without nixos-install dump"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ install_logs_compose: merged nds.log"
        fi
        rm -f "$session_tmp" "$detail_tmp" "$diag_tmp" "$composed_tmp"
    fi

    if declare -f _nds_install_partition_disko_pick_template &>/dev/null; then
        out=$(_nds_install_partition_disko_pick_template)
        if [[ -f "$out" ]]; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ disko template: ${out}"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ disko template missing: $out"
        fi
        if [[ -f "$out" ]] && grep -Eq '^[[:space:]]*\{[[:space:]]*(config|pkgs),' "$out"; then
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ disko template: NixOS module args (disko CLI does not pass pkgs)"
        elif [[ -f "$out" ]]; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ disko template: attrset (no required pkgs)"
        fi
        if [[ -f "$out" ]] && grep -q 'espAtBoot = bootLoader != "grub"' "$out" \
            && grep -q 'mkFsMnt "vfat" "/boot"' "$out"; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ disko template: systemd-boot ESP at /boot"
        elif [[ -f "$out" ]]; then
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ disko template: systemd-boot ESP should mount at /boot"
        fi
        if [[ -f "$out" ]] && grep -q -- '-n" "boot"' "$out" \
            && grep -q -- '-L" "nixos"' "$out"; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ disko template: filesystem labels boot/nixos"
        elif [[ -f "$out" ]]; then
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ disko template: missing boot/nixos mkfs labels"
        fi
        if [[ -f "$out" ]] && command -v nix-instantiate >/dev/null 2>&1 \
            && declare -f _nds_install_partition_disko_generate_params &>/dev/null; then
            local disko_work eval_out
            disko_work=$(mktemp -d)
            cp "$out" "${disko_work}/default.nix"
            _nds_install_partition_disko_generate_params \
                "${disko_work}/params.nix" "/dev/sda" "ext4" "0" "false" "20G" "false" "manual"
            eval_out=$(nix-instantiate --eval --expr \
                "builtins.isAttrs (import ${disko_work}/default.nix)" 2>/dev/null || true)
            if [[ "$eval_out" == "true" ]]; then
                TEST_PASSED=$((TEST_PASSED + 1))
                console "  ✓ disko template: imports without pkgs"
            else
                TEST_FAILED=$((TEST_FAILED + 1))
                console "  ✗ disko template: import without pkgs failed"
            fi
            rm -rf "$disko_work"
        fi
    fi

    out=$(NDS_NIXOS_STATE_VERSION=27.11 _nds_nixcfg_state_version)
    if [[ "$out" == "27.11" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ nixcfg stateVersion: NDS_NIXOS_STATE_VERSION override"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ nixcfg stateVersion override: expected 27.11 got $out"
    fi

    if declare -f _nds_install_flake_normalize_eval_hosts &>/dev/null; then
        local quoted_eval norm
        local -a listed=()
        quoted_eval='"control-toolkit\nencrypted-worker\ngateway-01"'
        norm="$(_nds_install_flake_normalize_eval_hosts "$quoted_eval")"
        mapfile -t listed < <(printf '%s\n' "$norm")
        if [[ ${#listed[@]} -eq 3 ]] \
            && nds_flake_host_in_list "control-toolkit" "${listed[@]}"; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ flake hosts: split quoted nix eval string into names"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ flake hosts: quoted eval stayed one blob (${#listed[@]}): ${norm}"
        fi
        norm="$(_nds_install_flake_normalize_eval_hosts $'control-toolkit\nworker-01')"
        mapfile -t listed < <(printf '%s\n' "$norm")
        if [[ ${#listed[@]} -eq 2 ]] && nds_flake_host_in_list "worker-01" "${listed[@]}"; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ flake hosts: pass through real newlines"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ flake hosts: newline list broken (${#listed[@]}): ${norm}"
        fi
    fi

    if grep -q 'skip UUID rewrite' \
        "${SCRIPT_DIR}/install/classic/logic/install_machine_facts.sh"; then
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ mounts.nix: still skips UUID rewrite for by-label placeholders"
    else
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ mounts.nix: rewrite by-label placeholders to UUID"
    fi

    local leaf_tmp roles_out script_out
    leaf_tmp=$(mktemp -d)
    mkdir -p "${leaf_tmp}/.roles/worker" "${leaf_tmp}/.roles/toolkit" \
        "${leaf_tmp}/.nds" "${leaf_tmp}/profiles"
    printf '%s\n' '{ }' > "${leaf_tmp}/.roles/worker/opts.nix"
    printf '%s\n' '{ }' > "${leaf_tmp}/.roles/toolkit/opts.nix"
    printf '%s\n' '{ }' > "${leaf_tmp}/profiles/control-toolkit.nix"
    printf '%s\n' 'remote_action_run() { :; }' > "${leaf_tmp}/.nds/action.sh"
    roles_out="$(_nds_install_flake_discover_roles "$leaf_tmp")"
    if [[ "$roles_out" == "worker" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ discover_roles: prefers .roles/ over profiles/; skips toolkit"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ discover_roles: expected worker got ${roles_out}"
    fi
    mkdir -p "${leaf_tmp}/.nds/actions"
    printf '%s\n' 'remote_action_run() { :; }' > "${leaf_tmp}/.nds/actions/addRole.sh"
    printf '%s\n' 'remote_action_run() { :; }' > "${leaf_tmp}/.nds/actions/toolkit.sh"
    printf '%s\n' 'remote_action_run() { :; }' > "${leaf_tmp}/.nds/actions/siteHook.sh"
    printf '%s\n' 'addRole|Add a host' 'toolkit|Ops VM' 'siteHook|Leaf custom' \
        > "${leaf_tmp}/.nds/actions/manifest"
    if [[ "$(nds_cast_list_actions "$leaf_tmp")" == "siteHook" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ cast_list_actions: user actions only (skips addRole/toolkit)"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ cast_list_actions: $(nds_cast_list_actions "$leaf_tmp")"
    fi
    if ! nds_cast_action_script "$leaf_tmp" addRole >/dev/null 2>&1 \
        && [[ "$(nds_cast_action_script "$leaf_tmp" siteHook)" == "${leaf_tmp}/.nds/actions/siteHook.sh" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ cast_action_script: skips addRole stub; resolves user action"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ cast_action_script: stub still loadable or siteHook missing"
    fi
    local stub_only
    stub_only=$(mktemp -d)
    mkdir -p "${stub_only}/.nds/actions"
    printf '%s\n' 'remote_action_run() { :; }' > "${stub_only}/.nds/actions/addRole.sh"
    printf '%s\n' 'remote_action_run() { :; }' > "${stub_only}/.nds/actions/toolkit.sh"
    if [[ -z "$(nds_cast_list_actions "$stub_only")" ]] \
        && ! nds_cast_require_user_actions "$stub_only" >/dev/null 2>&1; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ empty catalog (Cast stubs only) fails closed"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ empty catalog: list or require_user_actions"
    fi
    rm -rf "$stub_only"

    local restore_dir
    restore_dir=$(mktemp -d)
    mkdir -p "${restore_dir}/.nds/hosts"
    printf 'export NDS_DISK_STRATEGY="nds"\n' > "${restore_dir}/.nds/hosts/lab.env"
    printf '%s\n' '[disk]' 'DISK_STRATEGY="disko"' > "${restore_dir}/.nds/hosts/lab.recipe"
    nds_cfg_set DISK_STRATEGY ""
    nds_flake_load_host_restore "$restore_dir" lab
    if [[ "$(nds_cfg_get DISK_STRATEGY)" == "disko" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ host restore: .recipe wins over legacy .env"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ host restore: recipe did not win ($(nds_cfg_get DISK_STRATEGY))"
    fi
    rm -f "${restore_dir}/.nds/hosts/lab.recipe"
    nds_cfg_set DISK_STRATEGY ""
    nds_flake_load_host_restore "$restore_dir" lab
    if [[ "$(nds_cfg_get DISK_STRATEGY)" == "nds" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ host restore: falls back to .env"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ host restore: env fallback ($(nds_cfg_get DISK_STRATEGY))"
    fi
    rm -rf "$restore_dir"

    script_out="$(nds_flake_find_action_script "$leaf_tmp")"
    if [[ "$script_out" == "${leaf_tmp}/.nds/action.sh" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ find_action_script: leaf .nds/action.sh override"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ find_action_script: expected override got ${script_out}"
    fi
    printf '%s\n' \
        '{' \
        '  "nodes": {' \
        '    "root": { "inputs": { "thundercast": "thundercast" } },' \
        '    "thundercast": {' \
        '      "locked": {' \
        '        "rev": "abc123",' \
        '        "type": "git",' \
        '        "url": "ssh://git@github.com/CodeAnthem/thundercast.git"' \
        '      }' \
        '    }' \
        '  }' \
        '}' > "${leaf_tmp}/flake.lock"
    if [[ "$(_nds_install_flake_lock_node_field "${leaf_tmp}/flake.lock" thundercast rev)" == "abc123" ]] \
        && [[ "$(_nds_install_flake_lock_input_url "$leaf_tmp" thundercast)" == "git@github.com:CodeAnthem/thundercast.git" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ flake.lock: thundercast url/rev from locked git node"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ flake.lock: thundercast parse failed"
    fi
    NDS_FLAKE_REPO_URL="git@github.com:CodeAnthem/dp_cluster.git"
    if _nds_git_is_install_leaf CodeAnthem dp_cluster \
        && ! _nds_git_is_install_leaf CodeAnthem thundercast; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ install leaf: write-key match is the flake URL only"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ install leaf: owner/repo match broken"
    fi
    unset NDS_FLAKE_REPO_URL
    nds_cfg_set CAST_ACTION ""
    nds_cfg_set FLAKE_REPO_URL "git@github.com:example/leaf.git"
    local _saved_unattended
    _saved_unattended="$(declare -f nds_mode_is_unattended)"
    nds_mode_is_unattended() { return 0; }
    if ! nds_cast_select_action "$leaf_tmp" 2>/dev/null; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ cast_select_action: unattended without NDS_CAST_ACTION fails"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ cast_select_action: should not default to addRole"
    fi
    eval "$_saved_unattended"
    nds_cfg_set CAST_ACTION ""
    nds_cfg_set FLAKE_REPO_URL ""
    export NDS_CAST_ACTION="siteHook"
    nds_mode_is_unattended() { return 0; }
    if nds_cast_select_action "$leaf_tmp" \
        && [[ "$(nds_cfg_get CAST_ACTION)" == "siteHook" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ cast_select_action: NDS_CAST_ACTION env before settings apply"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ cast_select_action: NDS_CAST_ACTION env ignored"
    fi
    eval "$_saved_unattended"
    unset NDS_CAST_ACTION
    nds_cfg_set CAST_ACTION ""
    nds_cfg_set FLAKE_HOST ""
    nds_cfg_set NETWORK_HOSTNAME "lab-worker-c"
    nds_cfg_set FLAKE_INSTALL_PATH "/mnt/etc/nixos"
    nds_flake_prepare remote
    if [[ "$(nds_cfg_get FLAKE_HOST)" == "lab-worker-c" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ flake_prepare: empty FLAKE_HOST copies NETWORK_HOSTNAME"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ flake_prepare: expected lab-worker-c got $(nds_cfg_get FLAKE_HOST)"
    fi
    nds_cfg_set FLAKE_HOST "worker-02"
    nds_cfg_set NETWORK_HOSTNAME "lab-worker-c"
    nds_flake_prepare remote
    if [[ "$(nds_cfg_get NETWORK_HOSTNAME)" == "worker-02" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ flake_prepare: FLAKE_HOST wins over NETWORK_HOSTNAME"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ flake_prepare: NETWORK_HOSTNAME not synced from FLAKE_HOST"
    fi
    nds_cfg_set FLAKE_HOST "lab-worker-c"
    nds_cfg_set NETWORK_HOSTNAME "lab-worker-c"
    nds_cfg_set SCAFFOLD_ROLE ""
    mkdir -p "${leaf_tmp}/.roles/encrypted-worker"
    printf '%s\n' '{ }' > "${leaf_tmp}/.roles/encrypted-worker/opts.nix"
    if [[ "$(_nds_flake_default_role "encrypted-worker|gateway|worker")" == "worker" ]] \
        && [[ "$(_nds_flake_default_role "encrypted-worker|gateway")" == "encrypted-worker" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ default_role: prefers worker when present"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ default_role: worker preference broken"
    fi
    local _saved_choice _saved_numbered _saved_aa
    _saved_choice="$(declare -f nds_aa_ask_choice)"
    _saved_numbered="$(declare -f nds_aa_ask_numbered_choice)"
    _saved_aa="${NDS_CFG_AA_NAME:-}"
    NDS_CFG_AA_NAME=""
    nds_aa_ask_choice() {
        [[ -n "${NDS_CFG_AA_NAME:-}" ]] || return 1
        nds_cfg_set "$1" "${5:-worker}"
        return 0
    }
    nds_aa_ask_numbered_choice() {
        [[ -n "${NDS_CFG_AA_NAME:-}" ]] || return 1
        case "$1" in
            SCAFFOLD_MODE) nds_cfg_set SCAFFOLD_MODE "${4:-new}" ;;
            SCAFFOLD_ROLE)
                [[ "$4" == "worker" ]] || return 1
                nds_cfg_set SCAFFOLD_ROLE worker
                ;;
            FLAKE_HOST) nds_cfg_set FLAKE_HOST "${4:-}" ;;
            *) nds_cfg_set "$1" "${4:-}" ;;
        esac
        return 0
    }
    if nds_flake_role_select "$leaf_tmp" \
        && [[ "$(nds_cfg_get SCAFFOLD_ROLE)" == "worker" ]] \
        && [[ "$(nds_cfg_get FLAKE_HOST)" == "lab-worker-c" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ role_select: numbered menu binds AA and stores SCAFFOLD_ROLE"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ role_select: SCAFFOLD_ROLE='$(nds_cfg_get SCAFFOLD_ROLE)' (ISO skipped role list)"
    fi
    eval "$_saved_choice"
    eval "$_saved_numbered"
    NDS_CFG_AA_NAME="$_saved_aa"
    if grep -q 'nds_aa_ask_numbered_choice SCAFFOLD_ROLE' \
        "${SCRIPT_DIR}/install/flake/ui/install_flake_scaffold.sh"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ role_select: Role prompt is a numbered list"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ role_select: Role prompt is still a typed choice"
    fi
    local _saved_push probe_git
    probe_git=$(mktemp -d)
    git -C "$probe_git" init --quiet
    git -C "$probe_git" config user.email nds@localhost
    git -C "$probe_git" config user.name NDS
    git -C "$probe_git" commit --quiet --allow-empty -m init
    nds_cfg_set FLAKE_REPO_URL "git@github.com:CodeAnthem/dp_cluster.git"
    export NDS_FLAKE_REPO_URL="git@github.com:CodeAnthem/dp_cluster.git"
    _saved_push="$(declare -f _nds_install_flake_git_for_url)"
    _nds_install_flake_git_for_url() {
        case "$*" in
            *--dry-run*) return 1 ;;
            *) return 0 ;;
        esac
    }
    if ! nds_install_flake_probe_leaf_write "$probe_git" 2>/dev/null; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ leaf write probe: dry-run failure aborts"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ leaf write probe: dry-run failure was ignored"
    fi
    _nds_install_flake_git_for_url() { return 0; }
    if nds_install_flake_probe_leaf_write "$probe_git"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ leaf write probe: dry-run success continues"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ leaf write probe: dry-run success failed"
    fi
    eval "$_saved_push"
    rm -rf "$probe_git"
    if _nds_cast_url_is_http "https://github.com/CodeAnthem/thundercast.git" \
        && ! _nds_cast_url_is_http "git@github.com:CodeAnthem/thundercast.git"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ cast clone: HTTPS vs SSH URL classification"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ cast clone: HTTPS URL classification"
    fi
    if ! grep -q 'GIT_ASKPASS' "${SCRIPT_DIR}/install/flake/logic/install_flake_cast.sh" \
        && ! grep -q 'logic_main || crash "Failed to execute action"' \
        "${SCRIPT_DIR}/app/main.sh"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ cast clone: no fake GIT_ASKPASS; action fail is not crash 200"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ cast clone: still fake-askpass or crash() on action failure"
    fi
    local _saved_anon _saved_git _saved_run _saved_runtime
    local clone_out http_tmp
    _saved_anon="$(declare -f _nds_cast_https_anonymous_ok)"
    _saved_git="$(declare -f nds_git_clone)"
    _saved_run="$(declare -f nds_git_access_run)"
    _saved_runtime="${NDS_RUNTIME_DIR:-}"
    nds_cfg_set FLAKE_REPO_URL "git@github.com:CodeAnthem/dp_cluster.git"
    export NDS_FLAKE_REPO_URL="git@github.com:CodeAnthem/dp_cluster.git"
    nds_cfg_set GIT_ACCESS_STRATEGY ""
    nds_cfg_set GIT_EXISTING_KEY ""
    nds_git_access_run() {
        local -n _g_run=$2
        _g_run[FLAKE_REPO_URL]="git@github.com:CodeAnthem/thundercast.git"
        _g_run[GIT_ACCESS_STRATEGY]="deploy-all"
        _g_run[GIT_EXISTING_KEY]="true"
        export NDS_FLAKE_REPO_URL="${_g_run[FLAKE_REPO_URL]}"
        return 0
    }
    if nds_cast_ensure_access "https://github.com/CodeAnthem/thundercast.git" \
        && [[ "$(nds_cfg_get FLAKE_REPO_URL)" == "git@github.com:CodeAnthem/dp_cluster.git" ]] \
        && [[ "${NDS_FLAKE_REPO_URL}" == "git@github.com:CodeAnthem/dp_cluster.git" ]] \
        && [[ -z "$(nds_cfg_get GIT_ACCESS_STRATEGY)" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ cast access: catalog wizard does not steal FLAKE_REPO_URL or GIT_ACCESS_STRATEGY"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ cast access: FLAKE_REPO_URL became $(nds_cfg_get FLAKE_REPO_URL) env=${NDS_FLAKE_REPO_URL:-}"
    fi
    unset -f nds_git_access_run
    eval "$_saved_run"
    _nds_cast_https_anonymous_ok() { return 1; }
    nds_git_clone() {
        local dest="$2"
        mkdir -p "${dest}/.nds/actions"
        printf '%s\n' 'remote_action_run() { :; }' > "${dest}/.nds/actions/addRole.sh"
        return 0
    }
    NDS_RUNTIME_DIR=$(mktemp -d)
    clone_out="$(nds_cast_clone "https://github.com/CodeAnthem/thundercast.git" 2>/dev/null || true)"
    if [[ -n "$clone_out" && -f "${clone_out}/.nds/actions/addRole.sh" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ cast clone: private HTTPS falls back to SSH nds_git_clone"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ cast clone: private HTTPS did not use SSH clone path"
    fi
    rm -rf "$NDS_RUNTIME_DIR"
    eval "$_saved_anon"
    eval "$_saved_git"
    if curl -fsSL --connect-timeout 8 --max-time 20 -o /dev/null \
        -A 'nds-selftest' \
        "https://raw.githubusercontent.com/CodeAnthem/thundercast/main/src/app/VERSION"; then
        if _nds_cast_https_anonymous_ok "https://github.com/CodeAnthem/thundercast.git"; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ cast clone: public HTTPS ls-remote works (thundercast)"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ cast clone: public HTTPS ls-remote failed (would break public catalogs)"
        fi
        http_tmp=$(mktemp -d)
        if _nds_cast_git_http_clone "https://github.com/CodeAnthem/thundercast.git" \
            "${http_tmp}/boot" 2>/dev/null \
            && [[ -f "${http_tmp}/boot/start.sh" ]]; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ cast clone: live public HTTPS clone (thundercast)"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ cast clone: live public HTTPS clone failed"
        fi
        rm -rf "$http_tmp"
        if _nds_cast_https_anonymous_ok "https://github.com/CodeAnthem/thundercast.git"; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ cast clone: thundercast HTTPS is public (anonymous clone)"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ cast clone: thundercast HTTPS should be anonymously cloneable"
        fi
    else
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ cast clone: skip live GitHub checks (unreachable)"
    fi
    NDS_RUNTIME_DIR="$_saved_runtime"
    rm -rf "$leaf_tmp"

    local scaf_root scaf_host _sv_save
    scaf_root=$(mktemp -d)
    mkdir -p "${scaf_root}/.roles/worker"
    printf '%s\n' '{ }' > "${scaf_root}/.roles/worker/opts.nix"
    nds_cfg_set NETWORK_HOSTNAME "lab-worker-c"
    nds_cfg_set NETWORK_METHOD "dhcp"
    nds_cfg_set NETWORK_IP ""
    nds_cfg_set NETWORK_GATEWAY ""
    nds_cfg_set NETWORK_MASK "255.255.255.0"
    nds_cfg_set NETWORK_DNS_PRIMARY "1.1.1.1"
    nds_cfg_set NETWORK_DNS_SECONDARY ""
    nds_cfg_set NETWORK_INTERFACE "eth0"
    nds_cfg_set DISK_STRATEGY "nds"
    nds_cfg_set DISK_TARGET "/dev/sda"
    nds_cfg_set DISK_FS_TYPE "ext4"
    nds_cfg_set DISK_SWAP_SIZE_MIB "0"
    nds_cfg_set ENCRYPTION "false"
    _sv_save="${NDS_NIXOS_STATE_VERSION:-}"
    export NDS_NIXOS_STATE_VERSION="24.11"
    scaf_host="${scaf_root}/hosts/x86_64-linux/lab-worker-c"
    if _nds_install_flake_scaffold_host_folder "$scaf_root" "lab-worker-c" "worker" \
        && [[ ! -f "${scaf_host}/disko.nix" ]] \
        && grep -q 'networkmanager.enable = true' "${scaf_host}/configuration.nix" \
        && ! grep -q 'address = ""' "${scaf_host}/configuration.nix"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ scaffold: nds strategy skips disko.nix; DHCP has no empty address"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ scaffold: nds/DHCP host still wrote disko.nix or empty static IP"
    fi
    nds_cfg_set DISK_STRATEGY "disko"
    export NDS_SCAFFOLD_OVERWRITE_SKIP=true
    if _nds_install_flake_scaffold_host_folder "$scaf_root" "lab-worker-c" "worker" \
        && [[ -f "${scaf_host}/disko.nix" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ scaffold: disko strategy writes disko.nix"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ scaffold: disko strategy did not write disko.nix"
    fi
    unset NDS_SCAFFOLD_OVERWRITE_SKIP
    nds_cfg_set PLATFORM_VM_GUEST_TOOLS "true"
    nds_cfg_set PLATFORM_VM_TYPE "vmware"
    if _nds_install_flake_write_guest_nix "$scaf_host" \
        && grep -q 'virtualisation.vmware.guest.enable' "${scaf_host}/guest.nix"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ guest.nix: VMware guest tools from PLATFORM_VM_*"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ guest.nix: VMware guest tools missing"
    fi
    nds_cfg_set PLATFORM_VM_GUEST_TOOLS "false"
    if [[ -n "$_sv_save" ]]; then
        export NDS_NIXOS_STATE_VERSION="$_sv_save"
    else
        unset NDS_NIXOS_STATE_VERSION
    fi
    rm -rf "$scaf_root"

    local sops_tmp op_pub machine_pub placeholder
    sops_tmp=$(mktemp -d)
    op_pub="age1operatorpubkeytestaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    machine_pub="age1machinepubkeytestbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
    placeholder="age1ql3z7hjy54pw9hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p"
    if nds_toolkit_write_sops_policy "$sops_tmp" "$op_pub" \
        && grep -q 'creation_rules: \[\]' "${sops_tmp}/.sops.yaml" \
        && ! grep -q 'secrets/luks' "${sops_tmp}/.sops.yaml"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ toolkit sops policy: new file is empty rules (Init owns recipients)"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ toolkit sops policy: new file should be empty creation_rules"
    fi
    cat > "${sops_tmp}/.sops.yaml" << EOF
creation_rules:
  - path_regex: secrets/swarm/worker\\.yaml\$
    age: >-
      ${placeholder}
EOF
    if nds_toolkit_write_sops_policy "$sops_tmp" "$op_pub" \
        && grep -qF "$placeholder" "${sops_tmp}/.sops.yaml" \
        && ! grep -qF "$op_pub" "${sops_tmp}/.sops.yaml"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ toolkit sops policy: leaves existing yaml (no placeholder swap)"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ toolkit sops policy: must not rewrite existing .sops.yaml"
    fi
    cat > "${sops_tmp}/.sops.yaml" << EOF
creation_rules:
  - path_regex: secrets/swarm/worker\\.yaml\$
    age:
      - ${op_pub}
      - ${machine_pub}
EOF
    if nds_toolkit_write_sops_policy "$sops_tmp" "$op_pub" \
        && grep -qF "$machine_pub" "${sops_tmp}/.sops.yaml" \
        && grep -qF "$op_pub" "${sops_tmp}/.sops.yaml"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ toolkit sops policy: reinstall does not clobber existing yaml"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ toolkit sops policy: clobbered existing yaml"
    fi
    cat > "${sops_tmp}/.sops.yaml" << EOF
creation_rules:
  - path_regex: secrets/swarm/worker\\.yaml\$
    age:
      - ${machine_pub}
EOF
    if nds_toolkit_write_sops_policy "$sops_tmp" "$op_pub" \
        && grep -qF "$machine_pub" "${sops_tmp}/.sops.yaml" \
        && ! grep -qF "$op_pub" "${sops_tmp}/.sops.yaml"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ toolkit sops policy: does not append operator (Init owns that)"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ toolkit sops policy: must not append operator into .sops.yaml"
    fi

    local seed_cast seed_mnt
    seed_cast=$(mktemp -d)
    seed_mnt=$(mktemp -d)
    mkdir -p "${seed_cast}/toolkitScripts"
    printf '%s\n' '#!/bin/sh' 'echo ok' > "${seed_cast}/toolkitScripts/toolkit.sh"
    printf '%s\n' '#!/bin/sh' 'echo sops' > "${seed_cast}/toolkitScripts/tc-sops.sh"
    chmod +x "${seed_cast}/toolkitScripts/toolkit.sh" "${seed_cast}/toolkitScripts/tc-sops.sh"
    git -C "$seed_cast" init -q
    git -C "$seed_cast" -c user.email=nds@test -c user.name=nds add toolkitScripts
    git -C "$seed_cast" -c user.email=nds@test -c user.name=nds commit -q -m seed
    NDS_CAST_PROBE_DIR="$seed_cast"
    NDS_CAST_DEFAULT_URL="git@github.com:CodeAnthem/thundercast.git"
    if nds_toolkit_seed_scripts_to_target "$seed_mnt" \
        && [[ -x "${seed_mnt}/var/lib/nds-toolkit/current/toolkit.sh" ]] \
        && [[ "$(readlink "${seed_mnt}/var/lib/nds-toolkit/current")" == "src/toolkitScripts" ]] \
        && [[ "$(git -C "${seed_mnt}/var/lib/nds-toolkit/src" remote get-url origin 2>/dev/null)" == "$NDS_CAST_DEFAULT_URL" ]] \
        && [[ -L "${seed_mnt}/root/.nds/bin/tc-sops" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ toolkit seed: relative symlink to toolkitScripts"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ toolkit seed: missing current/toolkit.sh, tc-sops, or stale origin"
    fi
    unset NDS_CAST_DEFAULT_URL
    unset NDS_CAST_PROBE_DIR
    rm -rf "$sops_tmp" "$seed_cast" "$seed_mnt"
}
