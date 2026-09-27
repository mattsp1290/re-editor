# Birb exact-source patch

Owner: Matt Spurlin (`mattsp1290/re-editor`), for flutter-foundation's native
editor qualification. Based on upstream re_editor 0.10.0 commit
`0a2a7d832011431d123b1b9391a481171cb4b849`. Its `lib/` directory matches the
publisher archive SHA-256
`66671c4774a6b4c5254c9a53ab35a083e7e7da9ae371c519bcf491c70a2a4e56`.
Keep the upstream MIT LICENSE and dependency licenses when distributing.

## Scope

`CodeLineOptions(preserveLineBreaks: true)` retains LF, CR and CRLF in loaded and
inserted source. `lineBreak` still selects separators for the Enter command.
The default remains upstream normalization. Direct construction from exact
source uses `CodeLines.fromText(source, preserveLineBreaks: true)`.

Each existing CodeLine carries optional separator metadata. Parsing, text and
selection serialization, clipboard, range replacement, joins, indentation and
folds preserve it. The existing engine history stores it as part of value
equality, including newline-only changes. Rendering/highlighting can continue
to request normalized line text; no renderer or input stack is replaced.

Related fixes satisfy qualification and controller probes:

- Nested `runRevocableOp` calls share one undo record, including the first
  operation in an empty history; exception cleanup restores transaction state.
- Exact-source mode keeps selection and folding changes in the current history
  node without creating undo entries or discarding redo after navigation.
- All exact-source value mutations check for CR and LF joining into one logical
  separator before history or listeners observe the result. This uncommon case
  reparses the source, expands folds and moves a caret inside the new CRLF to
  its end; undo restores the prior value, including folds and selection.
  Selection-only values sharing the existing line collection skip this check.
- Select-all expands a fold at the document tail so its contents are included.
- Exact-source web input accepts full editing values and translates them into
  the existing delta/pairing/composition pipeline. Flutter 3.47.1's semantic
  web text field omits `beforeinput`, so delta mode reports text edits as
  selection-only changes when accessibility is enabled. Native input retains
  delta mode. Selection-only platform messages must not replace a multiline
  selection with the unchanged base-line text. `full_input_value_test.dart`
  covers replacement, pairing, composition, deletion and exact undo.
- Forward delete between paired delimiters uses the existing paired backward
  delete operation. Upstream's own `deleteForward()` test fails without this
  correction on the selected SDK, including in a pristine baseline checkout.

Pending focus, drag-scroll, autocomplete, cursor-start and caret-position retry timers are cancelled when
their view/input owner is disposed. `view_disposal_test.dart` exercises twenty
immediate mount/edit/detach cycles without draining timers to hide leaks.

No private APIs are exposed. Public consumers should encapsulate engine types.
This patch alone does not qualify a complete editor: geometry, rendering,
worker lifecycle, real browser/native input and the full Foundation W1 matrix
remain separate gates.

## Verification and upgrades

Use Flutter 3.47.1 and bundled Dart 3.13.1. `flutter test` passes 160 tests,
including thirteen exact-source regressions in `test/exact_source_test.dart`
and two keyboard-command separator-join regressions in `test/exact_command_seams_test.dart`.
They cover UTF-8 equality, 64 KiB source load, mixed separators, synchronous
observation, copy/paste channel roundtrip, composing state, folds, command
mutations, multi-edit undo and 250 deterministic randomized range edits.
Clipboard and IME tests are framework-level probes, not physical OS evidence.

`flutter analyze --no-pub` reports upstream deprecations, missing override and
unused debug declarations; it is not a passing analysis gate. No warning
suppression is added by this patch. Foundation separately analyzes its package.

Pin a full pushed fork SHA in consumers without dependency overrides. Before
upgrading, compare all patched source files and the added `_code_line_exact.dart` helper with the upstream release,
run all upstream and exact-source tests, then rerun Foundation's entire W1 and
platform acceptance matrix. Remove the patch only when the replacement
upstream release passes those same requirements. Do not claim source fidelity
from normalized-text comparisons or drop mixed-separator tests to upgrade.
