import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:near_field/theme/nothing_theme.dart';
import 'package:near_field/widgets/near_field_mark.dart';

Widget _host(Widget child, {double width = 400}) => MaterialApp(
  theme: NothingTheme.light,
  home: Scaffold(
    body: Center(
      child: SizedBox(
        width: width,
        child: Center(child: child),
      ),
    ),
  ),
);

void main() {
  group('NearFieldMark', () {
    for (final size in <double>[24, 48, 96, 160]) {
      testWidgets('renders at ${size.toInt()}dp without error', (tester) async {
        await tester.pumpWidget(_host(NearFieldMark(size: size)));
        expect(tester.takeException(), isNull);

        final box = tester.getSize(find.byType(NearFieldMark));
        expect(box.width, size);
        expect(box.height, size);
      });
    }

    testWidgets('exposes a single image semantics label', (tester) async {
      await tester.pumpWidget(_host(const NearFieldMark(size: 96)));
      final handle = tester.ensureSemantics();
      expect(find.bySemanticsLabel('Near Field'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('dark and monochrome variants paint cleanly', (tester) async {
      await tester.pumpWidget(
        _host(
          const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              NearFieldMark(size: 72, onDark: true),
              NearFieldMark(size: 72, monochrome: true),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('NearFieldStackedWordmark', () {
    testWidgets('renders and keeps a stable aspect ratio', (tester) async {
      await tester.pumpWidget(
        _host(const NearFieldStackedWordmark(width: 148)),
      );
      expect(tester.takeException(), isNull);

      final box = tester.getSize(find.byType(NearFieldStackedWordmark));
      expect(box.width, 148);
      expect(box.height, closeTo(148 * (236 / 216), 0.01));
    });

    testWidgets('fits inside a 320px screen with surrounding copy', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _host(
          const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              NearFieldStackedWordmark(width: 148),
              SizedBox(height: 16),
              Text('NO ALARMS YET'),
            ],
          ),
          width: 300,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('carries a brand semantics label', (tester) async {
      await tester.pumpWidget(const _WordmarkHost());
      final handle = tester.ensureSemantics();
      expect(find.bySemanticsLabel('Near Field'), findsOneWidget);
      handle.dispose();
    });
  });
}

class _WordmarkHost extends StatelessWidget {
  const _WordmarkHost();

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: NothingTheme.light,
    home: const Scaffold(
      body: Center(child: NearFieldStackedWordmark(width: 160)),
    ),
  );
}
