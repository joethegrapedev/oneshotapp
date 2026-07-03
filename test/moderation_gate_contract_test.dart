import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:oneshot_journal/data/moderation_repository.dart';
import 'package:oneshot_journal/models/entry.dart';
import 'package:oneshot_journal/models/moderation_outcome.dart';

/// A mocktail fake of the moderation repository. The real one calls the
/// `moderate-and-pool` edge function; here we assert the *contract* the write
/// flow relies on, without any network. The server is the sole authority for
/// pool eligibility.
class MockModerationRepository extends Mock implements ModerationRepository {}

void main() {
  late MockModerationRepository repo;
  const entryId = 'entry-123';

  setUp(() {
    repo = MockModerationRepository();
  });

  group('submitForSharing outcome contract', () {
    test('clean → isShareable true, not self-harm', () async {
      when(() => repo.submitForSharing(entryId)).thenAnswer(
        (_) async => const ModerationOutcome(
          status: GateStatus.clean,
          isShareable: true,
          message: '',
        ),
      );

      final outcome = await repo.submitForSharing(entryId);

      expect(outcome.isClean, isTrue);
      expect(outcome.isShareable, isTrue);
      expect(outcome.isSelfHarm, isFalse);
      verify(() => repo.submitForSharing(entryId)).called(1);
    });

    test('held_selfharm → isSelfHarm true, isShareable false, crisis present',
        () async {
      when(() => repo.submitForSharing(entryId)).thenAnswer(
        (_) async => ModerationOutcome.fromJson(const {
          'status': 'held_selfharm',
          'is_shareable': false,
          'message': 'support',
          'crisis': {
            'region': 'SG',
            'resources': [
              {'name': 'SOS', 'contact': '1767', 'hours': '24h'},
            ],
          },
        }),
      );

      final outcome = await repo.submitForSharing(entryId);

      expect(outcome.isSelfHarm, isTrue);
      expect(outcome.isShareable, isFalse);
      expect(
        outcome.crisisResources,
        isNotEmpty,
        reason: 'self-harm must route to crisis resources',
      );
    });

    test('rejected → isShareable false', () async {
      when(() => repo.submitForSharing(entryId)).thenAnswer(
        (_) async => const ModerationOutcome(
          status: GateStatus.rejected,
          isShareable: false,
          message: 'not allowed',
        ),
      );

      final outcome = await repo.submitForSharing(entryId);

      expect(outcome.isShareable, isFalse);
      expect(outcome.isClean, isFalse);
      expect(outcome.status, GateStatus.rejected);
    });

    test('rejected_objectionable → isShareable false', () async {
      when(() => repo.submitForSharing(entryId)).thenAnswer(
        (_) async => const ModerationOutcome(
          status: GateStatus.rejectedObjectionable,
          isShareable: false,
          message: 'not allowed',
        ),
      );

      final outcome = await repo.submitForSharing(entryId);
      expect(outcome.isShareable, isFalse);
      expect(outcome.status, GateStatus.rejectedObjectionable);
    });
  });

  group('client never asserts pool eligibility (security contract)', () {
    test('Entry.toInsertJson() omits is_shareable even when true locally', () {
      // Even if a (hypothetical) locally-constructed entry carried
      // is_shareable=true, the insert payload must never send it — only the
      // service role may promote an entry into the pool.
      final entry = Entry(
        id: 'e1',
        authorId: 'a1',
        body: 'staged for sharing',
        createdAt: DateTime.utc(2026, 7, 1),
        visibility: Visibility.shared,
        moderationStatus: ModerationStatus.pending,
        isShareable: true,
      );

      final insert = entry.toInsertJson();

      expect(insert.containsKey('is_shareable'), isFalse);
      expect(insert['moderation_status'], 'pending');
      expect(insert['visibility'], 'shared');
    });
  });
}
