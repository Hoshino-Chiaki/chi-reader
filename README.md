# chi_reader
![photo1](image/Screenshot%20from%202026-06-07%2010-46-10.png)
![photo2](image/Screenshot%20from%202026-06-07%2010-46-36.png)

`chi_reader` is a transparent Quickshell HUD for reading `.chi` study notes on **Arch Linux + Niri**.

It is designed for fast keyboard-driven note lookup while working in a Wayland desktop: open the HUD, choose a `.chi` file, choose a section, read compact command notes, and copy commands without leaving the current workspace.

## Scope

This project is intentionally scoped to:

- Arch Linux
- Niri Wayland compositor
- Quickshell
- User-local installation under `~/.config/chi_reader`

Other Linux distributions, desktop environments, and compositors are not supported by this project unless you adapt the paths, keybindings, and Quickshell/Niri behavior yourself.

## Features

- Transparent HUD for `.chi` notes
- File selector and section selector
- Keyboard navigation
- Fast scrolling
- Copy buttons for code blocks and command rows
- Persistent configurable `.chi` directory
- Daily automatic SSH backup from config
- Manual backup with confirmation prompt
- One-shot server-to-local restore gate for dangerous overwrite recovery
- Syntax blocks for code, command packs, rules, tables, and ASCII flows
- No extra in-panel settings UI; configuration is done with `md-hud` commands

## Project Layout

```text
chi_reader/
  bin/md-hud
  server/chi-backup-receive
  quickshell/markdown-hud/shell.qml
  quickshell/markdown-hud/docs.json
  config.example.json
  README.md
  USAGE.md
```

`bin/md-hud` is the launcher and control command.

`quickshell/markdown-hud/shell.qml` is the HUD UI.

`USAGE.md` is the detailed `.chi` syntax reference.

`server/chi-backup-receive` is an optional server-side backup receiver used over SSH.

## Dependencies

Install the runtime dependencies on Arch Linux:

```sh
sudo pacman -Syu --needed quickshell jq wl-clipboard
```

Required tools:

- `quickshell` / `qs`: runs the HUD and IPC
- `jq`: generates the document index
- `wl-copy`: copies commands to the Wayland clipboard
- `niri`: compositor used for keybindings
- `openssh`: optional, used for remote backup

## Install

Recommended install location:

```text
~/.config/chi_reader
```

From the project source directory:

```sh
mkdir -p ~/.config
cp -a /home/chiaki/Documents/chi_reader ~/.config/chi_reader
mkdir -p ~/.local/bin
ln -sf ~/.config/chi_reader/bin/md-hud ~/.local/bin/md-hud
chmod +x ~/.config/chi_reader/bin/md-hud
```

Make sure `~/.local/bin` is in your shell `PATH`:

