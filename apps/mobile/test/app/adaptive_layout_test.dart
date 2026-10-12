import 'package:electra_mobile/app/adaptive_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('classifies exact responsive boundaries', () {
    expect(
      ElectraBreakpoints.fromWidth(699),
      ElectraSizeClass.compact,
    );
    expect(
      ElectraBreakpoints.fromWidth(700),
      ElectraSizeClass.medium,
    );
    expect(
      ElectraBreakpoints.fromWidth(1099),
      ElectraSizeClass.medium,
    );
    expect(
      ElectraBreakpoints.fromWidth(1100),
      ElectraSizeClass.expanded,
    );
  });

  for (final width in <double>[390, 834, 1440]) {
    testWidgets('renders adaptive builder at width $width', (tester) async {
      ElectraSizeClass? captured;
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: width,
              height: 600,
              child: ElectraAdaptiveBuilder(
                builder: (context, layout) {
                  captured = layout.sizeClass;
                  return Text(layout.sizeClass.name);
                },
              ),
            ),
          ),
        ),
      );

      expect(captured, ElectraBreakpoints.fromWidth(width));
      expect(find.text(captured!.name), findsOneWidget);
    });
  }
}
