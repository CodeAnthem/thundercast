#!/usr/bin/env bash
# ==================================================================================================
# NDS - nixWriter pure block tests
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-06 | Modified: 2026-08-16
# ==================================================================================================

suite_nixwriter() {
    local tmp_dir output content
    local _sv_save="${NDS_NIXOS_STATE_VERSION:-}"

    export NDS_NIXOS_STATE_VERSION="26.05"

    if ! declare -f nds_nixcfg_register &>/dev/null; then
        warn "nixWriter not loaded — skipping"
        return 0
    fi

    tmp_dir=$(mktemp -d)
    output="${tmp_dir}/configuration.nix"

    nds_nixcfg_clear
    nds_nixcfg_register "nix" 'nix.settings.experimental-features = [ "nix-command" "flakes" ];' 5
    nds_nixcfg_access "admin" "true" "true" "2222" "false" "ssh-ed25519 AAAA" "s3cret"
    nds_nixcfg_region "Europe/Zurich" "en_US.UTF-8" "" "ch" ""
    nds_nixcfg_boot "grub" "false" "/dev/sdb"
    nds_nixcfg_network "purehost" "dhcp" "" "" "1.1.1.1" "1.0.0.1"
    nds_nixcfg_write "$output"

    content=$(<"$output")
    assert_contains "$content" 'users.users.admin' "pure access block"
    assert_contains "$content" 'initialHashedPassword =' "pure access hashed password"
    assert_not_contains "$content" 'initialPassword =' "pure access must not embed plaintext password"
    assert_not_contains "$content" 's3cret' "pure access must not embed plaintext password"
    assert_contains "$content" '$6$' "pure access SHA-512 hash"
    assert_contains "$content" 'ports = [ 2222 ]' "pure access ssh port"
    assert_contains "$content" 'Europe/Zurich' "pure region block"
    assert_contains "$content" 'console.keyMap = "sg"' "pure region Swiss console keymap"
    assert_contains "$content" 'description = "admin"' "pure access user description"
    assert_contains "$content" 'device = "/dev/sdb"' "pure boot grub disk"
    assert_contains "$content" 'purehost' "pure network hostname"
    assert_contains "$content" 'networkmanager.enable = true' "pure dhcp networkmanager"

    nds_nixcfg_clear
    _nds_nixcfg_network_dhcp "unlockhost" "" "" "true"
    nds_nixcfg_write "${tmp_dir}/remote-dhcp.nix"
    content=$(<"${tmp_dir}/remote-dhcp.nix")
    assert_contains "$content" 'systemd.network.enable = true' "remote unlock dhcp uses networkd"
    assert_not_contains "$content" 'networkmanager.enable = true' "remote unlock dhcp skips NM"

    nds_nixcfg_clear
    _nds_nixcfg_remoteUnlock_generate 2222 "ssh-rsa TEST" "dhcp"
    nds_nixcfg_write "${tmp_dir}/remote-unlock.nix"
    content=$(<"${tmp_dir}/remote-unlock.nix")
    assert_contains "$content" 'boot.initrd.network.ssh' "remote unlock ssh"
    assert_contains "$content" 'port = 2222' "remote unlock port"

    rm -rf "$tmp_dir"
    if [[ -n "$_sv_save" ]]; then
        export NDS_NIXOS_STATE_VERSION="$_sv_save"
    else
        unset NDS_NIXOS_STATE_VERSION
    fi
}
