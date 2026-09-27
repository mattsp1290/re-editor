import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'Enter with CR convention does not split a resulting CRLF into two logical lines',
      () {
    final controller = CodeLineEditingController.fromText(
        'x\ra\n\nb',
        const CodeLineOptions(
            preserveLineBreaks: true, lineBreak: TextLineBreak.cr));
    addTearDown(controller.dispose);
    controller.selection =
        const CodeLineSelection.collapsed(index: 2, offset: 0);
    controller.applyNewLine();
    expect(controller.text, 'x\ra\n\r\nb');
    expect(controller.lineCount, 4);
    expect(controller.selection,
        const CodeLineSelection.collapsed(index: 3, offset: 0));
    controller.undo();
    expect(controller.text, 'x\ra\n\nb');
  });

  test('deletion that joins CR and LF preserves canonical logical positions',
      () {
    final controller = CodeLineEditingController.fromText(
        'x\ra\nb', const CodeLineOptions(preserveLineBreaks: true));
    addTearDown(controller.dispose);
    controller.selection = const CodeLineSelection(
        baseIndex: 1, baseOffset: 0, extentIndex: 1, extentOffset: 1);
    controller.deleteSelection();
    expect(controller.text, 'x\r\nb');
    expect(controller.lineCount, 2);
    expect(controller.selection,
        const CodeLineSelection.collapsed(index: 1, offset: 0));
    controller.undo();
    expect(controller.text, 'x\ra\nb');
  });
}
