import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/api_config.dart';

class TankmateCompatibilityLevel {
  static const String fullyCompatible = 'fully_compatible';
  static const String conditional = 'conditional';
  static const String incompatible = 'incompatible';
}

class TankmateRecommendation {
  final String name;
  final List<String> conditions;
  final String compatibilityLevel;

  TankmateRecommendation({
    required this.name,
    required this.conditions,
    required this.compatibilityLevel,
  });

  factory TankmateRecommendation.fromJson(Map<String, dynamic> json) {
    return TankmateRecommendation(
      name: json['name'] ?? '',
      conditions: List<String>.from(json['conditions'] ?? []),
      compatibilityLevel: json['compatibility_level'] ?? 'conditional',
    );
  }
}

class DetailedTankmateInfo {
  final String fishName;
  final List<String> fullyCompatibleTankmates;
  final List<TankmateRecommendation> conditionalTankmates;
  final List<String> incompatibleTankmates;
  final List<String> specialRequirements;
  final String careLevel;
  final double confidenceScore;
  final int totalFullyCompatible;
  final int totalConditional;
  final int totalIncompatible;
  final int totalRecommended;

  DetailedTankmateInfo({
    required this.fishName,
    required this.fullyCompatibleTankmates,
    required this.conditionalTankmates,
    required this.incompatibleTankmates,
    required this.specialRequirements,
    required this.careLevel,
    required this.confidenceScore,
    required this.totalFullyCompatible,
    required this.totalConditional,
    required this.totalIncompatible,
    required this.totalRecommended,
  });

  factory DetailedTankmateInfo.fromJson(Map<String, dynamic> json) {
    return DetailedTankmateInfo(
      fishName: json['fish_name'] ?? '',
      fullyCompatibleTankmates: List<String>.from(json['fully_compatible_tankmates'] ?? []),
      conditionalTankmates: (json['conditional_tankmates'] as List<dynamic>?)
          ?.map((item) => TankmateRecommendation.fromJson(item))
          .toList() ?? [],
      incompatibleTankmates: List<String>.from(json['incompatible_tankmates'] ?? []),
      specialRequirements: List<String>.from(json['special_requirements'] ?? []),
      careLevel: json['care_level'] ?? '',
      confidenceScore: (json['confidence_score'] ?? 0.0).toDouble(),
      totalFullyCompatible: json['total_fully_compatible'] ?? 0,
      totalConditional: json['total_conditional'] ?? 0,
      totalIncompatible: json['total_incompatible'] ?? 0,
      totalRecommended: json['total_recommended'] ?? 0,
    );
  }
}

class CompatibilityMatrixInfo {
  final String fish1Name;
  final String fish2Name;
  final String compatibilityLevel;
  final bool isCompatible;
  final List<String> compatibilityReasons;
  final List<String> conditions;
  final double compatibilityScore;
  final double confidenceScore;
  final String generationMethod;

  CompatibilityMatrixInfo({
    required this.fish1Name,
    required this.fish2Name,
    required this.compatibilityLevel,
    required this.isCompatible,
    required this.compatibilityReasons,
    required this.conditions,
    required this.compatibilityScore,
    required this.confidenceScore,
    required this.generationMethod,
  });

  factory CompatibilityMatrixInfo.fromJson(Map<String, dynamic> json) {
    return CompatibilityMatrixInfo(
      fish1Name: json['fish1_name'] ?? '',
      fish2Name: json['fish2_name'] ?? '',
      compatibilityLevel: json['compatibility_level'] ?? 'unknown',
      isCompatible: json['is_compatible'] ?? false,
      compatibilityReasons: List<String>.from(json['compatibility_reasons'] ?? []),
      conditions: List<String>.from(json['conditions'] ?? []),
      compatibilityScore: (json['compatibility_score'] ?? 0.0).toDouble(),
      confidenceScore: (json['confidence_score'] ?? 0.0).toDouble(),
      generationMethod: json['generation_method'] ?? '',
    );
  }
}

class EnhancedTankmateService {
  static final SupabaseClient _supabase = Supabase.instance.client;
  static String get _baseUrl => ApiConfig.baseUrl;

  /// Get detailed tankmate information for a specific fish
  static Future<DetailedTankmateInfo?> getTankmateDetails(String fishName) async {
    try {
      final response = await _supabase
          .from('fish_tankmate_recommendations')
          .select('*')
          .ilike('fish_name', fishName)
          .maybeSingle();

      if (response != null) {
        return DetailedTankmateInfo.fromJson(response);
      }
      return null;
    } catch (e) {
      print('Error getting tankmate details for $fishName: $e');
      return null;
    }
  }

  /// Get compatibility matrix information between two fish
  static Future<CompatibilityMatrixInfo?> getCompatibilityMatrix(
      String fish1Name, String fish2Name) async {
    try {
      final response = await _supabase
          .from('fish_compatibility_matrix')
          .select('*');

      if (response.isNotEmpty) {
        // Find the specific pair
        for (var item in response) {
          if ((item['fish1_name'] == fish1Name && item['fish2_name'] == fish2Name) ||
              (item['fish1_name'] == fish2Name && item['fish2_name'] == fish1Name)) {
            return CompatibilityMatrixInfo.fromJson(item);
          }
        }
      }
      return null;
    } catch (e) {
      print('Error getting compatibility matrix for $fish1Name + $fish2Name: $e');
      return null;
    }
  }

