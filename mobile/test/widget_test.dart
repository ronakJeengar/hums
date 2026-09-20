import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hums_mobile/core/widgets/hums_button.dart';
import 'package:hums_mobile/main.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('HumsApp boots and displays branding on Splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: HumsApp(),
      ),
    );

    // Verify initial splash screen branding
    expect(find.text('Hums'), findsOneWidget);
    expect(find.text('Acoustic Warmth & Audio Clarity'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Advance clock past the splash delay so all pending timers finish
    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    // Verify navigation to LoginScreen completed for unauthenticated user
    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Sign in to your Hums account'), findsOneWidget);
  });

  testWidgets('HumsButton renders label and triggers tap callbacks', (WidgetTester tester) async {
    bool tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: HumsButton(
              label: 'Test Action',
              onPressed: () {
                tapped = true;
              },
            ),
          ),
        ),
      ),
    );

    expect(find.text('Test Action'), findsOneWidget);
    await tester.tap(find.byType(HumsButton));
    await tester.pump();

    expect(tapped, isTrue);
  });
}
