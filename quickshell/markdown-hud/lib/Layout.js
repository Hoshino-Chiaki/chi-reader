.pragma library

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

function tableCellText(row, column) {
  if (Array.isArray(row)) return String(row[column] || "");
  if (row && row.length !== undefined) return String(row[column] || "");
  return "";
}

function visualTextUnits(value) {
  const text = String(value || "");
  let units = 0;
  for (let i = 0; i < text.length; i++) {
    units += text.charCodeAt(i) > 127 ? 2 : 1;
  }
  return Math.max(1, units);
}

function estimateWrappedLines(value, charsPerLine) {
  const text = String(value || "");
  if (text.length === 0) return 1;
  return Math.max(1, Math.ceil(text.length / charsPerLine));
}

function estimateWrappedVisualLines(value, unitsPerLine) {
  return Math.max(1, Math.ceil(visualTextUnits(value) / Math.max(1, unitsPerLine)));
}

function estimateRuleHeight(block) {
  const lines = Array.isArray(block.lines) ? block.lines : [];
  let wrappedLines = 0;
  for (let i = 0; i < lines.length; i++) {
    wrappedLines += estimateWrappedLines("* " + String(lines[i] || ""), 38);
  }
  return 58 + wrappedLines * 20;
}

function estimateTextHeight(block) {
  const lines = String(block.text || "").split(/\r?\n/);
  let wrappedLines = 0;
  for (let i = 0; i < lines.length; i++) {
    wrappedLines += estimateWrappedLines(lines[i], 44);
  }
  return Math.max(18, wrappedLines * 18);
}

function codeVisualLineCount(value, unitsPerLine) {
  const lines = String(value || "").split(/\r?\n/);
  let total = 0;
  for (let i = 0; i < lines.length; i++) {
    total += estimateWrappedVisualLines(lines[i], unitsPerLine);
  }
  return Math.max(1, total);
}

function estimateCodeHeight(block) {
  const wrappedLines = codeVisualLineCount(block.code || "", 42);
  return Math.max(50, wrappedLines * 18 + (String(block.label || "").length > 0 ? 52 : 30));
}

function codePackEntries(block) {
  if (!block || !block.entries || block.entries.length === undefined) return [];
  return block.entries;
}

function codePackRowHeight(entry) {
  const label = String(entry && entry.label || "");
  const code = String(entry && entry.code || "");
  const codeLines = codeVisualLineCount(code, 36);
  return Math.max(54, codeLines * 18 + (label.length > 0 ? 39 : 28));
}

function codePackRowsHeight(entries) {
  const source = entries && entries.length !== undefined ? entries : [];
  let height = 0;
  for (let i = 0; i < source.length; i++) {
    height += codePackRowHeight(source[i]);
    if (i < source.length - 1) height += 6;
  }
  return height;
}

function estimateCodePackHeight(block) {
  const entries = codePackEntries(block);
  return 26 + (String(block.title || "").length > 0 ? 26 : 0) + codePackRowsHeight(entries);
}

function codePackCodeLineIndex(entries, rowIndex) {
  const source = entries && entries.length !== undefined ? entries : [];
  let lineIndex = 0;
  const target = Math.max(0, Number(rowIndex || 0));
  for (let i = 0; i < source.length && i < target; i++) {
    const label = String(source[i] && source[i].label || "").trim();
    if (label.length > 0) lineIndex += 1;
    lineIndex += 1;
    if (i < source.length - 1) lineIndex += 1;
  }
  const currentLabel = target < source.length
    ? String(source[target] && source[target].label || "").trim()
    : "";
  if (currentLabel.length > 0) lineIndex += 1;
  return lineIndex;
}

function tableColumnUnits(rows, column) {
  const source = rows && rows.length !== undefined ? rows : [];
  let units = 1;
  for (let i = 0; i < source.length; i++) {
    units = Math.max(units, visualTextUnits(tableCellText(source[i], column)));
  }
  return units;
}

function tableColumnWidth(rows, columns, column, tableWidth) {
  const count = Math.max(1, Math.min(6, Number(columns) || 1));
  const width = Math.max(1, Number(tableWidth) || 1);
  const minWidth = Math.min(88, width / count);
  let totalUnits = 0;
  for (let i = 0; i < count; i++) {
    totalUnits += tableColumnUnits(rows, i);
  }
  const flexibleWidth = Math.max(1, width - minWidth * count);
  const extra = flexibleWidth * tableColumnUnits(rows, column) / Math.max(1, totalUnits);
  return Math.max(minWidth, minWidth + extra);
}

function tableRowHeight(row, rows, columns, tableWidth) {
  const cells = normalizeLines(row);
  let lines = 1;
  for (let i = 0; i < cells.length; i++) {
    const columnWidth = tableColumnWidth(rows, columns, i, tableWidth);
    const unitsPerLine = Math.max(3, Math.floor(Math.max(30, columnWidth - 16) / 10));
    lines = Math.max(lines, estimateWrappedVisualLines(cells[i], unitsPerLine));
  }
  return Math.max(58, lines * 24 + 36);
}

function tableRowsHeight(rows, columns, tableWidth) {
  const source = Array.isArray(rows) ? rows : normalizeLines(rows);
  let height = 0;
  for (let i = 0; i < source.length; i++) {
    height += tableRowHeight(source[i], source, columns, tableWidth);
  }
  return height;
}

function tableBlockHeight(block, availableWidth) {
  const rows = block.rows || [];
  const tableContentWidth = Math.max(120, Number(availableWidth || 1) - 38);
  const titleHeight = String(block.title || "").length > 0 ? 28 : 0;
  return 90 + titleHeight + tableRowsHeight(rows, block.columns || 1, tableContentWidth);
}

function estimateFlowHeight(block) {
  const lines = normalizeLines(block.lines || []);
  return 34 + (String(block.title || "").length > 0 ? 26 : 0) + Math.max(1, lines.length) * 18;
}

function estimateReaderHeight(blocks, availableWidth) {
  const readerBlocks = blocks && blocks.length !== undefined ? blocks : [];
  let height = 14;
  for (let i = 0; i < readerBlocks.length; i++) {
    const block = readerBlocks[i] || {};
    if (block.type === "rule") height += estimateRuleHeight(block);
    else if (block.type === "table") height += tableBlockHeight(block, availableWidth);
    else if (block.type === "flow") height += estimateFlowHeight(block);
    else if (block.type === "codep") height += estimateCodePackHeight(block);
    else if (block.type === "code") height += estimateCodeHeight(block);
    else height += estimateTextHeight(block);
    height += 8;
  }
  return height;
}
