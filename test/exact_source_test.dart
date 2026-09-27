import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const options = CodeLineOptions(
    preserveLineBreaks: true,
    lineBreak: TextLineBreak.crlf,
  );
  CodeLineEditingController create(String source) {
    final result = CodeLineEditingController.fromText(source, options);
    addTearDown(result.dispose);
    return result;
  }

  void exact(CodeLineEditingController controller, String source) {
    expect(utf8.encode(controller.text), utf8.encode(source));
  }

  test('exact load, selected copy source and synchronous replacement', () {
    for (final source in [
      '',
      'invalid Go {',
      'a\r\nb\rc\n',
      '\r\n\r\n',
      '\t😀\r\n\t中\r',
      'x' * 65536,
    ]) {
      final controller = create(source);
      exact(controller, source);
      controller.selectAll();
      expect(controller.selectedText, source);
      var observed = '';
      controller.addListener(() => observed = controller.text);
      controller.replaceSelection('new\r\nsource\r\n');
      expect(observed, 'new\r\nsource\r\n');
      controller.undo();
      exact(controller, source);
      controller.redo();
      exact(controller, 'new\r\nsource\r\n');
    }
  });

  test('newline-only edits have distinct history values', () {
    final controller = create('a\nb\n');
    controller.selectAll();
    controller.replaceSelection('a\r\nb\r');
    exact(controller, 'a\r\nb\r');
    controller.undo();
    exact(controller, 'a\nb\n');
    controller.redo();
    exact(controller, 'a\r\nb\r');
  });

  test('selection and folding neither create history nor discard redo', () {
    final controller = create('a\r\nb\rc\n');
    controller.selection = const CodeLineSelection.collapsed(index: 0, offset: 1);
    expect(controller.canUndo, isFalse);
    controller.collapseChunk(1, 3);
    expect(controller.canUndo, isFalse);
    controller.replaceSelection('X');
    controller.undo();
    exact(controller, 'a\r\nb\rc\n');
    controller.selection = const CodeLineSelection.collapsed(index: 0, offset: 0);
    controller.expandChunk(1);
    expect(controller.canRedo, isTrue);
    controller.redo();
    exact(controller, 'aX\r\nb\rc\n');
  });

  test('nested folds retain source and copied complete selection', () {
    const source = '{\r\n {\r  x\n }\r\n}\nend';
    final controller = create(source);
    controller.collapseChunk(1, 4);
    controller.collapseChunk(0, 3);
    exact(controller, source);
    controller.selectAll();
    expect(controller.selectedText, source);
    controller.expandChunk(0);
    controller.expandChunk(1);
    exact(controller, source);
  });

  test('fold reaching document end is included in select all', () {
    const source = '{\r\n x\r}\n';
    final controller = create(source);
    controller.collapseChunk(0, controller.codeLines.length);
    controller.selectAll();
    expect(controller.selectedText, source);
  });

  test('new line uses selected convention while preserving other separators',
      () {
    final controller = create('ab\rcd\nef');
    controller.selection =
        const CodeLineSelection.collapsed(index: 0, offset: 1);
    controller.applyNewLine();
    exact(controller, 'a\r\nb\rcd\nef');
    controller.undo();
    exact(controller, 'ab\rcd\nef');
  });

  test('joins retain following separator and undo restores removed separator',
      () {
    final controller = create('ab\rcd\nef');
    controller.selection =
        const CodeLineSelection.collapsed(index: 1, offset: 0);
    controller.deleteBackward();
    exact(controller, 'abcd\nef');
    controller.undo();
    exact(controller, 'ab\rcd\nef');
    controller.selection =
        const CodeLineSelection.collapsed(index: 0, offset: 2);
    controller.deleteForward();
    exact(controller, 'abcd\nef');
    controller.undo();
    exact(controller, 'ab\rcd\nef');
  });

  test('indent, outdent and replace all preserve mixed separators', () {
    const source = 'ab\rcd\nef\r\n';
    final controller = create(source);
    controller.selectAll();
    controller.applyIndent();
    exact(controller, '  ab\r  cd\n  ef\r\n');
    controller.applyOutdent();
    exact(controller, source);
    controller.replaceAll(RegExp('[ace]'), 'XX');
    exact(controller, 'XXb\rXXd\nXXf\r\n');
    controller.undo();
    exact(controller, source);
  });

  test('IME edits retain separators outside composition', () {
    final controller = create('ab\rcd\nef');
    controller.selection =
        const CodeLineSelection.collapsed(index: 1, offset: 1);
    controller.edit(const TextEditingValue(
      text: 'c中d',
      selection: TextSelection.collapsed(offset: 2),
      composing: TextRange(start: 1, end: 2),
    ));
    exact(controller, 'ab\rc中d\nef');
    expect(controller.isComposing, isTrue);
    controller.clearComposing();
    exact(controller, 'ab\rc中d\nef');
  });

  test('one engine transaction undoes multiple replacements', () {
    const source = 'ab\rcd\nef';
    final controller = create(source);
    controller.runRevocableOp(() {
      controller.replaceSelection(
          'X',
          const CodeLineSelection(
            baseIndex: 2,
            baseOffset: 0,
            extentIndex: 2,
            extentOffset: 1,
          ));
      controller.replaceSelection(
          'Y',
          const CodeLineSelection(
            baseIndex: 0,
            baseOffset: 0,
            extentIndex: 0,
            extentOffset: 1,
          ));
    });
    exact(controller, 'Yb\rcd\nXf');
    controller.undo();
    exact(controller, source);
  });

  test('random range edits match raw source and undo exactly', () {
    final random = Random(1290);
    final controller = create('a\r\nb\rc\n😀');
    const replacements = ['', 'X', '\r', '\n', '\r\n', 'a\r\nb\rc\n'];
    for (var iteration = 0; iteration < 250; iteration++) {
      final before = controller.text;
      final lines = controller.codeLines.toList();
      final start = random.nextInt(lines.length);
      final end = start + random.nextInt(lines.length - start);
      // Line boundaries avoid splitting UTF-16 surrogate pairs.
      final startOffset = random.nextBool() ? 0 : lines[start].length;
      final endOffset = end == start
          ? lines[end].length
          : (random.nextBool() ? 0 : lines[end].length);
      int rawOffset(int index, int offset) {
        for (var i = 0; i < index; i++) {
          offset += lines[i].length +
              (lines[i].sourceLineBreak ?? options.lineBreak).value.length;
        }
        return offset;
      }

      final replacement = replacements[random.nextInt(replacements.length)];
      final expected = before.replaceRange(
        rawOffset(start, startOffset),
        rawOffset(end, endOffset),
        replacement,
      );
      controller.selection = CodeLineSelection(
        baseIndex: start,
        baseOffset: startOffset,
        extentIndex: end,
        extentOffset: endOffset,
      );
      controller.replaceSelection(replacement);
      exact(controller, expected);
      if (before != expected) {
        controller.undo();
        exact(controller, before);
        controller.redo();
        exact(controller, expected);
      }
    }
  });

  test('system clipboard copy and paste retain separators', () async {
    String? clipboard;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboard = (call.arguments as Map)['text'] as String;
      }
      if (call.method == 'Clipboard.getData') {
        return {'text': clipboard};
      }
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    const source = 'a\r\nb\rc\n';
    final first = create(source)..selectAll();
    await first.copy();
    expect(clipboard, source);
    final second = create('');
    second.paste();
    await Future<void>.delayed(Duration.zero);
    exact(second, source);
    second.undo();
    exact(second, '');
  });
}
