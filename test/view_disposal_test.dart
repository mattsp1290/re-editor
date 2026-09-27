import 'package:flutter/material.dart';
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
      controller.replaceSelection('a longer replacement');
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      scroll.dispose();
      scroll.verticalScroller.dispose();
      scroll.horizontalScroller.dispose();
      expect(tester.takeException(), isNull);
    }
    // The widget-test invariant rejects pending timers after this returns.
  }, variant: TargetPlatformVariant({TargetPlatform.linux}));
}
