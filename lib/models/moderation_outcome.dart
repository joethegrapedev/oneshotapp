import 'crisis_resource.dart';

/// The result of submitting an entry to the server moderation gate.
enum GateStatus {
  clean,
  heldSelfharm,
  heldPii,
  rejected,
  rejectedObjectionable;

  static GateStatus fromDb(String? v) => switch (v) {
        'clean' => GateStatus.clean,
        'held_selfharm' => GateStatus.heldSelfharm,
        'held_pii' => GateStatus.heldPii,
        'rejected' => GateStatus.rejected,
        'rejected_objectionable' => GateStatus.rejectedObjectionable,
        _ => GateStatus.rejectedObjectionable,
      };
}

class ModerationOutcome {
  const ModerationOutcome({
    required this.status,
    required this.isShareable,
    required this.message,
    this.categories = const {},
    this.crisisResources = const [],
  });

  final GateStatus status;
  final bool isShareable;
  final String message;
  final Map<String, dynamic> categories;
  final List<CrisisResource> crisisResources;

  bool get isSelfHarm => status == GateStatus.heldSelfharm;
  bool get isClean => status == GateStatus.clean;

  factory ModerationOutcome.fromJson(Map<String, dynamic> json) {
    final crisis = json['crisis'] as Map<String, dynamic>?;
    final resources = (crisis?['resources'] as List?)
            ?.map(
              (e) => CrisisResource.fromJson((e as Map).cast<String, dynamic>()),
            )
            .toList() ??
        const <CrisisResource>[];

    return ModerationOutcome(
      status: GateStatus.fromDb(json['status'] as String?),
      isShareable: json['is_shareable'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      categories:
          (json['categories'] as Map?)?.cast<String, dynamic>() ?? const {},
      crisisResources: resources,
    );
  }
}
