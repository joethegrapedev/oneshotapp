/// A local crisis-support resource surfaced on the crisis screen.
class CrisisResource {
  const CrisisResource({
    required this.name,
    required this.contact,
    required this.hours,
    this.note,
  });

  final String name;
  final String contact;
  final String hours;
  final String? note;

  factory CrisisResource.fromJson(Map<String, dynamic> json) {
    return CrisisResource(
      name: json['name'] as String,
      contact: json['contact'] as String,
      hours: json['hours'] as String? ?? '',
      note: json['note'] as String?,
    );
  }
}
