#!/usr/bin/env bash
# ==================================================================================================
# targetSeed - copy preserves modes
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# ==================================================================================================

# shellcheck source=../../setup_TEST.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../setup_TEST.sh"
import_dir "$(dirname "${BASH_SOURCE[0]}")" --depth 0

suite_targetSeed() {
    local src mnt mode
    src=$(mktemp -d)
    mnt=$(mktemp -d)
    mkdir -p "${src}/root"
    printf '%s\n' secret > "${src}/root/key"
    chmod 600 "${src}/root/key"
    targetSeed_copy "$src" "$mnt"
    mode=$(stat -c '%a' "${mnt}/root/key")
    if [[ "$mode" == 600 && $(<"${mnt}/root/key") == secret ]]; then
        bts_pass "targetSeed_copy preserves the file mode"
    else
        bts_fail "copied mode was ${mode}"
    fi
    rm -rf "$src" "$mnt"

    local keys map line
    keys=$(mktemp -d)
    mnt=$(mktemp -d)
    printf '%s\n' 'priv' > "${keys}/github.com_codeanthem_thundercast"
    targetSeed_gitKeys "$keys" "$mnt" || { bts_fail "git keys install failed"; return; }
    map=$(<"${mnt}/var/lib/tcast/git.map")
    line=$'codeanthem/thundercast\t/root/.ssh/nds/github.com_codeanthem_thundercast'
    if [[ "$map" == *"$line"* && -x "${mnt}/var/lib/tcast/bin/tcast-git-ssh" \
        && -f "${mnt}/root/.ssh/nds/github.com_codeanthem_thundercast" ]]; then
        bts_pass "git.map is owner/repo and tcast-git-ssh is installed"
    else
        bts_fail "git map was '${map}'"
    fi
    # shellcheck source=../../../../tcast/lib/tcast_common.sh
    source "$(dirname "${BASH_SOURCE[0]}")/../../../../tcast/lib/tcast_common.sh"
    # shellcheck source=../../../../tcast/lib/tcast_git_ssh.sh
    source "$(dirname "${BASH_SOURCE[0]}")/../../../../tcast/lib/tcast_git_ssh.sh"
    export TCAST_GIT_SSH_MAP="${mnt}/var/lib/tcast/git.map"
    export TCAST_GIT_SSH_ROOT="$mnt"
    local looked
    looked=$(_tcast_git_ssh_lookup_key codeanthem/thundercast)
    if [[ "$looked" == "${mnt}/root/.ssh/nds/github.com_codeanthem_thundercast" ]]; then
        bts_pass "tcast reads the written git.map"
    else
        bts_fail "tcast lookup was '${looked}'"
    fi
    rm -rf "$keys" "$mnt"
}
