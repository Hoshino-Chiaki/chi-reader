# chi_reader

![photo1](image/Screenshot%20from%202026-06-07%2010-46-10.png)
![photo2](image/Screenshot%20from%202026-06-07%2010-46-36.png)

`chi_reader` is a transparent Quickshell HUD for reading `.chi` study notes on **Arch Linux + Niri**.

It is built for quick command lookup: open the HUD, choose a file, choose a section, read the note, and copy commands without leaving the current workspace.

## Supported Environment

- Arch Linux
- Niri Wayland compositor
- Quickshell
- User-local install at `~/.config/chi_reader`

Other desktops or distributions are not the target environment.

## Main Features

- Transparent `.chi` note HUD
- File selector and nested section selector
- Three-level note tree: `::sec -> ::sub -> ::tri`
- Rich text headings: `#` is strongest, `##` is slightly lighter
- Copy buttons for `::code` and every row in `::codep`
- Wrapped long code lines without clipping
- Config-driven `.chi` directory
- SSH backup, daily timer backup, and gated one-shot restore

## Project Layout

```text
chi_reader/
  bin/md-hud
  server/chi-backup-receive
  quickshell/markdown-hud/
    shell.qml
    docs.json
    lib/
      Format.js
      Layout.js
      Parser.js
      Sections.js
  config.example.json
  README.md
  SYNTAX.md
```

Module responsibilities:

- `shell.qml`: HUD state, IPC, keyboard handling, and visible UI
- `lib/Format.js`: rich text rendering, inline code, bold text, headings
- `lib/Parser.js`: `.chi` block parsing, code packs, tables, rules
- `lib/Layout.js`: wrapped-code/table/reader height calculations
- `lib/Sections.js`: `::sec`, `::sub`, `::tri` tree parsing
- `bin/md-hud`: launcher, config, backup, timer, reload, scroll commands
- `server/chi-backup-receive`: SSH backup receiver on the server

## Install

Install dependencies:

```sh
sudo pacman -Syu --needed quickshell jq wl-clipboard openssh
```

Install locally:

```sh
mkdir -p ~/.config ~/.local/bin
cp -a /home/chiaki/Documents/chi_reader ~/.config/chi_reader
ln -sf ~/.config/chi_reader/bin/md-hud ~/.local/bin/md-hud
chmod +x ~/.config/chi_reader/bin/md-hud
```

Test:

```sh
md-hud status
md-hud toggle
```

## Niri Keybindings

```kdl
Super+E allow-inhibiting=false hotkey-overlay-title="Markdown HUD: Toggle" {
    spawn "md-hud" "toggle";
}

Super+Up allow-inhibiting=false hotkey-overlay-title="Markdown HUD: Scroll Up" {
    spawn "md-hud" "scroll-up";
}

Super+Down allow-inhibiting=false hotkey-overlay-title="Markdown HUD: Scroll Down" {
    spawn "md-hud" "scroll-down";
}
```

## Config

Config file:

```text
~/.config/chi_reader/config.json
```

Show config:

```sh
md-hud config
```

Set the `.chi` directory:

```sh
md-hud dir /home/chiaki/Documents/chi
```

Example:

```json
{
  "chi_dir": "/home/chiaki/Documents/chi",
  "backup": {
    "host": "backup.example.com",
    "user": "backup-user",
    "port": 22,
    "identity_file": "~/.ssh/id_ed25519",
    "remote_command": "/home/backup-user/.local/bin/chi-backup-receive",
    "keep": 20,
    "time": "09:30"
  },
  "restore": {
    "download_overwrite_once": "no",
    "remote_archive": "latest.tar.gz"
  }
}
```

## Commands

```sh
md-hud toggle
md-hud show
md-hud hide
md-hud reload
md-hud status
md-hud metrics
md-hud scroll-up
md-hud scroll-down
md-hud dir
md-hud dir /path/to/chi
md-hud dir-reset
md-hud config
md-hud config-path
md-hud config-set KEY VALUE
```

Backup commands:

```sh
md-hud backup-test
md-hud backup
md-hud backup-auto
md-hud backup-timer-install
md-hud backup-timer-status
md-hud backup-timer-remove
```

## Backup

Server setup:

```sh
ssh backup-user@SERVER_HOST 'mkdir -p ~/.local/bin ~/chi_reader_backups'
scp server/chi-backup-receive backup-user@SERVER_HOST:~/.local/bin/chi-backup-receive
ssh backup-user@SERVER_HOST 'chmod 700 ~/.local/bin/chi-backup-receive'
```

Client setup:

```sh
md-hud config-set backup.host SERVER_HOST
md-hud config-set backup.user backup-user
md-hud config-set backup.remote_command /home/backup-user/.local/bin/chi-backup-receive
md-hud config-set backup.time 09:30
```

Run one backup:

```sh
md-hud backup
```

Enable daily backup:

```sh
md-hud backup-timer-install
```

Dangerous one-shot restore:

```sh
md-hud config-set restore.download_overwrite_once yes
md-hud backup
```

Then type `RESTORE`. The flag is reset to `no` after the attempt.

## Syntax

The full rule list is in [SYNTAX.md](SYNTAX.md).

Rule count:

- 8 block/structure rules
- 6 inline/plain-text rules
- 1 block ending rule
- 15 total syntax rules

Tiny example:

```text
::sec 01.Linux
::sub 01.Files
::tri 01.List

# 一级标题
## 二级标题

::code 查看文件
ls -la
::
```

## Troubleshooting

Reload the HUD:

```sh
md-hud reload
```

Check layout metrics:

```sh
md-hud metrics
```

Check current document directory:

```sh
md-hud dir
```

If no documents appear, make sure `chi_dir` exists and contains `.chi` files.
