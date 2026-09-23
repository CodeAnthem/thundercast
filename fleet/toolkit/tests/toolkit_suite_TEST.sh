#!/usr/bin/env bash
# ==================================================================================================
# Fleet toolkit - bashTestSuite suite
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-19 | Modified: 2026-09-23
# Description:   Toolkit + tcast-sops logic tests (no private keys, no github)
# ==================================================================================================

# shellcheck source=./setup_TEST.sh
source "$(dirname "${BASH_SOURCE[0]}")/setup_TEST.sh"

suite_toolkit() {
    WORKDIR="$(mktemp -d)"
    LEAF="${WORKDIR}/leaf"
    export TCAST_LEAF_DIR="$LEAF"
    export TCAST_TOOLKIT_OP_KEY="${WORKDIR}/operator_sops.key"
    export TCAST_GIT_PUSH=0
    export TCAST_GIT_NAME=test
    export TCAST_GIT_EMAIL=test@test
    export TCAST_UI_NO_CLEAR=1
    export TCAST_UI_NO_PAUSE=1
    export TCAST_TOOLKIT_ROOT="$ROOT"
    
    mkdir -p "$LEAF/secrets/hosts" "$LEAF/.roles/worker"
    printf '{ ... }: {}\n' > "$LEAF/flake.nix"
    printf '{ opts.nixos.profile.id = "worker"; }\n' > "$LEAF/.roles/worker/opts.nix"
    git -C "$LEAF" init -q
    git -C "$LEAF" -c user.email=t@t -c user.name=t add flake.nix
    git -C "$LEAF" -c user.email=t@t -c user.name=t commit -q -m init
    
    tcast_register_ensure_defaults
    _aaf="${WORKDIR}/aa.conf"
    tcast_aa_set "$_aaf" weird 'secrets/with space/x.yaml'
    if [[ "$(tcast_aa_get "$_aaf" weird)" == 'secrets/with space/x.yaml' ]]; then
        bts_pass "aa roundtrips values with spaces"
    else
        bts_fail "aa space roundtrip"
    fi
    tcast_aa_set "$_aaf" note 'a=b#c'
    if [[ "$(tcast_aa_get "$_aaf" note)" == 'a=b#c' ]]; then
        bts_pass "aa roundtrips values with = and #"
    else
        bts_fail "aa special-char roundtrip"
    fi
    unset _aaf
    tcast_operator_ready && bts_fail "ready before init" || bts_pass "not ready before init"
    if out="$(tcast_sops_health)"; then
        echo "$out" | grep -q 'not registered' && bts_pass "health empty without operator" || bts_fail "health unregistered message"
    else
        bts_fail "health without operator should pass"
    fi
    mkdir -p "$LEAF/.toolkit/operator/keys"
    "$AGE" -o "$TCAST_TOOLKIT_OP_KEY" >/dev/null 2>&1
    "$AGE" -y "$TCAST_TOOLKIT_OP_KEY" > "$LEAF/.toolkit/operator/keys/age.pub"
    tcast_register_import_leaf
    tcast_operator_ready && bts_fail "pub file skipped Init" || bts_pass "pub file does not skip Init"
    tcast_register_meta_set operator_age_pub "$(tr -d '[:space:]' < "$LEAF/.toolkit/operator/keys/age.pub")"
    tcast_operator_ready && bts_fail "register pub skipped Init" || bts_pass "register pub without initialized_at is not ready"
    
    tcast_sops_operator_init >/dev/null 2>&1  # operator pubkey recorded
    tcast_operator_ready && bts_pass "ready after init" || bts_fail "ready after init"
    [[ "$(tcast_register_meta_get operator_age_pub)" == age1* ]] && bts_pass "operator init records pub" || bts_fail "operator pub"
    [[ -f "$TCAST_TOOLKIT_OP_KEY" ]] && bts_pass "operator private stays off-leaf" || bts_fail "operator private"
    if grep -q 'AGE-SECRET-KEY-' "$LEAF"/.toolkit/operator/keys/age.pub 2>/dev/null; then
        bts_fail "operator private leaked into leaf pub file"
    else
        bts_pass "leaf operator age.pub is public only"
    fi
    if tcast_sops_health >/dev/null; then
        bts_pass "health empty after init"
    else
        bts_fail "health empty after init"
    fi
    
    tcast_sops_put_value secrets/operator.yaml placeholder unset
    [[ -f "$LEAF/secrets/operator.yaml" ]] && grep -q '^sops:' "$LEAF/secrets/operator.yaml" \
        && bts_pass "encrypt new secret at real path" || bts_fail "encrypt operator.yaml"
    
    if tcast_sops_health >/dev/null; then
        bts_pass "health after encrypt"
    else
        bts_fail "health after encrypt"
    fi
    
    tcast_nodes_scaffold lab-node-a worker x86_64-linux >/dev/null 2>&1  # scaffolded host
    [[ -f "$LEAF/hosts/x86_64-linux/lab-node-a/nds_generated.nix" ]] && bts_pass "scaffold nds_generated.nix" || bts_fail "scaffold generated"
    [[ "$(tcast_register_host_get lab-node-a role)" == worker ]] && bts_pass "register host role" || bts_fail "register host"
    [[ -f "$LEAF/.toolkit/machines/lab-node-a/config" ]] && bts_pass "host config file" || bts_fail "host config file"
    [[ -f "$LEAF/.nds/hosts/lab-node-a.recipe" ]] && bts_pass "scaffold recipe" || bts_fail "scaffold recipe"
    [[ ! -f "$LEAF/.nds/hosts/lab-node-a.env" ]] && bts_pass "no leftover .env" || bts_fail "leftover .env"
    
    HOSTKEY="${WORKDIR}/host.age"
    age-keygen -o "$HOSTKEY" >/dev/null 2>&1
    HOSTPUB="$(age-keygen -y "$HOSTKEY" 2>/dev/null)"
    rm -f "$HOSTKEY"
    tcast_nodes_enroll_age lab-node-a "$HOSTPUB"
    grep -q "$HOSTPUB" "$LEAF/.sops.yaml" && bts_pass "enroll writes pub into .sops.yaml" || bts_fail "enroll policy"
    [[ -f "$LEAF/.toolkit/machines/lab-node-a/keys/age.pub" ]] && bts_pass "enroll writes keys/age.pub" || bts_fail "host age.pub"
    tcast_register_scope_add_member luks lab-node-a
    [[ "$(tcast_register_host_get lab-node-a groups)" == *luks* ]] && bts_pass "groups csv in host config" || bts_fail "groups csv"
    
    tcast_sops_put_value secrets/hosts/lab-node-a.yaml private_key dummy
    grep -q '^sops:' "$LEAF/secrets/hosts/lab-node-a.yaml" && bts_pass "per-host secret encrypts" || bts_fail "host secret"
    
    tcast_sops_put_value secrets/operator.yaml placeholder changed
    sops -d "$LEAF/secrets/operator.yaml" | grep -q 'changed' && bts_pass "change secret value" || bts_fail "set value"
    
    printf 'AGE-SECRET-KEY-LEAK\n' > "$LEAF/oops.txt"
    git -C "$LEAF" add oops.txt
    if tcast_git_validate >/dev/null 2>&1; then  # REFUSE: private key
        bts_fail "validate should refuse private key"
    else
        bts_pass "validate refuses AGE-SECRET-KEY"
    fi
    rm -f "$LEAF/oops.txt"
    git -C "$LEAF" reset -q HEAD -- oops.txt 2>/dev/null || true
    
    tcast_sops_remove_file secrets/hosts/lab-node-a.yaml
    [[ ! -f "$LEAF/secrets/hosts/lab-node-a.yaml" ]] && bts_pass "remove secret file" || bts_fail "remove"
    
    printf 'plain: true\n' > "$LEAF/secrets/operator-plain.yaml"
    git -C "$LEAF" add secrets/operator-plain.yaml
    if tcast_git_validate >/dev/null 2>&1; then  # REFUSE: unencrypted secrets/
        bts_fail "validate should refuse unencrypted secrets/"
    else
        bts_pass "validate refuses plaintext secrets/"
    fi
    rm -f "$LEAF/secrets/operator-plain.yaml"
    git -C "$LEAF" reset -q HEAD -- secrets/operator-plain.yaml 2>/dev/null || true
    
    tcast_sops_operator_rotate >/dev/null 2>&1  # sops sync + operator key rotated
    sops -d "$LEAF/secrets/operator.yaml" >/dev/null && bts_pass "decrypt after operator rotate" || bts_fail "rotate decrypt"
    
    if ver="$("${ROOT}/toolkit.sh" --version)" && [[ -n "$ver" ]]; then
        bts_pass "toolkit --version ($ver)"
    else
        bts_fail "toolkit --version"
    fi
    
    if "${ROOT}/toolkit.sh" sops help 2>/dev/null | grep -q 'tcast-sops health'; then
        bts_pass "toolkit sops help"
    else
        bts_fail "toolkit sops help"
    fi
    if out="$("${ROOT}/tcast-sops.sh" health)" && echo "$out" | grep -q 'operator:'; then
        bts_pass "tcast-sops health"
    else
        bts_fail "tcast-sops health"
    fi
    
    SAVE_LEAF="$TCAST_LEAF_DIR"
    SYNC="${WORKDIR}/syncleaf"
    BARE="${WORKDIR}/syncbare.git"
    WORK="${WORKDIR}/syncwork"
    mkdir -p "$SYNC"
    printf '{ }\n' > "$SYNC/flake.nix"
    git -C "$SYNC" init -q
    git -C "$SYNC" branch -M main
    git -C "$SYNC" -c user.email=t@t -c user.name=t add flake.nix
    git -C "$SYNC" -c user.email=t@t -c user.name=t commit -q -m base
    git clone --bare -q "$SYNC" "$BARE"
    git -C "$SYNC" remote add origin "$BARE"
    git -C "$SYNC" fetch -q origin
    git -C "$SYNC" branch --set-upstream-to=origin/main main >/dev/null
    export TCAST_LEAF_DIR="$SYNC"
    tcast_leaf_sync >/dev/null 2>&1
    [[ "${TCAST_LEAF_BEHIND:-0}" == 0 && "${TCAST_LEAF_SYNC_NEED_PROMPT:-0}" == 0 ]] \
        && bts_pass "sync already latest" || bts_fail "sync already latest"
    
    git clone -q "$BARE" "$WORK"
    printf '{ x }\n' > "$WORK/flake.nix"
    git -C "$WORK" -c user.email=t@t -c user.name=t commit -q -am up
    git -C "$WORK" push -q origin main
    printf '{ local }\n' > "$SYNC/flake.nix"
    tcast_leaf_sync >/dev/null 2>&1
    if [[ "${TCAST_LEAF_SYNC_NEED_PROMPT:-}" == 1 ]] && echo "${TCAST_LEAF_COLLISIONS:-}" | grep -q 'flake.nix' \
        && grep -q local "$SYNC/flake.nix"; then
        bts_pass "collision on overlapping flake.nix"
    else
        bts_fail "collision detect"
    fi
    
    tcast_leaf_reset_to_origin >/dev/null 2>&1  # HEAD is now at
    grep -q x "$SYNC/flake.nix" && bts_pass "reset takes origin" || bts_fail "reset origin"
    
    printf '{ y }\n' > "$WORK/flake.nix"
    git -C "$WORK" -c user.email=t@t -c user.name=t commit -q -am up2
    git -C "$WORK" push -q origin main
    tcast_leaf_sync >/dev/null 2>&1  # leaf fast-forwarded
    if [[ "${TCAST_LEAF_SYNC_NEED_PROMPT:-0}" == 0 ]] && grep -q y "$SYNC/flake.nix"; then
        bts_pass "ff when clean"
    else
        bts_fail "ff when clean"
    fi
    
    if (export TCAST_LEAF_DIR=/etc/nixos; tcast_leaf_assert_separate >/dev/null 2>&1); then  # leaf must not be /etc/nixos
        bts_fail "assert /etc/nixos"
    else
        bts_pass "refuse leaf=/etc/nixos"
    fi
    export TCAST_LEAF_DIR="$SAVE_LEAF"
    
    if declare -f tcast_ui_input_guard_enable >/dev/null \
        && declare -f tcast_ui_tty_read >/dev/null; then
        tcast_ui_input_guard_disable
        bts_pass "input guard disable is a no-op without enable"
    else
        bts_fail "input guard functions missing"
    fi

    rm -rf "$WORKDIR"
}