  /// Get enhanced tankmate recommendations for multiple fish
  static Future<Map<String, dynamic>?> getEnhancedTankmateRecommendations(
      List<String> fishNames) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/tankmate-recommendations'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'fish_names': fishNames}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('Error getting enhanced tankmate recommendations: $e');
      return null;
    }
  }

  /// Get AI-generated compatibility analysis between two fish
  static Future<Map<String, dynamic>?> getAICompatibilityAnalysis(
      String fish1Name, String fish2Name) async {
    try {
      final uri = Uri.parse('$_baseUrl/ai-compatibility-analysis').replace(
        queryParameters: {
          'fish1_name': fish1Name,
          'fish2_name': fish2Name,
        },
      );
      
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print('AI API Error: ${response.statusCode} - ${response.body}');
      }
      return null;
    } catch (e) {
      print('Error getting AI compatibility analysis: $e');
      return null;
    }
  }

  /// Get AI-generated fish care requirements
  static Future<Map<String, dynamic>?> getAIFishRequirements(String fishName) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/ai-fish-requirements/$fishName'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('Error getting AI fish requirements: $e');
      return null;
    }
  }

  /// Get all tankmate recommendations for a fish (combines fully compatible and conditional)
  static Future<List<String>> getAllTankmateRecommendations(String fishName) async {
    try {
      final details = await getTankmateDetails(fishName);
      if (details != null) {
        List<String> allRecommendations = [];
        
        // Add fully compatible tankmates
        allRecommendations.addAll(details.fullyCompatibleTankmates);
        
        // Add conditional tankmates (extract names)
        allRecommendations.addAll(
          details.conditionalTankmates.map((item) => item.name)
        );
        
        return allRecommendations;
      }
      return [];
    } catch (e) {
      print('Error getting all tankmate recommendations for $fishName: $e');
      return [];
    }
  }

  /// Get tankmate recommendations by compatibility level
  static Future<Map<String, List<String>>> getTankmateRecommendationsByLevel(
      String fishName) async {
    try {
      final details = await getTankmateDetails(fishName);
      if (details != null) {
        return {
          TankmateCompatibilityLevel.fullyCompatible: details.fullyCompatibleTankmates,
          TankmateCompatibilityLevel.conditional: 
              details.conditionalTankmates.map((item) => item.name).toList(),
          TankmateCompatibilityLevel.incompatible: details.incompatibleTankmates,
        };
      }
      return {
        TankmateCompatibilityLevel.fullyCompatible: [],
        TankmateCompatibilityLevel.conditional: [],
        TankmateCompatibilityLevel.incompatible: [],
      };
    } catch (e) {
      print('Error getting tankmate recommendations by level for $fishName: $e');
      return {
        TankmateCompatibilityLevel.fullyCompatible: [],
        TankmateCompatibilityLevel.conditional: [],
        TankmateCompatibilityLevel.incompatible: [],
      };
    }
  }

  /// Get special requirements for a fish
  static Future<List<String>> getSpecialRequirements(String fishName) async {
    try {
      final details = await getTankmateDetails(fishName);
      return details?.specialRequirements ?? [];
    } catch (e) {
      print('Error getting special requirements for $fishName: $e');
      return [];
    }
  }

  /// Check if two fish are compatible
  static Future<bool> areFishCompatible(String fish1Name, String fish2Name) async {
    try {
      final matrix = await getCompatibilityMatrix(fish1Name, fish2Name);
      return matrix?.isCompatible ?? false;
    } catch (e) {
      print('Error checking compatibility between $fish1Name and $fish2Name: $e');
      return false;
    }
  }

  /// Get compatibility level between two fish
  static Future<String> getCompatibilityLevel(String fish1Name, String fish2Name) async {
    try {
      final matrix = await getCompatibilityMatrix(fish1Name, fish2Name);
      return matrix?.compatibilityLevel ?? 'unknown';
    } catch (e) {
      print('Error getting compatibility level between $fish1Name and $fish2Name: $e');
      return 'unknown';
    }
  }

  /// Get compatibility reasons between two fish
  static Future<List<String>> getCompatibilityReasons(
      String fish1Name, String fish2Name) async {
    try {
      final matrix = await getCompatibilityMatrix(fish1Name, fish2Name);
      return matrix?.compatibilityReasons ?? [];
    } catch (e) {
      print('Error getting compatibility reasons between $fish1Name and $fish2Name: $e');
      return [];
    }
  }

  /// Get conditions required for conditional compatibility
  static Future<List<String>> getCompatibilityConditions(
      String fish1Name, String fish2Name) async {
    try {
      final matrix = await getCompatibilityMatrix(fish1Name, fish2Name);
      return matrix?.conditions ?? [];
    } catch (e) {
      print('Error getting compatibility conditions between $fish1Name and $fish2Name: $e');
      return [];
    }
  }
}
