# Terminal for Spicetify

A terminal-inspired Spotify theme with square panels, monospace text, a muted
charcoal palette, and amber highlights. Built and checked on the Windows desktop
client.

![Terminal theme preview](assets/preview.png)

## Features

- Framed NAV, LIB, main view, INSPECT, and TRANSPORT panels.
- Aligned `[EXT]`, `[HOME]`, and history controls.
- Compact track rows and monochrome artwork.
- Short library labels with Spotify's native hover labels.
- A 144-pixel volume slider, 28-pixel drag target, visible handle, and live percentage.
- Hidden native window buttons and menu dots. **F8** shows or hides them, with
  space reserved in the navigation when visible.
- Spotify's native navigation, playback, seeking, and playlist actions.

## Install on Windows

Install and set up [Spicetify](https://spicetify.app/) first. Then paste this
one command into PowerShell:

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/braces157/spicetify-terminal/main/install.ps1)))
```

The installer fetches the theme without Git, finds your Spicetify config,
backs up the current Terminal files and config, and applies the theme. Spotify
may restart. Re-running the command installs the latest version.

Backups are saved under `TerminalBackups` beside your Spicetify config file.
If installation fails, the script restores the files and settings it changed.
It does not install Spotify or Spicetify.

You can [download and inspect the script](install.ps1) before running it. It
supports Windows PowerShell 5.1 and PowerShell 7.

### Installer options

After downloading the repository, these commands can be run from its folder:

```powershell
# Install from the downloaded copy, with no network fetch.
.\install.ps1 -LocalSource .

# Fetch the theme files without changing the selected theme or restarting Spotify.
.\install.ps1 -NoApply

# Install a particular GitHub branch, tag, or commit.
.\install.ps1 -Ref main
```

Use `-SpicetifyPath 'C:\path\to\spicetify.exe'` for a portable Spicetify setup.
If repository access is restricted, the installer can fall back to an
authenticated GitHub CLI.

### Manual installation

Download the repository ZIP, extract it, and copy `Terminal` into the `Themes`
folder beside the config file printed by `spicetify --config`. Then run:

```powershell
spicetify config current_theme Terminal color_scheme Terminal inject_css 1 inject_theme_js 1 replace_colors 1
spicetify apply
```

If a Marketplace theme is already active, deselect it in Marketplace before
applying Terminal so its injected CSS does not override this theme.

For dense playlist rows, choose **Compact** in Spotify's playlist view menu.
List view is also supported.

## Customize and update

Edit the installed `Terminal/color.ini` and the `--tui-*` variables in
`Terminal/user.css`, then run `spicetify refresh`. The theme uses Cascadia Mono,
Consolas, and system fallback fonts; it downloads no external fonts or images.

To update, run the install command again. You can also pull or download the
latest repository and run `.\install.ps1 -LocalSource .`.

## Compatibility

Validated with **Spotify 1.3.3.264** and **Spicetify 2.45.3** on Windows.
Layout checks passed at viewport widths of 800, 844, and 1100 pixels. The native
volume drag behavior and both directions of the F8 toggle were verified.

Spotify updates can change selectors and internal APIs. Most structural rules
use semantic roles, test IDs, and theme-owned presentation attributes; some
artwork selectors target the tested client version.

Native titlebar hiding uses `NativeAPI` and `ControlMessageAPI` when available.
It keeps the selected visibility when Spotify changes panels or viewport zoom,
and restores the original API methods when the theme script is cleaned up.
Platforms without these APIs retain their native window controls. Other
platforms have not been tested.

## Credits

The terminal direction was inspired by
[NephVx2/Spicetify-tui](https://github.com/NephVx2/Spicetify-tui).
The native titlebar API approach was informed by
[No Controls](https://github.com/ohitstom/spicetify-extensions/tree/main/noControls).
