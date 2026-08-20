#!/usr/bin/env bash
# ==================================================================================================
# ThunderCast - tc-status (NixOS / flake host status — not the toolkit Status menu)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-20 | Modified: 2026-08-20
# ==================================================================================================
set -euo pipefail

FLAKE_ROOT="${NDS_FLAKE_ROOT:-${TC_FLAKE_ROOT:-/etc/nixos}}"
HOST_NAME="${NDS_FLAKE_HOST:-${TC_FLAKE_HOST:-$(hostname -s 2>/dev/null || echo nixos)}}"

echo "host:     ${HOST_NAME}"
echo "hostname: $(hostname 2>/dev/null || true)"
if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    echo "os:       ${PRETTY_NAME:-$NAME}"
fi
if command -v nixos-version >/dev/null 2>&1; then
    echo "nixos:    $(nixos-version 2>/dev/null || true)"
fi
if [[ -d "$FLAKE_ROOT/.git" ]]; then
    echo "flake:    ${FLAKE_ROOT}  $(git -C "$FLAKE_ROOT" rev-parse --short HEAD 2>/dev/null || echo '?')"
    git -C "$FLAKE_ROOT" status -sb 2>/dev/null | head -5 | sed 's/^/  /'
fi
if systemctl cat comin.service >/dev/null 2>&1; then
    echo "comin:    $(systemctl is-active comin.service 2>/dev/null || echo unknown)"
fi
if [[ -L /run/current-system ]]; then
    echo "system:   $(readlink -f /run/current-system 2>/dev/null || true)"
fi
exit 0
