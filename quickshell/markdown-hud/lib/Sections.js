.pragma library

function parseSections(text) {
  const markers = [];
  const source = String(text || "");
  const lines = source.split(/\r?\n/);
  let offset = 0;

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    let match = line.match(/^::(sec|sub|tri)\s+(.+?)\s*$/);
    if (match) {
      const markerType = String(match[1] || "");
      const markerLevel = markerType === "sec" ? 1 : (markerType === "sub" ? 2 : 3);
      markers.push({
        "title": String(match[2]).trim() || "Section " + String(markers.length + 1),
        "level": markerLevel,
        "start": offset,
        "contentStart": offset + line.length + 1
      });
    }
    offset += line.length + 1;
  }

  if (markers.length === 0) {
    return { "roots": [], "error": "" };
  }

  const nextRoots = [];
  let currentRoot = null;
  let currentSub = null;
  let parseError = "";

  for (let i = 0; i < markers.length; i++) {
    const contentEnd = i + 1 < markers.length ? markers[i + 1].start : text.length;
    const rawText = text.slice(markers[i].contentStart, contentEnd);
    const node = {
      "title": markers[i].title,
      "text": rawText.replace(/^\r?\n/, ""),
      "children": []
    };

    if (markers[i].level === 1) {
      currentRoot = node;
      currentSub = null;
      nextRoots.push(node);
    } else if (markers[i].level === 2) {
      if (!currentRoot) {
        parseError = "::sub appears before any ::sec: " + markers[i].title;
        break;
      }
      currentRoot.children.push(node);
      currentSub = node;
    } else {
      if (!currentSub) {
        parseError = "::tri appears before any ::sub: " + markers[i].title;
        break;
      }
      currentSub.children.push(node);
    }
  }

  if (parseError === "") {
    for (let i = 0; i < nextRoots.length; i++) {
      parseError = validateNode(nextRoots[i]);
      if (parseError !== "") break;
    }
  }

  return { "roots": nextRoots, "error": parseError };
}

function validateNode(node) {
  if ((node.children || []).length > 0 && String(node.text || "").trim() !== "") {
    return "目录结构错误: `" + node.title + "` 同时包含正文和子目录。一个目录下面要么只有子目录，要么直接就是正文。";
  }
  const children = node.children || [];
  for (let i = 0; i < children.length; i++) {
    const childError = validateNode(children[i]);
    if (childError !== "") return childError;
  }
  return "";
}