```sh
printf '%s\n' 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

Test the command:

```sh
md-hud status
md-hud toggle
```

## Configure Niri Keybindings

Add a keybinding to your Niri config, for example:

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

Then validate and reload Niri with your normal Niri workflow.

## Document Directory

Project settings live in:

```text
~/.config/chi_reader/config.json
```

Show the current config:

```sh
md-hud config
```

Show the config path:

```sh
md-hud config-path
```

Example config:

```json
{
  "chi_dir": "/home/chiaki/Documents/chi",
  "backup": {
    "host": "backup.example.com",
    "user": "chiaki",
    "port": 22,
    "identity_file": "~/.ssh/id_ed25519",
    "remote_command": "chi-backup-receive",
    "keep": 20,
    "time": "03:30"
  },
  "restore": {
    "download_overwrite_once": "no",
    "remote_archive": "latest.tar.gz"
  }
}
```

By default, `.chi` files are read from:

```text
/home/chiaki/Documents/chi
```

Show the current directory:

```sh
md-hud dir
```

Set a new persistent directory:

```sh
md-hud dir ~/Documents/chi
md-hud dir /path/to/chi-folder
```

This writes `chi_dir` in `~/.config/chi_reader/config.json`.

Reset to the default:

```sh
md-hud dir-reset
```

Temporary one-shot override:

```sh
CHI_HUD_DIR=/path/to/chi md-hud toggle
```

## Remote Backup

Remote backup is intentionally implemented over SSH instead of a custom HTTP daemon. This keeps the complexity low: SSH already handles authentication, encryption, users, firewall policy, and audit logs.

Complexity level:

- Low on the client: one `md-hud backup` command
- Low on the server: one receiver script in `PATH`
- No web service, no open custom port, no database
- The tradeoff is that the server must allow SSH login for the backup user

### Server Setup

Copy the receiver script to the server:

```sh
scp server/chi-backup-receive chiaki@backup.example.com:~/.local/bin/chi-backup-receive
ssh chiaki@backup.example.com 'chmod +x ~/.local/bin/chi-backup-receive'
```

Make sure `~/.local/bin` is in the server user's `PATH`, or set `backup.remote_command` to the absolute path:

```sh
md-hud config-set backup.remote_command /home/chiaki/.local/bin/chi-backup-receive
```

By default, the server stores backups in:

```text
~/chi_reader_backups
```

Server-side environment variables:

```sh
CHI_BACKUP_ROOT=/path/to/backups
CHI_BACKUP_NAME=chi
CHI_BACKUP_KEEP=20
```

The receiver stores timestamped archives like:

```text
chi-20260609-153000.tar.gz
latest.tar.gz
```

### Client Backup Config

Set the backup server:

```sh
md-hud config-set backup.host backup.example.com
md-hud config-set backup.user chiaki
md-hud config-set backup.port 22
md-hud config-set backup.identity_file ~/.ssh/id_ed25519
md-hud config-set backup.keep 20
md-hud config-set backup.time 03:30
```

Test the server:

```sh
md-hud backup-test
```

Run a backup:

```sh
md-hud backup
```

The manual backup command asks for confirmation, then uploads the configured `chi_dir` as a compressed tar archive through SSH.

### Automatic Daily Backup

The automatic backup time is read from `backup.time` in `~/.config/chi_reader/config.json`.

```sh
md-hud config-set backup.time 03:30
md-hud backup-timer-install
```

Check the user timer:

```sh
md-hud backup-timer-status
```

Remove it:

```sh
md-hud backup-timer-remove
```

The timer runs:

```sh
md-hud backup-auto
```

`backup-auto` only uploads. It never performs a restore, even if the restore switch is armed.

### One-Shot Restore From Server

Server-to-local restore is intentionally gated because it overwrites matching local files.

There is no normal restore command. To restore, arm the one-shot switch in config:

```sh
md-hud config-set restore.download_overwrite_once yes
md-hud config-set restore.remote_archive latest.tar.gz
md-hud backup
```

Then type `RESTORE` when prompted.

After the attempt, `restore.download_overwrite_once` is reset to `no`. Extra local files are kept; files with the same names as the archive contents are overwritten.

## Commands

```sh
md-hud toggle
md-hud show
md-hud hide
md-hud reload
md-hud status
md-hud scroll-up
md-hud scroll-down
md-hud metrics
md-hud dir
md-hud dir /path/to/chi
md-hud dir-reset
md-hud config
md-hud config-path
md-hud config-set KEY VALUE
md-hud backup-test
md-hud backup
md-hud backup-auto
md-hud backup-timer-install
md-hud backup-timer-status
md-hud backup-timer-remove
```

## `.chi` Syntax

Short example:

```text
::sec 01.Linux
::sub 01.chmod
::tri 01.权限查看

::code 查看权限
ls -l
::

::codep 常用命令
装软件	yay -S 软件名
删软件	yay -Rns 软件名
::

::rule purview_rule:
u代表User，也就是文件主人
g代表Group，也就是用户组
::

::table 2 常用选项
选项	说明
-b	显示本次启动的日志
::

::flow SSH 流程
本机
  │
  ▼
GitHub
::
```

## Interaction

- `Win+E`: toggle HUD, if configured in Niri
- `Win+Up` / `Win+Down`: scroll through `md-hud`
- `j` / `k` or arrow keys: move/select or scroll
- `Enter`: select file or section
- `Esc`: close or go back
- `CP`: copy a code command to the clipboard

## Notes

- Keep syntax markers at the start of a line.
- End block syntax with a line containing only `::`.
- Use `::sec` for level 1, `::sub` under `::sec`, and `::tri` under `::sub`.
- Use `::codep` for many related one-line commands.
- Use `::code` for multiline scripts.
- Use `::flow` for ASCII diagrams and process charts.
- Use Tab-separated rows in `::table` blocks.

## Troubleshooting

Check whether the HUD process is reachable:

```sh
md-hud status
```

Regenerate the document index and reload:

```sh
md-hud reload
```

Print scroll and layout metrics:

```sh
md-hud metrics
```

Check the current `.chi` directory:

```sh
md-hud dir
```

If the HUD opens but no documents appear, make sure the configured directory exists and contains `.chi` files.
