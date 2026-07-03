/// The current user's profile row. `suspended` and `reportStrikes` are
/// service-role controlled and shown here read-only.
class Profile {
  const Profile({
    required this.id,
    required this.createdAt,
    required this.ageConfirmed,
    required this.tosAcceptedAt,
    required this.tosVersion,
    required this.suspended,
    required this.reportStrikes,
  });

  final String id;
  final DateTime createdAt;
  final bool ageConfirmed;
  final DateTime? tosAcceptedAt;
  final String? tosVersion;
  final bool suspended;
  final int reportStrikes;

  bool get hasAcceptedTos => tosAcceptedAt != null;

  /// Whether onboarding gates (age + ToS) are both satisfied.
  bool get isOnboarded => ageConfirmed && hasAcceptedTos;

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      ageConfirmed: json['age_confirmed'] as bool? ?? false,
      tosAcceptedAt: json['tos_accepted_at'] == null
          ? null
          : DateTime.parse(json['tos_accepted_at'] as String),
      tosVersion: json['tos_version'] as String?,
      suspended: json['suspended'] as bool? ?? false,
      reportStrikes: json['report_strikes'] as int? ?? 0,
    );
  }
}
