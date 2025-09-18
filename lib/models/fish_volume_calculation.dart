class FishVolumeCalculation {
  final String? id;
  final String tankShape;
  final String tankVolume;
  final Map<String, int> fishSelections;
  final Map<String, int> recommendedQuantities;
  final List<String>? tankmateRecommendations;
  final Map<String, dynamic> waterRequirements;
  final Map<String, dynamic> feedingInformation;
  final DateTime dateCalculated;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  FishVolumeCalculation({
    this.id,
    required this.tankShape,
    required this.tankVolume,
    required this.fishSelections,
    required this.recommendedQuantities,
    this.tankmateRecommendations,
    required this.waterRequirements,
    required this.feedingInformation,
    required this.dateCalculated,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tank_shape': tankShape,
      'tank_volume': tankVolume,
      'fish_selections': fishSelections,
      'recommended_quantities': recommendedQuantities,
      'tankmate_recommendations': tankmateRecommendations,
      'water_requirements': waterRequirements,
      'feeding_information': feedingInformation,
      'date_calculated': dateCalculated.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory FishVolumeCalculation.fromJson(Map<String, dynamic> json) {
    return FishVolumeCalculation(
      id: json['id'],
      tankShape: json['tank_shape'] ?? '',
      tankVolume: json['tank_volume'] ?? '',
      fishSelections: Map<String, int>.from(json['fish_selections'] ?? {}),
      recommendedQuantities: Map<String, int>.from(json['recommended_quantities'] ?? {}),
      tankmateRecommendations: json['tankmate_recommendations'] != null 
          ? List<String>.from(json['tankmate_recommendations']) 
          : null,
      waterRequirements: Map<String, dynamic>.from(json['water_requirements'] ?? {}),
      feedingInformation: Map<String, dynamic>.from(json['feeding_information'] ?? {}),
      dateCalculated: DateTime.parse(json['date_calculated'] ?? DateTime.now().toIso8601String()),
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  FishVolumeCalculation copyWith({
    String? id,
    String? tankShape,
    String? tankVolume,
    Map<String, int>? fishSelections,
    Map<String, int>? recommendedQuantities,
    List<String>? tankmateRecommendations,
    Map<String, dynamic>? waterRequirements,
    Map<String, dynamic>? feedingInformation,
    DateTime? dateCalculated,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FishVolumeCalculation(
      id: id ?? this.id,
      tankShape: tankShape ?? this.tankShape,
      tankVolume: tankVolume ?? this.tankVolume,
      fishSelections: fishSelections ?? this.fishSelections,
      recommendedQuantities: recommendedQuantities ?? this.recommendedQuantities,
      tankmateRecommendations: tankmateRecommendations ?? this.tankmateRecommendations,
      waterRequirements: waterRequirements ?? this.waterRequirements,
      feedingInformation: feedingInformation ?? this.feedingInformation,
      dateCalculated: dateCalculated ?? this.dateCalculated,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
