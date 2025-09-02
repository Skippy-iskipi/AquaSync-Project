class DietCalculation {
  final String? id;
  final Map<String, int> fishSelections;
  final int totalPortion;
  final String? totalPortionRange;
  final Map<String, dynamic> portionDetails;
  final List<String>? compatibilityIssues;
  final String? feedingNotes;
  final String? feedingTips;
  final int? feedingsPerDay;
  final String? feedingTimes;
  final List<String>? aiFoodTypes;
  final Map<String, dynamic>? tankTotalsByFood;
  final DateTime dateCalculated;
  final DateTime? createdAt;
  final String savedPlan;

  DietCalculation({
    this.id,
    required this.fishSelections,
    required this.totalPortion,
    this.totalPortionRange,
    required this.portionDetails,
    this.compatibilityIssues,
    this.feedingNotes,
    this.feedingTips,
    this.feedingsPerDay,
    this.feedingTimes,
    this.aiFoodTypes,
    this.tankTotalsByFood,
    required this.dateCalculated,
    this.createdAt,
    this.savedPlan = 'free',
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fish_selections': fishSelections,
      'total_portion': totalPortion,
      if (totalPortionRange != null) 'total_portion_range': totalPortionRange,
      'portion_details': portionDetails,
      'compatibility_issues': compatibilityIssues,
      'feeding_notes': feedingNotes,
      'feeding_tips': feedingTips,
      'feedings_per_day': feedingsPerDay,
      'feeding_times': feedingTimes,
      'ai_food_types': aiFoodTypes,
      'tank_totals_by_food': tankTotalsByFood,
      'date_calculated': dateCalculated.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'saved_plan': savedPlan,
    };
  }

  factory DietCalculation.fromJson(Map<String, dynamic> json) {
    return DietCalculation(
      id: json['id']?.toString(),
      fishSelections: Map<String, int>.from(json['fish_selections'] ?? {}),
      totalPortion: json['total_portion'] ?? 0,
      totalPortionRange: json['total_portion_range']?.toString(),
      portionDetails: Map<String, dynamic>.from(json['portion_details'] ?? {}),
      compatibilityIssues: json['compatibility_issues'] != null 
          ? List<String>.from(json['compatibility_issues']) 
          : null,
      feedingNotes: json['feeding_notes']?.toString(),
      feedingTips: json['feeding_tips']?.toString(),
      feedingsPerDay: json['feedings_per_day'] is int
          ? json['feedings_per_day'] as int
          : int.tryParse(json['feedings_per_day']?.toString() ?? ''),
      feedingTimes: json['feeding_times']?.toString(),
      aiFoodTypes: json['ai_food_types'] != null 
          ? List<String>.from(json['ai_food_types']) 
          : null,
      tankTotalsByFood: json['tank_totals_by_food'] != null 
          ? Map<String, dynamic>.from(json['tank_totals_by_food']) 
          : null,
      dateCalculated: DateTime.parse(json['date_calculated']),
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      savedPlan: json['saved_plan']?.toString() ?? 'free',
    );
  }
}
