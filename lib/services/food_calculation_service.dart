import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'openai_service.dart';

class FoodCalculationService {
  // Based on research: Small fish consume 0.5-1% of body weight daily in dry food
  static final SupabaseClient _supabase = Supabase.instance.client;

  // Food densities (grams per unit) - based on research
  static const Map<String, double> _foodDensities = {
    'flakes': 0.3, // grams per teaspoon
    'pellets': 1.5, // grams per teaspoon
    'micro pellets': 1.2, // grams per teaspoon
    'algae wafers': 2.0, // grams per wafer
    'frozen food': 5.0, // grams per cube
    'bloodworms': 0.8, // grams per teaspoon
    'brine shrimp': 0.6, // grams per teaspoon
  };

  /// Calculate daily food consumption for fish selections
  static Future<Map<String, double>> calculateDailyConsumption(Map<String, int> fishSelections) async {
    Map<String, double> dailyConsumption = {};
    
    for (var entry in fishSelections.entries) {
      String fishName = entry.key;
      int quantity = entry.value;
      
      // Get fish weight from database or AI
      double fishWeight = await _getFishWeight(fishName);
      
      // Calculate daily consumption: 0.75% of body weight (middle of 0.5-1% range)
      double dailyPerFish = fishWeight * 0.0075; // 0.75% in decimal
      double totalDaily = dailyPerFish * quantity;
      
      dailyConsumption[entry.key] = totalDaily;
    }
    
    return dailyConsumption;
  }

  /// Calculate how long food will last with professional inventory management including expiration and spoilage
  static Future<Map<String, dynamic>> calculateFoodDuration({
    required Map<String, int> fishSelections,
    required String foodType,
    required double containerSizeGrams,
  }) async {
    // Calculate total daily consumption for all fish
    Map<String, double> dailyConsumption = await calculateDailyConsumption(fishSelections);
    double totalDailyGrams = dailyConsumption.values.fold(0.0, (sum, consumption) => sum + consumption);
    
    if (totalDailyGrams <= 0) {
      return {
        'duration_days': 0,
        'duration_readable': 'No consumption data',
        'recommendation': 'Unable to calculate without fish consumption data',
        'urgency': 'info',
      };
    }
    
    // Calculate basic duration in days
    double durationDays = containerSizeGrams / totalDailyGrams;
    
    // Get feed shelf life information
    final shelfLifeInfo = _getFeedShelfLife(foodType);
    final maxShelfLifeDays = shelfLifeInfo['shelf_life_days'] as int;
    final optimalUseDays = shelfLifeInfo['optimal_use_days'] as int;
    
    // Calculate realistic usage timeline
    final effectiveDays = durationDays.clamp(0, maxShelfLifeDays.toDouble()).toInt();
    final recommendedPurchaseAmount = _calculateOptimalPurchaseAmount(totalDailyGrams, optimalUseDays);
    
    String recommendation = '';
    String urgency = 'normal';
    String readableDuration = '';
    
    // Professional inventory analysis
    if (durationDays > maxShelfLifeDays) {
      recommendation = 'EXCESS: Will spoil before use! Food expires in $maxShelfLifeDays days but will last ${durationDays.toInt()} days. Buy ${recommendedPurchaseAmount.toInt()}g instead for optimal freshness.';
      urgency = 'warning';
      readableDuration = '${effectiveDays} days (will spoil)';
    } else if (durationDays > optimalUseDays) {
      recommendation = 'LARGE SUPPLY: Will last ${durationDays.toInt()} days but optimal freshness is ${optimalUseDays} days. Consider buying ${recommendedPurchaseAmount.toInt()}g portions for better nutrition.';
      urgency = 'info';
      readableDuration = _formatDuration(durationDays.toInt());
    } else if (durationDays < 7) {
      recommendation = 'LOW STOCK: Only ${durationDays.toInt()} days remaining. Purchase ${recommendedPurchaseAmount.toInt()}g soon to avoid running out.';
      urgency = 'urgent';
      readableDuration = '${durationDays.toInt()} days';
    } else if (durationDays < 14) {
      recommendation = 'RESTOCK SOON: ${durationDays.toInt()} days remaining. Plan to purchase ${recommendedPurchaseAmount.toInt()}g within a week.';
      urgency = 'attention';
      readableDuration = _formatDuration(durationDays.toInt());
    } else {
      recommendation = 'GOOD LEVEL: ${durationDays.toInt()} days supply. Next purchase recommended in ${(durationDays - 7).toInt()} days with ${recommendedPurchaseAmount.toInt()}g.';
      urgency = 'normal';
      readableDuration = _formatDuration(durationDays.toInt());
    }
    
    return {
      'duration_days': durationDays.round(),
      'effective_days': effectiveDays,
      'duration_readable': readableDuration,
      'daily_consumption_grams': totalDailyGrams,
      'weekly_consumption_grams': totalDailyGrams * 7,
      'monthly_consumption_grams': totalDailyGrams * 30,
      'shelf_life_days': maxShelfLifeDays,
      'optimal_use_days': optimalUseDays,
      'recommended_purchase_amount': recommendedPurchaseAmount,
      'recommendation': recommendation,
      'urgency': urgency,
      'will_spoil': durationDays > maxShelfLifeDays,
      'food_type': foodType,
      'container_size_grams': containerSizeGrams,
    };
  }

