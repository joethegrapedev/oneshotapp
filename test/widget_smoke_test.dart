// Hide the Flutter `Visibility` widget so the model's `Visibility` enum
// (from entry.dart) is unambiguous in this file.
import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:oneshot_journal/core/providers.dart';
import 'package:oneshot_journal/core/theme.dart';
import 'package:oneshot_journal/data/entries_repository.dart';
import 'package:oneshot_journal/data/pool_repository.dart';
import 'package:oneshot_journal/features/crisis/crisis_screen.dart';
import 'package:oneshot_journal/features/journal/journal_screen.dart';
import 'package:oneshot_journal/features/read/read_back_screen.dart';
import 'package:oneshot_journal/models/entry.dart';
import 'package:oneshot_journal/models/served_entry.dart';

class MockEntriesRepository extends Mock implements EntriesRepository {}

class MockPoolRepository extends Mock implements PoolRepository {}

/// Wraps a screen in a plain MaterialApp (NOT MaterialApp.router) so the screen
/// builds standalone; `context.goNamed` is only used in callbacks, never at
/// build time, so no GoRouter is required to pump these.
Widget _host(Widget child, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      theme: AppTheme.light(),
      home: child,
    ),
  );
}

void main() {
  setUpAll(() {
    // Keep tests offline & deterministic — never fetch fonts over the network.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('CrisisScreen builds and shows supportive headline + resources',
      (tester) async {
    await tester.pumpWidget(_host(const CrisisScreen()));
    await tester.pumpAndSettle();

    expect(find.text('You matter. Support is available.'), findsOneWidget);
    // Local fallback resources are rendered.
    expect(find.textContaining('Samaritans of Singapore'), findsOneWidget);
    expect(find.textContaining('995'), findsOneWidget);
    expect(find.text('Back to journal'), findsOneWidget);
  });

  testWidgets('ReadBackScreen shows kind cold-start empty state when pool empty',
      (tester) async {
    final pool = MockPoolRepository();
    when(() => pool.serveOne()).thenAnswer((_) async => null);

    await tester.pumpWidget(
      _host(
        const ReadBackScreen(),
        overrides: [poolRepositoryProvider.overrideWithValue(pool)],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('No entries to read just yet'), findsOneWidget);
    expect(find.text('Back to journal'), findsOneWidget);
    verify(() => pool.serveOne()).called(1);
  });

  testWidgets('ReadBackScreen shows a served entry with Report + Block actions',
      (tester) async {
    final pool = MockPoolRepository();
    when(() => pool.serveOne()).thenAnswer(
      (_) async => ServedEntry(
        id: 's1',
        body: 'a gentle note from a stranger',
        createdAt: DateTime.utc(2026, 6, 30),
        authorId: 'stranger-1',
      ),
    );

    await tester.pumpWidget(
      _host(
        const ReadBackScreen(),
        overrides: [poolRepositoryProvider.overrideWithValue(pool)],
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('a gentle note from a stranger'),
      findsOneWidget,
    );
    // Report and Block are two distinct, separately-labelled actions.
    expect(find.text('Report'), findsOneWidget);
    expect(find.text('Block writer'), findsOneWidget);
    expect(find.text('Read another'), findsOneWidget);
  });

  testWidgets('JournalScreen builds and shows empty state when no entries',
      (tester) async {
    final entries = MockEntriesRepository();
    when(() => entries.myEntries(search: any(named: 'search')))
        .thenAnswer((_) async => const <Entry>[]);

    await tester.pumpWidget(
      _host(
        const JournalScreen(),
        overrides: [entriesRepositoryProvider.overrideWithValue(entries)],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('One Shot'), findsOneWidget);
    expect(find.text('Write'), findsOneWidget);
    expect(find.text('Read one'), findsOneWidget);
    expect(find.textContaining('Your journal is empty'), findsOneWidget);
  });

  testWidgets('JournalScreen lists an entry with a status chip', (tester) async {
    final entries = MockEntriesRepository();
    when(() => entries.myEntries(search: any(named: 'search'))).thenAnswer(
      (_) async => [
        Entry(
          id: 'e1',
          authorId: 'me',
          body: 'a private thought',
          createdAt: DateTime.utc(2026, 7, 1),
          visibility: Visibility.private,
          moderationStatus: ModerationStatus.private,
          isShareable: false,
        ),
      ],
    );

    await tester.pumpWidget(
      _host(
        const JournalScreen(),
        overrides: [entriesRepositoryProvider.overrideWithValue(entries)],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('a private thought'), findsOneWidget);
    expect(find.text('Private'), findsOneWidget);
  });
}
