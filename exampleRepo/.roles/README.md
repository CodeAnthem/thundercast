# Roles (templates, not machines)

Add a role: add a folder `.roles/<id>/`.
Remove a role: delete that folder.
A machine using a role is `hosts/<system>/<hostname>/` — deleting a role does not delete machines.

| File | What |
|------|------|
| `opts.nix` | Nix options for this role (you edit) |
| `nds.sh` | Optional NDS defaults for **new** machines of this role (encryption, disk) |
| `hooks/*.sh` | Optional ISO hooks (`nds_hook_register`), addRole only |

After scaffold, the host’s `opts.nix` is a copy — changing the template does not rewrite existing hosts.