  /// Get feed shelf life information based on feed type
  static Map<String, dynamic> _getFeedShelfLife(String foodType) {
    final foodTypeLower = foodType.toLowerCase();
    
    // Dry feeds (pellets, flakes)
    if (foodTypeLower.contains('pellet') || foodTypeLower.contains('flake') || 
        foodTypeLower.contains('wafer') || foodTypeLower.contains('stick')) {
      return {
        'shelf_life_days': 365, // 1 year unopened, 3-6 months opened
        'optimal_use_days': 90,  // 3 months for best nutrition
      };
    }
    
    // Freeze-dried foods
    if (foodTypeLower.contains('freeze-dried') || foodTypeLower.contains('freeze dried')) {
      return {
        'shelf_life_days': 730, // 2 years
        'optimal_use_days': 180, // 6 months for best quality
      };
    }
    
    // Frozen foods
    if (foodTypeLower.contains('frozen')) {
      return {
        'shelf_life_days': 365, // 1 year frozen
        'optimal_use_days': 180, // 6 months for best quality
      };
    }
    
    // Live foods (very short shelf life)
    if (foodTypeLower.contains('live')) {
      return {
        'shelf_life_days': 7,   // 1 week maximum
        'optimal_use_days': 3,  // 3 days for best quality
      };
    }
    
    // Vegetables and fresh foods
    if (foodTypeLower.contains('vegetable') || foodTypeLower.contains('fruit') || 
        foodTypeLower.contains('blanched')) {
      return {
        'shelf_life_days': 5,   // 5 days refrigerated
        'optimal_use_days': 2,  // 2 days for best nutrition
      };
    }
    
    // Default for other feeds
    return {
      'shelf_life_days': 180, // 6 months
      'optimal_use_days': 60,  // 2 months
    };
  }

  /// Calculate optimal purchase amount based on consumption and freshness
  static double _calculateOptimalPurchaseAmount(double dailyConsumption, int optimalUseDays) {
    // Add 10% buffer for safety
    return (dailyConsumption * optimalUseDays * 1.1).ceil().toDouble();
  }

  /// Format duration into readable text
  static String _formatDuration(int days) {
    if (days < 7) {
      return '$days days';
    } else if (days < 30) {
      int weeks = (days / 7).floor();
      int remainingDays = days % 7;
      return remainingDays > 0 ? '$weeks weeks, $remainingDays days' : '$weeks weeks';
    } else if (days < 365) {
      int months = (days / 30).floor();
      return '$months months';
    } else {
      int years = (days / 365).floor();
      return '$years year${years > 1 ? 's' : ''}';
    }
  }

  /// Get standard container sizes for different food types
  static List<Map<String, dynamic>> getStandardContainerSizes(String foodType) {
    switch (foodType.toLowerCase()) {
      case 'flakes':
        return [
          {'size': '28g', 'grams': 28.0, 'description': 'Small container'},
          {'size': '62g', 'grams': 62.0, 'description': 'Medium container'},
          {'size': '142g', 'grams': 142.0, 'description': 'Large container'},
          {'size': '284g', 'grams': 284.0, 'description': 'Extra large container'},
        ];
      case 'pellets':
      case 'micro pellets':
        return [
          {'size': '45g', 'grams': 45.0, 'description': 'Small container'},
          {'size': '113g', 'grams': 113.0, 'description': 'Medium container'},
          {'size': '227g', 'grams': 227.0, 'description': 'Large container'},
          {'size': '454g', 'grams': 454.0, 'description': 'Extra large container'},
        ];
      case 'algae wafers':
        return [
          {'size': '85g', 'grams': 85.0, 'description': 'Small container'},
          {'size': '170g', 'grams': 170.0, 'description': 'Medium container'},
          {'size': '340g', 'grams': 340.0, 'description': 'Large container'},
        ];
      default:
        return [
          {'size': '50g', 'grams': 50.0, 'description': 'Small container'},
          {'size': '100g', 'grams': 100.0, 'description': 'Medium container'},
          {'size': '200g', 'grams': 200.0, 'description': 'Large container'},
        ];
    }
  }

