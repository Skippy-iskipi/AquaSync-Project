import 'dart:convert';

class WaterCalculation {
  final String? id;
  final String minimumTankVolume;
  final Map<String, int> fishSelections;
  final Map<String, int> recommendedQuantities;
  final DateTime dateCalculated;
  final String phRange;
  final String temperatureRange;
  final String tankStatus;
  final String? tankShape; // new field for tank shape
  final Map<String, dynamic>? waterRequirements; // new field for water requirements
  final List<String>? tankmateRecommendations; // moved from AI content
  final Map<String, dynamic>? feedingInformation; // new field for feeding info
  final DateTime? createdAt;
  // Removed AI-generated content fields that are no longer used
  final String? waterParametersResponse;
  final String? tankAnalysisResponse;
  final String? filtrationResponse;
  final String? dietCareResponse;
  final bool archived;
  final DateTime? archivedAt;

  WaterCalculation({
    this.id,
    required this.minimumTankVolume,
    required this.fishSelections,
    required this.recommendedQuantities,
    required this.dateCalculated,
    required this.phRange,
    required this.temperatureRange,
    required this.tankStatus,
    this.tankShape,
    this.waterRequirements,
    this.tankmateRecommendations,
    this.feedingInformation,
    this.createdAt,
    this.waterParametersResponse,
    this.tankAnalysisResponse,
    this.filtrationResponse,
    this.dietCareResponse,
    this.archived = false,
    this.archivedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'minimum_tank_volume': minimumTankVolume,
      'fish_selections': fishSelections,
      'recommended_quantities': recommendedQuantities,
      'date_calculated': dateCalculated.toIso8601String(),
      'ph_range': phRange,
      'temperature_range': temperatureRange,
      'tank_status': tankStatus,
      'tank_shape': tankShape,
      'water_requirements': waterRequirements,
      'tankmate_recommendations': tankmateRecommendations,
      'feeding_information': feedingInformation,
      'created_at': createdAt?.toIso8601String(),
      'water_parameters_response': waterParametersResponse,
      'tank_analysis_response': tankAnalysisResponse,
      'filtration_response': filtrationResponse,
      'diet_care_response': dietCareResponse,
      'archived': archived,
      'archived_at': archivedAt?.toIso8601String(),
    };
  }

  factory WaterCalculation.fromJson(Map<String, dynamic> json) {
    return WaterCalculation(
      id: json['id'],
      minimumTankVolume: json['minimum_tank_volume'] ?? json['minimumTankVolume'],
      fishSelections: Map<String, int>.from(json['fish_selections'] ?? json['fishSelections']),
      recommendedQuantities: Map<String, int>.from(json['recommended_quantities'] ?? json['recommendedQuantities'] ?? {}),
      dateCalculated: DateTime.parse(json['date_calculated'] ?? json['dateCalculated']),
      phRange: json['ph_range'] ?? json['phRange'],
      temperatureRange: json['temperature_range'] ?? json['temperatureRange'],
      tankStatus: json['tank_status'] ?? json['tankStatus'] ?? 'Unknown',
      tankShape: json['tank_shape'],
      waterRequirements: json['water_requirements'] != null 
          ? (json['water_requirements'] is String 
              ? Map<String, dynamic>.from(jsonDecode(json['water_requirements']))
              : Map<String, dynamic>.from(json['water_requirements']))
          : null,
      tankmateRecommendations: json['tankmate_recommendations'] != null 
          ? List<String>.from(json['tankmate_recommendations']) 
          : null,
      feedingInformation: json['feeding_information'] != null 
          ? (json['feeding_information'] is String 
              ? Map<String, dynamic>.from(jsonDecode(json['feeding_information']))
              : Map<String, dynamic>.from(json['feeding_information']))
          : null,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      waterParametersResponse: json['water_parameters_response'],
      tankAnalysisResponse: json['tank_analysis_response'],
      filtrationResponse: json['filtration_response'],
      dietCareResponse: json['diet_care_response'],
      archived: json['archived'] ?? false,
      archivedAt: json['archived_at'] != null ? DateTime.parse(json['archived_at']) : null,
    );
  }
} 