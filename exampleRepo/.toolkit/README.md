# .toolkit — ops cluster state (not NDS)

Owned by the **toolkit** on the ops VM. Git-safe: public keys and membership only. Private age/SSH keys stay in the install zip / on the VM.

All toolkit VMs share this git tree. The only private key they must share is the **operator age private** (`/etc/sops/age/operator_sops.key` on each ops VM — never in git).

| Path | What |
|------|------|
| `config` | Cluster data (`version=1`) |
| `state` | Cluster state (`initialized_at`, last enroll/rotate) |
| `operator/keys/age.pub` `operator/keys/ssh.pub` | Cluster operator pubs |
| `machines/<hostname>/keys/` | That machine’s pubs |
| `machines/<hostname>/config` | `role`, `system`, `groups` (comma-separated) |
| `sops/secrets.map` | `id=path` (`%s` = hostname). Recipients come from pubs |

Values in `config` / `state` / `secrets.map` / machine `config` are `key=value`. Quote the value if it contains space, `=`, `#`, or `"`.

Delete `machines/<hostname>/` to unenroll.

NDS recipes stay under `.nds/hosts/<host>.recipe`.
