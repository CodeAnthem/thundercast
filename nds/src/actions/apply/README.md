# apply

Load a sealed recipe or a bundle zip, review the active fields, then birth the machine. Every schema group is enabled. There are no pins and no `action_recipe`.

The pipeline reloads the recipe's `INSTALL_ACTION` `setup.sh` so that action's hooks run. Its `action_recipe` does not run again.

```bash
bash nds/src/app/main.sh apply /path/to/host.recipe
bash nds/src/app/main.sh apply /path/nds_bundle.zip --unattended
```
