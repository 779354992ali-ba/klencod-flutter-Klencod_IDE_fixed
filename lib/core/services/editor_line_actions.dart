import 'package:flutter/services.dart';

class EditorLineEditResult {
  final String text;
  final TextSelection selection;

  const EditorLineEditResult({required this.text, required this.selection});
}

/// Pure text operations used by the editor's line-action toolbar.
class EditorLineActions {
  const EditorLineActions._();

  static EditorLineEditResult? duplicateSelectedLines({
    required String text,
    required TextSelection selection,
  }) {
    if (!selection.isValid) return null;
    final lines = text.split('\n');
    final start = _lineForOffset(text, selection.start);
    var end = _lineForOffset(text, selection.end);
    if (selection.end > selection.start &&
        selection.end <= text.length &&
        text.substring(0, selection.end).endsWith('\n')) {
      end--;
    }
    end = end.clamp(start, lines.length - 1).toInt();
    final copies = lines.sublist(start, end + 1);
    lines.insertAll(end + 1, copies);
    final newText = lines.join('\n');
    final newStart = _offsetForLine(lines, start + copies.length);
    final newEnd = _offsetForLine(lines, start + copies.length + copies.length);
    final boundedEnd = newEnd.clamp(newStart, newText.length).toInt();
    return EditorLineEditResult(
      text: newText,
      selection: TextSelection(baseOffset: newStart, extentOffset: boundedEnd),
    );
  }

  static EditorLineEditResult? moveCurrentLine({
    required String text,
    required TextSelection selection,
    required bool down,
  }) {
    if (!selection.isValid) return null;
    final lines = text.split('\n');
    final line = _lineForOffset(text, selection.extentOffset);
    final target = down ? line + 1 : line - 1;
    if (target < 0 || target >= lines.length) return null;
    final column = selection.extentOffset - _offsetForLine(lines, line);
    final targetColumn = column.clamp(0, lines[target].length).toInt();
    final current = lines[line];
    lines[line] = lines[target];
    lines[target] = current;
    final newOffset = (_offsetForLine(lines, target) + targetColumn)
        .clamp(0, text.length)
        .toInt();
    final updatedText = lines.join('\n');
    final safeOffset = newOffset.clamp(0, updatedText.length).toInt();
    return EditorLineEditResult(
      text: updatedText,
      selection: TextSelection.collapsed(offset: safeOffset),
    );
  }

  static EditorLineEditResult? toggleLineComments({
    required String text,
    required TextSelection selection,
    required String language,
  }) {
    if (!selection.isValid || text.isEmpty) return null;
    final style = _commentStyle(language);
    if (style == null) return null;
    final prefix = style.$1;
    final suffix = style.$2;
    final lines = text.split('\n');
    final start = _lineForOffset(text, selection.start);
    var end = _lineForOffset(text, selection.end);
    if (selection.end > selection.start &&
        selection.end <= text.length &&
        text.substring(0, selection.end).endsWith('\n')) {
      end--;
    }
    end = end.clamp(start, lines.length - 1).toInt();
    final selected = lines.sublist(start, end + 1);
    final nonEmpty = selected.where((line) => line.trim().isNotEmpty);
    if (nonEmpty.isEmpty) return null;
    final remove = nonEmpty.every((line) =>
        line.trimLeft().startsWith(prefix) &&
        (suffix.isEmpty || line.trimRight().endsWith(suffix)));
    var deltaAtStart = 0;
    var deltaThroughEnd = 0;
    for (var i = start; i <= end; i++) {
      final line = lines[i];
      final leading = line.length - line.trimLeft().length;
      if (line.trim().isEmpty) continue;
      if (remove) {
        final commentAt = line.indexOf(prefix, leading);
        var updatedLine = line.replaceRange(commentAt, commentAt + prefix.length, '');
        var removed = prefix.length;
        if (updatedLine.startsWith(' ', commentAt)) {
          updatedLine = updatedLine.replaceRange(commentAt, commentAt + 1, '');
          removed++;
        }
        if (suffix.isNotEmpty) {
          final suffixAt = updatedLine.lastIndexOf(suffix);
          if (suffixAt >= 0) {
            var removeStart = suffixAt;
            if (removeStart > 0 && updatedLine[removeStart - 1] == ' ') {
              removeStart--;
              removed++;
            }
            updatedLine = updatedLine.replaceRange(removeStart, suffixAt + suffix.length, '');
            removed += suffix.length;
          }
        }
        lines[i] = updatedLine;
        if (i == start &&
            selection.start >= _offsetForLine(lines, i) + commentAt) {
          deltaAtStart -= prefix.length + 1;
        }
        deltaThroughEnd -= removed;
      } else {
        final inserted = suffix.isEmpty ? '$prefix ' : '$prefix ${line.substring(leading)} $suffix';
        lines[i] = suffix.isEmpty
            ? line.replaceRange(leading, leading, inserted)
            : '${line.substring(0, leading)}$inserted';
        final added = suffix.isEmpty ? prefix.length + 1 : prefix.length + suffix.length + 2;
        if (i == start &&
            selection.start >= _offsetForLine(lines, i) + leading) {
          deltaAtStart += prefix.length + 1;
        }
        deltaThroughEnd += added;
      }
    }
    final updated = lines.join('\n');
    final newStart = (selection.start + deltaAtStart).clamp(0, updated.length).toInt();
    final newEnd = selection.isCollapsed
        ? newStart
        : (selection.end + deltaThroughEnd).clamp(0, updated.length).toInt();
    return EditorLineEditResult(
      text: updated,
      selection: TextSelection(
        baseOffset: selection.baseOffset > selection.extentOffset ? newEnd : newStart,
        extentOffset: selection.baseOffset > selection.extentOffset ? newStart : newEnd,
      ),
    );
  }

  static (String, String)? _commentStyle(String language) {
    switch (language.toLowerCase()) {
      case 'python':
      case 'bash':
      case 'yaml':
        return ('#', '');
      case 'html':
      case 'xml':
      case 'markdown':
        return ('<!--', '-->');
      case 'css':
        return ('/*', '*/');
      case 'sql':
        return ('--', '');
      case 'dart':
      case 'javascript':
      case 'typescript':
      case 'java':
      case 'kotlin':
      case 'swift':
      case 'c':
      case 'c++':
      case 'go':
      case 'rust':
      case 'php':
        return ('//', '');
      default:
        return null;
    }
  }

  static int _lineForOffset(String text, int rawOffset) {
    final offset = rawOffset.clamp(0, text.length).toInt();
    return '\n'.allMatches(text.substring(0, offset)).length;
  }

  static int _offsetForLine(List<String> lines, int line) {
    var offset = 0;
    final stop = line.clamp(0, lines.length).toInt();
    for (var i = 0; i < stop; i++) {
      offset += lines[i].length + 1;
    }
    return offset;
  }
}
