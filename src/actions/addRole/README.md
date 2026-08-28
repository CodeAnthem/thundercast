# addRole

First-class NDS action: scaffold `nixosConfigurations.<host>` from the leaf’s `.roles/` (or `profiles/`), write a recipe, **confirm disk wipe**, git-push, then Part A flake-install.

Not a catalog script. ThunderCast `.nds/actions/addRole.sh` is a stub that fails closed.

```bash
export NDS_ACTION=addRole
sudo -E bash src/app/main.sh
```

## You need

- A **private leaf** with `.roles/<role>/` (copy [exampleRepo](../../../exampleRepo/README.md))
- **Write** Git access on the ISO (account key or write-enabled deploy key)
- A new hostname (or `SCAFFOLD_MODE=existing` to reuse a folder already in git)

## Flow

1. Clone install flake (write probe)
2. Pick role + host
3. Settings menu (boot / disk / encryption)
4. **Disk confirm** — abort here leaves origin unchanged
5. Compose: scaffold, `.nds/hosts/<host>.recipe`, push
6. Part A: partition + `nixos-install --flake`

ISO hooks: `.nds/hooks/addRole/*.sh` (`nds_hook_register`). Functions: `.nds/hooks/lib/`.

Secrets stay as `*_FILE` paths in the recipe. Disk device is not stored in the portable recipe.

## After install

Same as [installFlake](../installFlake/README.md): reboot, `findmnt /boot`, `tc-switch` / `tc-status`.
