#!/usr/bin/env bash
# ==================================================================================================
# NDS - Classic config - Virtualisation guest tools
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-30 | Modified: 2026-08-19
# Description:   VM guest agents for classicInstall
# ==================================================================================================


_nds_nixcfg_virtualisation_generate() {
    local vm_type="$1"
    local output=""

    case "$vm_type" in
        vmware)
            output="virtualisation.vmware.guest.enable = true;"
            ;;
        qemu|kvm)
            output="services.qemuGuest.enable = true;"
            ;;
        hyperv)
            output="virtualisation.hypervGuest.enable = true;"
            ;;
        virtualbox)
            output="virtualisation.virtualbox.guest.enable = true;"
            ;;
        xen)
            output="# Xen guest - add hypervisor-specific guest tools in configuration.nix if needed"
            ;;
        other)
            output="# Unknown hypervisor - add guest tools in configuration.nix if needed"
            ;;
        *)
            return 0
            ;;
    esac

    nds_nixcfg_register "virtualisation" "$output" 55
}
