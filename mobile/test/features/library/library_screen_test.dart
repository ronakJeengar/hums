import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hums_mobile/features/library/domain/entities/library_summary_entity.dart';
import 'package:hums_mobile/features/library/presentation/providers/library_provider.dart';
import 'package:hums_mobile/features/library/presentation/screens/library_screen.dart';

void main() {
  testWidgets('LibraryScreen renders summary counts and collection tiles',
      (tester) async {
    const summary = LibrarySummaryEntity(
      likedTracksCount: 42,
      playlistsCount: 5,
      followingCreatorsCount: 8,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          librarySummaryProvider.overrideWith((ref) => Future.value(summary)),
        ],
        child: const MaterialApp(
          home: LibraryScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Title & Header
    expect(find.text('My Library'), findsOneWidget);

    // Verify Liked Songs hero card
    expect(find.text('Liked Songs'), findsOneWidget);
    expect(find.text('42 songs'), findsOneWidget);

    // Verify navigation tiles
    expect(find.text('Playlists'), findsOneWidget);
    expect(find.text('5 collections'), findsOneWidget);

    expect(find.text('Downloaded'), findsOneWidget);
    expect(find.text('Offline tracks & episodes'), findsOneWidget);

    expect(find.text('Recently Played'), findsOneWidget);
    expect(find.text('Following'), findsOneWidget);
    expect(find.text('8 artists'), findsOneWidget);
  });

  testWidgets('LibraryScreen renders zero counts when library is empty',
      (tester) async {
    const emptySummary = LibrarySummaryEntity(
      likedTracksCount: 0,
      playlistsCount: 0,
      followingCreatorsCount: 0,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          librarySummaryProvider.overrideWith((ref) => Future.value(emptySummary)),
        ],
        child: const MaterialApp(
          home: LibraryScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('0 songs'), findsOneWidget);
    expect(find.text('0 collections'), findsOneWidget);
    expect(find.text('0 artists'), findsOneWidget);
  });
}
