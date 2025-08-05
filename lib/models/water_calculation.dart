class WaterCalculation {
  final String? id;
  final String minimumTankVolume;
  final Map<String, int> fishSelections;
  final Map<String, int> recommendedQuantities;
  final DateTime dateCalculated;
  final String phRange;
  final String temperatureRange;
  final String tankStatus;
  final Map<String, String>? oxygenNeeds; // new
  final Map<String, String>? filtrationNeeds; // new
  final DateTime? createdAt;

  WaterCalculation({
    this.id,
    required this.minimumTankVolume,
    required this.fishSelections,
    required this.recommendedQuantities,
    required this.dateCalculated,
    required this.phRange,
    required this.temperatureRange,
    required this.tankStatus,
    this.oxygenNeeds,
    this.filtrationNeeds,
    this.createdAt,
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
      'oxygen_needs': oxygenNeeds,
      'filtration_needs': filtrationNeeds,
      'created_at': createdAt?.toIso8601String(),
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
      oxygenNeeds: json['oxygen_needs'] != null ? Map<String, String>.from(json['oxygen_needs']) : null,
      filtrationNeeds: json['filtration_needs'] != null ? Map<String, String>.from(json['filtration_needs']) : null,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
    );
  }
} 