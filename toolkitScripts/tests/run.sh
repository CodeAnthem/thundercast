#!/usr/bin/env bash
# ==================================================================================================
# Thundercast - toolkitScripts logic tests (no private keys, no github)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-19 | Modified: 2026-08-28
# ==================================================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/core.sh
source "${ROOT}/lib/core.sh"
# shellcheck source=../lib/ui.sh
source "${ROOT}/lib/ui.sh"
# shellcheck source=../lib/register.sh
source "${ROOT}/lib/register.sh"
# shellcheck source=../lib/sops.sh
source "${ROOT}/lib/sops.sh"
# shellcheck source=../lib/git.sh
source "${ROOT}/lib/git.sh"
# shellcheck source=../lib/nodes.sh
source "${ROOT}/lib/nodes.sh"
# shellcheck source=../menus.sh
source "${ROOT}/menus.sh"

PASS=0
FAIL=0
fail() { echo "FAIL: $*"; FAIL=$((FAIL + 1)); }
ok() { echo "OK: $*"; PASS=$((PASS + 1)); }

AGE="$(command -v age-keygen || true)"
SOPS="$(command -v sops || true)"
if [[ -z "$AGE" ]]; then
    AGE="$(find /nix/store -maxdepth 4 -type f -name age-keygen 2>/dev/null | head -1)"
fi
if [[ -z "$SOPS" ]]; then
    SOPS="$(find /nix/store -maxdepth 4 -type f -name sops 2>/dev/null | head -1)"
fi
[[ -n "$AGE" && -n "$SOPS" ]] || { echo "need age-keygen and sops"; exit 1; }
export PATH="$(dirname "$AGE"):$(dirname "$SOPS"):$PATH"

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT
LEAF="${WORKDIR}/leaf"
export TCAST_LEAF_DIR="$LEAF"
export TCAST_TOOLKIT_OP_KEY="${WORKDIR}/operator.txt"
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
_kvf="${WORKDIR}/kv.conf"
tcast_kv_set "$_kvf" weird 'secrets/with space/x.yaml'
if [[ "$(tcast_kv_get "$_kvf" weird)" == 'secrets/with space/x.yaml' ]] \
    && grep -q 'weird="secrets/with space/x.yaml"' "$_kvf"; then
    ok "kv quotes values with spaces"
else
    fail "kv space quoting"
fi
tcast_kv_set "$_kvf" note 'a=b#c'
if [[ "$(tcast_kv_get "$_kvf" note)" == 'a=b#c' ]]; then
    ok "kv quotes values with = and #"
else
    fail "kv special-char quoting"
fi
unset _kvf
tcast_operator_ready && fail "ready before init" || ok "not ready before init"
if out="$(tcast_sops_health)"; then
    echo "$out" | grep -q 'not registered' && ok "health empty without operator" || fail "health unregistered message"
else
    fail "health without operator should pass"
fi
mkdir -p "$LEAF/.toolkit/operator/keys"
"$AGE" -o "$TCAST_TOOLKIT_OP_KEY" >/dev/null 2>&1
"$AGE" -y "$TCAST_TOOLKIT_OP_KEY" > "$LEAF/.toolkit/operator/keys/age.pub"
tcast_register_import_leaf
tcast_operator_ready && fail "pub file skipped Init" || ok "pub file does not skip Init"
tcast_register_meta_set operator_age_pub "$(tr -d '[:space:]' < "$LEAF/.toolkit/operator/keys/age.pub")"
tcast_operator_ready && fail "register pub skipped Init" || ok "register pub without initialized_at is not ready"

tcast_sops_operator_init
tcast_operator_ready && ok "ready after init" || fail "ready after init"
[[ "$(tcast_register_meta_get operator_age_pub)" == age1* ]] && ok "operator init records pub" || fail "operator pub"
[[ -f "$TCAST_TOOLKIT_OP_KEY" ]] && ok "operator private stays off-leaf" || fail "operator private"
if grep -q 'AGE-SECRET-KEY-' "$LEAF"/.toolkit/operator/keys/age.pub 2>/dev/null; then
    fail "operator private leaked into leaf pub file"
else
    ok "leaf operator age.pub is public only"
fi
if tcast_sops_health >/dev/null; then
    ok "health empty after init"
else
    fail "health empty after init"
fi

tcast_sops_put_value secrets/operator.yaml placeholder unset
[[ -f "$LEAF/secrets/operator.yaml" ]] && grep -q '^sops:' "$LEAF/secrets/operator.yaml" \
    && ok "encrypt new secret at real path" || fail "encrypt operator.yaml"

if tcast_sops_health >/dev/null; then
    ok "health after encrypt"
else
    fail "health after encrypt"
fi

tcast_nodes_scaffold lab-node-a worker x86_64-linux
[[ -f "$LEAF/hosts/x86_64-linux/lab-node-a/nds_generated.nix" ]] && ok "scaffold nds_generated.nix" || fail "scaffold generated"
[[ "$(tcast_register_host_get lab-node-a role)" == worker ]] && ok "register host role" || fail "register host"
[[ -f "$LEAF/.toolkit/machines/lab-node-a/config" ]] && ok "host config file" || fail "host config file"
[[ -f "$LEAF/.nds/hosts/lab-node-a.recipe" ]] && ok "scaffold recipe" || fail "scaffold recipe"
[[ ! -f "$LEAF/.nds/hosts/lab-node-a.env" ]] && ok "no leftover .env" || fail "leftover .env"

