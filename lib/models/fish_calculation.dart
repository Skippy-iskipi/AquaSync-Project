class FishCalculation {
  final String? id;
  final String tankVolume;
  final Map<String, int> fishSelections;
  final Map<String, int> recommendedQuantities;
  final DateTime dateCalculated;
  final String phRange;
  final String temperatureRange;
  final String tankStatus;
  final String currentBioload;
  final DateTime? createdAt;

  FishCalculation({
    this.id,
    required this.tankVolume,
    required this.fishSelections,
    required this.recommendedQuantities,
    required this.dateCalculated,
    required this.phRange,
    required this.temperatureRange,
    required this.tankStatus,
    required this.currentBioload,
    this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tank_volume': tankVolume,
      'fish_selections': fishSelections,
      'recommended_quantities': recommendedQuantities,
      'date_calculated': dateCalculated.toIso8601String(),
      'ph_range': phRange,
      'temperature_range': temperatureRange,
      'tank_status': tankStatus,
      'current_bioload': currentBioload,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  factory FishCalculation.fromJson(Map<String, dynamic> json) {
    return FishCalculation(
      id: json['id'],
      tankVolume: json['tank_volume'] ?? json['tankVolume'],
      fishSelections: Map<String, int>.from(json['fish_selections'] ?? json['fishSelections']),
      recommendedQuantities: Map<String, int>.from(json['recommended_quantities'] ?? json['recommendedQuantities'] ?? {}),
      dateCalculated: DateTime.parse(json['date_calculated'] ?? json['dateCalculated']),
      phRange: json['ph_range'] ?? json['phRange'],
      temperatureRange: json['temperature_range'] ?? json['temperatureRange'],
      tankStatus: json['tank_status'] ?? json['tankStatus'] ?? 'Unknown',
      currentBioload: json['current_bioload'] ?? json['currentBioload'] ?? '0%',
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
    );
  }
} 