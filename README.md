<div align="center">
<img src="https://raw.githubusercontent.com/vdutts7/squircle/main/webp/terminal.webp" alt="logo" width="80" height="80" />
<h1>clip2copy</h1>
<p><i><b>Auto-copy macOS screenshots to clipboard when saved 📋</b></i></p>

[![Github][github]][github-url]
[![Homebrew][homebrew]][homebrew-url]

</div>

<br/>

## Table of Contents

<ol>
  <a href="#about">📝 About</a><br/>
  <a href="#install">💻 Install</a><br/>
  <a href="#usage">🚀 Usage</a><br/>
  <a href="#config">⚙️ Config</a><br/>
  <a href="#tools-used">🔧 Tools Used</a><br/>
  <a href="#contact">👤 Contact</a>
</ol>

<br/>

## About

macOS saves screenshots as files but does not always put them on the clipboard. **clip2copy** watches your screenshot folder, copies each new PNG to the clipboard, and optionally renames it to `ss-<hex>.png`.

```
⌘⇧3 / ⌘⇧4 / ⌘⇧5
  → ~/Downloads/Screenshot ….png
  → fswatch detects
  → rename ss-a1b2c3.png (optional)
  → clipboard ready for ⌘V
```

**Why not osascript?** PNG clipboard via AppleScript is broken on macOS Sequoia 15+. clip2copy uses Swift `NSPasteboard`.

**vs ⌘⌃⇧4:** built-in capture-to-clipboard skips saving a file. clip2copy gives you **both** — file on disk and clipboard.

<br/>

## Install

```bash
brew tap vdutts7/tap
brew update
brew install clip2copy
clip2copy setup              # wizard — pick save folder, applies macOS override
brew services start clip2copy
```

### Setup wizard

On first install, run `clip2copy setup`. It:

1. Shows where macOS **currently** saves screenshots
2. Lets you pick **Downloads**, **Desktop**, or a **custom path**
3. Writes `com.apple.screencapture location` — same as System Settings → Screenshots
4. Saves config to `~/.config/clip2copy/config.json`
5. Tells you to restart the watcher

**macOS factory default** (when never configured): `~/Desktop`

Change settings anytime:

```bash
clip2copy config show
clip2copy config set location downloads
clip2copy config set location desktop
clip2copy config set location ~/Pictures/Screenshots
clip2copy config set rename off
clip2copy config set shadow on      # drop window shadow
clip2copy status
brew services restart clip2copy     # after changes
```

### From source

```bash
git clone https://github.com/vdutts7/clip2copy.git
cd clip2copy
brew install fswatch
make install install-watch
make service-start   # or: brew services after tap install
```

<br/>

## Usage

After `brew services start clip2copy`:

1. Take a screenshot (⌘⇧4)
2. Paste anywhere (⌘V)

Manual copy of a single file:

```bash
clip2copy ~/Downloads/ss-deadbeef.png
```

Check service:

```bash
brew services list | grep clip2copy
tail -f $(brew --prefix)/var/log/clip2copy.log
```

<br/>

## Config

Stored at `~/.config/clip2copy/config.json`.

| Key | CLI | Default | Description |
|-----|-----|---------|-------------|
| `location` | `config set location …` | `~/Downloads` | Where screenshots save + watcher watches |
| `rename` | `config set rename on\|off` | `on` | Rename screenshots (off = keep macOS name) |
| `renamePrefix` | `config set prefix …` | `ss` | Prefix when rename on → `ss-a1b2c3.png` |
| `disableShadow` | `config set shadow on\|off` | `on` | Drop window shadow |

Paths are validated on set: must be a directory (created if missing) and writable. Prefix: 1–32 chars `[A-Za-z0-9_-]`.

```bash
clip2copy config validate location ~/Pictures/Caps   # dry-run check
clip2copy config validate prefix myshot
clip2copy config set prefix cap                      # cap-deadbeef.png
clip2copy config set rename off                      # keep Screenshot….png
```

<br/>

## Tools Used

- [fswatch](https://github.com/emcrisostomo/fswatch) — FSEvents file watcher
- Swift / Cocoa — `NSImage` + `NSPasteboard` clipboard copy
- launchd — via `brew services`

<br/>

## Contact

<a href="https://vd7.io"><img src="https://res.cloudinary.com/ddyc1es5v/image/upload/v1773910810/readme-badges/readme-badge-vd7.png" alt="vd7.io" height="40" /></a> &nbsp; <a href="https://x.com/vdutts7"><img src="https://res.cloudinary.com/ddyc1es5v/image/upload/v1773910817/readme-badges/readme-badge-x.png" alt="/vdutts7" height="40" /></a>

<!-- BADGES -->
[github]: https://img.shields.io/badge/💻_clip2copy-000000?style=for-the-badge
[github-url]: https://github.com/vdutts7/clip2copy
[homebrew]: https://img.shields.io/badge/Homebrew-vdutts7/tap-FBB040?style=for-the-badge&logo=homebrew&logoColor=white
[homebrew-url]: https://github.com/vdutts7/homebrew-tap
