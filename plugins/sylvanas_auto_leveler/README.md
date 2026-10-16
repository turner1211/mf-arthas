# Sylvanas Auto Leveler

Version 0.17.98.50 is the dedicated questing and leveling package. Its route catalog, settings, interface, navigation ownership, checkpoints, logs, and recovery state belong only to the Auto Leveler and are not shared with BG Player or any class/spec plugin.

## Runtime safety

- Loader-managed character and object reads pass through a protected Leveler-owned adapter.
- Character reads can safely return unavailable while loading, zoning, disconnecting, or reloading.
- Navigation position providers reject an unavailable character instead of raising an error.
- Object scans keep the existing short snapshot cache to avoid repeated full scans in one update window.

## Package layout

This Project Sylvanas package contains only active `.lua` and `.md` files. Historical working backups are preserved outside the live scripts folder so the loader cannot recursively discover obsolete copies. Native navigation services, map files, installers, and writable runtime data are external to this package.

## Navigation

The Leveler requests navigation through ArthasNav. ArthasNav remains a separate library and companion installation, with AmeisenNav available only as its configured fallback. Install and start ArthasNav according to the instructions supplied with the ArthasNav release.

## Support

For setup help, bugs, or route problems, use the **arthas** channel in the Project Sylvanas Discord and include the relevant built-in logs.
