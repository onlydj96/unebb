import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:unebb/shared/widgets/phase_switcher.dart';

int _inits = 0;
int _taps = 0;

class _Phase extends StatefulWidget {
  const _Phase(this.label, {super.key});
  final String label;

  @override
  State<_Phase> createState() => _PhaseState();
}

class _PhaseState extends State<_Phase> {
  @override
  void initState() {
    super.initState();
    _inits++;
  }

  // Phases put their button in different corners so a tap can only reach
  // the intended one.
  @override
  Widget build(BuildContext context) => Align(
        alignment:
            widget.label == 'first' ? Alignment.topLeft : Alignment.bottomRight,
        child: TextButton(
          onPressed: () => _taps++,
          child: Text(widget.label),
        ),
      );
}

Widget _app(String phase) => MaterialApp(
      home: Scaffold(
        body: PhaseSwitcher(child: _Phase(phase, key: ValueKey(phase))),
      ),
    );

void main() {
  setUp(() {
    _inits = 0;
    _taps = 0;
  });

  testWidgets('switching phases does not remount the outgoing view',
      (tester) async {
    await tester.pumpWidget(_app('first'));
    expect(_inits, 1);

    await tester.pumpWidget(_app('second'));
    await tester.pump(const Duration(milliseconds: 100));

    // Only the new phase was created; "first" kept its state while fading.
    expect(_inits, 2);
    expect(find.text('first'), findsOneWidget);
  });

  testWidgets('the outgoing view ignores taps while it fades out',
      (tester) async {
    await tester.pumpWidget(_app('first'));
    await tester.pumpWidget(_app('second'));
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.text('first'), warnIfMissed: false);
    expect(_taps, 0);

    await tester.tap(find.text('second'));
    expect(_taps, 1);
  });
}
