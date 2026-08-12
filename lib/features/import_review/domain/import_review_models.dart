class ImportReview {
  const ImportReview({
    required this.status,
    required this.version,
    required this.expiresAt,
    required this.items,
    this.source = const ImportReviewSource(),
    this.isSubmitting = false,
    this.submissionError,
  });

  final String status;
  final int version;
  final DateTime? expiresAt;
  final List<ImportReviewItem> items;
  final ImportReviewSource source;
  final bool isSubmitting;
  final String? submissionError;

  ImportReview copyWith({
    bool? isSubmitting,
    String? submissionError,
    bool clearSubmissionError = false,
  }) =>
      ImportReview(
        status: status,
        version: version,
        expiresAt: expiresAt,
        items: items,
        source: source,
        isSubmitting: isSubmitting ?? this.isSubmitting,
        submissionError: clearSubmissionError
            ? null
            : submissionError ?? this.submissionError,
      );

  factory ImportReview.fromJson(Map<String, dynamic> json) => ImportReview(
        status: json['status'] as String? ?? 'invalid',
        version: json['version'] as int? ?? 0,
        expiresAt: DateTime.tryParse(json['expiresAt'] as String? ?? ''),
        source: ImportReviewSource.fromJson(
          Map<String, dynamic>.from(json['source'] as Map? ?? const {}),
        ),
        items: (json['items'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(ImportReviewItem.fromJson)
            .toList(growable: false),
      );
}

class ImportReviewItem {
  const ImportReviewItem({
    required this.id,
    required this.summary,
    required this.issues,
    this.transaction = const ImportReviewTransaction(),
    this.saveStatus = 'pending',
    this.transactionId,
  });

  final String id;
  final String summary;
  final List<ImportReviewIssue> issues;
  final ImportReviewTransaction transaction;
  final String saveStatus;
  final String? transactionId;

  factory ImportReviewItem.fromJson(Map<String, dynamic> json) =>
      ImportReviewItem(
        id: json['id'] as String? ?? '',
        summary: json['summary'] as String? ?? 'Transaction awaiting review',
        transaction: ImportReviewTransaction.fromJson(
          Map<String, dynamic>.from(json['transaction'] as Map? ?? const {}),
        ),
        saveStatus: json['saveStatus'] as String? ?? 'pending',
        transactionId: json['transactionId'] as String?,
        issues: (json['issues'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(ImportReviewIssue.fromJson)
            .toList(growable: false),
      );
}

class ImportReviewSource {
  const ImportReviewSource({
    this.senderEmail,
    this.subjectLine,
    this.receivedAt,
    this.files = const [],
  });

  final String? senderEmail;
  final String? subjectLine;
  final DateTime? receivedAt;
  final List<ImportReviewSourceFile> files;

  bool get hasDetails =>
      senderEmail != null ||
      subjectLine != null ||
      receivedAt != null ||
      files.isNotEmpty;

  factory ImportReviewSource.fromJson(Map<String, dynamic> json) =>
      ImportReviewSource(
        senderEmail: json['senderEmail'] as String?,
        subjectLine: json['subjectLine'] as String?,
        receivedAt: DateTime.tryParse(json['receivedAt'] as String? ?? ''),
        files: (json['files'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(ImportReviewSourceFile.fromJson)
            .toList(growable: false),
      );
}

class ImportReviewSourceFile {
  const ImportReviewSourceFile({
    required this.name,
    required this.status,
    required this.transactionCount,
  });

  final String name;
  final String status;
  final int transactionCount;

  factory ImportReviewSourceFile.fromJson(Map<String, dynamic> json) =>
      ImportReviewSourceFile(
        name: json['name'] as String? ?? '',
        status: json['status'] as String? ?? 'unknown',
        transactionCount: json['transactionCount'] as int? ?? 0,
      );
}

class ImportReviewTransaction {
  const ImportReviewTransaction({
    this.type,
    this.amount,
    this.currency,
    this.date,
    this.merchant,
    this.description,
    this.category,
  });

  final String? type;
  final double? amount;
  final String? currency;
  final DateTime? date;
  final String? merchant;
  final String? description;
  final String? category;

  bool get hasDetails =>
      type != null ||
      amount != null ||
      currency != null ||
      date != null ||
      merchant != null ||
      description != null ||
      category != null;

  factory ImportReviewTransaction.fromJson(Map<String, dynamic> json) =>
      ImportReviewTransaction(
        type: json['type'] as String?,
        amount: (json['amount'] as num?)?.toDouble(),
        currency: json['currency'] as String?,
        date: DateTime.tryParse(json['date'] as String? ?? ''),
        merchant: json['merchant'] as String?,
        description: json['description'] as String?,
        category: json['category'] as String?,
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
