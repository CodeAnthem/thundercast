#!/usr/bin/env bash
# ==================================================================================================
# NDS - Platform preset
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-01 | Modified: 2026-08-15
# ==================================================================================================

# Description: Detect hypervisor / VM type (none | vmware | qemu | kvm | xen | hyperv | virtualbox | other).
_nds_settings_platform_detect_virt() {
    local virt=""

    if command -v systemd-detect-virt &>/dev/null; then
        virt=$(systemd-detect-virt -v 2>/dev/null || true)
        case "$virt" in
            none|"") printf 'none'; return 0 ;;
            vmware) printf 'vmware'; return 0 ;;
            qemu) printf 'qemu'; return 0 ;;
            kvm) printf 'kvm'; return 0 ;;
            xen) printf 'xen'; return 0 ;;
            microsoft) printf 'hyperv'; return 0 ;;
            oracle) printf 'virtualbox'; return 0 ;;
            *) printf 'other'; return 0 ;;
        esac
    fi

    if [[ -r /sys/class/dmi/id/sys_vendor ]]; then
        virt=$(tr '[:upper:]' '[:lower:]' < /sys/class/dmi/id/sys_vendor)
        case "$virt" in
            *vmware*) printf 'vmware'; return 0 ;;
            *qemu*|*kvm*) printf 'qemu'; return 0 ;;
            *xen*) printf 'xen'; return 0 ;;
            *microsoft*) printf 'hyperv'; return 0 ;;
            *innotek*|*virtualbox*) printf 'virtualbox'; return 0 ;;
        esac
    fi

    printf 'none'
}

platform_defaults() {
    local detected virt_default on_vm_default tools_default
    detected=$(_nds_settings_platform_detect_virt)
    if [[ "$detected" != none ]]; then
        virt_default="$detected"
        on_vm_default=true
        tools_default=true
    else
        virt_default=none
        on_vm_default=false
        tools_default=false
    fi
    nds_cfg_set PLATFORM_RUN_ON_VM "$on_vm_default"
    nds_cfg_set PLATFORM_VM_TYPE "$virt_default"
    nds_cfg_set PLATFORM_VM_GUEST_TOOLS "$tools_default"
}

platform_configure() {
    nds_cfg_section_title "Platform"
    nds_cfg_ask_toggle PLATFORM_RUN_ON_VM "Running in a virtual machine" "$(nds_cfg_get PLATFORM_RUN_ON_VM)"
    if nds_cfg_true PLATFORM_RUN_ON_VM; then
        nds_cfg_ask_choice PLATFORM_VM_TYPE "Virtual machine type" \
            "none|vmware|qemu|kvm|xen|hyperv|virtualbox|other" \
            "none=Physical / unknown|vmware=VMware|qemu=QEMU|kvm=KVM|xen=Xen|hyperv=Hyper-V|virtualbox=VirtualBox|other=Other" \
            "$(nds_cfg_get PLATFORM_VM_TYPE)"
        nds_cfg_ask_toggle PLATFORM_VM_GUEST_TOOLS "Install VM guest tools" true
    fi
}

platform_summary() {
    nds_cfg_summary_row "Virtual machine" "$(nds_cfg_display_toggle "$(nds_cfg_get PLATFORM_RUN_ON_VM)")"
    if nds_cfg_true PLATFORM_RUN_ON_VM; then
        nds_cfg_summary_row "VM type" "$(nds_cfg_get PLATFORM_VM_TYPE)"
        nds_cfg_summary_row "Guest tools" "$(nds_cfg_display_toggle "$(nds_cfg_get PLATFORM_VM_GUEST_TOOLS)")"
    fi
}

platform_validate() {
    return 0
}

if declare -f nds_preset_register_hooks &>/dev/null; then
    nds_preset_register_hooks \
        defaults=platform_defaults \
        configure=platform_configure \
        validate=platform_validate \
        summary=platform_summary
fi

NDS_PRESET_PRIORITY=25
NDS_PRESET_DISPLAY="Platform"
