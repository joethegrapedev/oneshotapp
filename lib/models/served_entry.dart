/// A stranger's entry served to the current reader through the pool.
///
/// Deliberately minimal — anonymous. `authorId` is carried only so the reader
/// can Block that author; it is never displayed and there is no reply channel.
class ServedEntry {
  const ServedEntry({
    required this.id,
    required this.body,
    required this.createdAt,
    required this.authorId,
  });

  final String id;
  final String body;
  final DateTime createdAt;
  final String authorId;

  factory ServedEntry.fromJson(Map<String, dynamic> json) {
    return ServedEntry(
      id: json['id'] as String,
      body: json['body'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
      authorId: json['author_id'] as String,
    );
  }
}
