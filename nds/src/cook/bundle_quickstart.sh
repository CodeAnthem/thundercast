#!/usr/bin/env bash
# ==================================================================================================
# NDS - Bundle quick-start text
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# Description:   First login, LUKS, remote unlock, sops, and toolkit notes from the recipe.
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

nds_bundle_quickstart() {
    local -n _R=$1
    local _qs_out=$2 _qs_ver="unknown" _qs_host _qs_ip _qs_port _qs_user _qs_list _qs_bit
    local -a _qs_bits=()
    local _qs_file
    _qs_file="$(dirname "${BASH_SOURCE[0]}")/../VERSION"
    [[ -f "$_qs_file" ]] && _qs_ver=$(<"$_qs_file")
    _qs_host=${_R[NETWORK_HOSTNAME]:-${_R[FLAKE_HOST]:-unknown}}
    _qs_user=${_R[ACCESS_ADMIN_USER]:-admin}
    _qs_port=${_R[ACCESS_SSH_PORT]:-22}
    if declare -f nds_session_hostIp >/dev/null; then
        _qs_ip=${ nds_session_hostIp; }
    fi
    _qs_ip=${_qs_ip:-<machine-ip>}
    {
        printf '%s\n' "# NDS Quick Start - ${_qs_host}" "" \
            "Personalized setup guide for this machine." \
            "**Keep this bundle safe.** It holds unlock secrets when encryption was used." "" \
            "- **Hostname:** ${_qs_host}" \
            "- **Address:** ${_qs_ip}" \
            "- **NDS version:** ${_qs_ver}" \
            "- **Mode:** ${_R[INSTALL_MODE]:-local}" "" \
            "## What's in this bundle" "" \
            "| Path | What |" \
            "|------|------|" \
            '| `nds-restore.recipe` | Action and choices. Pass this file, or pass the whole bundle zip. |'
        _qs_bits=()
        [[ -n ${_R[ACCESS_ADMIN_PASSWORD_FILE]:-} ]] && _qs_bits+=("admin password")
        if [[ ${_R[ENCRYPTION]:-} == true && ${_R[ENCRYPTION_PASSWORD]:-} == true ]]; then
            _qs_bits+=("LUKS passphrase")
        fi
        if [[ ${_R[ENCRYPTION]:-} == true && ${_R[ENCRYPTION_KEY]:-} == true ]]; then
            _qs_bits+=("LUKS keyfile (copy it to the USB before reboot)")
        fi
        [[ -n ${_R[GIT_KEYS_DIR]:-} ]] && _qs_bits+=("git keys in secrets/git")
        if ((${#_qs_bits[@]})); then
            _qs_list=""
            for _qs_bit in "${_qs_bits[@]}"; do
                [[ -n "$_qs_list" ]] && _qs_list+=", "
                _qs_list+="$_qs_bit"
            done
            printf '%s\n' "| \`secrets/\` | ${_qs_list} |"
        else
            printf '%s\n' '| `secrets/` | Generated secret files |'
        fi
        if [[ -n ${_R[TOOLKIT_AGE_KEY_FILE]:-} || ${_R[INSTALL_ACTION]:-} == toolkit ]]; then
            printf '%s\n\n%s\n%s\n' "" "## Operator keys (keep this zip)" \
                "The operator age key and toolkit SSH key in this zip are not in git. Lose the zip and the toolkit secrets cannot be decrypted."
        fi
        if [[ ${_R[ENCRYPTION]:-} == true && ${_R[ENCRYPTION_REMOTE_UNLOCK]:-} == true ]]; then
            printf '%s\n' "" "## Remote unlock (initrd SSH)" "" \
                "Unlock the disk before login. The initrd SSH server listens on port ${_R[ENCRYPTION_REMOTE_PORT]:-2222} as root." \
                "Use the private key that matches the public key installed during setup." "" \
                '```bash' \
                "ssh -p ${_R[ENCRYPTION_REMOTE_PORT]:-2222} -o IdentitiesOnly=yes root@${_qs_ip} -i /path/to/unlock-key" \
                '```' "" \
                "### Initrd host key vs your unlock key" "" \
                "The initrd host key identifies the machine. Your unlock key is the client key and is not in this zip."
        elif [[ ${_R[ENCRYPTION]:-} == true ]]; then
            printf '%s\n' "" "## Disk encryption (LUKS)" "" \
                "The root disk is encrypted and must be unlocked at every boot."
        fi
        if [[ ${_R[ENCRYPTION]:-} == true && ${_R[ENCRYPTION_KEY]:-} == true ]]; then
            printf '%s\n' "" "### USB keyfile (required to boot)" "" \
                "Copy the keyfile onto a USB stick before you reboot." \
                "ENCRYPTION_KEY_BOOT_DEVICE = ${_R[ENCRYPTION_KEY_BOOT_DEVICE]:-}"
            if [[ -n ${_R[ENCRYPTION_KEY_BOOT_FILE]:-} ]]; then
                printf '%s\n' "Place it on the stick as ${_R[ENCRYPTION_KEY_BOOT_FILE]}."
            else
                printf '%s\n' "Write it as raw bytes to the USB device."
            fi
            if [[ ${_R[ENCRYPTION_PASSWORD]:-} != true ]]; then
                printf '%s\n' "" "Key-only mode has no passphrase fallback. If the USB is lost, the system cannot boot."
            fi
        fi
        printf '%s\n' "" "## First login" "" \
            "Log in as \`${_qs_user}\`. The admin password file is under secrets/ when it was generated." \
            "SSH: ssh ${_qs_user}@${_qs_ip}$( [[ "$_qs_port" != 22 ]] && printf ' -p %s' "$_qs_port" )"
        if [[ -n ${_R[SOPS_AGE_KEY_FILE]:-} || -n ${_R[TOOLKIT_AGE_KEY_FILE]:-} ]]; then
            printf '%s\n' "" "## Sops" "" \
                "Add the machine age public key to .sops.yaml, re-encrypt the host secrets, and commit."
        fi
        printf '%s\n' "" "## Restore this install" "" \
            "Pass the recipe file from an unpacked bundle:" "" \
            '```bash' \
            'bash nds/src/app/main.sh --import "$PWD/nds-restore.recipe"' \
            '```' "" \
            "Or pass the whole bundle. The preview still runs:" "" \
            '```bash' \
            'bash nds/src/app/main.sh --restore /path/to/nds_bundle.zip' \
            '```'
    } > "$_qs_out"
}
