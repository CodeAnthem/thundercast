#!/usr/bin/env bash
# ==================================================================================================
# Git utility - standalone tests (no NDS)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-29 | Modified: 2026-08-31
# ==================================================================================================

set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../main.sh
source "${ROOT}/main.sh"

PASS=0
FAIL=0

# Description: Record a passing check.
ok() {
    PASS=$((PASS + 1))
    printf '  ok  %s\n' "$1"
}

# Description: Record a failing check.
fail() {
    FAIL=$((FAIL + 1))
    printf '  FAIL %s\n' "$1"
}

# Description: Pass when the command returns 0.
assert() {
    local name="$1"
    shift
    if "$@"; then
        ok "$name"
    else
        fail "$name"
    fi
}

# Description: Pass when the command returns non-zero.
assert_false() {
    local name="$1"
    shift
    if "$@"; then
        fail "$name"
    else
        ok "$name"
    fi
}

# Description: Pass when two strings are equal.
assert_eq() {
    local name="$1" got="$2" want="$3"
    if [[ "$got" == "$want" ]]; then
        ok "$name"
    else
        fail "$name ($got != $want)"
    fi
}

export GIT_INTERACTIVE=0
GIT_WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/git_test.XXXXXX")"
export GIT_WORKDIR
git_onLoad

URL="https://github.com/CodeAnthem/dp_cluster.git"
SSH_URL="git+ssh://git@github.com/CodeAnthem/thundercore.git"
GENERIC_URL="git@gitlab.example.com:g/r.git"
BAD_URL="git@example.invalid:x/y.git"

assert "validate https" git_url_validate "$URL"
assert_false "reject empty" git_url_validate ""
assert_false "reject garbage" git_url_validate "not a url"

assert "index https" git_store_index "$URL"
host=${ git_store_get "$URL" host; }
owner=${ git_store_get "$URL" owner; }
repoName=${ git_store_get "$URL" repoName; }
provider=${ git_store_get "$URL" provider; }
assert_eq "https host" "$host" "github.com"
assert_eq "https owner" "$owner" "CodeAnthem"
assert_eq "https repoName" "$repoName" "dp_cluster"
assert_eq "https provider" "$provider" "github"
httpsSafe=${ git_store_getSafeUrl "$URL"; }
assert "index scp same identity" git_store_index "git@github.com:CodeAnthem/dp_cluster.git"
assert "index git+ssh same identity" git_store_index "git+ssh://git@github.com/CodeAnthem/dp_cluster.git"
sshSameSafe=${ git_store_getSafeUrl "git@github.com:CodeAnthem/dp_cluster.git"; }
gitSshSafe=${ git_store_getSafeUrl "git+ssh://git@github.com/CodeAnthem/dp_cluster.git"; }
assert_eq "safeUrl token" "$httpsSafe" "github_com_CodeAnthem_dp_cluster"
assert_eq "safeUrl scp form" "$sshSameSafe" "$httpsSafe"
assert_eq "safeUrl git+ssh form" "$gitSshSafe" "$httpsSafe"

# Same identity, different raw form: set via scp, read via https
SCP_URL="git@github.com:CodeAnthem/dp_cluster.git"
git_store_set "$SCP_URL" accessVerified "true"
viaHttps=${ git_store_get "$URL" accessVerified; }
viaScp=${ git_store_get "$SCP_URL" accessVerified; }
assert_eq "multi-form set/get" "$viaHttps" "true"
assert_eq "multi-form scp read" "$viaScp" "true"
assert "multi-form canRead https" git_store_canRead "$URL"
assert "multi-form canRead scp" git_store_canRead "$SCP_URL"

QURL="https://github.com/CodeAnthem/dp_cluster.git?ref=main#frag"
assert "index query fragment" git_store_index "$QURL"
qHost=${ git_store_get "$QURL" host; }
qSafe=${ git_store_getSafeUrl "$QURL"; }
assert_eq "query host" "$qHost" "github.com"
assert_eq "query same safeUrl" "$qSafe" "$httpsSafe"

