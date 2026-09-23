#!/usr/bin/env bash
# ==================================================================================================
# NDS - Bundle path helpers
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-30 | Modified: 2026-08-16
# Description:   Default zip path and download filename for the install backup
# ==================================================================================================

# Description: Absolute path of the install backup zip on this live ISO.
# Returns:
# - <String> /home/<ssh-user>/nds_bundle.zip
nds_bundle_path() {
    printf '/home/%s/nds_bundle.zip' "${ nds_lib_getSshUser; }"
}

# Description: Suggested local filename when copying the zip off the ISO.
# Returns:
# - <String> nds_install_backup_<stamp>_<hostname>.zip
nds_bundle_local_name() {
    local hostname stamp
    hostname="$(nds_cfg_get NETWORK_HOSTNAME)"
    hostname="${hostname:-nixos}"
    printf -v stamp '%(%Y%m%d_%H%M%S)T' -1
    printf 'nds_install_backup_%s_%s.zip' "$stamp" "$hostname"
}
