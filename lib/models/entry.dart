/// Author intent for an entry.
enum Visibility { private, shared }

/// Server-authoritative moderation status. The client can only ever cause
/// `private`, `pending`, or `removed`; all other transitions come from the gate.
enum ModerationStatus {
  private,
  pending,
  clean,
  heldSelfharm,
  heldPii,
  rejected,
  rejectedObjectionable,
  removed;

  static ModerationStatus fromDb(String? v) {
    switch (v) {
      case 'pending':
        return ModerationStatus.pending;
      case 'clean':
        return ModerationStatus.clean;
      case 'held_selfharm':
        return ModerationStatus.heldSelfharm;
      case 'held_pii':
        return ModerationStatus.heldPii;
      case 'rejected':
        return ModerationStatus.rejected;
      case 'rejected_objectionable':
        return ModerationStatus.rejectedObjectionable;
      case 'removed':
        return ModerationStatus.removed;
      case 'private':
      default:
        return ModerationStatus.private;
    }
  }

  String get db => switch (this) {
        ModerationStatus.private => 'private',
        ModerationStatus.pending => 'pending',
        ModerationStatus.clean => 'clean',
        ModerationStatus.heldSelfharm => 'held_selfharm',
        ModerationStatus.heldPii => 'held_pii',
        ModerationStatus.rejected => 'rejected',
        ModerationStatus.rejectedObjectionable => 'rejected_objectionable',
        ModerationStatus.removed => 'removed',
      };
}

/// An entry the current user authored.
class Entry {
  const Entry({
    required this.id,
    required this.authorId,
    required this.body,
    required this.createdAt,
    required this.visibility,
    required this.moderationStatus,
    required this.isShareable,
    this.moderationCategories = const {},
    this.moderatedAt,
  });

  final String id;
  final String authorId;
  final String body;
  final DateTime createdAt;
  final Visibility visibility;
  final ModerationStatus moderationStatus;
  final bool isShareable;
  final Map<String, dynamic> moderationCategories;
  final DateTime? moderatedAt;

  bool get isPrivate => visibility == Visibility.private;

  /// True once the entry has actually been accepted into the shared pool.
  bool get isInPool =>
      isShareable && moderationStatus == ModerationStatus.clean;

  factory Entry.fromJson(Map<String, dynamic> json) {
    return Entry(
      id: json['id'] as String,
      authorId: json['author_id'] as String,
      body: json['body'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
      visibility: (json['visibility'] as String?) == 'shared'
          ? Visibility.shared
          : Visibility.private,
      moderationStatus:
          ModerationStatus.fromDb(json['moderation_status'] as String?),
      isShareable: json['is_shareable'] as bool? ?? false,
      moderationCategories:
          (json['moderation_categories'] as Map?)?.cast<String, dynamic>() ??
              const {},
      moderatedAt: json['moderated_at'] == null
          ? null
          : DateTime.parse(json['moderated_at'] as String),
    );
  }

  /// Only the fields a client is permitted to insert (RLS enforces the rest).
  Map<String, dynamic> toInsertJson() => {
        'body': body,
        'visibility': visibility == Visibility.shared ? 'shared' : 'private',
        'moderation_status': moderationStatus.db,
        // is_shareable intentionally omitted — service role only.
      };

  Entry copyWith({
    String? body,
    Visibility? visibility,
    ModerationStatus? moderationStatus,
    bool? isShareable,
  }) {
    return Entry(
      id: id,
      authorId: authorId,
      body: body ?? this.body,
      createdAt: createdAt,
      visibility: visibility ?? this.visibility,
      moderationStatus: moderationStatus ?? this.moderationStatus,
      isShareable: isShareable ?? this.isShareable,
      moderationCategories: moderationCategories,
      moderatedAt: moderatedAt,
    );
  }
}
