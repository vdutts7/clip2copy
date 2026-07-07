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
brew install clip2copy
brew services start clip2copy
```

Optional — point screenshots at Downloads:

```bash
defaults write com.apple.screencapture location "$HOME/Downloads"
defaults write com.apple.screencapture disable-shadow -bool true
killall SystemUIServer 2>/dev/null || true
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

| Env var | Default | Description |
|---------|---------|-------------|
| `CLIP2COPY_DIR` | `~/Downloads` | Directory to watch |
| `CLIP2COPY_RENAME` | `1` | `0` = keep macOS filename |

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
