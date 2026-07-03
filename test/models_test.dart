import 'package:flutter_test/flutter_test.dart';
import 'package:oneshot_journal/models/entry.dart';
import 'package:oneshot_journal/models/moderation_outcome.dart';
import 'package:oneshot_journal/models/profile.dart';
import 'package:oneshot_journal/models/served_entry.dart';

void main() {
  group('Entry', () {
    test('fromJson parses all fields and derives state', () {
      final entry = Entry.fromJson({
        'id': 'e1',
        'author_id': 'a1',
        'body': 'hello world',
        'created_at': '2026-07-01T10:00:00Z',
        'visibility': 'shared',
        'moderation_status': 'clean',
        'is_shareable': true,
        'moderation_categories': {'self-harm': 0.01},
        'moderated_at': '2026-07-01T10:05:00Z',
      });

      expect(entry.id, 'e1');
      expect(entry.authorId, 'a1');
      expect(entry.body, 'hello world');
      expect(entry.visibility, Visibility.shared);
      expect(entry.moderationStatus, ModerationStatus.clean);
      expect(entry.isShareable, isTrue);
      expect(entry.isInPool, isTrue);
      expect(entry.isPrivate, isFalse);
      expect(entry.moderationCategories['self-harm'], 0.01);
      expect(entry.moderatedAt, isNotNull);
    });

    test('fromJson defaults: missing fields are safe', () {
      final entry = Entry.fromJson({
        'id': 'e2',
        'author_id': 'a2',
        'created_at': '2026-07-01T10:00:00Z',
      });

      expect(entry.body, '');
      expect(entry.visibility, Visibility.private);
      expect(entry.moderationStatus, ModerationStatus.private);
      expect(entry.isShareable, isFalse);
      expect(entry.isInPool, isFalse);
      expect(entry.isPrivate, isTrue);
      expect(entry.moderationCategories, isEmpty);
      expect(entry.moderatedAt, isNull);
    });

    test('isInPool requires BOTH is_shareable true AND status clean', () {
      // shareable but not clean → not in pool.
      final notClean = Entry.fromJson({
        'id': 'e3',
        'author_id': 'a3',
        'created_at': '2026-07-01T10:00:00Z',
        'is_shareable': true,
        'moderation_status': 'pending',
      });
      expect(notClean.isInPool, isFalse);

      // clean but not shareable → not in pool.
      final notShareable = Entry.fromJson({
        'id': 'e4',
        'author_id': 'a4',
        'created_at': '2026-07-01T10:00:00Z',
        'is_shareable': false,
        'moderation_status': 'clean',
      });
      expect(notShareable.isInPool, isFalse);
    });

    test('toInsertJson NEVER includes is_shareable (security contract)', () {
      final entry = Entry.fromJson({
        'id': 'e5',
        'author_id': 'a5',
        'body': 'draft',
        'created_at': '2026-07-01T10:00:00Z',
        'visibility': 'shared',
        'moderation_status': 'pending',
        'is_shareable': true,
      });

      final insert = entry.toInsertJson();
      expect(
        insert.containsKey('is_shareable'),
        isFalse,
        reason: 'client must never assert pool eligibility',
      );
      expect(insert['body'], 'draft');
      expect(insert['visibility'], 'shared');
      expect(insert['moderation_status'], 'pending');
    });

    test('toInsertJson maps visibility + status for a private draft', () {
      final entry = Entry.fromJson({
        'id': 'e6',
        'author_id': 'a6',
        'body': 'secret',
        'created_at': '2026-07-01T10:00:00Z',
        'visibility': 'private',
        'moderation_status': 'private',
      });

      final insert = entry.toInsertJson();
      expect(insert['visibility'], 'private');
      expect(insert['moderation_status'], 'private');
      expect(insert.containsKey('is_shareable'), isFalse);
    });
  });

  group('ModerationStatus', () {
    test('fromDb maps every known db value', () {
      expect(ModerationStatus.fromDb('private'), ModerationStatus.private);
      expect(ModerationStatus.fromDb('pending'), ModerationStatus.pending);
      expect(ModerationStatus.fromDb('clean'), ModerationStatus.clean);
      expect(
        ModerationStatus.fromDb('held_selfharm'),
        ModerationStatus.heldSelfharm,
      );
      expect(ModerationStatus.fromDb('held_pii'), ModerationStatus.heldPii);
      expect(ModerationStatus.fromDb('rejected'), ModerationStatus.rejected);
      expect(
        ModerationStatus.fromDb('rejected_objectionable'),
        ModerationStatus.rejectedObjectionable,
      );
      expect(ModerationStatus.fromDb('removed'), ModerationStatus.removed);
    });

    test('fromDb defaults unknown / null to private', () {
      expect(ModerationStatus.fromDb(null), ModerationStatus.private);
      expect(ModerationStatus.fromDb('nonsense'), ModerationStatus.private);
    });

    test('db + fromDb round-trip for every status', () {
      for (final status in ModerationStatus.values) {
        expect(
          ModerationStatus.fromDb(status.db),
          status,
          reason: 'round-trip failed for $status',
        );
      }
    });
  });

  group('ModerationOutcome', () {
    test('fromJson parses a clean (shareable) outcome without crisis', () {
      final outcome = ModerationOutcome.fromJson({
        'status': 'clean',
        'is_shareable': true,
        'categories': {'self-harm': 0.0},
        'message': '',
      });

      expect(outcome.status, GateStatus.clean);
      expect(outcome.isClean, isTrue);
      expect(outcome.isShareable, isTrue);
      expect(outcome.isSelfHarm, isFalse);
      expect(outcome.crisisResources, isEmpty);
    });

    test('fromJson parses a held_selfharm outcome WITH crisis resources', () {
      final outcome = ModerationOutcome.fromJson({
        'status': 'held_selfharm',
        'is_shareable': false,
        'message': 'We want to make sure you have support.',
        'categories': {'self-harm': 0.9},
        'crisis': {
          'region': 'SG',
          'resources': [
            {
              'name': 'Samaritans of Singapore (SOS)',
              'contact': '1767',
              'hours': '24h',
              'note': 'verify at build time',
            },
            {
              'name': 'national mindline 1771',
              'contact': '1771',
            },
          ],
        },
      });

      expect(outcome.status, GateStatus.heldSelfharm);
      expect(outcome.isSelfHarm, isTrue);
      expect(outcome.isShareable, isFalse);
      expect(outcome.crisisResources, hasLength(2));
      expect(
        outcome.crisisResources.first.name,
        'Samaritans of Singapore (SOS)',
      );
      expect(outcome.crisisResources.first.contact, '1767');
      expect(outcome.crisisResources.first.hours, '24h');
      expect(outcome.crisisResources.first.note, 'verify at build time');
      // hours has a safe default when omitted.
      expect(outcome.crisisResources[1].hours, '');
      expect(outcome.crisisResources[1].note, isNull);
    });

    test('fromJson defaults unknown status to rejected_objectionable', () {
      final outcome = ModerationOutcome.fromJson({'status': 'weird'});
      expect(outcome.status, GateStatus.rejectedObjectionable);
      expect(outcome.isShareable, isFalse);
      expect(outcome.crisisResources, isEmpty);
    });
  });

  group('ServedEntry', () {
    test('fromJson parses the anonymous served shape', () {
      final served = ServedEntry.fromJson({
        'id': 's1',
        'body': 'a stranger note',
        'created_at': '2026-06-30T08:00:00Z',
        'author_id': 'stranger-1',
      });

      expect(served.id, 's1');
      expect(served.body, 'a stranger note');
      expect(served.authorId, 'stranger-1');
      expect(served.createdAt, DateTime.parse('2026-06-30T08:00:00Z'));
    });

    test('fromJson tolerates a missing body', () {
      final served = ServedEntry.fromJson({
        'id': 's2',
        'created_at': '2026-06-30T08:00:00Z',
        'author_id': 'stranger-2',
      });
      expect(served.body, '');
    });
  });

  group('Profile.isOnboarded', () {
    Profile build({required bool age, DateTime? tosAt}) => Profile(
          id: 'p1',
          createdAt: DateTime.parse('2026-01-01T00:00:00Z'),
          ageConfirmed: age,
          tosAcceptedAt: tosAt,
          tosVersion: tosAt == null ? null : '2026-07-01',
          suspended: false,
          reportStrikes: 0,
        );

    test('onboarded only when age confirmed AND ToS accepted', () {
      final ts = DateTime.parse('2026-07-01T00:00:00Z');
      expect(build(age: true, tosAt: ts).isOnboarded, isTrue);
      expect(build(age: false, tosAt: ts).isOnboarded, isFalse);
      expect(build(age: true, tosAt: null).isOnboarded, isFalse);
      expect(build(age: false, tosAt: null).isOnboarded, isFalse);
    });

    test('hasAcceptedTos reflects tos_accepted_at presence', () {
      expect(build(age: true, tosAt: null).hasAcceptedTos, isFalse);
      expect(
        build(age: true, tosAt: DateTime.parse('2026-07-01T00:00:00Z'))
            .hasAcceptedTos,
        isTrue,
      );
    });

    test('fromJson parses profile row', () {
      final profile = Profile.fromJson({
        'id': 'p9',
        'created_at': '2026-01-01T00:00:00Z',
        'age_confirmed': true,
        'tos_accepted_at': '2026-07-01T00:00:00Z',
        'tos_version': '2026-07-01',
        'suspended': false,
        'report_strikes': 2,
      });
      expect(profile.isOnboarded, isTrue);
      expect(profile.reportStrikes, 2);
      expect(profile.suspended, isFalse);
    });
  });
}
