# toolkit

Create or restore the toolkit host and seed its keys. Local only.

Groups: `install toolkit flake git boot disk encryption platform`. Defaults: `FLAKE_HOST=control-toolkit`, `TOOLKIT_MODE=new`. Pins: `INSTALL_KIND=flake`, `INSTALL_MODE=local`.

`action_recipe` writes `.toolkit/operator/keys/age.pub` and `ssh.pub`, the machine `age.pub`, a portable recipe, and the seed tree. `TOOLKIT_MODE=restore` reads `TOOLKIT_BUNDLE` (zip or directory) into `secrets/toolkit/`.

A `cook.post_install` hook copies `fleet/toolkit` onto the target as `/var/lib/nds-toolkit/current`.

```bash
bash nds/src/app/main.sh --unattended --action toolkit
```
