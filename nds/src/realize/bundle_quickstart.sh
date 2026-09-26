#!/usr/bin/env bash
# ==================================================================================================
# NDS - Bundle quick-start text
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

nds_bundle_quickstart() {
    local -n _R=$1
    local _qs_out=$2 _qs_ver="unknown" _qs_version_file
    _qs_version_file="$(dirname "${BASH_SOURCE[0]}")/../VERSION"
    [[ -f "$_qs_version_file" ]] && _qs_ver=$(<"$_qs_version_file")
    cat > "$_qs_out" <<EOF
# NDS restore

Version: ${_qs_ver}
Action: ${_R[INSTALL_ACTION]:-apply}
Kind: ${_R[INSTALL_KIND]:-}
Mode: ${_R[INSTALL_MODE]:-local}
Host: ${_R[NETWORK_HOSTNAME]:-${_R[FLAKE_HOST]:-}}

Apply the sealed recipe in this bundle to birth the machine again.
Secrets in this archive are files under secrets/.
EOF
}
