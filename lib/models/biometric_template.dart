class BiometricTemplate {
  final String userId;
  final String encryptedTemplate;
  final DateTime createdAt;

  BiometricTemplate({
    required this.userId,
    required this.encryptedTemplate,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'encryptedTemplate': encryptedTemplate,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory BiometricTemplate.fromJson(Map<String, dynamic> json) {
    return BiometricTemplate(
      userId: json['userId'],
      encryptedTemplate: json['encryptedTemplate'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}