part of re_editor;

// Exact separators can join across any mutation, including Enter, deletion,
// IME input and range replacement. Canonicalize before history/listeners see
// the value so source coordinates never observe a phantom line inside CRLF.
CodeLineEditingValue _canonicalExactValue(
    CodeLineEditingValue value, TextLineBreak fallback) {
  bool previousCr = false;
  bool ambiguous = false;
  int visited = 0;
  final int count = value.codeLines.lineCount;
  void inspect(CodeLine line) {
    if (ambiguous) return;
    final TextLineBreak separator = line.sourceLineBreak ?? fallback;
    if (previousCr &&
        line.text.isEmpty &&
        separator == TextLineBreak.lf &&
        visited < count - 1) {
      ambiguous = true;
      return;
    }
    previousCr = separator == TextLineBreak.cr;
    visited++;
    for (final CodeLine child in line.chunks) {
      inspect(child);
    }
  }

  for (int i = 0; i < value.codeLines.length; i++) {
    inspect(value.codeLines[i]);
    if (ambiguous) break;
  }
  if (!ambiguous) return value;

  int sourceLength(CodeLine line) =>
      line.asString(0, fallback, true).length +
      line.trailingLineBreak(fallback).value.length;
  int rawOffset(int index, int offset) {
    for (int i = 0; i < index; i++) {
      offset += sourceLength(value.codeLines[i]);
    }
    return offset;
  }

  final String source = value.codeLines.asString(fallback, true, true);
  final CodeLines lines = CodeLines.fromText(source, preserveLineBreaks: true);
  MapEntry<int, int> positionAt(int offset) {
    if (offset > 0 &&
        offset < source.length &&
        source.codeUnitAt(offset - 1) == 13 &&
        source.codeUnitAt(offset) == 10) {
      offset++;
    }
    int index = 0;
    while (index < lines.length - 1 && offset > lines[index].length) {
      offset -= sourceLength(lines[index]);
      index++;
    }
    return MapEntry(index, offset);
  }

  final CodeLineSelection oldSelection = value.selection;
  final MapEntry<int, int> base =
      positionAt(rawOffset(oldSelection.baseIndex, oldSelection.baseOffset));
  final MapEntry<int, int> extent = positionAt(
      rawOffset(oldSelection.extentIndex, oldSelection.extentOffset));
  TextRange composing = value.composing;
  if (composing.isValid) {
    int newBaseStart = 0;
    for (int i = 0; i < base.key; i++) {
      newBaseStart += sourceLength(lines[i]);
    }
    final int delta = rawOffset(oldSelection.baseIndex, 0) - newBaseStart;
    composing =
        TextRange(start: composing.start + delta, end: composing.end + delta);
  }
  return value.copyWith(
    codeLines: lines,
    selection: oldSelection.copyWith(
        baseIndex: base.key,
        baseOffset: base.value,
        extentIndex: extent.key,
        extentOffset: extent.value),
    composing: composing,
  );
}
