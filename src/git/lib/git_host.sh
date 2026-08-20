#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git host helpers (standalone)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-07 | Modified: 2026-08-16
# Description:   Host detection and registration URLs (argument-only)
# ==================================================================================================

# Description: True when host is GitHub.
# Arguments:
# - host: <String> Parsed git host
# Returns:
# - <Bool> 0 when GitHub
nds_git_host_is_github() {
    local host="$1"
    [[ "$host" == github.com || "$host" == *.github.com ]]
}

# Description: Account SSH key registration URL for a git host.
# Arguments:
# - host: <String> Parsed git host
# Returns:
# - <String> HTTPS URL (stdout)
nds_git_account_ssh_register_url() {
    local host="$1"
    case "$host" in
        github.com|*.github.com)
            printf 'https://github.com/settings/ssh/new\n'
            ;;
        *gitlab*)
            printf 'https://%s/-/profile/keys\n' "$host"
            ;;
        *)
            printf 'https://%s (account SSH keys in your profile settings)\n' "$host"
            ;;
    esac
}

# Description: Deploy key registration URL for a repository.
# Arguments:
# - host:  <String> Git host
# - owner: <String> Repository owner
# - repo:  <String> Repository name
# Returns:
# - <String> HTTPS URL (stdout)
nds_git_deploy_key_register_url() {
    local host="$1" owner="$2" repo="$3"
    case "$host" in
        github.com|*.github.com)
            printf 'https://github.com/%s/%s/settings/keys\n' "$owner" "$repo"
            ;;
        *gitlab*)
            printf 'https://%s/%s/%s/-/deploy_keys\n' "$host" "$owner" "$repo"
            ;;
        *)
            printf 'https://%s/%s/%s (deploy keys in repository settings)\n' "$host" "$owner" "$repo"
            ;;
    esac
}

# Description: Official GitHub SSH host key lines (docs.github.com fingerprints).
# Returns:
# - <String> known_hosts lines (stdout)
nds_git_github_official_host_keys() {
    printf '%s\n' \
        "github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl" \
        "github.com ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg=" \
        "github.com ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCj7ndNxQowgcQnjshcLrqPEiiphnt+VTTvDP6mHBL9j1aNUkY4Ue1gvwnGLVlOhGeYrnZaMgRK6+PKCUXaDbC7qtbW8gIkhL7aGCsOr/C56SJMy/BCZfxd1nWzAOxSDPgVsmerOBYfNqltV9/hWCqBywINIR+5dIg6JTJ72pcEpEjcYgXkE2YEFXV1JHnsKgbLWNlhScqb2UmyRkQyytRLtL+38TGxkxCflmO+5Z8CSSNY7GidjMIZ7Q4zMjA2n1nGrlTDkzwDCsw+wqFPGQA179cnfGWOWRVruj16z6XyvxvjJwbz0wQZ75XK5tKSb7FNyeIEs4TT4jk+S4dhPeAUC5y+bDYirYgM4GC7uEnztnZyaVWQ7B381AK4Qdrwt51ZqExKbQpTUNn+EjqoTwvqNj4kqx5QUCI0ThS/YkOxJCXmPUWZbhjpCg56i+2aB6CmK2JGhn57K5mj0MNdBXA4/WnwH6XoPWJzK5Nyu2zB3nAZp+S5hpQs+p1vN1/wsjk="
}
