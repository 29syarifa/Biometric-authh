class BiometricTemplate {
  final String userId;
  final String encryptedTemplate;
  final DateTime createdAt;
  final int embeddingCount; // how many face vectors enrolled

  BiometricTemplate({
    required this.userId,
    required this.encryptedTemplate,
    required this.createdAt,
    this.embeddingCount = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'encryptedTemplate': encryptedTemplate,
      'createdAt': createdAt.toIso8601String(),
      'embeddingCount': embeddingCount,
    };
  }

  factory BiometricTemplate.fromJson(Map<String, dynamic> json) {
    return BiometricTemplate(
      userId: json['userId'] as String,
      encryptedTemplate: json['encryptedTemplate'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      embeddingCount: (json['embeddingCount'] as int?) ?? 0,
    );
  }
}