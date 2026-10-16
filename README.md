# mf-arthas

Project Sylvanas plugins, delivered over HTTP by small loaders that stay the
same while the plugin logic behind them changes.

## Layout

| Path | What it is |
| --- | --- |
| `loaders/<project>_loader/` | The plugin folder you install. `header.lua`, `main.lua` and `mf_loader.lua` do not change when a project is updated. |
| `plugins/<project>/` | The real plugin code the loader downloads, plus its `manifest.txt`. |
| `tools/sync_plugins.ps1` | Copies the local project folders into `plugins/`, rewrites the manifests, creates missing loaders. |
| `tools/loader_template/mf_loader.lua` | The loader copied into every loader folder. Not a plugin. |
| `tools/test_loader.lua` | Offline tests for the loader (LuaJIT, fake `core`, no network). |

## Installing a plugin

1. Copy one folder from `loaders/` (for example `loaders/sylvanas_mage_loader`)
   into the Sylvanas `scripts` folder.
2. Remove the old plugin folder of the same project from `scripts`, so the
   plugin does not load twice under the same name.
3. Load plugins. On the first load the loader downloads the project
   (`[mf-arthas:<project>]` lines in the log show progress) and starts it once
   the download finishes.

## How it loads

- Everything goes through the Sylvanas API: `core.http_get` for downloads,
  `core.create_data_file` / `core.write_data_file` / `core.read_data_file` for
  the cache in `scripts_data/mf_arthas/<project>/`, and
  `core.register_on_update_callback` to start a fresh install on the next tick.
- The loader runs the project's own `header.lua` from the downloaded copy, so
  the plugin name, version and class/spec load rule still come from the
  project and update with it.
- The project's `require` calls resolve to the downloaded files; `common/...`
  and other host modules go through the normal `require`.
- Downloaded chunks are named inside the loader's folder, so anything the host
  resolves from the Lua stack (owning plugin, menu persistence, error
  locations) points at the installed loader plugin.

## How updates reach players

- On every load the loader starts the installed copy immediately, then checks
  GitHub.
- When `manifest.txt` has a new build, only the changed files are downloaded.
  The new build is used the next time plugins are loaded.
- A failed, partial or wrong-sized download never replaces the installed copy.
- All files of one update come from the same commit (pinned through the GitHub
  API, with a fallback to the `main` branch when the API is unavailable). One
  lookup is shared by all loaders in a load.

## Publishing an update

Edit the project in its usual folder next to this repository (for example
`../sylvanas_mage_v1.2.24`), then:

```powershell
pwsh tools/sync_plugins.ps1                 # all projects
pwsh tools/sync_plugins.ps1 -Only sylvanas_mage
luajit tools/test_loader.lua
git add -A
git commit -m "Update sylvanas_mage"
git push
```

The script finds the newest `_v<version>` folder for versioned projects, so a
renamed release folder needs no edits. To add a project, add a line to the
`$Projects` table at the top of the script; its loader folder is created on the
next run. Existing `header.lua` / `main.lua` files are never rewritten.

Do not edit files in `plugins/` by hand without re-running the script: the
loader checks every file's size against the manifest.

## Notes

- `.gitattributes` turns off line-ending conversion. The manifest sizes must
  match the bytes GitHub serves.
- `.md` files and `tests*` files are not downloaded.
- The repository must stay public: the loaders fetch from
  `raw.githubusercontent.com` without credentials.
- The loaders run whatever is pushed to `main`. Anyone with push access to this
  repository controls the code that runs in players' clients.
