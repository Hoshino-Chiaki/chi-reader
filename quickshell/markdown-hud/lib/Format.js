.pragma library

function escapeHtml(value) {
  return String(value)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function renderInline(value) {
  return escapeHtml(value)
    .replace(/`([^`]+)`/g, "<span style=\"color:#ffffff; font-weight:800;\">$1</span>")
    .replace(/\*\*([^*]+)\*\*/g, "<b>$1</b>");
}

function renderTable(source) {
  const rows = String(source).split(/\n/).map(line => line.trim()).filter(line => line.length > 0);
  if (rows.length === 0) return "";

  let html = "<table cellspacing=\"0\" cellpadding=\"4\" style=\"border-collapse:collapse;\">";
  for (let r = 0; r < rows.length; r++) {
    const cells = rows[r].split(/\t+| {2,}|\s+\|\s+|\|/).map(cell => cell.trim()).filter(cell => cell.length > 0);
    if (cells.length === 0) continue;

    html += "<tr>";
    for (let c = 0; c < cells.length; c++) {
      const tag = r === 0 ? "th" : "td";
      html += "<" + tag + " style=\"border:1px solid rgba(255,255,255,0.28); color:#f7f4ec;\">" + renderInline(cells[c]) + "</" + tag + ">";
    }
    html += "</tr>";
  }
  html += "</table>";
  return html;
}

function renderTextToHtml(source) {
  const lines = String(source || "").split(/\n/);
  let html = "";
  let paragraph = [];
  let inTable = false;
  let tableLines = [];

  function flushParagraph() {
    if (paragraph.length === 0) return;
    html += "<p style=\"margin:0 0 8px 0;\">" + renderInline(paragraph.join(" ")) + "</p>";
    paragraph = [];
  }

  function flushTable() {
    if (!inTable) return;
    html += renderTable(tableLines.join("\n"));
    tableLines = [];
    inTable = false;
  }

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    const trimmed = line.trim();

    if (/^<t\d*\b/i.test(trimmed)) {
      flushParagraph();
      inTable = true;
      const rest = trimmed.replace(/^<t\d*\s*/i, "").replace(/t>$/i, "");
      if (rest.length > 0) tableLines.push(rest);
      if (/t>$/i.test(trimmed)) flushTable();
      continue;
    }

    if (inTable) {
      if (/t>$/i.test(trimmed)) {
        const rest = trimmed.replace(/t>$/i, "");
        if (rest.length > 0) tableLines.push(rest);
        flushTable();
      } else {
        tableLines.push(line);
      }
      continue;
    }

    if (trimmed.length === 0) {
      flushParagraph();
      continue;
    }

    if (/^-{11,}$/.test(trimmed)) {
      flushParagraph();
      html += "<hr style=\"border:0; border-top:1px solid rgba(255,255,255,0.42); margin:10px 0;\" />";
      continue;
    }

    const titledDivider = trimmed.match(/^-{3,}\s*(.+?)\s*-{3,}$/);
    if (titledDivider) {
      flushParagraph();
      html += "<p style=\"margin:10px 0 6px 0; color:#ffffff; font-weight:850;\">" + renderInline(titledDivider[1]) + "</p>";
      continue;
    }

    if (/^#{1,4}\s+/.test(trimmed)) {
      flushParagraph();
      const level = Math.min(4, trimmed.match(/^#+/)[0].length);
      const text = trimmed.replace(/^#{1,4}\s+/, "");
      const size = level === 1 ? 21 : level === 2 ? 17 : 15;
      const weight = level === 1 ? 900 : level === 2 ? 760 : 700;
      html += "<p style=\"margin:8px 0 6px 0; font-size:" + size + "px; font-weight:" + weight + "; color:#ffffff;\">" + renderInline(text) + "</p>";
      continue;
    }

    if (/^[-*]\s+/.test(trimmed)) {
      flushParagraph();
      html += "<p style=\"margin:2px 0 2px 10px;\">* " + renderInline(trimmed.replace(/^[-*]\s+/, "")) + "</p>";
      continue;
    }

    paragraph.push(trimmed);
  }

  flushParagraph();
  flushTable();
  return html;
}
