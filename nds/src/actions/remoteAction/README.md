# remoteAction

Clone a catalog and fill the action named by `CATALOG_ACTION`.

Groups: `install catalog`. No pin. `action_recipe` clones when `work/catalog/.git` is missing, imports the catalog action, and asks for its preview unless `action.preview` is skipped. That action's `action_plan` writes `COOK_PHASES`.

`INSTALL_ACTION` stays `remoteAction`. The inner name is `CATALOG_ACTION`.

```bash
bash nds/src/app/main.sh --action remoteAction
```
