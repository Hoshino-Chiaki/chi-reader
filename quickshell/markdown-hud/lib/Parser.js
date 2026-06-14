.pragma library

function normalizeCodeBlock(value) {
  let text = String(value || "");
  text = text.replace(/^\r?\n/, "");
  text = text.replace(/\r?\n$/, "");
  return text;
}

function normalizeLines(lines) {
  const output = [];
  if (Array.isArray(lines)) {
    for (let i = 0; i < lines.length; i++) output.push(String(lines[i] || ""));
  } else if (lines && lines.length !== undefined) {
    for (let i = 0; i < lines.length; i++) output.push(String(lines[i] || ""));
  } else if (lines !== undefined && lines !== null) {
    const parts = String(lines).split(/\r?\n/);
    for (let i = 0; i < parts.length; i++) output.push(parts[i]);
  }
  return output;
}

function renderRuleLines(lines) {
  const source = normalizeLines(lines);
  return source.map(line => "* " + String(line)).join("\n");
}

function splitTableRow(line, columns) {
  const count = Math.max(1, Math.min(6, Number(columns) || 1));
  let cells = [];
  const raw = String(line || "").trim();

  if (raw.indexOf("\t") >= 0) {
    cells = raw.split(/\t+/).map(cell => cell.trim());
  } else {
    const parts = raw.split(/\s+/).filter(part => part.length > 0);
    for (let i = 0; i < count - 1 && i < parts.length; i++) cells.push(parts[i]);
    cells.push(parts.slice(count - 1).join(" "));
  }

  while (cells.length < count) cells.push("");
  if (cells.length > count) {
    cells = cells.slice(0, count - 1).concat([cells.slice(count - 1).join(" ")]);
  }
  return cells;
}

function parseTableRows(lines, columns) {
  const source = normalizeLines(lines);
  const rows = [];
  for (let i = 0; i < source.length; i++) {
    if (String(source[i] || "").trim().length === 0) continue;
    rows.push(splitTableRow(source[i], columns));
  }
  return rows;
}

function parseCodePack(lines) {
  const source = normalizeLines(lines);
  const entries = [];
  const displayLines = [];
  for (let i = 0; i < source.length; i++) {
    const raw = String(source[i] || "").trim();
    if (raw.length === 0) continue;

    let label = "";
    let code = raw;
    const tabIndex = raw.indexOf("\t");
    const parenMatch = raw.match(/^\(([^)]*)\)\s*(.+)$/);
    const wideSpaceMatch = raw.match(/^(.+?)\s{2,}(.+)$/);
    if (tabIndex >= 0) {
      label = raw.slice(0, tabIndex).trim();
      code = raw.slice(tabIndex + 1).trim();
    } else if (parenMatch) {
      label = parenMatch[1].trim();
      code = parenMatch[2].trim();
    } else if (wideSpaceMatch) {
      label = wideSpaceMatch[1].trim();
      code = wideSpaceMatch[2].trim();
    }

    if (code.length > 0) {
      entries.push({ "label": label, "code": code });
      if (label.length > 0) displayLines.push(label);
      displayLines.push("  " + code);
      if (i < source.length - 1) displayLines.push("");
    }
  }
  return { "entries": entries, "displayText": displayLines.join("\n") };
}

function renderChiBlocks(source) {
  const blocks = [];
  const text = String(source || "");
  const lines = text.split(/\r?\n/);
  let textLines = [];

  function flushText() {
    const literal = textLines.join("\n");
    if (literal.length > 0) blocks.push({ "type": "text", "text": literal });
    textLines = [];
  }

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    let match = line.match(/^::table\s+(\d+)(?:\s+(.+?))?\s*$/);
    if (match) {
      flushText();
      const columns = Math.max(1, Math.min(6, Number(match[1]) || 1));
      const body = [];
      i++;
      while (i < lines.length && !/^::\s*$/.test(lines[i])) {
        body.push(lines[i]);
        i++;
      }
      blocks.push({
        "type": "table",
        "columns": columns,
        "title": String(match[2] || "").trim(),
        "rows": parseTableRows(body, columns)
      });
      continue;
    }

    match = line.match(/^::codep(?:\s+(.+?))?\s*$/);
    if (match) {
      flushText();
      const body = [];
      i++;
      while (i < lines.length && !/^::\s*$/.test(lines[i])) {
        body.push(lines[i]);
        i++;
      }
      const pack = parseCodePack(body);
      blocks.push({
        "type": "codep",
        "title": String(match[1] || "").trim(),
        "entries": pack.entries,
        "displayText": pack.displayText
      });
      continue;
    }

    match = line.match(/^::rule(?:\s+(.+?))?\s*$/);
    if (match) {
      flushText();
      const body = [];
      i++;
      while (i < lines.length && !/^::\s*$/.test(lines[i])) {
        body.push(lines[i]);
        i++;
      }
      blocks.push({
        "type": "rule",
        "title": String(match[1] || "").trim(),
        "lines": body
      });
      continue;
    }

    match = line.match(/^::flow(?:\s+(.+?))?\s*$/);
    if (match) {
      flushText();
      const body = [];
      i++;
      while (i < lines.length && !/^::\s*$/.test(lines[i])) {
        body.push(lines[i]);
        i++;
      }
      blocks.push({
        "type": "flow",
        "title": String(match[1] || "").trim(),
        "lines": body
      });
      continue;
    }

    match = line.match(/^::code(?:\s+(.+?))?\s*$/);
    if (match) {
      flushText();
      const label = String(match[1] || "").trim();
      const codeLines = [];
      i++;
      while (i < lines.length && !/^::\s*$/.test(lines[i])) {
        codeLines.push(lines[i]);
        i++;
      }
      blocks.push({
        "type": "code",
        "label": label,
        "code": normalizeCodeBlock(codeLines.join("\n"))
      });
      continue;
    }

    textLines.push(line);
  }

  flushText();
  return blocks;
}

function codePackEntries(block) {
  if (!block || !block.entries || block.entries.length === undefined) return [];
  return block.entries;
}
