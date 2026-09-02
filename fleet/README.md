# Fleet — leaf, toolkit, birth wizards

[![fleet selftest](https://github.com/CodeAnthem/thundercast/actions/workflows/fleet-selftest.yml/badge.svg)](https://github.com/CodeAnthem/thundercast/actions/workflows/fleet-selftest.yml)
[![fleet shellcheck](https://github.com/CodeAnthem/thundercast/actions/workflows/fleet-shellcheck.yml/badge.svg)](https://github.com/CodeAnthem/thundercast/actions/workflows/fleet-shellcheck.yml)

Multi-host deployment product. Day-2 work does **not** require NDS.

## Layout

```
fleet/
  exampleRepo/     # copy to a private leaf remote
  toolkit/         # ops VM menus + tcast-sops
  modules/nixos/   # host + toolkit modules
  nds-actions/     # toolkit + addFleetHost (NDS auto-loads)
  docs/TODO.md
  dev/
```

## Tests

```bash
bash fleet/dev/selftest.sh      # needs age + sops
bash fleet/dev/shellcheck.sh
```
