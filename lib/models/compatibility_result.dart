import 'dart:convert';

class CompatibilityResult {
  final String? id;
  final Map<String, int> selectedFish; // Changed from individual fish names to map
  final String compatibilityLevel; // Changed from bool to string
  final List<String> reasons;
  final Map<String, dynamic> pairAnalysis; // New: stores pair-by-pair results
  final Map<String, dynamic> tankmateRecommendations; // New: stores tankmate recommendations
  final DateTime dateChecked;
  final DateTime? createdAt;

  CompatibilityResult({
    this.id,
    required this.selectedFish,
    required this.compatibilityLevel,
    required this.reasons,
    required this.pairAnalysis,
    required this.tankmateRecommendations,
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

    // Handle selected_fish JSONB
    Map<String, int> selectedFish = {};
    if (json['selected_fish'] != null) {
      if (json['selected_fish'] is Map) {
        selectedFish = Map<String, int>.from(json['selected_fish']);
      } else if (json['selected_fish'] is String) {
        try {
          final parsed = jsonDecode(json['selected_fish']);
          selectedFish = Map<String, int>.from(parsed);
        } catch (e) {
          selectedFish = {};
        }
      }
    }

    // Handle pair_analysis JSONB
    Map<String, dynamic> pairAnalysis = {};
    if (json['pair_analysis'] != null) {
      if (json['pair_analysis'] is Map) {
        pairAnalysis = Map<String, dynamic>.from(json['pair_analysis']);
      } else if (json['pair_analysis'] is String) {
        try {
          final parsed = jsonDecode(json['pair_analysis']);
          pairAnalysis = Map<String, dynamic>.from(parsed);
        } catch (e) {
          pairAnalysis = {};
        }
      }
    }

    // Handle tankmate_recommendations JSONB
    Map<String, dynamic> tankmateRecommendations = {};
    if (json['tankmate_recommendations'] != null) {
      if (json['tankmate_recommendations'] is Map) {
        tankmateRecommendations = Map<String, dynamic>.from(json['tankmate_recommendations']);
      } else if (json['tankmate_recommendations'] is String) {
        try {
          final parsed = jsonDecode(json['tankmate_recommendations']);
          tankmateRecommendations = Map<String, dynamic>.from(parsed);
        } catch (e) {
          tankmateRecommendations = {};
        }
      }
    }

    return CompatibilityResult(
      id: json['id'],
      selectedFish: selectedFish,
      compatibilityLevel: json['compatibility_level'] ?? 'unknown',
      reasons: parsedReasons,
      pairAnalysis: pairAnalysis,
      tankmateRecommendations: tankmateRecommendations,
      dateChecked: DateTime.parse(json['date_checked']),
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'selected_fish': selectedFish,
      'compatibility_level': compatibilityLevel,
      'reasons': reasons,
      'pair_analysis': pairAnalysis,
      'tankmate_recommendations': tankmateRecommendations,
      'date_checked': dateChecked.toIso8601String(),
    };
  }
} 