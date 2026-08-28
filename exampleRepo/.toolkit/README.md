# .toolkit — ops cluster state (not NDS)

Owned by the **toolkit** on the ops VM. Git-safe: public keys and membership only. Private age/SSH keys stay in the install zip / on the VM.

All toolkit VMs share this git tree. The only private key they must share is the **operator age private** (`/etc/sops/age/operator_sops.key` on each ops VM — never in git). A second ops VM (another hypervisor) uses `CAST_TOOLKIT_MODE=restore` so it gets the same operator key; each VM still has its own `hosts/…/<name>/nds_generated.nix`.

| Path | What |
|------|------|
| `config` | Sourced bash AA (`declare -gA tcast_aa`) — `version` |
| `state` | Sourced bash AA — `initialized_at`, last enroll/rotate |
| `operator/keys/age.pub` `operator/keys/ssh.pub` | Cluster operator pubs |
| `machines/<hostname>/keys/` | That machine’s pubs |
| `machines/<hostname>/config` | Sourced bash AA — `role`, `system`, `groups` (comma-separated) |
| `sops/secrets.map` | Sourced bash AA `id` → path (`%s` = hostname). Recipients come from pubs |

Files are `source`d, not parsed. Bash `%q` quoting handles spaces and odd characters.

Delete `machines/<hostname>/` to unenroll.

NDS recipes stay under `.nds/hosts/<host>.recipe`.
