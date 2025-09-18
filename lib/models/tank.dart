import 'dart:math' as math;

class Tank {
  final String? id;
  final String name;
  final String tankShape; // 'rectangle', 'bowl', 'cylinder'
  final double length;
  final double width;
  final double height;
  final String unit; // 'CM' or 'IN'
  final double volume; // Calculated volume in liters
  final Map<String, int> fishSelections; // fish name -> quantity
  final Map<String, dynamic> compatibilityResults; // Compatibility analysis
  final Map<String, dynamic> feedingRecommendations; // AI feeding recommendations
  final Map<String, int> recommendedFishQuantities; // AI recommended quantities per fish
  final Map<String, double> availableFeeds; // feed name -> quantity available (in grams)
  final Map<String, dynamic> feedInventory; // Detailed feed inventory
  final Map<String, dynamic> feedPortionData; // Portion per fish data
  final DateTime dateCreated;
  final DateTime? lastUpdated;
  final DateTime? createdAt;

  Tank({
    this.id,
    required this.name,
    required this.tankShape,
    required this.length,
    required this.width,
    required this.height,
    required this.unit,
    required this.volume,
    required this.fishSelections,
    required this.compatibilityResults,
    required this.feedingRecommendations,
    required this.recommendedFishQuantities,
    required this.availableFeeds,
    required this.feedInventory,
    required this.feedPortionData,
    required this.dateCreated,
    this.lastUpdated,
    this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'tank_shape': tankShape,
      'length': length,
      'width': width,
      'height': height,
      'unit': unit,
      'volume': volume,
      'fish_selections': fishSelections,
      'compatibility_results': compatibilityResults,
      'feeding_recommendations': feedingRecommendations,
      'recommended_fish_quantities': recommendedFishQuantities,
      'available_feeds': availableFeeds,
      'feed_inventory': feedInventory,
      'feed_portion_data': feedPortionData,
      'date_created': dateCreated.toIso8601String(),
      'last_updated': lastUpdated?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
    };
  }

  // Convert to database format for Supabase
  Map<String, dynamic> toDatabaseJson() {
    return {
      'id': id,
      'name': name,
      'tank_shape': tankShape,
      'length': length,
      'width': width,
      'height': height,
      'unit': unit,
      'volume': volume,
      'fish_selections': fishSelections,
      'compatibility_results': compatibilityResults,
      'feeding_recommendations': feedingRecommendations,
      'recommended_fish_quantities': recommendedFishQuantities,
      'available_feeds': availableFeeds,
      'feed_inventory': feedInventory,
      'feed_portion_data': feedPortionData,
      'date_created': dateCreated.toIso8601String(),
      'last_updated': lastUpdated?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
    };
  }

  factory Tank.fromJson(Map<String, dynamic> json) {
    try {
      return Tank(
        id: json['id']?.toString(),
        name: json['name'] ?? '',
        tankShape: json['tank_shape'] ?? 'rectangle',
        length: double.tryParse(json['length']?.toString() ?? '0') ?? 0.0,
        width: double.tryParse(json['width']?.toString() ?? '0') ?? 0.0,
        height: double.tryParse(json['height']?.toString() ?? '0') ?? 0.0,
        unit: json['unit'] ?? 'CM',
        volume: double.tryParse(json['volume']?.toString() ?? '0') ?? 0.0,
        fishSelections: Map<String, int>.from(json['fish_selections'] ?? {}),
        compatibilityResults: Map<String, dynamic>.from(json['compatibility_results'] ?? {}),
        feedingRecommendations: Map<String, dynamic>.from(json['feeding_recommendations'] ?? {}),
        recommendedFishQuantities: Map<String, int>.from(json['recommended_fish_quantities'] ?? {}),
        availableFeeds: _parseAvailableFeeds(json['available_feeds']),
        feedInventory: Map<String, dynamic>.from(json['feed_inventory'] ?? {}),
        feedPortionData: Map<String, dynamic>.from(json['feed_portion_data'] ?? {}),
        dateCreated: DateTime.parse(json['date_created']),
        lastUpdated: json['last_updated'] != null ? DateTime.parse(json['last_updated']) : null,
        createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      );
    } catch (e) {
      print('Error parsing Tank from JSON: $e');
      return Tank(
        id: json['id']?.toString(),
        name: json['name'] ?? 'Unknown Tank',
        tankShape: 'rectangle',
        length: 0.0,
        width: 0.0,
        height: 0.0,
        unit: 'CM',
        volume: 0.0,
        fishSelections: {},
        compatibilityResults: {},
        feedingRecommendations: {},
        recommendedFishQuantities: {},
        availableFeeds: {},
        feedInventory: {},
        feedPortionData: {},
        dateCreated: DateTime.now(),
        lastUpdated: null,
        createdAt: null,
      );
    }
  }

