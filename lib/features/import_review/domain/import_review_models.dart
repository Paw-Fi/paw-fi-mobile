class ImportReview {
  const ImportReview({
    required this.status,
    required this.version,
    required this.expiresAt,
    required this.items,
  });

  final String status;
  final int version;
  final DateTime? expiresAt;
  final List<ImportReviewItem> items;

  factory ImportReview.fromJson(Map<String, dynamic> json) => ImportReview(
        status: json['status'] as String? ?? 'invalid',
        version: json['version'] as int? ?? 0,
        expiresAt: DateTime.tryParse(json['expiresAt'] as String? ?? ''),
        items: (json['items'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(ImportReviewItem.fromJson)
            .toList(growable: false),
      );
}

class ImportReviewItem {
  const ImportReviewItem(
      {required this.id, required this.summary, required this.issues});

  final String id;
  final String summary;
  final List<ImportReviewIssue> issues;

  factory ImportReviewItem.fromJson(Map<String, dynamic> json) =>
      ImportReviewItem(
        id: json['id'] as String? ?? '',
        summary: json['summary'] as String? ?? 'Transaction awaiting review',
        issues: (json['issues'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(ImportReviewIssue.fromJson)
            .toList(growable: false),
      );
}

class ImportReviewIssue {
  const ImportReviewIssue({required this.field, required this.choices});

  final String field;
  final List<ImportReviewChoice> choices;

  factory ImportReviewIssue.fromJson(Map<String, dynamic> json) =>
      ImportReviewIssue(
        field: json['field'] as String? ?? '',
        choices: (json['choices'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(ImportReviewChoice.fromJson)
            .toList(growable: false),
      );
}

class ImportReviewChoice {
  const ImportReviewChoice(
      {required this.id, required this.label, required this.evidence});

  final String id;
  final String label;
  final String evidence;

  factory ImportReviewChoice.fromJson(Map<String, dynamic> json) =>
      ImportReviewChoice(
        id: json['id'] as String? ?? '',
        label: json['label'] as String? ?? '',
        evidence: json['evidence'] as String? ?? '',
      );
}
