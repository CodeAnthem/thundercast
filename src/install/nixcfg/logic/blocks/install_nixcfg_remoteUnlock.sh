#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-01 | Modified: 2026-08-16
# Description:   Initrd SSH remote-unlock Nix config
# Feature:       boot.initrd.network.ssh (dropbear/unssh) + systemd initrd
#                networking. Host key is embedded automatically via the
#                hostKeys option (NixOS wires it into the initrd secrets).
# ==================================================================================================

# Auto-mode: reads from disk settings.
# Emits initrd SSH server + systemd initrd networking so the user can SSH
# into the initrd and unlock LUKS with `systemctl default`.
#
# 0 = off; 30-3600 = power-off after N seconds. Anything else is treated as off.
_nds_nixcfg_remoteUnlock_shutdown_sec() {
    local sec="${1:-0}"
    [[ "$sec" =~ ^[0-9]+$ ]] || { printf '0\n'; return 0; }
    if [[ "$sec" -eq 0 ]]; then
        printf '0\n'
    elif [[ "$sec" -ge 30 && "$sec" -le 3600 ]]; then
        printf '%s\n' "$sec"
    else
        printf '0\n'
    fi
}

_nds_nixcfg_remoteUnlock_generate() {
    local remote_port="$1"
    local ssh_key="$2"
    local net_mode="$3"
    local ip="${4:-}"
    local prefix="${5:-24}"
    local gateway="${6:-}"
    local show_hint="${7:-true}"
    local shutdown_sec
    shutdown_sec=$(_nds_nixcfg_remoteUnlock_shutdown_sec "${8:-0}")

    local net_block
    if [[ "$net_mode" == "static" ]]; then
        local ip_only="${ip%/*}"
        net_block=$(nds_nixcfg_subst "$(cat <<'EOF'
boot.initrd.systemd.network.networks."10-remote-unlock" = {
  matchConfig.Type = "ether";
  address = [ "@@IP@@/@@PREFIX@@" ];
  gateway = [ "@@GATEWAY@@" ];
  linkConfig.RequiredForOnline = "routable";
};
EOF
)" @@IP@@ "$ip_only" @@PREFIX@@ "$prefix" @@GATEWAY@@ "$gateway")
    else
        # ClientIdentifier = "mac" makes the initrd request its DHCP lease by
        # MAC address — the same identity the booted system uses (see
        # network.sh) — so the DHCP server hands out the SAME IP in the initrd
        # and after boot. Otherwise the initrd gets its own, unknowable lease.
        net_block=$(cat <<'EOF'
boot.initrd.systemd.network.networks."10-remote-unlock" = {
  matchConfig.Type = "ether";
  networkConfig.DHCP = "ipv4";
  dhcpV4Config.ClientIdentifier = "mac";
  linkConfig.RequiredForOnline = "routable";
};
EOF
)
    fi

    # Quoted heredoc: bash expands nothing, so Nix ${pkgs...} stays literal.
    # Only @@TOKEN@@ placeholders are filled in.
    #
    # Console hint (ENCRYPTION_REMOTE_HINT, default on): ExecStart must be a
    # real store binary (busybox). Busybox ip has no iproute2 -o oneline mode,
    # so parse `ip addr` / networkd leases. Do not wait for wait-online.
    # StandardOutput=tty + TTYPath=/dev/console: raw VT, magenta ANSI.
    # Hint text is concatenated, not subst'd as a value — bash would eat \033.
    #
    # command="systemctl default" runs the unlock prompt directly on SSH login;
    # 2>/dev/null hides the harmless "system scope bus" notice (no D-Bus in
    # initrd). boot.initrd.systemd.network.enable is required or networkd never
    # starts and SSH is unreachable.
    #
    # ENCRYPTION_REMOTE_SHUTDOWN: Type=simple watchdog that powers off after
    # N seconds if still in the initrd (0 = off). Never gate sshd. Type=simple
    # so initrd.target does not wait out the sleep; Conflicts=initrd-switch-root
    # kills the sleep on a successful unlock. Poweroff (not reboot): a remote
    # attacker cannot get a fresh prompt without a physical or hypervisor
    # power-on.
    [[ "$show_hint" == "false" ]] || show_hint=true

    local ssh_block
    ssh_block=$(nds_nixcfg_subst "$(cat <<'EOF'
boot.initrd.network.enable = true;
boot.initrd.network.ssh = {
  enable = true;
  port = @@REMOTE_PORT@@;
  authorizedKeys = [ ''command="systemctl default 2>/dev/null" @@SSH_KEY@@'' ];
  hostKeys = [ "/etc/secrets/initrd/ssh_host_ed25519_key" ];
};
boot.initrd.systemd.enable = true;
boot.initrd.systemd.network.enable = true;
boot.initrd.availableKernelModules = [ "e1000" "e1000e" "vmxnet3" "virtio_net" "r8169" "igb" "ixgbe" "tg3" ];
EOF
)" @@REMOTE_PORT@@ "$remote_port" @@SSH_KEY@@ "$ssh_key")

    local hint_block=""
    if [[ "$show_hint" == "true" ]]; then
        hint_block=$(nds_nixcfg_subst "$(cat <<'EOF'
boot.initrd.systemd.services.nds-show-ip = {
  description = "Show remote LUKS unlock address";
  wantedBy = [ "initrd.target" ];
  after = [ "systemd-networkd.service" "sshd.service" ];
  wants = [ "systemd-networkd.service" ];
  unitConfig.DefaultDependencies = false;
  path = [ pkgs.busybox ];
  serviceConfig = {
    Type = "oneshot";
    RemainAfterExit = true;
    StandardOutput = "tty";
    StandardError = "tty";
    TTYPath = "/dev/console";
    TTYReset = "no";
    TTYVHangup = "no";
    ExecStart = "${pkgs.busybox}/bin/sh -c ${builtins.toJSON ''
      get_addr() {
        for f in /run/systemd/netif/leases/*; do
          [ -f "$f" ] || continue
          a=$(${pkgs.busybox}/bin/sed -n 's/^ADDRESS=//p' "$f" | ${pkgs.busybox}/bin/head -n1)
          [ -n "$a" ] && { echo "$a"; return 0; }
        done
        ${pkgs.busybox}/bin/ip addr show 2>/dev/null \
          | ${pkgs.busybox}/bin/sed -n 's/^[[:space:]]*inet \([0-9][0-9.]*\).*/\1/p' \
          | ${pkgs.busybox}/bin/grep -v '^127\.' \
          | ${pkgs.busybox}/bin/head -n1
      }
      n=0
      addr=$(get_addr)
      while [ -z "$addr" ] && [ "$n" -lt 20 ]; do
        n=$((n + 1))
        ${pkgs.busybox}/bin/sleep 1
        addr=$(get_addr)
      done
      ${pkgs.busybox}/bin/echo
      if ! /bin/systemctl is-active --quiet sshd; then
        ${pkgs.busybox}/bin/echo -e "\033[1;35m>>> Remote LUKS unlock:\033[0m SSH is not listening — use the console passphrase"
      elif [ -n "$addr" ]; then
        ${pkgs.busybox}/bin/echo -e "\033[1;35m>>> Remote LUKS unlock:\033[0m root@$addr -p @@REMOTE_PORT@@"
      else
        ${pkgs.busybox}/bin/echo -e "\033[1;35m>>> Remote LUKS unlock:\033[0m root@<no-ipv4-yet> -p @@REMOTE_PORT@@"
      fi
    ''}";
  };
};
EOF
)" @@REMOTE_PORT@@ "$remote_port")
    fi

    local shutdown_block=""
    if [[ "$shutdown_sec" -ge 30 ]]; then
        shutdown_block=$(nds_nixcfg_subst "$(cat <<'EOF'
boot.initrd.systemd.services.nds-unlock-lockout = {
  description = "Power off if LUKS still locked after @@TIMEOUT@@ seconds";
  wantedBy = [ "initrd.target" ];
  after = [ "sshd.service" ];
  conflicts = [ "initrd-switch-root.service" ];
  unitConfig.DefaultDependencies = false;
  unitConfig.ConditionPathExists = "/etc/initrd-release";
  path = [ pkgs.busybox ];
  serviceConfig = {
    Type = "simple";
    Restart = "no";
    TimeoutStopSec = "5s";
    StandardOutput = "tty";
    StandardError = "tty";
    TTYPath = "/dev/console";
    TTYReset = "no";
    TTYVHangup = "no";
    ExecStart = "${pkgs.busybox}/bin/sh -c ${builtins.toJSON ''
      ${pkgs.busybox}/bin/sleep @@TIMEOUT@@
      [ -e /etc/initrd-release ] || exit 0
      ${pkgs.busybox}/bin/echo
      ${pkgs.busybox}/bin/echo -e "\033[1;31m>>> Remote LUKS unlock:\033[0m timed out, powering off"
      exec /bin/systemctl poweroff --force --force
    ''}";
  };
};
EOF
)" @@TIMEOUT@@ "$shutdown_sec")
    fi

    local store_items=""
    if [[ "$show_hint" == "true" || "$shutdown_sec" -ge 30 ]]; then
        store_items+=" pkgs.busybox"
    fi
    local store_block=""
    if [[ -n "$store_items" ]]; then
        store_block="boot.initrd.systemd.storePaths = [${store_items} ];"
    fi

    local block="$ssh_block"
    [[ -n "$hint_block" ]] && block+=$'\n'"$hint_block"
    [[ -n "$shutdown_block" ]] && block+=$'\n'"$shutdown_block"
    [[ -n "$store_block" ]] && block+=$'\n'"$store_block"
    block+=$'\n'"$net_block"

    nds_nixcfg_register "remoteUnlock" "$block" 13
}