  // Helper method to safely parse available feeds from JSON
  static Map<String, double> _parseAvailableFeeds(dynamic feedsJson) {
    if (feedsJson == null) return {};
    
    try {
      if (feedsJson is Map) {
        final Map<String, double> result = {};
        feedsJson.forEach((key, value) {
          if (key is String) {
            final doubleValue = double.tryParse(value.toString()) ?? 0.0;
            result[key] = doubleValue;
          }
        });
        return result;
      }
    } catch (e) {
      print('Error parsing available feeds: $e');
    }
    
    return {};
  }

  Tank copyWith({
    String? id,
    String? name,
    String? tankShape,
    double? length,
    double? width,
    double? height,
    String? unit,
    double? volume,
    Map<String, int>? fishSelections,
    Map<String, dynamic>? compatibilityResults,
    Map<String, dynamic>? feedingRecommendations,
    Map<String, int>? recommendedFishQuantities,
    Map<String, double>? availableFeeds,
    Map<String, dynamic>? feedInventory,
    Map<String, dynamic>? feedPortionData,
    DateTime? dateCreated,
    DateTime? lastUpdated,
    DateTime? createdAt,
  }) {
    return Tank(
      id: id ?? this.id,
      name: name ?? this.name,
      tankShape: tankShape ?? this.tankShape,
      length: length ?? this.length,
      width: width ?? this.width,
      height: height ?? this.height,
      unit: unit ?? this.unit,
      volume: volume ?? this.volume,
      fishSelections: fishSelections ?? this.fishSelections,
      compatibilityResults: compatibilityResults ?? this.compatibilityResults,
      feedingRecommendations: feedingRecommendations ?? this.feedingRecommendations,
      recommendedFishQuantities: recommendedFishQuantities ?? this.recommendedFishQuantities,
      availableFeeds: availableFeeds ?? this.availableFeeds,
      feedInventory: feedInventory ?? this.feedInventory,
      feedPortionData: feedPortionData ?? this.feedPortionData,
      dateCreated: dateCreated ?? this.dateCreated,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // Calculate volume based on tank shape
  static double calculateVolume(String tankShape, double length, double width, double height, String unit) {
    // Convert to centimeters if needed
    double lengthCm = unit == 'CM' ? length : length * 2.54;
    double widthCm = unit == 'CM' ? width : width * 2.54;
    double heightCm = unit == 'CM' ? height : height * 2.54;

    // Validate inputs based on tank shape
    if (lengthCm <= 0 || heightCm <= 0) {
      return 0;
    }
    
    // For rectangle, width must be > 0
    if (tankShape == 'rectangle' && widthCm <= 0) {
      return 0;
    }

    double volumeLiters;
    
    switch (tankShape) {
      case 'rectangle':
        // Standard rectangular tank: L × W × H
        volumeLiters = (lengthCm * widthCm * heightCm) / 1000.0;
        break;
      case 'bowl':
        // Bowl tank: Fixed volume of 10L as specified
        volumeLiters = 10.0;
        break;
      case 'cylinder':
        // Cylindrical tank: π × r² × h
        // length = diameter, height = height
        final diameterCm = lengthCm;
        final cylinderHeight = heightCm;
        
        if (diameterCm <= 0 || cylinderHeight <= 0) {
          return 0;
        }
        
        final radius = diameterCm / 2.0;
        final cc = 3.14159265359 * radius * radius * cylinderHeight;
        volumeLiters = cc / 1000.0;
        break;
      default:
        // Default to rectangular calculation
        volumeLiters = (lengthCm * widthCm * heightCm) / 1000.0;
    }

    return volumeLiters;
  }

  // Get volume calculation steps for display
  static String getVolumeCalculationSteps(String tankShape, double length, double width, double height, String unit) {
    final lengthCm = unit == 'CM' ? length : length * 2.54;
    final widthCm = unit == 'CM' ? width : width * 2.54;
    final heightCm = unit == 'CM' ? height : height * 2.54;
    final volume = calculateVolume(tankShape, length, width, height, unit);

    switch (tankShape) {
      case 'rectangle':
        return '''
Rectangle Tank Volume Calculation:
Formula: V = Length × Width × Height

Step 1: Convert to centimeters (if needed)
Length: ${length.toStringAsFixed(1)} ${unit.toLowerCase()} = ${lengthCm.toStringAsFixed(1)} cm
Width: ${width.toStringAsFixed(1)} ${unit.toLowerCase()} = ${widthCm.toStringAsFixed(1)} cm
Height: ${height.toStringAsFixed(1)} ${unit.toLowerCase()} = ${heightCm.toStringAsFixed(1)} cm

Step 2: Calculate volume in cubic centimeters
V = ${lengthCm.toStringAsFixed(1)} × ${widthCm.toStringAsFixed(1)} × ${heightCm.toStringAsFixed(1)}
V = ${(lengthCm * widthCm * heightCm).toStringAsFixed(1)} cm³

Step 3: Convert to liters
V = ${(lengthCm * widthCm * heightCm).toStringAsFixed(1)} cm³ ÷ 1000 = ${volume.toStringAsFixed(2)} L

Final Result: ${volume.toStringAsFixed(2)} L (${(volume * 0.264172).toStringAsFixed(2)} US gallons)
''';
      case 'bowl':
        return '''
Bowl Tank Volume:
Fixed Volume: 10.0 L (${(10.0 * 0.264172).toStringAsFixed(2)} US gallons)

Note: Bowl tanks use a standardized volume for consistent calculations.
''';
      case 'cylinder':
        final radius = lengthCm / 2.0;
        final area = math.pi * radius * radius;
        return '''
Cylinder Tank Volume Calculation:
Formula: V = π × r² × h

Step 1: Convert to centimeters (if needed)
Diameter: ${length.toStringAsFixed(1)} ${unit.toLowerCase()} = ${lengthCm.toStringAsFixed(1)} cm
Height: ${height.toStringAsFixed(1)} ${unit.toLowerCase()} = ${heightCm.toStringAsFixed(1)} cm

Step 2: Calculate radius
Radius (r) = Diameter ÷ 2 = ${lengthCm.toStringAsFixed(1)} ÷ 2 = ${radius.toStringAsFixed(1)} cm

Step 3: Calculate base area
Area = π × r² = π × (${radius.toStringAsFixed(1)})² = π × ${(radius * radius).toStringAsFixed(1)}
Area = ${area.toStringAsFixed(1)} cm²

Step 4: Calculate volume in cubic centimeters
V = Area × Height = ${area.toStringAsFixed(1)} × ${heightCm.toStringAsFixed(1)}
V = ${(area * heightCm).toStringAsFixed(1)} cm³

Step 5: Convert to liters
V = ${(area * heightCm).toStringAsFixed(1)} cm³ ÷ 1000 = ${volume.toStringAsFixed(2)} L

Final Result: ${volume.toStringAsFixed(2)} L (${(volume * 0.264172).toStringAsFixed(2)} US gallons)
''';
      default:
        return 'Unknown tank shape';
    }
  }

  // Get compatibility status
  String getCompatibilityStatus() {
    if (compatibilityResults.isEmpty) return 'Unknown';
    
    final status = compatibilityResults['status'] as String?;
    if (status != null) {
      switch (status) {
        case 'compatible':
          return 'Compatible';
        case 'compatible_with_condition':
          return 'Compatible with Condition';
        case 'incompatible':
          return 'Incompatible';
        default:
          return 'Unknown';
      }
    }
    
    // Fallback to old logic
    final issues = compatibilityResults['compatibility_issues'] as List?;
    if (issues == null || issues.isEmpty) return 'Compatible';
    
    return 'Incompatible';
  }

  // Get days until feed runs out
  int? getDaysUntilFeedRunsOut(String feedName) {
    if (!availableFeeds.containsKey(feedName) || !feedingRecommendations.containsKey('daily_consumption')) {
      return null;
    }
    
    try {
      final availableAmountG = availableFeeds[feedName]!; // Available amount in grams
      final dailyConsumption = feedingRecommendations['daily_consumption'] as Map<String, dynamic>?;
      if (dailyConsumption == null) return null;
      
      // Calculate total daily consumption for this feed type across all fish
      double totalFeedConsumptionGPerDay = 0.0;
      
      // Sum up consumption for all fish that use this feed type
      for (final entry in dailyConsumption.entries) {
        final fishName = entry.key;
        final fishDailyConsumption = double.tryParse(entry.value.toString()) ?? 0.0;
        
        // Check if this fish uses this feed type by looking at feeding recommendations
        final portionText = feedingRecommendations['portion_per_feeding']?.toString() ?? '';
        if (portionText.toLowerCase().contains(fishName.toLowerCase()) && 
            portionText.toLowerCase().contains(feedName.toLowerCase())) {
          totalFeedConsumptionGPerDay += fishDailyConsumption;
        }
      }
      
      final feedConsumptionGPerDay = totalFeedConsumptionGPerDay;
      
      if (feedConsumptionGPerDay <= 0) return null;
      
      final daysRemaining = (availableAmountG / feedConsumptionGPerDay).floor();
      
      return daysRemaining;
    } catch (e) {
      print('Error calculating days until feed runs out for $feedName: $e');
      return null;
    }
  }

  // Get all feed inventory durations
  Map<String, int> getAllFeedDurations() {
    final Map<String, int> durations = {};
    
    for (final feedName in availableFeeds.keys) {
      final days = getDaysUntilFeedRunsOut(feedName);
      if (days != null) {
        durations[feedName] = days;
      }
    }
    
    return durations;
  }

  // Get the shortest duration (most critical feed)
  int? getShortestFeedDuration() {
    final durations = getAllFeedDurations();
    if (durations.isEmpty) return null;
    
    return durations.values.reduce((a, b) => a < b ? a : b);
  }

  // Get feed inventory summary text
  String getFeedInventorySummary() {
    final durations = getAllFeedDurations();
    if (durations.isEmpty) return 'No feed data available';
    
    final shortest = getShortestFeedDuration();
    if (shortest == null) return 'No feed data available';
    
    if (durations.length == 1) {
      final feedName = durations.keys.first;
      final days = durations[feedName]!;
      return '$feedName: $days days';
    } else {
      return 'Shortest: $shortest days (${durations.length} feeds)';
    }
  }

  // Calculate recommended fish quantities based on tank volume and fish requirements
  static Future<Map<String, int>> calculateRecommendedFishQuantities(
    double tankVolumeLiters,
    Map<String, int> currentFishSelections,
    Map<String, dynamic> compatibilityResults,
    Map<String, double> fishVolumeRequirements,
  ) async {
    final Map<String, int> recommendations = {};
    print('--- Calculating Fish Recommendations ---');
    print('Tank Volume: ${tankVolumeLiters.toStringAsFixed(2)} L (${(tankVolumeLiters * 0.264172).toStringAsFixed(1)} US gal)');
    print('Selected Species: ${currentFishSelections.keys.toList()}');

    // Check compatibility first
    if (compatibilityResults['status'] == 'incompatible') {
      print('Species are incompatible - returning zero recommendations');
      for (final fishName in currentFishSelections.keys) {
        recommendations[fishName] = 0;
      }
      return recommendations;
    }

    // Get fish data for each species
    final Map<String, Map<String, dynamic>> speciesData = {};
    for (final fishName in currentFishSelections.keys) {
      speciesData[fishName] = await _getSpeciesData(fishName);
    }

    // Apply constraint-based stocking calculation
    final stocking = await _solveStockingConstraints(
      tankVolumeLiters,
      speciesData,
      compatibilityResults,
    );

    recommendations.addAll(stocking);

    // Final logging
    double totalVolume = 0.0;
    for (final entry in recommendations.entries) {
      final data = speciesData[entry.key]!;
      final volume = entry.value * (data['volume_per_fish_L'] as double);
      totalVolume += volume;
      
      print('${entry.key}: ${entry.value} fish');
      print(' -> Total volume: ${volume.toStringAsFixed(2)} L');
    }
    
    print('--- Final Validation ---');
    print('Total volume used: ${totalVolume.toStringAsFixed(2)} L / ${tankVolumeLiters.toStringAsFixed(2)} L (${(totalVolume/tankVolumeLiters*100).toStringAsFixed(1)}%)');
    
    return recommendations;
  }

  // Get species data with bioload calculations
  static Future<Map<String, dynamic>> _getSpeciesData(String fishName) async {
    final fishNameLower = fishName.toLowerCase();
    
    // Species data based on adult size, waste production, and hobby practices
    final Map<String, Map<String, dynamic>> speciesData = {
      'guppy': {
        'bioload_factor': 1.0,
        'volume_per_fish_L': 7.0,
        'adult_size_cm': 4.0,
        'waste_production': 'low',
        'schooling_min': 6,
        'max_recommended_per_40L': 5,
        'sex_ratio_suggestion': '1 male : 2-3 females',
        'daily_food_consumption_g': 0.05,
        'breeding_rate': 'high',
      },
      'molly': {
        'bioload_factor': 2.5,
        'volume_per_fish_L': 12.0,
        'adult_size_cm': 8.0,
        'waste_production': 'medium-high',
        'schooling_min': 4,
        'max_recommended_per_40L': 3,
        'sex_ratio_suggestion': '1 male : 2-3 females',
        'daily_food_consumption_g': 0.10,
        'breeding_rate': 'high',
      },
      'platy': {
        'bioload_factor': 1.8,
        'volume_per_fish_L': 8.0,
        'adult_size_cm': 6.0,
        'waste_production': 'medium',
        'schooling_min': 4,
        'max_recommended_per_40L': 5,
        'sex_ratio_suggestion': '1 male : 2 females',
        'daily_food_consumption_g': 0.07,
        'breeding_rate': 'high',
      },
      'neon tetra': {
        'bioload_factor': 0.5,
        'volume_per_fish_L': 3.0,
        'adult_size_cm': 3.0,
        'waste_production': 'very low',
        'schooling_min': 8,
        'max_recommended_per_40L': 13,
        'sex_ratio_suggestion': 'mixed group',
        'daily_food_consumption_g': 0.02,
        'breeding_rate': 'low',
      },
      'betta': {
        'bioload_factor': 1.5,
        'volume_per_fish_L': 19.0, // 5+ gallons minimum
        'adult_size_cm': 6.0,
        'waste_production': 'medium',
        'schooling_min': 1,
        'max_recommended_per_40L': 1,
        'sex_ratio_suggestion': '1 male only (territorial)',
        'daily_food_consumption_g': 0.06,
        'breeding_rate': 'controlled',
      },
      'goldfish': {
        'bioload_factor': 10.0,
        'volume_per_fish_L': 75.0,
        'adult_size_cm': 20.0,
        'waste_production': 'very high',
        'schooling_min': 1,
        'max_recommended_per_40L': 0,
        'sex_ratio_suggestion': 'research breeding requirements',
        'daily_food_consumption_g': 0.20,
        'breeding_rate': 'high',
      },
    };

    // Find matching species
    for (final entry in speciesData.entries) {
      if (fishNameLower.contains(entry.key) || entry.key.contains(fishNameLower)) {
        return entry.value;
      }
    }

    // Conservative default for unknown species
    return {
      'bioload_factor': 1.5,
      'volume_per_fish_L': 5.7,
      'adult_size_cm': 5.0,
      'waste_production': 'medium',
      'schooling_min': 1,
      'max_recommended_per_40L': 6,
      'sex_ratio_suggestion': 'research species requirements',
      'daily_food_consumption_g': 0.06,
      'breeding_rate': 'unknown',
    };
  }

  // Solve stocking constraints
  static Future<Map<String, int>> _solveStockingConstraints(
    double tankVolumeLiters,
    Map<String, Map<String, dynamic>> speciesData,
    Map<String, dynamic> compatibilityResults,
  ) async {
    final Map<String, int> stocking = {};
    final species = speciesData.keys.toList();
    
    if (species.length == 1) {
      // Single species - maximize within constraints
      final speciesName = species.first;
      final data = speciesData[speciesName]!;
      final maxByVolume = (tankVolumeLiters / (data['volume_per_fish_L'] as double)).floor();
      final maxByBioload = ((tankVolumeLiters / 40.0) * (data['max_recommended_per_40L'] as int)).floor();
      final schoolingMin = data['schooling_min'] as int;
      
      final maxPossible = [maxByVolume, maxByBioload].reduce((a, b) => a < b ? a : b);
      final minRequired = schoolingMin;
      
      stocking[speciesName] = maxPossible >= minRequired ? 
        maxPossible.clamp(minRequired, 50) : 
        maxPossible.clamp(1, 50);
    } else if (species.length == 2) {
      // Two species - apply specific pairing rules
      await _solveTwoSpeciesConstraints(tankVolumeLiters, species, speciesData, stocking);
    } else {
      // Multiple species - conservative general approach
      await _solveMultiSpeciesConstraints(tankVolumeLiters, species, speciesData, stocking);
    }

    // Apply compatibility reductions
    if (compatibilityResults['status'] == 'compatible_with_condition') {
      for (final key in stocking.keys) {
        stocking[key] = (stocking[key]! * 0.8).floor().clamp(1, stocking[key]!);
      }
      print('Applied 20% reduction for conditional compatibility');
    }

    return stocking;
  }

  // Solve constraints for two-species tanks
  static Future<void> _solveTwoSpeciesConstraints(
    double tankVolumeLiters,
    List<String> species,
    Map<String, Map<String, dynamic>> speciesData,
    Map<String, int> stocking,
  ) async {
    final species1 = species[0];
    final species2 = species[1];
    final data1 = speciesData[species1]!;
    final data2 = speciesData[species2]!;
    
    // General two-species constraint solving
    final v1 = data1['volume_per_fish_L'] as double;
    final v2 = data2['volume_per_fish_L'] as double;
    final min1 = data1['schooling_min'] as int;
    final min2 = data2['schooling_min'] as int;
    
    // Try different ratios and pick the best valid solution
    final solutions = <Map<String, int>>[];
    
    // Equal priority approach
    for (int n1 = min1; n1 <= 20; n1++) {
      final remainingVolume = tankVolumeLiters - (n1 * v1);
      final maxN2 = (remainingVolume / v2).floor();
      if (maxN2 >= min2) {
        solutions.add({species1: n1, species2: maxN2.clamp(min2, 20)});
      }
    }
    
    if (solutions.isNotEmpty) {
      // Pick solution with best total fish count within reason
      final bestSolution = solutions.reduce((a, b) {
        final totalA = a.values.reduce((x, y) => x + y);
        final totalB = b.values.reduce((x, y) => x + y);
        return totalA > totalB ? a : b;
      });
      stocking.addAll(bestSolution);
    } else {
      // Tank too small - minimal stocking
      stocking[species1] = min1;
      stocking[species2] = 0;
    }
  }

  // Solve constraints for multiple species
  static Future<void> _solveMultiSpeciesConstraints(
    double tankVolumeLiters,
    List<String> species,
    Map<String, Map<String, dynamic>> speciesData,
    Map<String, int> stocking,
  ) async {
    // Very conservative approach for 3+ species
    double remainingVolume = tankVolumeLiters * 0.7; // Use only 70% for multi-species
    
    // Sort by bioload (heaviest first for conservative allocation)
    final sortedSpecies = species.toList()..sort((a, b) => 
      (speciesData[b]!['bioload_factor'] as double).compareTo(speciesData[a]!['bioload_factor'] as double));
    
    for (final speciesName in sortedSpecies) {
      final data = speciesData[speciesName]!;
      final volumePerFish = data['volume_per_fish_L'] as double;
      final minSchool = data['schooling_min'] as int;
      
      final maxFish = (remainingVolume / volumePerFish).floor();
      if (maxFish >= minSchool) {
        stocking[speciesName] = maxFish.clamp(minSchool, minSchool + 2); // Conservative +2 max
        remainingVolume -= stocking[speciesName]! * volumePerFish;
      } else {
        stocking[speciesName] = 0;
      }
    }
  }

  // Get recommended quantity for a specific fish
  int? getRecommendedQuantity(String fishName) {
    return recommendedFishQuantities[fishName];
  }

  // Check if current fish quantity exceeds recommendation
  bool isQuantityOverRecommended(String fishName) {
    final current = fishSelections[fishName] ?? 0;
    final recommended = recommendedFishQuantities[fishName] ?? 0;
    return current > recommended;
  }

  // Get feeding schedule summary
  String getFeedingScheduleSummary() {
    try {
      if (feedingRecommendations.isEmpty) return 'No feeding schedule set';
      
      final schedule = feedingRecommendations['feeding_schedule'];
      if (schedule == null) return 'No feeding schedule set';
      
      if (schedule is String) {
        return schedule;
      } else if (schedule is Map<String, dynamic>) {
        final frequency = schedule['frequency'] ?? 2;
        final times = schedule['times'] ?? 'Morning and evening';
        return '$frequency times daily: $times';
      }
      
      return 'Custom schedule set';
    } catch (e) {
      print('Error getting feeding schedule summary: $e');
      return 'Schedule unavailable';
    }
  }
}
