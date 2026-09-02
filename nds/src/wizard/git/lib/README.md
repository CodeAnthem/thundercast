# src/git/lib

Argument-only git helpers. No `CONFIG_DATA`, no `nds_cfg_*`, no NDS UI.

| File | Responsibility |
|------|----------------|
| `git_url.sh` | Parse / normalize URLs, owner slug, `nds_git_urls_all_github` |
| `git_host.sh` | Host detection, register URLs, GitHub official host keys |
| `git_probe.sh` | Public probe, bare/key SSH env, clone with explicit key |
| `git_key.sh` | Generate / load / write a key at an explicit path |
| `git_name.sh` | Deploy-key / session-key filenames and titles |
| `git_ssh.sh` | SSH config / wrapper helpers |
| `git_warm.sh` | Step-UI chrome for warming gh / qrencode (`nds_git_warm_*`) |

Domain wiring lives in `src/git/access/`, `src/git/keys/`, and `src/git/wizard/`.