  /// Calculate portion size recommendation based on fish and quantity
  static Future<Map<String, dynamic>> calculatePortionSize({
    required String fishName,
    required int quantity,
    required String foodType,
  }) async {
    double fishWeight = await _getFishWeight(fishName);
    double dailyPerFish = fishWeight * 0.0075; // 0.75% of body weight
    double totalDaily = dailyPerFish * quantity;
    
    // Divide by feeding frequency (typically 2 times per day)
    double portionPerFeeding = totalDaily / 2;
    
    // Convert to user-friendly measurements
    String portionDescription = _convertToUserFriendlyPortion(portionPerFeeding, foodType);
    
    return {
      'portion_grams': portionPerFeeding,
      'portion_description': portionDescription,
      'daily_total_grams': totalDaily,
      'feeding_frequency': 2,
      'food_type': foodType,
    };
  }

  /// Get fish weight from database or AI with fallback
  static Future<double> _getFishWeight(String fishName) async {
    try {
      // Get fish size from database
      final response = await _supabase
          .from('fish_species')
          .select('"max_size_(cm)"')
          .ilike('common_name', '%$fishName%')
          .limit(1);

      if (response.isNotEmpty) {
        final fishData = response.first;
        
        // Calculate weight from max_size_(cm) using fish weight formula
        if (fishData['max_size_(cm)'] != null) {
          final sizeCm = double.tryParse(fishData['max_size_(cm)'].toString());
          if (sizeCm != null && sizeCm > 0) {
            // Fish weight formula for aquarium fish: Weight ≈ 0.12 * (length_cm)^2.8
            // This is more accurate for small aquarium fish than the cubic formula
            return 0.12 * pow(sizeCm, 2.8);
          }
        }
      }

      // If database lookup fails, try AI estimation
      return await _getAIEstimatedWeight(fishName);
      
    } catch (e) {
      print('Error getting fish weight from database: $e');
      // Fallback to AI estimation
      return await _getAIEstimatedWeight(fishName);
    }
  }

  /// Get AI-estimated fish weight
  static Future<double> _getAIEstimatedWeight(String fishName) async {
    try {
      final prompt = '''
      Estimate the average adult weight in grams for the fish species: $fishName
      
      Consider typical aquarium specimens, not wild maximum sizes.
      Return only a number (the weight in grams).
      
      Examples:
      - Neon tetra: 0.3
      - Guppy: 0.5  
      - Molly: 2.0
      - Angelfish: 15.0
      - Goldfish: 30.0
      ''';

      final aiResponse = await OpenAIService.getChatResponse(prompt);
      final weightStr = aiResponse.replaceAll(RegExp(r'[^0-9.]'), '');
      final weight = double.tryParse(weightStr);
      
      if (weight != null && weight > 0 && weight < 1000) {
        return weight;
      }
    } catch (e) {
      print('Error getting AI weight estimate: $e');
    }
    
    // Final fallback based on fish name patterns
    return _getFallbackWeight(fishName);
  }

  /// Fallback weight estimation based on fish name patterns
  static double _getFallbackWeight(String fishName) {
    final name = fishName.toLowerCase();
    
    // Small fish patterns
    if (name.contains('tetra') || name.contains('neon') || name.contains('rasbora')) {
      return 0.5;
    }
    if (name.contains('guppy') || name.contains('endler')) {
      return 0.5;
    }
    if (name.contains('danio') || name.contains('barb')) {
      return 1.0;
    }
    
    // Medium fish patterns  
    if (name.contains('molly') || name.contains('platy') || name.contains('swordtail')) {
      return 2.0;
    }
    if (name.contains('betta') || name.contains('gourami')) {
      return 3.0;
    }
    if (name.contains('corydoras') || name.contains('cory')) {
      return 3.0;
    }
    
    // Large fish patterns
    if (name.contains('angelfish') || name.contains('angel')) {
      return 15.0;
    }
    if (name.contains('discus')) {
      return 50.0;
    }
    if (name.contains('goldfish')) {
      return 30.0;
    }
    if (name.contains('cichlid')) {
      return 25.0;
    }
    if (name.contains('pleco') || name.contains('catfish')) {
      return 100.0;
    }
    
    // Default for unknown fish (small community fish average)
    return 2.0;
  }

