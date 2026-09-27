import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/languages/go.dart';

void main() {
  testWidgets('web analysis follows latest source and cancels on detach',
      (tester) async {
    final controller = CodeLineEditingController.fromText(
      'func first() {\n\tprintln(1)\n}\n',
      const CodeLineOptions(preserveLineBreaks: true),
    );
    CodeChunkController? chunks;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: CodeEditor(
      controller: controller,
      style: CodeEditorStyle(
          codeTheme: CodeHighlightTheme(
        languages: {'go': CodeHighlightThemeMode(mode: langGo)},
        theme: const {},
      )),
      indicatorBuilder: (context, editing, value, notifier) {
        chunks = value;
        return const SizedBox(width: 20);
      },
    ))));
    controller.text = 'func stale() {\n\tprintln(2)\n}\n';
    controller.text = 'package latest\n';
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(chunks!.value, isEmpty);
    controller.text = 'func latest() {\n\tprintln(3)\n}\n';
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(chunks!.value, isNotEmpty);
    controller.text = 'func pending() {\n\tprintln(4)\n}\n';
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    expect(tester.takeException(), isNull);
  }, skip: !kIsWeb);
}
