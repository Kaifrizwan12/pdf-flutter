const FLOW_GAP = 8;

function estimateWrappedLines(textValue, width, fontSize) {
  const text = String(textValue ?? '');
  const safeWidth = Math.max(1, width);
  const charsPerLine = Math.max(1, Math.floor(safeWidth / (fontSize * 0.52)));
  let lines = 0;

  for (const paragraph of text.split('\n')) {
    const words = paragraph.trim().split(/\s+/).filter(Boolean);
    if (words.length === 0) {
      lines += 1;
      continue;
    }

    let current = 0;
    for (const word of words) {
      const wordLength = word.length;
      if (current === 0) {
        lines += Math.floor(wordLength / charsPerLine);
        current = wordLength % charsPerLine;
      } else if (current + 1 + wordLength <= charsPerLine) {
        current += 1 + wordLength;
      } else {
        lines += 1;
        lines += Math.floor(wordLength / charsPerLine);
        current = wordLength % charsPerLine;
      }
    }
    if (current > 0) lines += 1;
  }

  return Math.max(1, lines);
}

function estimateTextHeight(el) {
  const style = el.style ?? {};
  const fontSize = style.fontSize ?? 11;
  const lineHeight = style.lineHeight ?? 1.5;
  const lines = estimateWrappedLines(el.content, el.width, fontSize);
  if (lines <= 1) return el.height;
  return Math.max(el.height, lines * fontSize * lineHeight + 4);
}

function normalizeElementSize(el) {
  if (el.type === 'text') return { ...el, height: estimateTextHeight(el) };
  return { ...el };
}

function applyAutoFlow(elements, changedId) {
  let next = [...elements];
  const changed = next.find(el => el.id === changedId);
  if (!changed) return next;

  const changedMidY = changed.y + changed.height / 2;
  const candidates = next
    .filter(el =>
      el.id !== changedId &&
      !el.locked &&
      el.y + el.height / 2 >= changedMidY - FLOW_GAP)
    .sort((a, b) => (a.y - b.y) || (a.x - b.x));

  let cursor = changed.y + changed.height + FLOW_GAP;
  for (const el of candidates) {
    if (el.y < cursor) {
      const idx = next.findIndex(candidate => candidate.id === el.id);
      if (idx !== -1) {
        next[idx] = { ...next[idx], y: cursor };
        cursor = next[idx].y + next[idx].height + FLOW_GAP;
      }
    } else {
      cursor = el.y + el.height + FLOW_GAP;
    }
  }

  return next;
}

export function normalizeTemplateLayoutForRender(elements, pageSize) {
  let next = (elements ?? []).map(el => ({ ...el }));
  const ordered = [...next].sort((a, b) => (a.y - b.y) || (a.x - b.x));

  for (const original of ordered) {
    const idx = next.findIndex(el => el.id === original.id);
    if (idx === -1) continue;
    const before = next[idx];
    const after = normalizeElementSize(before);
    if (after.height === before.height) continue;
    next = [...next];
    next[idx] = after;
    next = applyAutoFlow(next, after.id);
  }

  return {
    elements: next,
    pageSize: { ...pageSize, height: 842 },
  };
}
