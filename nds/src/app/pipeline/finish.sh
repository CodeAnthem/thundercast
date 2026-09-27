#!/usr/bin/env bash
# ==================================================================================================
# NDS - Finish screens
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# Description:   Bundle copy confirm and reboot. Skips are finish.backup and finish.reboot.
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

nds_skip_register finish.backup "do not wait for the bundle copy"
nds_skip_register finish.reboot "reboot only when NDS_REBOOT=true" keep-on-yes

_nds_finish_copy_hint() {
    local _fin_zip=$1 _fin_user _fin_host _fin_name
    declare -f nds_session_sshUser >/dev/null || return 0
    declare -f nds_session_hostIp >/dev/null || return 0
    _fin_user=$(nds_session_sshUser)
    _fin_host=$(nds_session_hostIp)
    [[ -n "$_fin_host" ]] || return 0
    _fin_name=nds_bundle.zip
    [[ "$_fin_zip" == *.tar.gz ]] && _fin_name=nds_bundle.tar.gz
    ui_b "Copy it from your local machine:"
    ui_i "SCP:"
    ui_i "  scp ${_fin_user}@${_fin_host}:${_fin_zip} ./${_fin_name}"
    ui_i "SSH:"
    ui_i "  ssh ${_fin_user}@${_fin_host} \"cat ${_fin_zip}\" > ${_fin_name}"
}

_nds_finish_usb() {
    local -n _fin_aa=$1
    [[ ${_fin_aa[ENCRYPTION]:-} == true && ${_fin_aa[ENCRYPTION_KEY]:-} == true ]] || return 0
    ui_h "Prepare your USB key (required to boot)"
    ui_i "The LUKS key is in this zip under secrets/."
    if [[ -n ${_fin_aa[ENCRYPTION_KEY_BOOT_FILE]:-} ]]; then
        ui_i "Copy it onto the USB as ${_fin_aa[ENCRYPTION_KEY_BOOT_FILE]} before you reboot."
    else
        ui_i "Copy it onto the USB as raw bytes before you reboot."
    fi
    ui_i "The device path must match ENCRYPTION_KEY_BOOT_DEVICE = ${_fin_aa[ENCRYPTION_KEY_BOOT_DEVICE]:-}"
    if [[ ${_fin_aa[ENCRYPTION_PASSWORD]:-} != true ]]; then
        ui_b "Key-only mode has no password fallback. If this USB is lost, the system cannot boot."
    fi
}

_nds_finish_reboot() {
    local _fin_rc=0
    if nds_skip finish.reboot; then
        if [[ ${NDS_REBOOT:-} == true ]]; then
            reboot
        else
            ui_b "Reboot when ready: sudo reboot"
        fi
        return 0
    fi
    prompt --type confirm "Reboot now?" || _fin_rc=$?
    if [[ "$_fin_rc" -eq 0 && "$UI_PROMPT_RESULT" == y ]]; then
        reboot
    else
        ui_b "Reboot when ready: sudo reboot"
    fi
}

nds_finish() {
    local _fin_file=$1 _fin_zip=$2
    local -A R=()
    local _fin_rc=0
    if [[ -f "$_fin_file" ]]; then
        nds_schema_enableAll || return 1
        nds_recipe_loadFile R "$_fin_file" || return 1
    fi
    ui_h "Save the restore package for future use"
    ui_b "Copy this zip off the machine before you reboot."
    ui_b "Bundle: ${_fin_zip}"
    if [[ ${R[ENCRYPTION]:-} == true ]]; then
        ui_b "Encryption was enabled. Keep this zip somewhere safe and offline."
        _nds_finish_usb R
    fi
    _nds_finish_copy_hint "$_fin_zip"
    ui_i "QUICK_START.md is at the root of the zip."
    ui_b "Online guide:"
    ui_i "https://github.com/CodeAnthem/thundercast/blob/main/nds/src/actions/classicInstall/README.md"
    if ! nds_skip finish.backup; then
        prompt --type confirm "I have copied the package (or do not need it)" || _fin_rc=$?
        [[ "$_fin_rc" -eq 0 && "$UI_PROMPT_RESULT" == y ]] || return 1
    fi
    if [[ ${R[INSTALL_MODE]:-} == remote ]]; then
        ui_h "Remote install complete"
        ui_b "The remote installer reboots the target when it finishes."
        ui_b "Commit the generated hardware facts in your flake host directory."
        ui_b "Enroll the machine age key in .sops.yaml, then run sops updatekeys on the split secret files."
    fi
    _nds_finish_reboot
}
