import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final extend in [false, true]) {
    test('word navigation direction and trailing whitespace: extend=$extend',
        () {
      final engine = CodeLineEditingController.fromText(
        'first\r\nword next   ',
        const CodeLineOptions(preserveLineBreaks: true),
      );
      addTearDown(engine.dispose);
      engine.selection = const CodeLineSelection.collapsed(index: 1, offset: 0);
      void forward() => extend
          ? engine.extendSelectionToWordBoundaryForward()
          : engine.moveCursorToWordBoundaryForward();
      forward();
      expect(engine.selection.extentOffset, 4);
      expect(engine.selection.baseOffset, extend ? 0 : 4);
      forward();
      expect(engine.selection.extentOffset, 9);
      forward();
      expect(engine.selection.extentOffset, 12);
      forward();
      expect(engine.selection.extentOffset, 12);
      extend
          ? engine.extendSelectionToWordBoundaryBackward()
          : engine.moveCursorToWordBoundaryBackward();
      expect(engine.selection.extentOffset, 5);
      expect(engine.selection.baseOffset, extend ? 0 : 5);
      expect(engine.text, 'first\r\nword next   ');
      expect(engine.canUndo, isFalse);
    });
  }
}
