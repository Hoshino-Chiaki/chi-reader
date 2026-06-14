# chi_reader Syntax Rules

This document lists every supported `.chi` rule and how to use it.

## Rule Count

Total syntax rules: **15**

- Block and structure rules: **8**
- Inline and plain-text rules: **6**
- Block ending rule: **1**

## Block And Structure Rules

| No. | Rule | Usage | Notes |
| --- | --- | --- | --- |
| 01 | `::sec TITLE` | Level-1 section | Top-level file directory. |
| 02 | `::sub TITLE` | Level-2 section | Must appear under a `::sec`. |
| 03 | `::tri TITLE` | Level-3 section | Must appear under a `::sub`. |
| 04 | `::code [LABEL]` | Multiline code block | One `CP` button copies the full code body. |
| 05 | `::codep [TITLE]` | Code pack | Each row gets an independent `CP` button. |
| 06 | `::rule [TITLE]` | Rule/list card | Each original line is displayed as a bullet point. |
| 07 | `::table N TITLE` | Table card | `N` is the number of columns, from 1 to 6. |
| 08 | `::flow [TITLE]` | ASCII flow chart | Preserves monospace layout and line breaks. |

## Inline And Plain-Text Rules

| No. | Rule | Usage | Render |
| --- | --- | --- | --- |
| 09 | `# TITLE` or `#TITLE` | Level-1 text heading | Strongest bold heading. |
| 10 | `## TITLE` or `##TITLE` | Level-2 text heading | Slightly lighter heading. |
| 11 | `` `text` `` | Inline code emphasis | Bright bold inline text. |
| 12 | `**text**` | Bold emphasis | Bold inline text. |
| 13 | `- item` or `* item` | Bullet line | Rendered as a compact bullet paragraph. |
| 14 | `-----------` | Divider | Horizontal separator line. |

## Block Ending Rule

| No. | Rule | Usage |
| --- | --- | --- |
| 15 | `::` | Ends a block | Required after `::code`, `::codep`, `::rule`, `::table`, and `::flow`. |

## Section Tree

Use three levels:

```text
::sec 01.Linux
::sub 01.Files
::tri 01.List files
```

Rules:

- `::sec` can contain direct text or `::sub` children.
- `::sub` can contain direct text or `::tri` children.
- A node should not mix direct text and child sections.
- `::tri` is the leaf level; put normal text and blocks under it.

## Code Block

```text
::code 查看目录
ls -la
::
```

Use when the command is one script or one logical block.

Long lines wrap visually, but `CP` copies the original code.

## Code Pack

```text
::codep pacman 常用命令
升级系统	sudo pacman -Syu
安装软件	sudo pacman -S 软件名
删除软件	sudo pacman -Rns 软件名
::
```

Use when one topic has many short commands.

Row formats:

```text
label<Tab>command
(label) command
label  command
```

Tab is preferred.

## Rule Card

```text
::rule chmod 权限记忆
u = user
g = group
o = others
::
```

Every original content line becomes:

```text
* line
```

## Table

```text
::table 2 journalctl 常用选项
选项	说明
-b	显示本次启动的日志
-f	跟踪日志
::
```

Rules:

- `N` is the column count.
- The first row is rendered as the header.
- Prefer tab-separated cells.
- If spaces are used, the parser keeps the remaining text in the last column.

## Flow

```text
::flow SSH 公钥绑定流程
你的电脑
  │
  ▼
GitHub
::
```

Use for process diagrams and relationship charts.

## Text Example

```text
# 一级标题
#1. 编号一级标题
## 二级标题
##02. 编号二级标题

Use `pacman -Syu` before upgrading.
**Do not paste commands you do not understand.**

- item one
- item two

-----------
```

## Recommended File Shape

```text
::sec 01.Topic
::sub 01.Subtopic
::tri 01.Small task

# Main idea
## Detail

Plain note text.

::code optional label
command here
::
```
