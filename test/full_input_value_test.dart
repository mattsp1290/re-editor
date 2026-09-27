import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';

void main() {
  testWidgets('full input values preserve multiline selection and exact undo',
      (tester) async {
    const original = 'main\r\nnext\rend\n';
    final controller = CodeLineEditingController.fromText(
        original, const CodeLineOptions(preserveLineBreaks: true));
    final focus = FocusNode();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: CodeEditor(
      controller: controller,
      focusNode: focus,
    ))));
    focus.requestFocus();
    await tester.pump();
    final client = (tester.testTextInput.log
            .lastWhere((call) => call.method == 'TextInput.setClient')
            .arguments as List)
        .first;
    Future<void> update(String text, int caret,
            {TextRange composing = TextRange.empty}) =>
        tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          SystemChannels.textInput.name,
          const JSONMethodCodec().encodeMethodCall(MethodCall(
            'TextInputClient.updateEditingState',
            [
              client,
              TextEditingValue(
                text: text,
                selection: TextSelection.collapsed(offset: caret),
                composing: composing,
              ).toJSON()
            ],
          )),
          (_) {},
        );
    controller.selectAll();
    await update('main', 1);
    expect(controller.text, original);
    expect(controller.isAllSelected, isTrue);
    await update('p', 1);
    expect(controller.text, 'p');
    await update('pa', 2);
    expect(controller.text, 'pa');
    await update('pa(', 3);
    expect(controller.text, 'pa()');
    controller.undo();
    expect(controller.text, 'p');
    controller.undo();
    expect(controller.text, original);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    focus.dispose();
    expect(tester.takeException(), isNull);
  }, variant: const TargetPlatformVariant({TargetPlatform.linux}));

  testWidgets(
      'full input composition and deletion use the existing delta pipeline',
      (tester) async {
    final controller = CodeLineEditingController.fromText(
        'package ', const CodeLineOptions(preserveLineBreaks: true));
    final focus = FocusNode();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: CodeEditor(
      controller: controller,
      focusNode: focus,
    ))));
    focus.requestFocus();
    await tester.pump();
    controller.selection =
        const CodeLineSelection.collapsed(index: 0, offset: 8);
    Future<void> update(String text, int caret, TextRange composing) async {
      tester.testTextInput.updateEditingValue(TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: caret),
          composing: composing));
      await tester.pump();
    }

    await update('package 中', 9, const TextRange(start: 8, end: 9));
    expect(controller.text, 'package 中');
    expect(controller.isComposing, isTrue);
    await update('package 中文', 10, TextRange.empty);
    expect(controller.text, 'package 中文');
    expect(controller.isComposing, isFalse);
    await update('package 中', 9, TextRange.empty);
    expect(controller.text, 'package 中');
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    focus.dispose();
    expect(tester.takeException(), isNull);
  }, variant: const TargetPlatformVariant({TargetPlatform.linux}));
}
