import 'dart:convert';

class CompatibilityResult {
  final String? id;
  final String fish1Name;
  final String fish1ImagePath;
  final String fish2Name;
  final String fish2ImagePath;
  final bool isCompatible;
  final List<String> reasons;
  final DateTime dateChecked;
  final DateTime? createdAt;

  CompatibilityResult({
    this.id,
    required this.fish1Name,
    required this.fish1ImagePath,
    required this.fish2Name,
    required this.fish2ImagePath,
    required this.isCompatible,
    required this.reasons,
    required this.dateChecked,
    this.createdAt,
  });

  factory CompatibilityResult.fromJson(Map<String, dynamic> json) {
    // Handle reasons which can be a string-encoded list
    List<String> parsedReasons = [];
    if (json['reasons'] is String) {
      // It might be a string like '["Reason 1", "Reason 2"]'
      try {
        parsedReasons = List<String>.from(jsonDecode(json['reasons']));
      } catch (e) {
        // Or it might be a simple string
        parsedReasons = [json['reasons']];
      }
    } else if (json['reasons'] is List) {
      parsedReasons = List<String>.from(json['reasons']);
    }

    return CompatibilityResult(
      id: json['id'],
      fish1Name: json['fish1_name'] ?? 'Unknown Fish',
      fish1ImagePath: json['fish1_image_path'] ?? '',
      fish2Name: json['fish2_name'] ?? 'Unknown Fish',
      fish2ImagePath: json['fish2_image_path'] ?? '',
      isCompatible: json['is_compatible'] ?? false,
      reasons: parsedReasons,
      dateChecked: DateTime.parse(json['date_checked']),
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fish1_name': fish1Name,
      'fish1_image_path': fish1ImagePath,
      'fish2_name': fish2Name,
      'fish2_image_path': fish2ImagePath,
      'is_compatible': isCompatible,
      'reasons': reasons,
      'date_checked': dateChecked.toIso8601String(),
    };
  }
} 