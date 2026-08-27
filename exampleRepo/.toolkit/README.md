# .toolkit — ops cluster state (not NDS)

Owned by the **toolkit** on the ops VM. Git-safe: public keys and membership only. Private age/SSH keys stay in the install zip / on the VM.

Several toolkit VMs share this tree (same git leaf). There is no `self/` folder — this machine is `.toolkit/machines/<hostname>/`. Operator identity is cluster-wide under `operator/`.

| Path | What | Edit? |
|------|------|--------|
| `operator/age.pub` `operator/ssh.pub` | Cluster operator pubs | Toolkit writes |
| `operator/meta` | Init timestamps | Toolkit writes |
| `machines/<hostname>/` | One folder per machine (age pub, role, groups) | Delete folder = unenroll |
| `sops/secrets.map` | Which secret files exist (`id` + path). Recipients come from pubs, not this file | Toolkit default; advanced: add a row |

NDS recipes (disk/encryption defaults) stay under `.nds/hosts/` — re-askable at restore.
