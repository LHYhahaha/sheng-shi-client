String limitTextLines(String text, int maxLines, {String? overText}) {
  final lines = text.split('\n');

  if (lines.length <= maxLines) return text;

  final visibleLines = lines.take(maxLines).toList();
  if (overText != null) {
    visibleLines[maxLines - 1] = '${visibleLines.last}$overText';
  } else {
    visibleLines[maxLines - 1] = '${visibleLines.last}…';
  }
  return visibleLines.join('\n');
}
