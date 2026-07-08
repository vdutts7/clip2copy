<div align="center">
<img src="https://raw.githubusercontent.com/vdutts7/squircle/main/webp/macos-screenshot.webp" alt="logo" width="80" height="80" />
<img src="https://raw.githubusercontent.com/vdutts7/squircle/main/webp/cmd.webp" alt="logo" width="80" height="80" />

<h1 align="center">clip2copy</h1>
<p align="center"><i><b>auto-copy macOS screenshots to clipboard (+ rename)</b></i></p>
<p align="center"><kbd>⌘</kbd><kbd>⇧</kbd><kbd>4</kbd> → <kbd>⌘</kbd><kbd>V</kbd></p>


<p align="center">
<a href="https://github.com/vdutts7/clip2copy">
<img src="https://img.shields.io/badge/clip2copy-000000?style=for-the-badge" alt="clip2copy"/>
</a>
<a href="https://github.com/vdutts7/homebrew-tap">
<img src="https://img.shields.io/badge/Homebrew-vdutts7/tap-FBB040?style=for-the-badge&logo=homebrew&logoColor=white" alt="Homebrew"/>
</a>
</p>

</div>

---

| | macOS default | clip2copy |
|---|---|---|
| file on disk | yes | yes |
| clipboard after save | no (Sequoia breaks osascript PNG) | yes |
| rename on save | macOS `Screenshot …` name | optional `a1b2c3.png` or `ss-a1b2c3.png` |
| screenshot folder | System Settings | wizard sets `com.apple.screencapture location` |

```bash
# ⌘⇧4 → ~/Downloads/Screenshot 2026-07-07 at 5.30.00 PM.png
# fswatch → optional rename → NSPasteboard → ⌘V
```

## Issue

- macOS writes screenshots to disk
- clipboard is a *separate* step + everything post-Sequoia = common PNG paste paths fail

- multiple failure modes without `clip2copy`:
  - ❌ `osascript` PNG clipboard broken on Sequoia 15+:
    - `NSPasteboard` via Swift is the stable path (official docs → https://developer.apple.com/documentation/AppKit/NSPasteboard)
  - ❌ built-in capture-to-clipboard **skips** the file:
    - `⌘⌃⇧4` gives clipboard only, **not both disk + paste**
  - ❌ watcher pointed at **wrong** folder:
    - macOS save location + fswatch path **must match**

## Setup

One time:
```bash
brew tap vdutts7/tap
brew update
brew install clip2copy
clip2copy setup
```
`clip2copy setup`:
- screenshot save location (e.g. Downloads/Desktop/custom path)
- (optional) rename (e.g. `3n1xm9y2.png` instead of `'Screenshot 2026-07-06 at 5.57.07 AM.png'`)
  - (optional) prefix (e.g. `ss-3n1xm9y2.png`)
- (optional) shadow selection
- writes to → `$HOME/.config/clip2copy/config.json`.

then:
```bash
brew services start clip2copy
```


Day to day use:

```bash
# ⌘+⇧+4 , ⌘V
clip2copy ~/Downloads/a1b2c3.png
clip2copy status
brew services list | rg clip2copy
tail -f $(brew --prefix)/var/log/clip2copy.log
```


## Config

`~/.config/clip2copy/config.json`

| key | cli | default | notes |
|---|---|---|---|
| location | `config set location …` | `~/Downloads` | watch dir + macOS override |
| rename | `config set rename on\|off` | on | off keeps macOS screenshot name |
| renamePrefix | `config set prefix …` | none | Enter in wizard → `a1b2c3.png` |
| disableShadow | `config set shadow on\|off` | on | `com.apple.screencapture disable-shadow` |

```bash
clip2copy config show
clip2copy config set location ~/Pictures/Caps
clip2copy config set prefix cap
clip2copy config validate location ~/Pictures/Caps
brew services restart clip2copy
```

## Gotchas

| problem | fix | stability | why |
|---|---|---|---|
| tap shows old formula | `brew update` before install | stable | Homebrew caches tap refs |
| config change ignored | `brew services restart clip2copy` | stable | launchd loads watcher script at start |
| paste empty after shot | check `brew services list` | stable | watcher must be `started` not `error` |

## Tools Used

<img src="https://img.shields.io/badge/Swift-F05138?style=for-the-badge&logo=swift&logoColor=white" alt="Swift"/>
<br/>
<img src="https://img.shields.io/badge/fswatch-000000?style=for-the-badge" alt="fswatch"/>
<br/>
<img src="https://img.shields.io/badge/NSPasteboard-000000?style=for-the-badge" alt="NSPasteboard"/>

## Contact

<a href="https://vd7.io">
<img src="https://res.cloudinary.com/ddyc1es5v/image/upload/v1773910810/readme-badges/readme-badge-vd7.png" alt="vd7.io" height="40" />
</a>
&nbsp;
<a href="https://x.com/vdutts7">
<img src="https://res.cloudinary.com/ddyc1es5v/image/upload/v1773910817/readme-badges/readme-badge-x.png" alt="/vdutts7" height="40" />
</a>
