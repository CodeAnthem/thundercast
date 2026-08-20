# Trust and verification

NDS runs with **root privileges** (via `sudo` from the **`nixos`** live-ISO user) and can **erase disks**. Do not pipe scripts into `bash` without understanding what they do.

## What runs on your machine

| Step | What happens |
|------|----------------|
| **`start.sh`** | Clones or refreshes this repo under `/tmp/<repo-name>`, optionally warns about untracked files, then runs `src/app/main.sh` |
| **`src/app/main.sh`** | Loads shell libraries, shows the configuration menu, partitions the target disk, and runs `nixos-install` |

This repository contains **no cluster secrets**, no private keys, and no org-specific credentials. LUKS keys are generated at install time; NDS packs them with your config and logs into a zip under `/home/nixos/` (and shows `scp` / `ssh` copy commands with your machine's IP). Copy the package before reboot.

## Verify before you run

1. **Read the entrypoints** — [`start.sh`](start.sh) and [`src/app/main.sh`](src/app/main.sh) are short and readable.
2. **Clone without installing** — download only, then inspect:
   ```bash
   curl -sSL https://raw.githubusercontent.com/CodeAnthem/thundercast/main/start.sh | bash -s -- --no-exec
   ls /tmp/thundercast   # or /tmp/<NDS_REPO_NAME> when using a fork
   ```
3. **Manual steps** — clone with git and run `sudo bash src/app/main.sh` yourself when you are satisfied.
4. **CI** — on every push: [ShellCheck](.github/workflows/shellcheck.yml) (`bash dev/shellcheck.sh`) and [self-tests](.github/workflows/selftest.yml) (`bash dev/selftest.sh`). Run the same locally before opening a PR.

## Forks and renamed repositories

There is **no GitHub variable** available to a `curl | bash` one-liner at runtime. To point at a different remote:

```bash
export NDS_REPO_URL='https://github.com/you/your-fork.git'
curl -sSL https://raw.githubusercontent.com/you/your-fork/main/start.sh | bash
```

When you run `start.sh` from a git checkout, it uses `git remote.origin.url` automatically. You can also set `NDS_REPO_NAME` to change the `/tmp` directory name.

## Supply-chain hygiene

- Prefer cloning over piping when you are unsure.
- Use `--no-exec` to fetch the tree without starting the installer.
- If `start.sh` reports untracked files in `/tmp/<repo>`, treat that as suspicious — the script can offer to delete them before continuing.
