class CompatibilityResult {
  final String? id;
  final String fish1Name;
  final String fish2Name;
  final String fish1ImagePath;
  final String fish2ImagePath;
  final bool isCompatible;
  final String compatibilityMessage;
  final List<String> reasons;
  final DateTime dateChecked;
  final DateTime? createdAt;
  final Map<String, dynamic>? fish1Details;
  final Map<String, dynamic>? fish2Details;

  CompatibilityResult({
    this.id,
    required this.fish1Name,
    required this.fish2Name,
    required this.fish1ImagePath,
    required this.fish2ImagePath,
    required this.isCompatible,
    required this.compatibilityMessage,
    required this.reasons,
    required this.dateChecked,
    this.createdAt,
    this.fish1Details,
    this.fish2Details,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'fish1_name': fish1Name,
    'fish2_name': fish2Name,
    'fish1_image_path': fish1ImagePath,
    'fish2_image_path': fish2ImagePath,
    'is_compatible': isCompatible,
    'compatibility_message': compatibilityMessage,
    'reasons': reasons.join('; '),
    'date_checked': dateChecked.toIso8601String(),
    'created_at': createdAt?.toIso8601String(),
    'fish1_details': fish1Details,
    'fish2_details': fish2Details,
  };

  factory CompatibilityResult.fromJson(Map<String, dynamic> json) => CompatibilityResult(
    id: json['id'],
    fish1Name: json['fish1_name'] ?? json['fish1Name'],
    fish2Name: json['fish2_name'] ?? json['fish2Name'],
    fish1ImagePath: json['fish1_image_path'] ?? json['fish1ImagePath'],
    fish2ImagePath: json['fish2_image_path'] ?? json['fish2ImagePath'],
    isCompatible: json['is_compatible'] ?? json['isCompatible'],
    compatibilityMessage: json['compatibility_message'] ?? json['compatibilityMessage'] ?? '',
    reasons: json['reasons'] is String
        ? (json['reasons'] as String).split(';').map((s) => s.trim()).where((s) => s.isNotEmpty).toList()
        : (json['reasons'] is List
            ? List<String>.from(json['reasons'])
            : []),
    dateChecked: DateTime.parse(json['date_checked'] ?? json['dateChecked']),
    createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
    fish1Details: json['fish1_details'] ?? json['fish1Details'],
    fish2Details: json['fish2_details'] ?? json['fish2Details'],
  );
} 