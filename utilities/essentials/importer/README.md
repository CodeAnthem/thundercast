# Importer

Source `*.sh` files from one directory into the current shell.

[![uses logger](https://img.shields.io/badge/uses-logger-2ea44f?style=flat-square)](../logger/README.md)
![subshells no](https://img.shields.io/badge/subshells-no-2ea44f?style=flat-square)

## Use

Call after essentials has loaded. Bootstrap lives in the [parent README](../README.md).

`import_dir` walks one directory. In each directory, `*.sh` files are sourced before subdirectories are entered. Basenames run in alphabetical order. A call in a sourced file resolves only if that function already exists: earlier in the same file, in a file already sourced, or from essentials. A later file is not pulled forward to satisfy the call.

Other names are skipped. Basenames matching `*_TEST.sh` are skipped unless `IMPORTER_INCLUDE_TESTS` is `true`. `import_file` still sources that path. The first failed source stops the walk. Files already sourced stay sourced.

### Config

Key this feature reads from `essentials_config`. The map is filled in the [parent README](../README.md). Checked at init, and read again on each `import_dir`.

| Key | Default | Meaning |
|-----|---------|---------|
| `IMPORTER_INCLUDE_TESTS` | `false` | `true` or `false`. When `false`, `import_dir` skips `*_TEST.sh` files. Any other value is an error |

### API

| Call | Arguments | Effect |
|------|-----------|--------|
| `import_file` | `<path>` | Source that file. A missing path or a failed source logs `error` and returns 1. Does not apply `--ignore` or the test-file skip |
| `import_dir` | `<dir> [--depth <0\|N>] [--ignore <pattern>]…` | Source `*.sh` under `<dir>`. Omitted `--depth` walks the whole tree. `0` is the root only. `N` adds N subdirectory levels. Each `--ignore` is a Bash `case` pattern on the basename: a matching file is skipped, a matching directory is not entered. Directory symlinks are not entered. An unknown argument, a bad depth, a missing directory, a bad `IMPORTER_INCLUDE_TESTS`, or a failed source logs `error` and returns 1 |

### Examples

```bash
import_file "$dir/bootstrap.sh"
import_dir "$dir" --ignore 'drafts'
```

## Develop

`importer.sh` holds init, `import_file`, `import_dir`, the walk, the test-file check, and the ignore match.

Init rejects a bad `IMPORTER_INCLUDE_TESTS`, then marks `importer`. No events. No globals. The default `false` lives only in `_essentials_importer_includeTests`. `--ignore` patterns stay on the call (`_im_ignores`). An empty list is not nameref'd, and the walk does not call the matcher. The `*_TEST.sh` skip is a separate file check, so it does not put a pattern on that list.

An empty depth is the unlimited walk (`[[ -z ]]`). A relative root is prefixed with `$PWD` before the walk, so a sourced file can `cd` without breaking the next path. Directory symlinks are skipped (`[[ -L ]]` on the path with the trailing slash removed). While names are collected, `nullglob` is on, `failglob` is off, and `noglob` is off. All three are restored before any file is sourced.

Do not:

- Run `bash -n`, or execute a file as its own process
- Add another built-in skip, or apply `*_TEST.sh` to directory names
- Keep walking after a failed source
- Nameref the ignore array when it is empty
- Follow a directory symlink, or leave `nullglob`, `failglob`, or `noglob` changed across `source`

### Tests

`importer_TEST.sh` — `bash utilities/bashTestSuite/main.sh utilities/essentials/importer/importer_TEST.sh`
