import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unebb/domain/models/memory_reading.dart';
import 'package:unebb/shared/widgets/memory_indicator.dart';

import '../helpers/test_app.dart';

void main() {
  group('percentOf', () {
    test('rounds down, so a level shows only once it is reached', () {
      expect(MemoryIndicator.percentOf(0.7999), 79); // good, not "80%"
      expect(MemoryIndicator.percentOf(0.80), 80);
      expect(MemoryIndicator.percentOf(0.5999), 59);
      expect(MemoryIndicator.percentOf(0.60), 60);
      expect(MemoryIndicator.percentOf(0.30), 30);
      expect(MemoryIndicator.percentOf(0.70), 70);
    });

    test('is clamped to 0–100', () {
      expect(MemoryIndicator.percentOf(-0.1), 0);
      expect(MemoryIndicator.percentOf(1.2), 100);
    });
  });

  testWidgets('shows the level and percent', (tester) async {
    await tester.pumpWidget(await testApp(const Scaffold(
      body: MemoryIndicator(
        reading: MemoryReading(MemoryLevel.good, 0.7999),
        showLabel: true,
      ),
    )));
    await tester.pump();

    expect(find.text('Good'), findsOneWidget);
    expect(find.text('79%'), findsOneWidget);
  });

  testWidgets('a word still being learnt shows no percent', (tester) async {
    await tester.pumpWidget(await testApp(const Scaffold(
      body: MemoryIndicator(
        reading: MemoryReading(MemoryLevel.learning, 0.0),
        showLabel: true,
      ),
    )));
    await tester.pump();

    expect(find.text('Learning'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets('the review delta uses the same percents', (tester) async {
    await tester.pumpWidget(await testApp(const Scaffold(
      body: MemoryStrengthDelta(previous: 0.0, updated: 0.7),
    )));
    await tester.pump();

    expect(find.text('0% → 70%'), findsOneWidget);
    expect(find.text('↑70%'), findsOneWidget);
  });
}
