# chi_reader Syntax v2

This is the final high-performance `.chi` format. Special syntax is line-based: markers must start at the beginning of a line.

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
```

## Document Directory

The HUD reads `.chi` files from the configured document directory.

Show the current directory:

```sh
md-hud dir
```

Set a new persistent directory and reload the HUD index:

```sh
md-hud dir /home/chiaki/Documents/chi
md-hud dir ~/Documents/chi
```

Reset to the default directory:

```sh
md-hud dir-reset
```

For a one-shot temporary override, use:

```sh
CHI_HUD_DIR=/path/to/chi md-hud toggle
```

## Sections

Top-level section:

```text
::sec 01.Linux
```

Child section:

```text
::sub 01.chmod
```

A `::sec` can contain text directly or contain `::sub` children. Avoid mixing both in one `::sec`.

## Text

Plain text is rendered as wrapped text.

Supported lightweight text:

```text
# 一级标题
## 二级标题
- 列表项
* 列表项
-----------
--- 小标题 ---
Use `command` and **important text**.
```

## Code Blocks

Code block:

```text
::code
ssh-keygen -t ed25519 -C "chiaki"
::
```

Code block with label:

```text
::code 生成公钥
ssh-keygen -t ed25519 -C "chiaki"
::
```

The copy button copies only the code body, not the label.

## Code Pack Blocks

Use `::codep` when one topic has many short one-line commands. Each row gets its own `CP` button.

```text
::codep 最常用记忆版
装软件	yay -S 软件名
删软件	yay -Rns 软件名
搜软件	yay 软件名
升级全系统	yay -Syu
::
```

Rules:

- `::codep title`
- Prefer Tab between the label and command.
- `(label) command` is also supported.
- Two or more spaces between label and command are also supported for old notes.
- End the block with a line containing only `::`.

## Rule Blocks

Rule block:

```text
::rule purview_rule:
01.字母法
u代表User也就是文件的主人
g代表Group也就是主人的熟人/团队
::
```

Each original content line is rendered as:

```text
* line
```

## Table Blocks

Table block:

```text
::table 2 常用选项概览
选项	说明
-b	显示本次启动的日志
-f	跟踪日志（类似 tail -f）
-k	只显示内核消息
::
```

Rules:

- `::table n title`
- `n` is the number of columns, from 1 to 6.
- The first content row is the header.
- Prefer Tab between cells.
- If a row uses spaces instead of Tab, the parser splits by whitespace and puts the remaining text into the last column.
- End the table with a line containing only `::`.

## Flow Blocks

Use `::flow` for ASCII diagrams, command flows, and relationship charts.

```text
::flow SSH 公钥绑定流程
你的电脑
  │
  │ 生成一对 SSH key
  ▼
GitHub 收到公钥
::
```

Rules:

- `::flow title`
- Content is rendered in monospace and preserves line breaks/spaces.
- End the block with a line containing only `::`.

## Performance Rules

- Marker lines start at column 1.
- Block endings use only `::`.
- Use Tab-separated table rows when cell text contains spaces.
- Use `::codep` for many related one-line commands.
- Use `::flow` for ASCII diagrams and process charts.
- Do not nest `::code`, `::codep`, `::rule`, `::table`, or `::flow` blocks.

## Keyboard

```text
Win+E       Toggle HUD
Win+Up      Scroll HUD up
Win+Down    Scroll HUD down
j / Down    Move down or scroll down
k / Up      Move up or scroll up
Enter       Select
Esc         Close or go back
```
