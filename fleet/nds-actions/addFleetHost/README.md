# addFleetHost

Scaffold a flake host from `.roles/<role>` and push the leaf.

Groups: `install flake git scaffold network boot disk encryption`. `hook_access` writes `FLAKE_LOCATION`. `hook_cook` pushes the leaf, then runs the local flake install.

`hook_material` copies the role, writes `.nds/hosts/<host>.recipe`, and sets `LEAF_PUSH_DIR`. The machine age public key is `.toolkit/machines/<host>/keys/age.pub`. `SCAFFOLD_MODE=existing` reuses a host folder instead of scaffolding.

```bash
bash nds/src/app/main.sh --unattended --action addFleetHost
```