HOSTKEY="${WORKDIR}/host.age"
age-keygen -o "$HOSTKEY" >/dev/null 2>&1
HOSTPUB="$(age-keygen -y "$HOSTKEY" 2>/dev/null)"
rm -f "$HOSTKEY"
tcast_nodes_enroll_age lab-node-a "$HOSTPUB"
grep -q "$HOSTPUB" "$LEAF/.sops.yaml" && ok "enroll writes pub into .sops.yaml" || fail "enroll policy"
[[ -f "$LEAF/.toolkit/machines/lab-node-a/keys/age.pub" ]] && ok "enroll writes keys/age.pub" || fail "host age.pub"
tcast_register_scope_add_member luks lab-node-a
[[ "$(tcast_register_host_get lab-node-a groups)" == *luks* ]] && ok "groups csv in host config" || fail "groups csv"

tcast_sops_put_value secrets/hosts/lab-node-a.yaml private_key dummy
grep -q '^sops:' "$LEAF/secrets/hosts/lab-node-a.yaml" && ok "per-host secret encrypts" || fail "host secret"

tcast_sops_put_value secrets/operator.yaml placeholder changed
sops -d "$LEAF/secrets/operator.yaml" | grep -q 'changed' && ok "change secret value" || fail "set value"

printf 'AGE-SECRET-KEY-LEAK\n' > "$LEAF/oops.txt"
git -C "$LEAF" add oops.txt
if tcast_git_validate; then
    fail "validate should refuse private key"
else
    ok "validate refuses AGE-SECRET-KEY"
fi
rm -f "$LEAF/oops.txt"
git -C "$LEAF" reset -q HEAD -- oops.txt 2>/dev/null || true

tcast_sops_remove_file secrets/hosts/lab-node-a.yaml
[[ ! -f "$LEAF/secrets/hosts/lab-node-a.yaml" ]] && ok "remove secret file" || fail "remove"

printf 'plain: true\n' > "$LEAF/secrets/operator-plain.yaml"
git -C "$LEAF" add secrets/operator-plain.yaml
if tcast_git_validate; then
    fail "validate should refuse unencrypted secrets/"
else
    ok "validate refuses plaintext secrets/"
fi
rm -f "$LEAF/secrets/operator-plain.yaml"
git -C "$LEAF" reset -q HEAD -- secrets/operator-plain.yaml 2>/dev/null || true

tcast_sops_operator_rotate
sops -d "$LEAF/secrets/operator.yaml" >/dev/null && ok "decrypt after operator rotate" || fail "rotate decrypt"

if ver="$("${ROOT}/toolkit.sh" --version)" && [[ -n "$ver" ]]; then
    ok "toolkit --version ($ver)"
else
    fail "toolkit --version"
fi

if "${ROOT}/toolkit.sh" sops help 2>/dev/null | grep -q 'tc-sops health'; then
    ok "toolkit sops help"
else
    fail "toolkit sops help"
fi
if out="$("${ROOT}/tc-sops.sh" health)" && echo "$out" | grep -q 'operator:'; then
    ok "tc-sops health"
else
    fail "tc-sops health"
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
tcast_leaf_sync
[[ "${TCAST_LEAF_BEHIND:-0}" == 0 && "${TCAST_LEAF_SYNC_NEED_PROMPT:-0}" == 0 ]] \
    && ok "sync already latest" || fail "sync already latest"

git clone -q "$BARE" "$WORK"
printf '{ x }\n' > "$WORK/flake.nix"
git -C "$WORK" -c user.email=t@t -c user.name=t commit -q -am up
git -C "$WORK" push -q origin main
printf '{ local }\n' > "$SYNC/flake.nix"
tcast_leaf_sync
if [[ "${TCAST_LEAF_SYNC_NEED_PROMPT:-}" == 1 ]] && echo "${TCAST_LEAF_COLLISIONS:-}" | grep -q 'flake.nix' \
    && grep -q local "$SYNC/flake.nix"; then
    ok "collision on overlapping flake.nix"
else
    fail "collision detect"
fi

tcast_leaf_reset_to_origin
grep -q x "$SYNC/flake.nix" && ok "reset takes origin" || fail "reset origin"

printf '{ y }\n' > "$WORK/flake.nix"
git -C "$WORK" -c user.email=t@t -c user.name=t commit -q -am up2
git -C "$WORK" push -q origin main
tcast_leaf_sync
if [[ "${TCAST_LEAF_SYNC_NEED_PROMPT:-0}" == 0 ]] && grep -q y "$SYNC/flake.nix"; then
    ok "ff when clean"
else
    fail "ff when clean"
fi

if (export TCAST_LEAF_DIR=/etc/nixos; tcast_leaf_assert_separate); then
    fail "assert /etc/nixos"
else
    ok "refuse leaf=/etc/nixos"
fi
export TCAST_LEAF_DIR="$SAVE_LEAF"

if declare -f tcast_ui_input_guard_enable >/dev/null \
    && declare -f tcast_ui_tty_read >/dev/null; then
    tcast_ui_input_guard_disable
    ok "input guard disable is a no-op without enable"
else
    fail "input guard functions missing"
fi

echo
echo "Passed: ${PASS}  Failed: ${FAIL}"
[[ "$FAIL" == 0 ]]
