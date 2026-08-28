# Roles (templates, not machines)

Add a role: add a folder `.roles/<id>/`.
Remove a role: delete that folder.
A machine using a role is `hosts/<system>/<hostname>/` — deleting a role does not delete machines.

| File | What |
|------|------|
| `opts.nix` | Nix options for this role (you edit) |
| `nds.sh` | Optional NDS defaults for **new** machines of this role (encryption, disk) |
| `hooks/*.sh` | Optional ISO hooks (`nds_hook_register`) when `SCAFFOLD_ROLE` matches |

`toolkit` is a real role (opts + nds + optional hooks) but **addRole hides it**. Install ops VMs with `NDS_ACTION=toolkit`. Extra ops VMs (another hypervisor) are extra host folders, same role, shared `.toolkit/`.

After scaffold, the host’s `opts.nix` is `(import ../../../.roles/<id>/opts.nix)`. Edit the role to change every host that still imports it; edit the host file to overlay.
