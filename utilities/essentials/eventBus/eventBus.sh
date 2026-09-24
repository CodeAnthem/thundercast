#!/usr/bin/env bash
# ==================================================================================================
# Thundercast - Bash Essentials - Event Bus
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-10 | Modified: 2026-09-24
# Description:   Named events with priority-ordered hooks.
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

_essentials_eventBus_init() {
    _essentials_init_isDone eventBus && return 0

    # shellcheck source=./eventBus_registry.sh
    _loadEssential "eventBus/eventBus_registry.sh"

    # shellcheck source=./eventBus_dispatch.sh
    _loadEssential "eventBus/eventBus_dispatch.sh"

    _essentials_init_mark eventBus
}
_essentials_eventBus_init || return 1
