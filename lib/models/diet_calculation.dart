class DietCalculation {
  final String? id;
  final Map<String, int> fishSelections;
  final int totalPortion;
  final Map<String, dynamic> portionDetails;
  final List<String>? compatibilityIssues;
  final String? feedingNotes;
  final String? feedingSchedule;
  final String? totalFoodPerFeeding;
  final Map<String, dynamic>? perFishBreakdown;
  final List<String>? recommendedFoodTypes;
  final String? feedingTips;
  final DateTime dateCalculated;
  final DateTime? createdAt;
  final String savedPlan;

  DietCalculation({
    this.id,
    required this.fishSelections,
    required this.totalPortion,
    required this.portionDetails,
    this.compatibilityIssues,
    this.feedingNotes,
    this.feedingSchedule,
    this.totalFoodPerFeeding,
    this.perFishBreakdown,
    this.recommendedFoodTypes,
    this.feedingTips,
    required this.dateCalculated,
    this.createdAt,
    this.savedPlan = 'free',
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fish_selections': fishSelections,
      'total_portion': totalPortion,
      'portion_details': portionDetails,
      'compatibility_issues': compatibilityIssues,
      'feeding_notes': feedingNotes,
      'feeding_schedule': feedingSchedule,
      'total_food_per_feeding': totalFoodPerFeeding,
      'per_fish_breakdown': perFishBreakdown,
      'recommended_food_types': recommendedFoodTypes,
      'feeding_tips': feedingTips,
      'date_calculated': dateCalculated.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'saved_plan': savedPlan,
    };
  }

  factory DietCalculation.fromJson(Map<String, dynamic> json) {
    return DietCalculation(
      id: json['id']?.toString(),
      fishSelections: Map<String, int>.from(json['fish_selections'] ?? {}),
      totalPortion: (json['total_portion'] ?? 0).toInt(),
      portionDetails: Map<String, dynamic>.from(json['portion_details'] ?? {}),
      compatibilityIssues: json['compatibility_issues'] != null 
          ? List<String>.from(json['compatibility_issues']) 
          : null,
      feedingNotes: json['feeding_notes']?.toString(),
      feedingSchedule: json['feeding_schedule']?.toString(),
      totalFoodPerFeeding: json['total_food_per_feeding']?.toString(),
      perFishBreakdown: json['per_fish_breakdown'] != null 
          ? Map<String, dynamic>.from(json['per_fish_breakdown']) 
          : null,
      recommendedFoodTypes: json['recommended_food_types'] != null 
          ? List<String>.from(json['recommended_food_types']) 
          : null,
      feedingTips: json['feeding_tips']?.toString(),
      dateCalculated: DateTime.parse(json['date_calculated']),
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      savedPlan: json['saved_plan']?.toString() ?? 'free',
    );
  }
}
