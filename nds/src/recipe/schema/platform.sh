#!/usr/bin/env bash
# ==================================================================================================
# NDS - Schema group platform
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

_nds_platform_virt() {
    local _nds_plat_virt=""
    if command -v systemd-detect-virt >/dev/null 2>&1; then
        _nds_plat_virt=$(systemd-detect-virt -v 2>/dev/null || true)
        case "$_nds_plat_virt" in
            none|"") printf '%s\n' none; return 0 ;;
            vmware) printf '%s\n' vmware; return 0 ;;
            qemu) printf '%s\n' qemu; return 0 ;;
            kvm) printf '%s\n' kvm; return 0 ;;
            xen) printf '%s\n' xen; return 0 ;;
            microsoft) printf '%s\n' hyperv; return 0 ;;
            oracle) printf '%s\n' virtualbox; return 0 ;;
            *) printf '%s\n' other; return 0 ;;
        esac
    fi
    if [[ -r /sys/class/dmi/id/sys_vendor ]]; then
        _nds_plat_virt=$(tr '[:upper:]' '[:lower:]' < /sys/class/dmi/id/sys_vendor)
        case "$_nds_plat_virt" in
            *vmware*) printf '%s\n' vmware; return 0 ;;
            *qemu*|*kvm*) printf '%s\n' qemu; return 0 ;;
            *xen*) printf '%s\n' xen; return 0 ;;
            *microsoft*) printf '%s\n' hyperv; return 0 ;;
            *innotek*|*virtualbox*) printf '%s\n' virtualbox; return 0 ;;
        esac
    fi
    printf '%s\n' none
}

nds_detect_platformVm() {
    local _nds_plat_virt
    _nds_plat_virt=${ _nds_platform_virt; }
    if [[ "$_nds_plat_virt" == none ]]; then
        printf '%s\n' false
    else
        printf '%s\n' true
    fi
}

nds_detect_platformType() {
    _nds_platform_virt
}

nds_detect_platformTools() {
    nds_detect_platformVm
}

nds_schema_group platform "Platform"
nds_schema_field platform PLATFORM_RUN_ON_VM bool --detect nds_detect_platformVm --label 'Running in a virtual machine'
nds_schema_field platform PLATFORM_VM_TYPE choice --detect nds_detect_platformType \
    --when 'PLATFORM_RUN_ON_VM=true' \
    --choices 'none|vmware|qemu|kvm|xen|hyperv|virtualbox|other' \
    --labels 'none=Physical|vmware=VMware|qemu=QEMU|kvm=KVM|xen=Xen|hyperv=Hyper-V|virtualbox=VirtualBox|other=Other' \
    --label 'Virtual machine type'
nds_schema_field platform PLATFORM_VM_GUEST_TOOLS bool --detect nds_detect_platformTools \
    --when 'PLATFORM_RUN_ON_VM=true' --label 'Install VM guest tools'
