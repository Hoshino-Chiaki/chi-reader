import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

Scope {
  id: root

  property bool panelVisible: false
  property string viewMode: "reader"
  property int currentIndex: 0
  property int selectedIndex: 0
  property int currentSectionIndex: -1
  property int selectedSectionIndex: 0
  property int sectionParentIndex: -1
  property bool pendingSectionSelector: false
  property var documents: []
  property var sections: []
  property var sectionRoots: []
  property int copiedBlockIndex: -1
  property int copyLayoutSerial: 0
  property string documentRoot: "/home/chiaki/Documents/chi"

  readonly property int panelWidth: 500
  readonly property int panelHeight: 600
  readonly property int inputRailWidth: 56
  readonly property color hudSurfaceColor: "#4d000000"
  readonly property color hudHeaderColor: "#66000000"
  readonly property color hudBorderColor: selectorMode ? "#55ffffff" : "#26ffffff"
  readonly property color primaryTextColor: "#f7f4ec"
  readonly property color secondaryTextColor: "#d8d2c6"
  readonly property color mutedTextColor: "#e7e1d6"
  readonly property color selectedRowColor: "#2effffff"
  readonly property color linkTextColor: "#8fc7ff"
  readonly property color scrollThumbColor: "#80ffffff"
  readonly property color textShadowColor: "#d0000000"
  readonly property string wlCopyCommand: Quickshell.env("CHI_HUD_WL_COPY") || "wl-copy"
  readonly property string shellCommand: Quickshell.env("CHI_HUD_SHELL") || "sh"
  readonly property int documentCount: documents.length
  readonly property var displayedSections: sectionParentIndex >= 0 && sectionParentIndex < sectionRoots.length
    ? (sectionRoots[sectionParentIndex].children || [])
    : sectionRoots
  readonly property int sectionCount: displayedSections.length
  readonly property bool selectorMode: viewMode !== "reader"
  readonly property bool fileSelectorMode: viewMode === "files"
  readonly property bool sectionSelectorMode: viewMode === "sections"
  readonly property var currentDocument: documentCount > 0 ? documents[currentIndex] : null
  readonly property var currentSection: currentSectionIndex >= 0 && currentSectionIndex < sectionCount ? displayedSections[currentSectionIndex] : null
  readonly property string currentTitle: currentDocument ? (currentDocument.title || basename(currentDocument.path || "")) : "No .chi"
  readonly property string currentChiPath: currentDocument ? resolvePath(currentDocument.path || "") : ""
  readonly property string headerTitle: fileSelectorMode
    ? documentRoot
    : sectionSelectorMode
      ? (sectionParentIndex >= 0 && sectionParentIndex < sectionRoots.length
        ? currentTitle + " / " + sectionRoots[sectionParentIndex].title
        : currentTitle)
      : currentSection
        ? (sectionParentIndex >= 0 && sectionParentIndex < sectionRoots.length
          ? currentTitle + " / " + sectionRoots[sectionParentIndex].title + " / " + currentSection.title
          : currentTitle + " / " + currentSection.title)
        : currentTitle
  readonly property int selectorCount: fileSelectorMode ? documentCount : sectionCount
  readonly property int activeSelectedIndex: fileSelectorMode ? selectedIndex : selectedSectionIndex
  readonly property string readerText: currentSection ? currentSection.text : (sectionRoots.length > 0 ? "" : chiFile.text())
  readonly property var readerBlocks: renderChiBlocks(readerText)
  readonly property var codeCopyTargets: copyTargetsFromBlocks(readerBlocks)

  function basename(path) {
    if (!path) return "Untitled";
    const clean = String(path).replace(/\/+$/, "");
    const parts = clean.split("/");
    return parts.length > 0 ? parts[parts.length - 1] : clean;
  }

  function resolvePath(path) {
    if (!path) return "";
    const value = String(path);
    if (value.startsWith("/") || value.startsWith("file:")) return value;
    return Qt.resolvedUrl(value);
  }

  function clampIndex(index) {
    if (documentCount <= 0) return 0;
    return Math.max(0, Math.min(index, documentCount - 1));
  }

  function loadDocumentList() {
    let parsed = {};

    try {
      parsed = JSON.parse(documentListFile.text());
    } catch (error) {
      documentRoot = "/home/chiaki/Documents/chi";
      documents = [];
      currentIndex = 0;
      selectedIndex = 0;
      return;
    }

    documentRoot = parsed.root || "/home/chiaki/Documents/chi";

    let nextDocuments = parsed.documents || [];
    if (!Array.isArray(nextDocuments)) nextDocuments = [];

    documents = nextDocuments.filter(entry => entry && entry.path);
    currentIndex = clampIndex(currentIndex);
    selectedIndex = clampIndex(selectedIndex);
  }

  function openSelector() {
    documentListFile.reload();
    loadDocumentList();
    selectedIndex = clampIndex(currentIndex);
    viewMode = "files";
    panelVisible = true;
    Qt.callLater(() => selectorKeys.forceActiveFocus());
  }

  function toggle() {
    if (panelVisible) hidePanel();
    else openSelector();
  }

  function showPanel() {
    openSelector();
  }

  function hidePanel() {
    viewMode = "reader";
    panelVisible = false;
  }

  function selectDocument(index) {
    if (documentCount <= 0) return;
    currentIndex = clampIndex(index);
    selectedIndex = currentIndex;
    sections = [];
    sectionRoots = [];
    sectionParentIndex = -1;
    currentSectionIndex = -1;
    selectedSectionIndex = 0;
    panelVisible = true;
    pendingSectionSelector = true;
    flick.contentY = 0;
    Qt.callLater(() => chiFile.reload());
  }

  function parseSections(text) {
    const markers = [];
    const source = String(text || "");
    const lines = source.split(/\r?\n/);
    let offset = 0;

    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];
      let match = line.match(/^::sec\s+(.+?)\s*$/);
      if (match) {
        markers.push({
          "title": String(match[1]).trim() || "Section " + String(markers.length + 1),
          "child": false,
          "start": offset,
          "contentStart": offset + line.length + 1
        });
      } else {
        match = line.match(/^::sub\s+(.+?)\s*$/);
        if (match) {
          markers.push({
            "title": String(match[1]).trim() || "Section " + String(markers.length + 1),
            "child": true,
            "start": offset,
            "contentStart": offset + line.length + 1
          });
        }
      }
      offset += line.length + 1;
    }

    if (markers.length === 0) {
      sections = [];
      sectionRoots = [];
      sectionParentIndex = -1;
      selectedSectionIndex = 0;
      currentSectionIndex = -1;
      return;
    }

    const nextRoots = [];
    let currentRoot = null;
    let parseError = "";

    for (let i = 0; i < markers.length; i++) {
      const contentEnd = i + 1 < markers.length ? markers[i + 1].start : text.length;
      const rawText = text.slice(markers[i].contentStart, contentEnd);
      const node = {
        "title": markers[i].title,
        "text": rawText.replace(/^\r?\n/, ""),
        "children": []
      };

      if (markers[i].child) {
        if (!currentRoot) {
          parseError = "Subdirectory marker appears before any parent directory: " + markers[i].title;
          break;
        }
        currentRoot.children.push(node);
      } else {
        currentRoot = node;
        nextRoots.push(node);
      }
    }

    if (parseError === "") {
      for (let i = 0; i < nextRoots.length; i++) {
        if ((nextRoots[i].children || []).length > 0 && String(nextRoots[i].text || "").trim() !== "") {
          parseError = "目录结构错误: `" + nextRoots[i].title + "` 同时包含正文和子目录。一个目录下面要么只有子目录，要么直接就是正文。";
          break;
        }
      }
    }

    if (parseError !== "") {
      const errorNode = {
        "title": "目录结构错误",
        "text": "# 目录结构错误\n\n" + parseError,
        "children": [],
        "error": true
      };
      sections = [errorNode];
      sectionRoots = [errorNode];
      sectionParentIndex = -1;
      selectedSectionIndex = 0;
      currentSectionIndex = 0;
      return;
    }

    const previousParentIndex = sectionParentIndex;
    const previousCurrentIndex = currentSectionIndex;

    sectionRoots = nextRoots;
    sections = nextRoots;
    sectionParentIndex = previousParentIndex >= 0 && previousParentIndex < sectionRoots.length ? previousParentIndex : -1;

    const nextDisplayedSections = sectionParentIndex >= 0 && sectionParentIndex < sectionRoots.length
      ? (sectionRoots[sectionParentIndex].children || [])
      : sectionRoots;
    const nextSectionCount = nextDisplayedSections.length;

    selectedSectionIndex = Math.max(0, Math.min(selectedSectionIndex, nextSectionCount - 1));
    currentSectionIndex = previousCurrentIndex >= 0
      ? Math.max(0, Math.min(previousCurrentIndex, nextSectionCount - 1))
      : -1;
  }

  function openSectionSelector() {
    if (sectionRoots.length === 0) {
      currentSectionIndex = -1;
      viewMode = "reader";
      panelVisible = true;
      return;
    }

    sectionParentIndex = -1;
    selectedSectionIndex = 0;
    viewMode = "sections";
    panelVisible = true;
    Qt.callLater(() => selectorKeys.forceActiveFocus());
  }

  function chooseSection(index) {
    if (sectionCount <= 0) return;
    const safeIndex = Math.max(0, Math.min(index, sectionCount - 1));
    const node = displayedSections[safeIndex];

    if (node && (node.children || []).length > 0) {
      sectionParentIndex = sectionRoots.indexOf(node);
      selectedSectionIndex = 0;
      currentSectionIndex = -1;
      viewMode = "sections";
      Qt.callLater(() => selectorKeys.forceActiveFocus());
      return;
    }

    currentSectionIndex = safeIndex;
    selectedSectionIndex = safeIndex;
    viewMode = "reader";
    panelVisible = true;
    flick.contentY = 0;
  }

  function activateSelection() {
    if (fileSelectorMode) selectDocument(selectedIndex);
    else if (sectionSelectorMode) chooseSection(selectedSectionIndex);
  }


  function moveSelection(delta) {
    if (selectorCount <= 0) return;
    const next = (activeSelectedIndex + delta + selectorCount) % selectorCount;

    if (fileSelectorMode) selectedIndex = next;
    else selectedSectionIndex = next;

    panelVisible = true;
    if (selectorMode) Qt.callLater(() => selectorKeys.forceActiveFocus());
  }

  function nextDocument(delta) {
    if (documentCount <= 0) return;
    selectDocument((currentIndex + delta + documentCount) % documentCount);
  }

  function clampScrollY(value) {
    return Math.max(0, Math.min(maxScrollY(), value));
  }

  function measuredReaderHeight() {
    const estimatedHeight = estimateReaderHeight();
    return readerColumn
      ? Math.max(flick.contentHeight, readerColumn.childrenRect.height + 16, estimatedHeight)
      : Math.max(flick.contentHeight, estimatedHeight);
  }

  function maxScrollY() {
    return Math.max(0, measuredReaderHeight() - flick.height);
  }

  function scrollReader(delta) {
    const amount = Math.max(120, Math.min(300, flick.height * 0.21));
    flick.contentY = clampScrollY(flick.contentY - (delta > 0 ? amount : -amount));
  }

  function scrollReaderBy(amount) {
    const before = flick.contentY;
    flick.contentY = clampScrollY(flick.contentY + amount);
    return "contentY " + String(Math.round(before)) + " -> " + String(Math.round(flick.contentY))
      + " / max " + String(Math.round(maxScrollY()))
      + " contentHeight=" + String(Math.round(flick.contentHeight))
      + " childrenRect=" + String(Math.round(readerColumn.childrenRect.height))
      + " estimated=" + String(Math.round(estimateReaderHeight()))
      + " flickHeight=" + String(Math.round(flick.height));
  }

  function wheelDelta(wheel) {
    if (wheel.angleDelta && wheel.angleDelta.y !== 0) return wheel.angleDelta.y;
    if (wheel.pixelDelta && wheel.pixelDelta.y !== 0) return wheel.pixelDelta.y * 6;
    return 0;
  }

  function handlePanelWheel(wheel) {
    const delta = wheelDelta(wheel);
    if (delta === 0) return;

    if (selectorMode) {
      const steps = Math.max(1, Math.min(5, Math.round(Math.abs(delta) / 45)));
      const direction = delta > 0 ? -1 : 1;
      for (let i = 0; i < steps; i++) moveSelection(direction);
    } else {
      scrollReader(delta);
    }
  }

  function escapeHtml(value) {
    return String(value)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  }

  function renderInline(value) {
    return escapeHtml(value)
      .replace(/`([^`]+)`/g, "<span style=\"color:#ffffff; font-weight:700;\">$1</span>")
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
        html += "<p style=\"margin:10px 0 6px 0; color:#ffffff; font-weight:800;\">" + renderInline(titledDivider[1]) + "</p>";
        continue;
      }

      if (/^#{1,4}\s+/.test(trimmed)) {
        flushParagraph();
        const level = Math.min(4, trimmed.match(/^#+/)[0].length);
        const text = trimmed.replace(/^#{1,4}\s+/, "");
        const size = level === 1 ? 20 : level === 2 ? 17 : 15;
        html += "<p style=\"margin:8px 0 6px 0; font-size:" + size + "px; font-weight:800; color:#ffffff;\">" + renderInline(text) + "</p>";
        continue;
      }

      if (/^[-*]\s+/.test(trimmed)) {
        flushParagraph();
        html += "<p style=\"margin:2px 0 2px 10px;\">• " + renderInline(trimmed.replace(/^[-*]\s+/, "")) + "</p>";
        continue;
      }

      paragraph.push(trimmed);
    }

    flushParagraph();
    flushTable();
    return html;
  }

  function normalizeCodeBlock(value) {
    let text = String(value || "");
    text = text.replace(/^\r?\n/, "");
    text = text.replace(/\r?\n$/, "");
    return text;
  }

  function normalizeRuleBlock(value) {
    let text = String(value || "");
    text = text.replace(/^\r?\n/, "");
    text = text.replace(/\r?\n$/, "");
    return text.split(/\r?\n/);
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

  function tableCellText(row, column) {
    if (Array.isArray(row)) return String(row[column] || "");
    if (row && row.length !== undefined) return String(row[column] || "");
    return "";
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

  function estimateCodeHeight(block) {
    const lines = String(block.code || "").split(/\r?\n/);
    let wrappedLines = 0;
    for (let i = 0; i < lines.length; i++) {
      wrappedLines += estimateWrappedVisualLines(lines[i], 44);
    }
    return Math.max(50, wrappedLines * 18 + (String(block.label || "").length > 0 ? 52 : 30));
  }

  function estimateCodePackHeight(block) {
    const entries = codePackEntries(block);
    return 26 + (String(block.title || "").length > 0 ? 26 : 0) + codePackRowsHeight(entries);
  }

  function codePackRowsHeight(entries) {
    const source = entries && entries.length !== undefined ? entries : [];
    let height = 0;
    for (let i = 0; i < source.length; i++) {
      const label = String(source[i] && source[i].label || "");
      const code = String(source[i] && source[i].code || "");
      const codeLines = estimateWrappedVisualLines(code, 38);
      height += Math.max(54, codeLines * 18 + (label.length > 0 ? 37 : 26));
      if (i < source.length - 1) height += 6;
    }
    return height;
  }

  function codePackEntries(block) {
    if (!block || !block.entries || block.entries.length === undefined) return [];
    return block.entries;
  }

  function renderCodePackLines(entries) {
    const source = entries && entries.length !== undefined ? entries : [];
    const lines = [];
    for (let i = 0; i < source.length; i++) {
      const label = String(source[i] && source[i].label || "").trim();
      const code = String(source[i] && source[i].code || "").trim();
      if (label.length > 0) lines.push(label);
      lines.push("  " + code);
      if (i < source.length - 1) lines.push("");
    }
    return lines.join("\n");
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

  function visualTextUnits(value) {
    const text = String(value || "");
    let units = 0;
    for (let i = 0; i < text.length; i++) {
      units += text.charCodeAt(i) > 127 ? 2 : 1;
    }
    return Math.max(1, units);
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

  function estimateTableHeight(block) {
    return tableBlockHeight(block, root.panelWidth - root.inputRailWidth - 24);
  }

  function tableBlockHeight(block, availableWidth) {
    const rows = block.rows || [];
    const tableContentWidth = Math.max(120, Number(availableWidth || 1) - 38);
    const titleHeight = String(block.title || "").length > 0 ? 28 : 0;
    return 90 + titleHeight + tableRowsHeight(rows, block.columns || 1, tableContentWidth);
  }

  function tableRowsHeight(rows, columns, tableWidth) {
    const source = Array.isArray(rows) ? rows : normalizeLines(rows);
    let height = 0;
    for (let i = 0; i < source.length; i++) {
      height += tableRowHeight(source[i], source, columns, tableWidth);
    }
    return height;
  }

  function estimateFlowHeight(block) {
    const lines = normalizeLines(block.lines || []);
    return 34 + (String(block.title || "").length > 0 ? 26 : 0) + Math.max(1, lines.length) * 18;
  }

  function estimateReaderHeight() {
    let height = 14;
    for (let i = 0; i < readerBlocks.length; i++) {
      const block = readerBlocks[i] || {};
      if (block.type === "rule") height += estimateRuleHeight(block);
      else if (block.type === "table") height += estimateTableHeight(block);
      else if (block.type === "flow") height += estimateFlowHeight(block);
      else if (block.type === "codep") height += estimateCodePackHeight(block);
      else if (block.type === "code") height += estimateCodeHeight(block);
      else height += estimateTextHeight(block);
      height += 8;
    }
    return height;
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

  function copyTargetBlockIndex(target, fallback) {
    if (target && target.blockIndex !== undefined) return Number(target.blockIndex);
    return fallback;
  }

  function copyTargetId(target, fallback) {
    if (target && target.copyId !== undefined) return Number(target.copyId);
    return copyTargetBlockIndex(target, fallback);
  }

  function copyTargetCode(target) {
    if (target && target.code !== undefined) return String(target.code || "");
    return "";
  }

  function copyTargetY(target, targetItem, buttonHeight) {
    if (!targetItem) return -1000;
    if (target && target.rowIndex !== undefined) {
      const entries = codePackEntries(target.block);
      const title = target.block ? String(target.block.title || "") : "";
      const titleOffset = title.length > 0 ? 20 : 0;
      const lineHeight = 13 * 1.12;
      const codeLine = codePackCodeLineIndex(entries, target.rowIndex);
      const rowOffset = 9 + titleOffset + 7 + codeLine * lineHeight + lineHeight / 2 - buttonHeight / 2;
      return targetItem.y - flick.contentY + rowOffset;
    }
    return targetItem.y - flick.contentY + 4 + Math.max(0, (targetItem.height - buttonHeight) / 2);
  }

  function copyTargetsFromBlocks(blocks) {
    const targets = [];
    for (let i = 0; i < blocks.length; i++) {
      if (blocks[i] && blocks[i].type === "code") {
        targets.push({ "blockIndex": i, "code": blocks[i].code || "" });
      } else if (blocks[i] && blocks[i].type === "codep") {
        const entries = codePackEntries(blocks[i]);
        for (let j = 0; j < entries.length; j++) {
          targets.push({
            "blockIndex": i,
            "rowIndex": j,
            "copyId": i * 1000 + j + 1,
            "block": blocks[i],
            "code": entries[j] ? entries[j].code || "" : ""
          });
        }
      }
    }
    return targets;
  }

  function copyCode(code, blockIndex) {
    const text = String(code || "");
    Quickshell.clipboardText = text;
    Quickshell.execDetached([
      root.shellCommand,
      "-c",
      "copy_bin=\"$2\"; if [ -x \"$copy_bin\" ] || command -v \"$copy_bin\" >/dev/null 2>&1; then printf %s \"$1\" | \"$copy_bin\"; fi",
      "chi-hud-copy",
      text,
      root.wlCopyCommand
    ]);
    copiedBlockIndex = blockIndex;
    copyFeedbackTimer.restart();
  }

  Timer {
    id: copyFeedbackTimer
    interval: 900
    repeat: false
    onTriggered: copiedBlockIndex = -1
  }

  FileView {
    id: documentListFile
    path: Qt.resolvedUrl("docs.json")
    watchChanges: true
    onLoaded: loadDocumentList()
    onLoadFailed: {
      documents = [];
      documentRoot = "/home/chiaki/Documents/chi";
    }
    onFileChanged: {
      reload();
      loadDocumentList();
    }
  }

  FileView {
    id: chiFile
    path: root.currentChiPath
    watchChanges: true
    onLoaded: {
      parseSections(text());
      flick.contentY = 0;
      if (pendingSectionSelector) {
        pendingSectionSelector = false;
        openSectionSelector();
      } else if (viewMode === "reader" && currentSectionIndex < 0 && sectionRoots.length > 0) {
        openSectionSelector();
      }
    }
    onLoadFailed: {
      sections = [];
      sectionRoots = [];
      sectionParentIndex = -1;
      currentSectionIndex = -1;
      if (pendingSectionSelector) {
        pendingSectionSelector = false;
        openSectionSelector();
      }
    }
    onFileChanged: reload()
  }

  IpcHandler {
    target: "mdhud"

    function toggle(): void { root.toggle(); }
    function open(): void { root.showPanel(); }
    function show(): void { root.showPanel(); }
    function hide(): void { root.hidePanel(); }
    function scrollUp(): string { return root.scrollReaderBy(-180); }
    function scrollDown(): string { return root.scrollReaderBy(180); }
    function metrics(): string {
      return "contentY=" + String(Math.round(flick.contentY))
        + " max=" + String(Math.round(root.maxScrollY()))
        + " contentHeight=" + String(Math.round(flick.contentHeight))
        + " childrenRect=" + String(Math.round(readerColumn.childrenRect.height))
        + " estimated=" + String(Math.round(root.estimateReaderHeight()))
        + " flickHeight=" + String(Math.round(flick.height))
        + " selector=" + String(root.selectorMode);
    }
    function reload(): void {
      documentListFile.reload();
      loadDocumentList();
      chiFile.reload();
    }
    function status(): string {
      return panelVisible ? "visible" : "hidden";
    }
  }

  PanelWindow {
    id: panel
    visible: root.panelVisible
    implicitWidth: root.panelWidth
    implicitHeight: root.panelHeight
    color: "transparent"
    focusable: root.selectorMode || root.codeCopyTargets.length > 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: (root.selectorMode || root.codeCopyTargets.length > 0)
      ? WlrKeyboardFocus.OnDemand
      : WlrKeyboardFocus.None
    WlrLayershell.namespace: "chi-reader"
    anchors {
      top: true
      left: true
    }
    margins {
      top: 36
      left: 8
    }
    mask: Region { item: surface }


    Rectangle {
      id: surface
      anchors.fill: parent
      color: root.hudSurfaceColor
      border.width: 1
      border.color: root.hudBorderColor
      radius: 8

      Rectangle {
        id: header
        anchors {
          left: parent.left
          right: parent.right
          top: parent.top
        }
        height: 38
        color: root.hudHeaderColor
        radius: 8

        Text {
          anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
            leftMargin: 12
            rightMargin: 12
          }
          text: root.headerTitle
          color: root.primaryTextColor
          font.pixelSize: 13
          font.bold: true
          elide: Text.ElideRight
          textFormat: Text.PlainText
          style: Text.Outline
          styleColor: root.textShadowColor
        }
      }

      Item {
        id: contentArea
        anchors {
          left: parent.left
          right: inputRail.left
          top: header.bottom
          bottom: parent.bottom
          margins: 10
          rightMargin: 2
        }
        clip: true

        Column {
          id: selectorList
          visible: root.selectorMode
          anchors.fill: parent
          spacing: 4

          Repeater {
            model: root.selectorCount

            Rectangle {
              width: selectorList.width
              height: 28
              radius: 5
              color: index === root.activeSelectedIndex ? root.selectedRowColor : "transparent"

              Text {
                anchors {
                  left: parent.left
                  right: parent.right
                  verticalCenter: parent.verticalCenter
                  leftMargin: 8
                  rightMargin: 8
                }
                text: root.fileSelectorMode
                  ? (root.documents[index].title || root.basename(root.documents[index].path || ""))
                  : ((root.displayedSections[index].children || []).length > 0
                    ? root.displayedSections[index].title + " /"
                    : root.displayedSections[index].title)
                color: index === root.activeSelectedIndex ? "#ffffff" : root.primaryTextColor
                font.pixelSize: 13
                font.bold: index === root.activeSelectedIndex
                elide: Text.ElideRight
                textFormat: Text.PlainText
                style: Text.Outline
                styleColor: root.textShadowColor
              }
            }
          }
        }

        Flickable {
          id: flick
          visible: !root.selectorMode
          anchors.fill: parent
          contentWidth: width
          contentHeight: Math.max(height, readerColumn.childrenRect.height + 16, root.estimateReaderHeight())
          boundsBehavior: Flickable.StopAtBounds
          clip: true

          WheelHandler {
            target: null
            enabled: !root.selectorMode
            onWheel: event => {
              root.handlePanelWheel(event);
              event.accepted = true;
            }
          }

          Column {
            id: readerColumn
            width: flick.width
            spacing: 8

            Text {
              visible: root.readerBlocks.length === 0
              width: parent.width
              text: root.documentCount === 0 ? "没有找到 .chi 文件" : "这个章节是空的"
              color: root.secondaryTextColor
              font.pixelSize: 14
              textFormat: Text.PlainText
              style: Text.Outline
              styleColor: root.textShadowColor
            }

            Repeater {
              id: blockRepeater
              model: root.readerBlocks
              onItemAdded: (index, item) => {
                root.copyLayoutSerial += 1;
                Qt.callLater(() => root.copyLayoutSerial += 1);
              }

              Loader {
                width: readerColumn.width
                height: modelData.type === "codep"
                  ? (item ? Math.max(item.height, item.implicitHeight || 0) : root.estimateCodePackHeight(modelData))
                  : modelData.type === "table"
                    ? root.tableBlockHeight(modelData, readerColumn.width)
                    : modelData.type === "flow"
                      ? root.estimateFlowHeight(modelData)
                  : item ? Math.max(item.height, item.implicitHeight || 0) : implicitHeight
                sourceComponent: modelData.type === "code"
                  ? codeBlockComponent
                  : modelData.type === "codep"
                    ? codePackBlockComponent
                    : modelData.type === "rule"
                      ? ruleBlockComponent
                      : modelData.type === "flow"
                        ? flowBlockComponent
                        : modelData.type === "table"
                          ? tableBlockComponent
                          : textBlockComponent
                property var block: modelData
                property int blockIndex: index
              }
            }

            Item {
              width: parent.width
              height: 14
            }
          }
        }

        MouseArea {
          anchors.fill: parent
          visible: !root.selectorMode
          hoverEnabled: true
          acceptedButtons: Qt.NoButton
          onWheel: wheel => {
            root.handlePanelWheel(wheel);
            wheel.accepted = true;
          }
        }
      }

      Rectangle {
        id: inputRail
        anchors {
          top: header.bottom
          bottom: parent.bottom
          right: parent.right
          topMargin: 6
          bottomMargin: 6
          rightMargin: 4
        }
        width: root.inputRailWidth
        color: "transparent"
        readonly property bool canScroll: !root.selectorMode && flick.contentHeight > flick.height + 1
        readonly property real thumbHeight: canScroll
          ? Math.max(30, inputRail.height * flick.height / Math.max(1, flick.contentHeight))
          : inputRail.height
        readonly property real thumbTravel: Math.max(1, inputRail.height - thumbHeight)

        WheelHandler {
          id: railWheel
          target: null
          enabled: !root.selectorMode
          onWheel: event => {
            root.handlePanelWheel(event);
            event.accepted = true;
          }
        }

        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          acceptedButtons: Qt.NoButton
          onEntered: {
            if (panel.focusable) Qt.callLater(() => selectorKeys.forceActiveFocus());
          }
          onWheel: wheel => {
            root.handlePanelWheel(wheel);
            wheel.accepted = true;
          }
        }

        MouseArea {
          anchors.fill: parent
          enabled: !root.selectorMode
          hoverEnabled: true
          acceptedButtons: Qt.LeftButton

          function updateScroll(mouseY) {
            if (!inputRail.canScroll) return;
            const ratio = Math.max(0, Math.min(1, (mouseY - inputRail.thumbHeight / 2) / inputRail.thumbTravel));
            flick.contentY = root.clampScrollY(ratio * (flick.contentHeight - flick.height));
          }

          onPressed: mouse => updateScroll(mouse.y)
          onPositionChanged: mouse => {
            if (pressed) updateScroll(mouse.y);
          }
          onWheel: wheel => {
            root.handlePanelWheel(wheel);
            wheel.accepted = true;
          }
        }

        Rectangle {
          visible: !root.selectorMode
          width: 3
          radius: 2
          color: "#34ffffff"
          x: inputRail.width - 8
          y: 0
          height: inputRail.height
        }

        Repeater {
          model: []

          Rectangle {
            id: copyButton
            readonly property int targetBlockIndex: root.copyTargetBlockIndex(modelData, index)
            readonly property int copyId: root.copyTargetId(modelData, index)
            readonly property string copyText: root.copyTargetCode(modelData)
            readonly property int layoutSerial: root.copyLayoutSerial
            readonly property var targetItem: {
              const tick = layoutSerial;
              return blockRepeater.itemAt(targetBlockIndex);
            }
            readonly property bool copied: root.copiedBlockIndex === copyId
            readonly property real preferredY: root.copyTargetY(modelData, targetItem, height)
            x: 6
            y: preferredY
            width: 36
            height: 22
            radius: 4
            visible: !root.selectorMode && targetItem && preferredY >= -height && preferredY <= inputRail.height
            scale: copied ? 1.08 : 1.0
            color: copied ? "#b8ffd3" : "#f4f7fb"
            border.width: 1
            border.color: copied ? "#46df82" : "#c8d2dc"

            Behavior on scale {
              NumberAnimation { duration: 110; easing.type: Easing.OutCubic }
            }

            Behavior on color {
              ColorAnimation { duration: 120 }
            }

            Text {
              anchors.centerIn: parent
              text: copyButton.copied ? "OK" : "CP"
              color: "#111111"
              font.pixelSize: 11
              font.bold: true
              textFormat: Text.PlainText
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              acceptedButtons: Qt.LeftButton
              onClicked: root.copyCode(copyButton.copyText, copyButton.copyId)
              onWheel: wheel => {
                root.handlePanelWheel(wheel);
                wheel.accepted = true;
              }
            }
          }
        }

        Rectangle {
          visible: !root.selectorMode
          width: 3
          radius: 2
          color: root.scrollThumbColor
          x: inputRail.width - 8
          height: inputRail.thumbHeight
          y: inputRail.canScroll ? Math.max(0, inputRail.thumbTravel * flick.visibleArea.yPosition) : 0
          opacity: inputRail.canScroll ? 1.0 : 0.45
        }
      }

      Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
          if (root.sectionSelectorMode && root.sectionParentIndex >= 0) {
            root.sectionParentIndex = -1;
            root.selectedSectionIndex = 0;
          } else {
            root.hidePanel();
          }
          event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
          root.activateSelection();
          event.accepted = true;
        } else if (event.key === Qt.Key_J || event.key === Qt.Key_Down) {
          if (root.selectorMode) root.moveSelection(1);
          else flick.contentY = root.clampScrollY(flick.contentY + 42);
          event.accepted = true;
        } else if (event.key === Qt.Key_K || event.key === Qt.Key_Up) {
          if (root.selectorMode) root.moveSelection(-1);
          else flick.contentY = root.clampScrollY(flick.contentY - 42);
          event.accepted = true;
        } else if (event.key === Qt.Key_H || event.key === Qt.Key_Left) {
          if (root.sectionSelectorMode && root.sectionParentIndex >= 0) {
            root.sectionParentIndex = -1;
            root.selectedSectionIndex = 0;
          } else {
            root.nextDocument(-1);
          }
          event.accepted = true;
        } else if (event.key === Qt.Key_L || event.key === Qt.Key_Right) {
          if (root.sectionSelectorMode) root.activateSelection();
          else root.nextDocument(1);
          event.accepted = true;
        }
      }

      Item {
        id: selectorKeys
        anchors.fill: parent
        focus: root.selectorMode
        Keys.forwardTo: [surface]
      }
    }
  }

  Component {
    id: textBlockComponent

    Text {
      width: parent.width
      height: implicitHeight
      text: block.text || ""
      color: root.primaryTextColor
      font.pixelSize: 14
      lineHeight: 1.18
      wrapMode: Text.Wrap
      textFormat: Text.PlainText
      style: Text.Outline
      styleColor: root.textShadowColor
    }
  }

  Component {
    id: codeBlockComponent

    Item {
      width: parent.width
      height: codeCard.height + 2

      Rectangle {
        id: codeCard
        readonly property bool hasLabel: String(block.label || "").length > 0
        width: Math.max(0, parent.width - 18)
        height: Math.max(50, codeText.implicitHeight + (hasLabel ? 52 : 30))
        x: Math.round((parent.width - width) / 2)
        y: 0
        radius: 6
        color: "#52111111"
        border.width: 1
        border.color: "#6affffff"

        Rectangle {
          id: labelBadge
          visible: codeCard.hasLabel
          anchors {
            left: parent.left
            top: parent.top
            leftMargin: 10
            topMargin: 7
          }
          height: 18
          width: Math.min(labelText.implicitWidth + 14, parent.width - 20)
          radius: 4
          color: "#edf2f7"

          Text {
            id: labelText
            anchors {
              left: parent.left
              right: parent.right
              verticalCenter: parent.verticalCenter
              leftMargin: 7
              rightMargin: 7
            }
            text: block.label || ""
            color: "#101010"
            font.pixelSize: 10
            font.bold: true
            elide: Text.ElideRight
            textFormat: Text.PlainText
          }
        }

        Text {
          id: codeText
          width: Math.max(0, parent.width - 66)
          x: 55
          y: codeCard.hasLabel ? 34 : Math.round((codeCard.height - implicitHeight) / 2)
          text: block.code || ""
          color: "#ffffff"
          font.family: "monospace"
          font.pixelSize: 13
          font.bold: true
          horizontalAlignment: Text.AlignLeft
          wrapMode: Text.WrapAtWordBoundaryOrAnywhere
          textFormat: Text.PlainText
          style: Text.Outline
          styleColor: "#d0000000"
        }

        Rectangle {
          id: inlineCodeCopyButton
          x: 10
          y: codeCard.hasLabel
            ? 34 + Math.max(0, (Math.min(22, codeText.implicitHeight) - height) / 2)
            : Math.round((codeCard.height - height) / 2)
          width: 36
          height: 22
          radius: 4
          color: root.copiedBlockIndex === blockIndex ? "#b8ffd3" : "#f4f7fb"
          border.width: 1
          border.color: root.copiedBlockIndex === blockIndex ? "#46df82" : "#c8d2dc"

          Text {
            anchors.centerIn: parent
            text: root.copiedBlockIndex === blockIndex ? "OK" : "CP"
            color: "#111111"
            font.pixelSize: 11
            font.bold: true
            textFormat: Text.PlainText
          }

          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton
            onClicked: root.copyCode(block.code || "", blockIndex)
            onWheel: wheel => {
              root.handlePanelWheel(wheel);
              wheel.accepted = true;
            }
          }
        }
      }
    }
  }

  Component {
    id: ruleBlockComponent

    Item {
      width: parent.width
      height: ruleCard.height + 2

      Rectangle {
        id: ruleCard
        width: parent.width - 18
        height: ruleContent.childrenRect.height + 20
        x: Math.round((parent.width - width) / 2)
        y: 0
        radius: 6
        color: "#4b101820"
        border.width: 1
        border.color: "#74d7ecff"

        Column {
          id: ruleContent
          anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            leftMargin: 12
            rightMargin: 12
            topMargin: 10
          }
          spacing: 6

          Text {
            width: parent.width
            height: implicitHeight
            text: block.title || "rule"
            color: "#ffffff"
            font.pixelSize: 13
            font.bold: true
            textFormat: Text.PlainText
            style: Text.Outline
            styleColor: root.textShadowColor
          }

          Rectangle {
            width: parent.width
            height: 1
            color: "#7dd7ecff"
          }

          Text {
            id: ruleBodyText
            width: parent.width
            height: implicitHeight
            text: root.renderRuleLines(block.lines || [])
            color: root.primaryTextColor
            font.family: "monospace"
            font.pixelSize: 13
            lineHeight: 1.16
            wrapMode: Text.Wrap
            textFormat: Text.PlainText
            style: Text.Outline
            styleColor: root.textShadowColor
          }

          Rectangle {
            width: parent.width
            height: 1
            color: "#7dd7ecff"
          }
        }
      }
    }
  }

  Component {
    id: codePackBlockComponent

    Item {
      width: parent.width
      height: codePackCard.height + 2

      Rectangle {
        id: codePackCard
        readonly property bool hasTitle: String(block.title || "").length > 0
        width: Math.max(0, parent.width - 18)
        height: codePackContent.implicitHeight + 18
        x: Math.round((parent.width - width) / 2)
        y: 0
        radius: 6
        color: "#52111111"
        border.width: 1
        border.color: "#6affffff"

        Column {
          id: codePackContent
          anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            leftMargin: 10
            rightMargin: 10
            topMargin: 9
          }
          spacing: 7

          Text {
            id: codePackTitle
            visible: codePackCard.hasTitle
            width: parent.width
            height: visible ? implicitHeight : 0
            text: block.title || ""
            color: "#ffffff"
            font.pixelSize: 13
            font.bold: true
            textFormat: Text.PlainText
            style: Text.Outline
            styleColor: root.textShadowColor
          }

          Column {
            id: codePackRows
            width: parent.width
            height: implicitHeight
            spacing: 6

            Repeater {
              model: root.codePackEntries(block)

              Rectangle {
                id: codePackRow
                readonly property string rowLabel: String(modelData.label || "")
                readonly property string copyText: String(modelData.code || "")
                readonly property int copyId: blockIndex * 1000 + index + 1
                readonly property bool copied: root.copiedBlockIndex === copyId
                width: parent.width
                height: Math.max(54, packCodeText.implicitHeight + (rowLabel.length > 0 ? 37 : 26))
                radius: 5
                color: "#381a1f24"
                border.width: 1
                border.color: copied ? "#46df82" : "#456affff"

                Rectangle {
                  id: packCopyButton
                  anchors {
                    left: parent.left
                    top: parent.top
                    leftMargin: 8
                    topMargin: 16
                  }
                  width: 36
                  height: 22
                  radius: 4
                  color: codePackRow.copied ? "#b8ffd3" : "#f4f7fb"
                  border.width: 1
                  border.color: codePackRow.copied ? "#46df82" : "#c8d2dc"

                  Text {
                    anchors.centerIn: parent
                    text: codePackRow.copied ? "OK" : "CP"
                    color: "#111111"
                    font.pixelSize: 11
                    font.bold: true
                    textFormat: Text.PlainText
                  }

                  MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton
                    onClicked: root.copyCode(codePackRow.copyText, codePackRow.copyId)
                    onWheel: wheel => {
                      root.handlePanelWheel(wheel);
                      wheel.accepted = true;
                    }
                  }
                }

                Text {
                  id: packLabelText
                  visible: codePackRow.rowLabel.length > 0
                  anchors {
                    left: packCopyButton.right
                    top: parent.top
                    right: parent.right
                    leftMargin: 8
                    rightMargin: 9
                    topMargin: 7
                  }
                  height: 14
                  text: codePackRow.rowLabel
                  color: "#d8edf6"
                  font.pixelSize: 10
                  font.bold: true
                  elide: Text.ElideRight
                  textFormat: Text.PlainText
                }

                Text {
                  id: packCodeText
                  x: packCopyButton.x + packCopyButton.width + 8
                  y: codePackRow.rowLabel.length > 0 ? 25 : 17
                  width: Math.max(0, parent.width - x - 9)
                  height: implicitHeight
                  text: codePackRow.copyText
                  color: "#ffffff"
                  font.family: "monospace"
                  font.pixelSize: 13
                  font.bold: true
                  verticalAlignment: Text.AlignTop
                  wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                  textFormat: Text.PlainText
                  style: Text.Outline
                  styleColor: "#d0000000"
                }
              }
            }
          }
        }
      }
    }
  }

  Component {
    id: tableBlockComponent

    Item {
      width: parent.width
      height: root.tableBlockHeight(block, width)

      Rectangle {
        id: tableCard
        readonly property int columnCount: Math.max(1, Math.min(6, Number(block.columns || 1)))
        width: parent.width - 18
        height: parent.height - 8
        x: Math.round((parent.width - width) / 2)
        y: 0
        radius: 6
        color: "#4b14171b"
        border.width: 1
        border.color: "#586f87ff"
        clip: true

        Column {
          id: tableContent
          anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            leftMargin: 10
            rightMargin: 10
            topMargin: 9
          }
          spacing: 7

          Text {
            id: tableTitle
            visible: String(block.title || "").length > 0
            width: parent.width
            height: visible ? implicitHeight : 0
            text: block.title || ""
            color: "#ffffff"
            font.pixelSize: 14
            font.bold: true
            textFormat: Text.PlainText
            style: Text.Outline
            styleColor: root.textShadowColor
          }

          Column {
            id: tableRows
            width: parent.width
            height: root.tableRowsHeight(block.rows || [], tableCard.columnCount, width)
            spacing: 0

            Repeater {
              model: block.rows || []

              Item {
                id: tableRow
                readonly property var rowData: modelData
                readonly property int rowNumber: index
                width: tableRows.width
                height: root.tableRowHeight(rowData, block.rows || [], tableCard.columnCount, tableRows.width)

                Row {
                  anchors.fill: parent
                  spacing: 0

                  Repeater {
                    model: tableCard.columnCount

                    Rectangle {
                      width: root.tableColumnWidth(block.rows || [], tableCard.columnCount, index, tableRows.width)
                      height: tableRow.height
                      clip: true
                      color: tableRow.rowNumber === 0
                        ? "#3f4548"
                        : tableRow.rowNumber % 2 === 0
                          ? "#24292c"
                          : "#202427"
                      border.width: 1
                      border.color: "#405075"

                      Text {
                        anchors {
                          left: parent.left
                          right: parent.right
                          top: parent.top
                          bottom: parent.bottom
                          margins: 8
                        }
                        text: root.tableCellText(tableRow.rowData, index)
                        color: tableRow.rowNumber === 0 ? "#ffffff" : root.primaryTextColor
                        font.pixelSize: 13
                        font.bold: tableRow.rowNumber === 0
                        wrapMode: Text.Wrap
                        verticalAlignment: Text.AlignVCenter
                        textFormat: Text.PlainText
                        style: Text.Outline
                        styleColor: root.textShadowColor
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }

  Component {
    id: flowBlockComponent

    Item {
      width: parent.width
      height: flowCard.height + 8

      Rectangle {
        id: flowCard
        readonly property bool hasTitle: String(block.title || "").length > 0
        width: parent.width - 18
        height: flowContent.childrenRect.height + 18
        x: Math.round((parent.width - width) / 2)
        y: 0
        radius: 6
        color: "#4210171c"
        border.width: 1
        border.color: "#5f8fb9ff"

        Column {
          id: flowContent
          anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            leftMargin: 10
            rightMargin: 10
            topMargin: 9
          }
          spacing: 7

          Text {
            visible: flowCard.hasTitle
            width: parent.width
            height: visible ? implicitHeight : 0
            text: block.title || ""
            color: "#ffffff"
            font.pixelSize: 13
            font.bold: true
            textFormat: Text.PlainText
            style: Text.Outline
            styleColor: root.textShadowColor
          }

          Text {
            width: parent.width
            height: implicitHeight
            text: root.normalizeLines(block.lines || []).join("\n")
            color: root.primaryTextColor
            font.family: "monospace"
            font.pixelSize: 13
            font.bold: true
            lineHeight: 1.12
            wrapMode: Text.NoWrap
            textFormat: Text.PlainText
            style: Text.Outline
            styleColor: root.textShadowColor
          }
        }
      }
    }
  }

  Component.onCompleted: {
    loadDocumentList();
  }
}
