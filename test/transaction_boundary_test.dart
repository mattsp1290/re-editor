import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final scenario in ['plain', 'nested', 'noop', 'composing']) {
    test('exact transaction seals later typing: $scenario', () {
      const tail = '\r\nend\rlast\n';
      final engine = CodeLineEditingController.fromText(
        'ab$tail',
        const CodeLineOptions(preserveLineBreaks: true),
      );
      addTearDown(engine.dispose);
      void input(String line, {TextRange composing = TextRange.empty}) {
        engine.edit(TextEditingValue(
          text: line,
          selection: TextSelection.collapsed(offset: line.length),
          composing: composing,
        ));
      }

      input('abc');
      engine.runRevocableOp(() {
        engine.replaceSelection(
            'B',
            const CodeLineSelection(
              baseIndex: 0,
              baseOffset: 1,
              extentIndex: 0,
              extentOffset: 2,
            ));
        if (scenario == 'nested') {
          engine.runRevocableOp(() => engine.replaceSelection(
                'C',
                const CodeLineSelection(
                  baseIndex: 0,
                  baseOffset: 2,
                  extentIndex: 0,
                  extentOffset: 3,
                ),
              ));
        }
      });
      final command = scenario == 'nested' ? 'aBC' : 'aBc';
      expect(engine.text, '$command$tail');
      if (scenario == 'noop') engine.runRevocableOp(() {});
      input('${command}x',
          composing: scenario == 'composing'
              ? const TextRange(start: 3, end: 4)
              : TextRange.empty);
      if (scenario == 'composing') input('${command}x');
      engine.undo();
      expect(engine.text, '$command$tail');
      engine.undo();
      expect(engine.text, 'abc$tail');
      engine.undo();
      expect(engine.text, 'ab$tail');
      engine.redo();
      engine.redo();
      engine.redo();
      expect(engine.text, '${command}x$tail');
      engine.undo();
      input('${command}y');
      expect(engine.canRedo, isFalse);
      engine.undo();
      expect(engine.text, '$command$tail');
    });
  }
}
