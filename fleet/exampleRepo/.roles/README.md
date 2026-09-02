# Roles (templates, not machines)

Add a role: add a folder `.roles/<id>/`.
Remove a role: delete that folder.
A machine using a role is `hosts/<system>/<hostname>/` — deleting a role does not delete machines.

| File | What |
|------|------|
| `opts.nix` | Nix options for this role (you edit) |
| `nds.sh` | Optional NDS defaults for **new** machines of this role (encryption, disk) |
| `hooks/*.sh` | Optional ISO hooks (`nds_hook_register`), addFleetHost only |

`toolkit` is an NDS **action**, not a Swarm role — addFleetHost skips that name. Ops VMs are host folders under `hosts/`.

After scaffold, the host’s `opts.nix` is `(import ../../../.roles/<id>/opts.nix)`.
