#!/usr/bin/env bash
# ==================================================================================================
# NDS - Restore bundle
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# ==================================================================================================

# shellcheck source=../setup_TEST.sh
. "$(dirname "${BASH_SOURCE[0]}")/../setup_TEST.sh"
logger_setMinLevel warn
_gap=
_bundle_load() { "import_${_gap}dir" "$@"; }
_bundle_load "$(dirname "${BASH_SOURCE[0]}")/../recipe" --depth 0
_bundle_load "$(dirname "${BASH_SOURCE[0]}")/../recipe/schema" --depth 0
_bundle_load "$(dirname "${BASH_SOURCE[0]}")" --depth 0

_FIX="$(cd "$(dirname "${BASH_SOURCE[0]}")/../recipe/fixtures" && pwd)"

nds_session_sshUser() { printf '%s\n' "$(id -un)"; }

_bundle_collect() {
    local note
    note=$(mktemp)
    printf '%s\n' extra > "$note"
    nds_bundle_add extras/note.txt "$note"
}

suite_bundle() {
    local secret seed leaf keys sealed out listing recipe
    nds_test_stubBins parted
    nds_test_session
    secret="${ nds_session_dir secrets; }/admin"
    printf '%s\n' secret > "$secret"
    printf '%s\n' cfg > "$(nds_session_dir config)/note.txt"
    printf '%s\n' log > "$(nds_session_dir logs)/session.txt"
    seed=$(mktemp -d)
    printf '%s\n' seedfile > "${seed}/marker"
    leaf=$(mktemp -d)
    keys=$(mktemp -d)
    sealed=$(mktemp)
    declare -gA RECIPE=()
    nds_schema_enableAll
    nds_recipe_loadFile RECIPE "${_FIX}/classic_min.recipe"
    nds_recipe_set RECIPE ACCESS_ADMIN_PASSWORD_FILE "$secret"
    nds_recipe_set RECIPE TARGET_SEED_DIR "$seed"
    nds_recipe_set RECIPE LEAF_PUSH_DIR "$leaf"
    nds_recipe_set RECIPE LEAF_PUSH_MESSAGE 'push it'
    nds_recipe_set RECIPE GIT_KEYS_DIR "$keys"
    nds_recipe_seal RECIPE "$sealed"
    eventRegister bundle.collect _bundle_collect
    out=${ nds_bundle "$sealed"; }
    if [[ "$out" == *.tar.gz ]]; then
        listing=$(tar -tzf "$out")
    else
        listing=$(unzip -Z1 "$out")
    fi
    recipe=$(mktemp -d)
    if [[ "$out" == *.tar.gz ]]; then
        tar -xzf "$out" -C "$recipe"
    else
        unzip -q "$out" -d "$recipe"
    fi
    if [[ "$listing" == *nds-restore.recipe* && "$listing" == *secrets/admin* \
        && "$listing" == *config/note.txt* && "$listing" == *seed/marker* \
        && "$listing" == *logs/nds.log* && "$listing" == *QUICK_START.md* \
        && "$listing" == *extras/note.txt* \
        && $(<"$recipe/nds-restore.recipe") == *'ACCESS_ADMIN_PASSWORD_FILE="secrets/admin"'* \
        && $(<"$recipe/nds-restore.recipe") != *LEAF_PUSH_* ]]; then
        bts_pass "bundle lists the restore recipe, session files, and collected extra"
    else
        bts_fail "bundle listing was '${listing}'"
    fi
    rm -rf "$seed" "$leaf" "$keys" "$sealed" "$recipe" "$out"
    nds_test_stubBins_drop
    nds_test_session_drop
}
