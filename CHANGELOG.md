# Changelog

## v1.3.4

### Fixed

- **Clipboard skipped when rename failed.** Watcher called `mv` before `clip2copy`. On MDM-managed Macs, `mv` in `~/Downloads` often returns `Operation not permitted`; watcher logged `rename failed` and never copied to clipboard. Now copies first, renames after (optional).
- **Pasteboard write reliability.** `clip2copy` writes raw PNG data to `NSPasteboard` first, with `NSImage` fallback. Clearer stderr on read/decode/pasteboard failures.

### Workaround (MDM / TCC)

- If `brew services` still cannot read or write from protected folders, set location to an unprotected path (e.g. `~/clip2copy-shots`), `clip2copy config set rename off`, `clip2copy config apply`, then `brew services restart clip2copy`.

## v1.3.3

### Fixed

- **Screenshot path U+202F.** macOS uses a narrow no-break space before `AM`/`PM` in screenshot filenames; `fswatch` often emits a regular space. `mv` failed with `No such file or directory` and clipboard never updated. Watcher resolves the correct path before copy/rename.
- **Pre-setup watch dir.** Fresh install without `clip2copy setup` watched `~/Downloads` while macOS default save location is `~/Desktop`. Watcher now uses macOS save location when no config exists.

## v1.3.2

### Fixed

- **launchd PATH.** `fswatch not found` under `brew services`; formula bakes Homebrew paths into the watch script at install time.