  /// Convert grams to user-friendly portion descriptions
  static String _convertToUserFriendlyPortion(double grams, String foodType) {
    switch (foodType.toLowerCase()) {
      case 'flakes':
        if (grams < 0.1) return 'tiny pinch of flakes';
        if (grams < 0.2) return 'small pinch of flakes';
        if (grams < 0.4) return 'medium pinch of flakes';
        return 'large pinch of flakes';
        
      case 'pellets':
      case 'micro pellets':
        int pelletCount = (grams / 0.02).round(); // ~0.02g per small pellet
        if (pelletCount < 3) return '2-3 pellets';
        if (pelletCount < 6) return '4-5 pellets';
        if (pelletCount < 10) return '6-8 pellets';
        return '$pelletCount pellets';
        
      case 'algae wafers':
        double waferFraction = grams / 2.0; // 2g per wafer
        if (waferFraction < 0.25) return '1/4 algae wafer';
        if (waferFraction < 0.5) return '1/3 algae wafer';
        if (waferFraction < 1.0) return '1/2 algae wafer';
        return '${waferFraction.toStringAsFixed(1)} algae wafers';
        
      case 'frozen food':
        double cubes = grams / 5.0; // 5g per cube
        if (cubes < 0.5) return '1/4 frozen food cube';
        if (cubes < 1.0) return '1/2 frozen food cube';
        return '${cubes.toStringAsFixed(1)} frozen food cubes';
        
      default:
        if (grams < 0.1) return 'tiny amount';
        if (grams < 0.3) return 'small amount';
        if (grams < 0.6) return 'medium amount';
        return 'large amount';
    }
  }

  /// Get feeding recommendations based on fish types
  static Map<String, dynamic> getFeedingRecommendations(Map<String, int> fishSelections) {
    bool hasBottomFeeders = _hasBottomFeeders(fishSelections.keys.toList());
    bool hasLargeFish = _hasLargeFish(fishSelections.keys.toList());
    bool hasSmallFish = _hasSmallFish(fishSelections.keys.toList());
    
    List<String> recommendations = [];
    List<String> foodTypes = [];
    
    if (hasSmallFish) {
      foodTypes.add('flakes');
      foodTypes.add('micro pellets');
      recommendations.add('Use small flakes or micro pellets for small fish');
    }
    
    if (hasLargeFish) {
      foodTypes.add('pellets');
      recommendations.add('Use larger pellets for bigger fish');
    }
    
    if (hasBottomFeeders) {
      foodTypes.add('algae wafers');
      foodTypes.add('sinking pellets');
      recommendations.add('Add sinking food for bottom-dwelling fish');
    }
    
    recommendations.add('Feed 2 times daily');
    recommendations.add('Remove uneaten food after 5 minutes');
    
    return {
      'recommended_food_types': foodTypes,
      'feeding_tips': recommendations,
      'feeding_frequency': 2,
      'feeding_times': ['Morning', 'Evening'],
    };
  }

  static bool _hasBottomFeeders(List<String> fishNames) {
    List<String> bottomFeeders = ['corydoras', 'pleco', 'catfish', 'loach'];
    return fishNames.any((fish) => 
      bottomFeeders.any((bottom) => fish.toLowerCase().contains(bottom)));
  }

  static bool _hasLargeFish(List<String> fishNames) {
    List<String> largeFish = ['angelfish', 'discus', 'goldfish', 'cichlid', 'oscar'];
    return fishNames.any((fish) => 
      largeFish.any((large) => fish.toLowerCase().contains(large)));
  }

  static bool _hasSmallFish(List<String> fishNames) {
    List<String> smallFish = ['guppy', 'tetra', 'neon', 'rasbora', 'danio'];
    return fishNames.any((fish) => 
      smallFish.any((small) => fish.toLowerCase().contains(small)));
  }
}
