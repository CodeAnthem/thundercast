#!/usr/bin/env bash
# ==================================================================================================
# NDS - Manual NixOS store / generation cleanup
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-09 | Modified: 2026-07-09
# Description:   Lab helper — delete old system generations and collect garbage.
#                Configurable retention via flags / env (auto-cleanup modules later).
# Env:
#   NDS_CLEAN_KEEP_GENS     Generations to keep (default 2)
#   NDS_CLEAN_OLDER_THAN    nix-collect-garbage threshold (default 7d)
# ==================================================================================================
set -euo pipefail

KEEP_GENS="${NDS_CLEAN_KEEP_GENS:-2}"
OLDER_THAN="${NDS_CLEAN_OLDER_THAN:-7d}"
DRY_RUN=0
OPTIMISE=0

_nds_clean_die() {
    echo "nds-clean: $*" >&2
    exit 1
}

_nds_clean_info() {
    echo "nds-clean: $*"
}

_nds_clean_usage() {
    cat <<EOF
nds-clean: remove unused Nix store paths and old system generations.

Options:
  --dry-run          Print actions without executing
  --keep-gens N      Keep N system generations (default: ${KEEP_GENS})
  --older-than T     Passed to nix-collect-garbage (default: ${OLDER_THAN})
  --optimise         Run nix store optimise after garbage collection
  -h, --help         Show this help

Env:
  NDS_CLEAN_KEEP_GENS
  NDS_CLEAN_OLDER_THAN
EOF
}

_nds_clean_run() {
    if [[ "$DRY_RUN" -eq 1 ]]; then
        _nds_clean_info "[dry-run] $*"
    else
        _nds_clean_info "$*"
        "$@"
    fi
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=1; shift ;;
        --keep-gens)
            [[ $# -ge 2 ]] || _nds_clean_die "--keep-gens requires a number"
            KEEP_GENS="$2"
            shift 2
            ;;
        --older-than)
            [[ $# -ge 2 ]] || _nds_clean_die "--older-than requires a value"
            OLDER_THAN="$2"
            shift 2
            ;;
        --optimise) OPTIMISE=1; shift ;;
        -h|--help)
            _nds_clean_usage
            exit 0
            ;;
        *)
            _nds_clean_die "unknown option: $1 (try --help)"
            ;;
    esac
done

[[ "$(id -u)" -eq 0 ]] || _nds_clean_die "run as root"

shopt -s nullglob
for d in /tmp/nds-switch-hostfacts.*; do
    [[ -d "$d" ]] || continue
    _nds_clean_run rm -rf "$d"
done

if command -v nix-env &>/dev/null; then
    _nds_clean_run nix-env -p /nix/var/nix/profiles/system --delete-generations "+${KEEP_GENS}"
fi

if command -v nix-collect-garbage &>/dev/null; then
    _nds_clean_run nix-collect-garbage --delete-older-than "$OLDER_THAN"
    _nds_clean_run nix-collect-garbage -d
fi

if [[ "$OPTIMISE" -eq 1 ]] && command -v nix &>/dev/null; then
    _nds_clean_run nix store optimise
fi

_nds_clean_info "done"