assert "index git+ssh" git_store_index "$SSH_URL"
sshHost=${ git_store_get "$SSH_URL" host; }
sshRepo=${ git_store_get "$SSH_URL" repoName; }
assert_eq "git+ssh host" "$sshHost" "github.com"
assert_eq "git+ssh repoName" "$sshRepo" "thundercore"

assert "index generic" git_store_index "$GENERIC_URL"
genericProvider=${ git_store_get "$GENERIC_URL" provider; }
assert_eq "generic host provider label" "$genericProvider" "gitlab"
needWriteDefault=${ git_store_get "$URL" needWrite; }
assert_eq "needWrite false after index" "$needWriteDefault" "false"
acc=${ git_store_getAccountUID "$URL"; }
assert_eq "getAccountUID" "$acc" "github.com/CodeAnthem"
repoUid=${ git_store_getRepoUID "$URL"; }
assert_eq "getRepoUID" "$repoUid" "github_CodeAnthem_dp_cluster"

acc2=${ git_store_getAccountUID "$SSH_URL"; }
assert_eq "getAccountUID auto-index" "$acc2" "github.com/CodeAnthem"
sshHost2=${ git_store_get "$SSH_URL" host; }
assert_eq "auto-index host" "$sshHost2" "github.com"

accountRepos=${ git_store_getAllReposOfAccountUID "github.com/CodeAnthem"; }
if printf '%s' "$accountRepos" | grep -q "dp_cluster" && printf '%s' "$accountRepos" | grep -q "thundercore"; then
    ok "getAllReposOfAccountUID"
else
    fail "getAllReposOfAccountUID"
fi

keyPath=${ git_store_getKeyPath "$URL"; }
storedKeyPath=${ git_store_get "$URL" keyPath; }
assert_eq "keyPath stored" "$keyPath" "$storedKeyPath"

target=${ git_store_getTargetDir "$URL"; }
storedTarget=${ git_store_get "$URL" targetDir; }
assert_eq "targetDir stored" "$target" "$storedTarget"
qTarget=${ git_store_getTargetDir "$QURL"; }
assert_eq "targetDir same identity" "$qTarget" "$target"

ssh=${ git_store_getUrlSsh "$URL"; }
assert_eq "toSsh" "$ssh" "git@github.com:CodeAnthem/dp_cluster.git"
https=${ git_store_getUrlHttps "$URL"; }
assert_eq "toHttps" "$https" "https://github.com/CodeAnthem/dp_cluster.git"

git_store_needWrite "$URL" true
needWriteSet=${ git_store_get "$URL" needWrite; }
assert_eq "needWrite true after setter" "$needWriteSet" "true"
git_store_set "$URL" accessVerified "true"
assert "canRead when verified" git_store_canRead "$URL"
assert "canWrite when needWrite" git_store_canWrite "$URL"

git_gh_setAccountUsingGh "$URL"
assert "account is using gh" git_gh_isAccountUsingGh "$URL"
assert_false "other account not using gh" git_gh_isAccountUsingGh "$GENERIC_URL"

debug_out=${ git_store_debug 2>&1; }
if printf '%s' "$debug_out" | grep -q "CodeAnthem/dp_cluster"; then
    ok "debug has repo url"
else
    fail "debug has repo url"
fi

key="${GIT_WORKDIR}/keys/testkey"
assert "keys create" git_helper_keys_create "$key" "test"
assert "keys isValid" git_helper_keys_isValid "$key"
pub=${ git_helper_keys_getPublic "$key"; }
if [[ "$pub" == ssh-ed25519* ]]; then ok "keys getPublic"; else fail "keys getPublic"; fi

assert "index invalid host" git_store_index "$BAD_URL"
git_store_set "$BAD_URL" needWrite "false"
git_store_set "$BAD_URL" isPrivate "true"
git_store_set "$BAD_URL" accessVerified "false"
assert_false "verifyAccess non-interactive fails" git_store_verifyAccess "$BAD_URL" "test reason"
assert_false "generic addDeployKey unsupported" git_generic_addDeployKey "$BAD_URL"
assert_false "interactive off" git_helper_interactive_isEnabled

git_onExit
rm -rf "$GIT_WORKDIR"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
