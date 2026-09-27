import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';

void main() {
  testWidgets('immediate detach cancels pending focus and caret retries',
      (tester) async {
    for (var cycle = 0; cycle < 20; cycle++) {
      final controller = CodeLineEditingController.fromText('short');
      final scroll = CodeScrollController();
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: CodeEditor(
        controller: controller,
        scrollController: scroll,
      ))));
      await tester.tap(find.byType(CodeEditor));
      controller.selectAll();
      final editing = tester.testTextInput.editingState!;
      final client = (tester.testTextInput.log
              .lastWhere(
                (call) => call.method == 'TextInput.setClient',
              )
              .arguments as List)
          .first;
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        SystemChannels.textInput.name,
        const JSONMethodCodec().encodeMethodCall(MethodCall(
          'TextInputClient.updateEditingStateWithDeltas',
          [
            client,
            {
              'deltas': [
                {
                  'oldText': editing['text'],
                  'deltaText': 'replacement',
                  'deltaStart': editing['selectionBase'],
                  'deltaEnd': editing['selectionExtent'],
                  'selectionBase': 11,
                  'selectionExtent': 11,
                  'selectionAffinity': 'TextAffinity.downstream',
                  'selectionIsDirectional': false,
                  'composingBase': -1,
                  'composingExtent': -1,
                }
              ]
            }
          ],
        )),
        (_) {},
      );
      expect(controller.text, 'replacement');
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      scroll.dispose();
      scroll.verticalScroller.dispose();
      scroll.horizontalScroller.dispose();
      expect(tester.takeException(), isNull);
    }
    // The widget-test invariant rejects pending timers after this returns.
  }, variant: TargetPlatformVariant.desktop());
}
