import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/tank.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_config.dart';

class TankProvider with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isInitialized = false;

  List<Tank> _tanks = [];
  List<Tank> _archivedTanks = [];

  List<Tank> get tanks => _tanks;
  List<Tank> get archivedTanks => _archivedTanks;

  TankProvider() {
    init();
  }

  // Format numbers without forcing a fixed number of decimals.
  // Keeps up to 6 decimal places, trimming trailing zeros and any dangling decimal point.
  String _formatNumber(double value) {
    final s = value.toStringAsFixed(6);
    final trimmed = s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    return trimmed.isEmpty ? '0' : trimmed;
  }

  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;

    _supabase.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      if (event == AuthChangeEvent.signedIn || event == AuthChangeEvent.initialSession) {
        loadTanks();
      } else if (event == AuthChangeEvent.signedOut) {
        _clearTanks();
      }
    });
  }

  void _clearTanks() {
    _tanks.clear();
    _archivedTanks.clear();
    notifyListeners();
  }

  Future<void> loadTanks() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      _clearTanks();
      return;
    }

    try {
      final List<dynamic> tanksData = await _supabase
          .from('tanks')
          .select('*')
          .eq('user_id', user.id)
          .or('archived.is.null,archived.eq.false')
          .order('created_at', ascending: false);
      
      _tanks = tanksData.map((json) => Tank.fromJson(json)).toList();
      notifyListeners();
    } catch (e) {
      print('Error loading tanks from Supabase: $e');
      _clearTanks();
    }
  }

  Future<void> addTank(Tank tank) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      // Prepare the tank data for database insertion
      final tankData = {
        'user_id': user.id,
        'name': tank.name,
        'tank_shape': tank.tankShape,
        'length': tank.length,
        'width': tank.width,
        'height': tank.height,
        'unit': tank.unit,
        'volume': tank.volume,
        'fish_selections': tank.fishSelections,
        'compatibility_results': tank.compatibilityResults,
        'feeding_recommendations': tank.feedingRecommendations,
        'recommended_fish_quantities': tank.recommendedFishQuantities,
        'available_feeds': tank.availableFeeds,
        'feed_inventory': tank.feedInventory,
        'feed_portion_data': tank.feedPortionData,
        'date_created': tank.dateCreated.toIso8601String(),
        'last_updated': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      };

      print('Adding tank to database with data: ${tankData.keys.join(', ')}');
      
      final response = await _supabase.from('tanks').insert(tankData).select();

      if (response.isNotEmpty) {
        final newTank = Tank.fromJson(response.first);
        _tanks.insert(0, newTank);
        notifyListeners();
        print('✅ Tank added successfully: ${newTank.name}');
      }
    } catch (e) {
      print('❌ Error adding tank to Supabase: $e');
      rethrow;
    }
  }

  Future<void> updateTank(Tank tank) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      // Prepare the tank data for database update
      final tankData = {
        'name': tank.name,
        'tank_shape': tank.tankShape,
        'length': tank.length,
        'width': tank.width,
        'height': tank.height,
        'unit': tank.unit,
        'volume': tank.volume,
        'fish_selections': tank.fishSelections,
        'compatibility_results': tank.compatibilityResults,
        'feeding_recommendations': tank.feedingRecommendations,
        'recommended_fish_quantities': tank.recommendedFishQuantities,
        'available_feeds': tank.availableFeeds,
        'feed_inventory': tank.feedInventory,
        'feed_portion_data': tank.feedPortionData,
        'last_updated': DateTime.now().toIso8601String(),
      };

      print('Updating tank in database with data: ${tankData.keys.join(', ')}');
      
      await _supabase.from('tanks').update(tankData).eq('id', tank.id!);

      final index = _tanks.indexWhere((t) => t.id == tank.id);
      if (index != -1) {
        _tanks[index] = tank;
        notifyListeners();
        print('✅ Tank updated successfully: ${tank.name}');
      }
    } catch (e) {
      print('❌ Error updating tank in Supabase: $e');
      rethrow;
    }
  }

  Future<void> archiveTank(String tankId) async {
    Tank? tankToArchive;
    try {
      // Find the tank to archive
      tankToArchive = _tanks.firstWhere((tank) => tank.id == tankId);
      
      // Remove from local list first to immediately update UI
      _tanks.removeWhere((tank) => tank.id == tankId);
      notifyListeners();
      
      // Then update database
      await _supabase.from('tanks').update({'archived': true, 'archived_at': DateTime.now().toIso8601String()}).eq('id', tankId);
    } catch (e) {
      print('Error archiving tank from Supabase: $e');
      // Re-add to list if database update fails
      if (tankToArchive != null) {
        _tanks.add(tankToArchive);
        notifyListeners();
      }
      rethrow;
    }
  }

  // Check fish compatibility
  Future<Map<String, dynamic>> checkFishCompatibility(Map<String, int> fishSelections, [Map<String, Map<String, int>>? fishSexSelections]) async {
    try {
      print('Checking compatibility for: $fishSelections');
      
      // Use the new backend endpoint with sex data
      final requestBody = {
        'fish_selections': fishSelections,
        'fish_sex_data': fishSexSelections ?? {},
      };
      
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/check_compatibility'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'status': data['overall_compatibility'] == 'compatible' ? 'compatible' : 
                   data['overall_compatibility'] == 'conditional' ? 'compatible_with_condition' : 'incompatible',
          'reason': (data['summary_reasons'] as List).join('\n'),
          'is_compatible': data['overall_compatibility'] != 'incompatible',
          'compatibility_issues': data['summary_reasons'] ?? [],
          'fish_details': data['detailed_results'] ?? {},
          'conditions': data['summary_conditions'] ?? [],
        };
      }
      
      // Fallback to old logic if new endpoint fails
      List<String> incompatibleReasons = [];
      List<String> conditionalReasons = [];
      
      // Check individual species compatibility (same species with multiple quantities)
      for (var entry in fishSelections.entries) {
        final fishName = entry.key;
        final quantity = entry.value;
        
        if (quantity > 1) {
          // Check if this species can live with itself in the given quantity
          final sameSpeciesList = List.filled(quantity, fishName);
          
          final sameSpeciesResponse = await http.post(
            Uri.parse(ApiConfig.checkGroupEndpoint),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json'
            },
            body: json.encode({'fish_names': sameSpeciesList}),
          ).timeout(ApiConfig.timeout);

          if (sameSpeciesResponse.statusCode == 200) {
            final sameSpeciesData = json.decode(sameSpeciesResponse.body);
            
            for (var result in sameSpeciesData['results']) {
              if (result['compatibility'] == 'Not Compatible') {
                incompatibleReasons.add('Too many $fishName fish together: ${result['reasons'].join(', ')}');
              } else if (result['compatibility'] == 'Compatible with Condition') {
                conditionalReasons.add('$quantity $fishName together: ${result['reasons'].join(', ')}');
              }
            }
          }
        }
      }
      
      // Check cross-species compatibility (if multiple species)
      if (fishSelections.length > 1) {
        final expandedFishNames = fishSelections.entries
            .expand((e) => List.filled(e.value, e.key))
            .toList();

        final crossSpeciesResponse = await http.post(
          Uri.parse(ApiConfig.checkGroupEndpoint),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json'
          },
          body: json.encode({'fish_names': expandedFishNames}),
        ).timeout(ApiConfig.timeout);

        if (crossSpeciesResponse.statusCode == 200) {
          final crossSpeciesData = json.decode(crossSpeciesResponse.body);
          
          for (var result in crossSpeciesData['results']) {
            final pair = result['pair'];
            if (result['compatibility'] == 'Not Compatible') {
              incompatibleReasons.add('${pair[0]} and ${pair[1]} are incompatible: ${result['reasons'].join(', ')}');
            } else if (result['compatibility'] == 'Compatible with Condition') {
              conditionalReasons.add('${pair[0]} and ${pair[1]}: ${result['reasons'].join(', ')}');
            }
          }
        }
      }
      
      // Determine overall status
      if (incompatibleReasons.isNotEmpty) {
        return {
          'status': 'incompatible',
          'reason': incompatibleReasons.join('\n'),
          'is_compatible': false,
          'compatibility_issues': incompatibleReasons,
          'fish_details': [],
        };
      } else if (conditionalReasons.isNotEmpty) {
        return {
          'status': 'compatible_with_condition',
          'reason': conditionalReasons.join('\n'),
          'is_compatible': true,
          'compatibility_issues': conditionalReasons,
          'fish_details': [],
        };
      } else {
        return {
          'status': 'compatible',
          'reason': 'All fish are compatible',
          'is_compatible': true,
          'compatibility_issues': [],
          'fish_details': [],
        };
      }
    } catch (e) {
      print('Error checking fish compatibility: $e');
      return {
        'status': 'error',
        'reason': 'Error checking compatibility: $e',
        'is_compatible': true,
        'compatibility_issues': [],
        'fish_details': [],
      };
    }
  }

  // Generate feeding recommendations using database portion_grams
  Future<Map<String, dynamic>> generateFeedingRecommendations(Map<String, int> fishSelections) async {
    print('Starting feeding recommendations generation for: $fishSelections');
    try {
      // Fetch portion_grams directly from database for each fish
      Map<String, dynamic> portionPerFeeding = {};
      Map<String, dynamic> dailyConsumption = {};
      List<String> recommendedFoods = [];
      Map<String, String> fishFeedingNotes = {};
      
      for (final entry in fishSelections.entries) {
        final fishName = entry.key;
        final quantity = entry.value;
        
        try {
          final response = await Supabase.instance.client
              .from('fish_species')
              .select('portion_grams, diet, preferred_food, feeding_notes')
              .or('common_name.ilike.%$fishName%,scientific_name.ilike.%$fishName%')
              .limit(1)
              .single();
          
          final portionGrams = response['portion_grams']?.toDouble() ?? 0.05; // Default 50mg
          final preferredFood = response['preferred_food'] ?? 'pellets'; // Use database preferred_food
          final feedingNotes = response['feeding_notes'] ?? 'Remove uneaten food after 5 minutes.';
          
          // Format portion display with preferred food from database using full precision
          String portionText;
          if (portionGrams >= 1.0) {
            portionText = '$fishName: ${_formatNumber(portionGrams)}g of $preferredFood per feeding';
          } else {
            final mg = portionGrams * 1000.0;
            portionText = '$fishName: ${_formatNumber(mg)}mg of $preferredFood per feeding';
          }
          
          portionPerFeeding[fishName] = portionText;
          
          // Calculate daily consumption (portion × feeding frequency × quantity)
          final dailyPerFish = portionGrams * 2; // 2 feedings per day
          dailyConsumption[fishName] = dailyPerFish * quantity;
          
          // Add preferred food to recommended foods list (avoid duplicates)
          if (!recommendedFoods.contains(preferredFood)) {
            recommendedFoods.add(preferredFood);
          }
          
          // Store feeding notes per fish
          fishFeedingNotes[fishName] = feedingNotes;
          
        } catch (e) {
          print('Error fetching portion_grams for $fishName: $e');
          // Fallback values with feed type
          portionPerFeeding[fishName] = '$fishName: 50mg of tropical flakes per feeding (default)';
          dailyConsumption[fishName] = 0.1 * quantity; // 100mg daily per fish
          fishFeedingNotes[fishName] = 'Remove uneaten food after 5 minutes.';
        }
      }
      
      // Build complete feeding recommendations
      final result = {
        'food_types': recommendedFoods,
        'feeding_schedule': {
          'frequency': '2 times per day',
          'times': 'Morning and Evening'
        },
        'portion_per_feeding': portionPerFeeding.values.join('\n'),
        'daily_consumption': dailyConsumption,
        'feeding_notes': fishFeedingNotes,
        'recommended_foods': recommendedFoods,
        'special_considerations': 'Monitor fish behavior and adjust portions if needed.'
      };
      
      print('✅ Database-based feeding recommendations generated successfully');
      return result;
      
    } catch (e) {
      print('❌ Error generating database feeding recommendations: $e');
      return _getFallbackFeedingRecommendations(fishSelections);
    }
  }
  
  Map<String, dynamic> _getFallbackFeedingRecommendations(Map<String, int> fishSelections) {
    Map<String, dynamic> portionPerFeeding = {};
    Map<String, dynamic> dailyConsumption = {};
    Map<String, String> fallbackNotes = {};
    
    for (final entry in fishSelections.entries) {
      final fishName = entry.key;
      final quantity = entry.value;
      portionPerFeeding[fishName] = '$fishName: 50mg of tropical flakes per feeding (fallback)';
      dailyConsumption[fishName] = 0.1 * quantity;
      fallbackNotes[fishName] = 'Check database for accurate feeding notes.';
    }
    
    return {
      'food_types': ['pellets'],
      'feeding_schedule': {
        'frequency': '2 times per day',
        'times': 'Morning and Evening'
      },
      'portion_per_feeding': portionPerFeeding.values.join('\n'),
      'daily_consumption': dailyConsumption,
      'feeding_notes': fallbackNotes,
      'recommended_foods': ['pellets'],
      'special_considerations': 'Update fish_species table with accurate portion_grams values.'
    };
  }

  // Calculate recommended fish quantities based on tank volume and compatibility
  Future<Map<String, int>> calculateRecommendedFishQuantities(
    double tankVolume,
    Map<String, int> fishSelections,
    Map<String, dynamic> compatibilityResults,
  ) async {
    // Fetch fish volume requirements from database
    final fishVolumeRequirements = await _getFishVolumeRequirements(fishSelections.keys.toList());
    
    return await Tank.calculateRecommendedFishQuantities(
      tankVolume,
      fishSelections,
      compatibilityResults,
      fishVolumeRequirements,
    );
  }

  Future<Map<String, double>> _getFishVolumeRequirements(List<String> fishNames) async {
    final Map<String, double> volumeRequirements = {};
    
    try {
      // Query fish_species table for size data
      final response = await _supabase
          .from('fish_species')
          .select('common_name, "max_size_(cm)"')
          .inFilter('common_name', fishNames);
      
      for (final fish in response) {
        final commonName = fish['common_name'] as String?;
        final maxSizeCm = fish['max_size_(cm)'];
        
        if (commonName != null && maxSizeCm != null) {
          // Convert fish size to volume requirement using aquarium guidelines
          final sizeInCm = double.tryParse(maxSizeCm.toString()) ?? 0.0;
          final volumeRequirement = _calculateVolumeFromSize(sizeInCm);
          volumeRequirements[commonName] = volumeRequirement;
        }
      }
      
      // Add fallback values for fish not found in database
      for (final fishName in fishNames) {
        if (!volumeRequirements.containsKey(fishName)) {
          // Try case-insensitive matching
          bool found = false;
          for (final dbFishName in volumeRequirements.keys) {
            if (dbFishName.toLowerCase() == fishName.toLowerCase()) {
              volumeRequirements[fishName] = volumeRequirements[dbFishName]!;
              found = true;
              break;
            }
          }
          
          if (!found) {
            // Use default based on common fish name patterns
            volumeRequirements[fishName] = _getDefaultVolumeRequirement(fishName);
          }
        }
      }
    } catch (e) {
      print('Error fetching fish volume requirements: $e');
      // Fallback to default values for all fish
      for (final fishName in fishNames) {
        volumeRequirements[fishName] = _getDefaultVolumeRequirement(fishName);
      }
    }
    
    return volumeRequirements;
  }

  double _calculateVolumeFromSize(double sizeCm) {
    // Calculate volume requirement based on fish size using aquarium guidelines
    // General rule: 1 inch of fish needs 1 gallon of water (3.78 liters)
    // But this varies by fish type and activity level
    
    if (sizeCm <= 0) return 20.0; // Default fallback
    
    final sizeInches = sizeCm / 2.54;
    
    // Base volume calculation
    double baseVolume = sizeInches * 3.78; // 1 gallon per inch rule
    
    // Adjust based on size categories
    if (sizeCm <= 5.0) {
      // Small fish (≤2 inches) - can be more densely stocked
      baseVolume *= 0.5;
    } else if (sizeCm <= 10.0) {
      // Medium-small fish (2-4 inches) - standard stocking
      baseVolume *= 0.8;
    } else if (sizeCm <= 15.0) {
      // Medium fish (4-6 inches) - need more space
      baseVolume *= 1.2;
    } else if (sizeCm <= 25.0) {
      // Large fish (6-10 inches) - need significantly more space
      baseVolume *= 2.0;
    } else {
      // Very large fish (>10 inches) - need lots of space
      baseVolume *= 3.0;
    }
    
    // Minimum volume requirements
    return baseVolume.clamp(2.0, 500.0);
  }

  double _getDefaultVolumeRequirement(String fishName) {
    final fishNameLower = fishName.toLowerCase();
    
    // Default volume requirements based on common fish patterns
    final Map<String, double> defaultRequirements = {
      // Small schooling fish
      'tetra': 4.0,
      'neon': 2.0,
      'guppy': 4.0,
      'endler': 4.0,
      'danio': 6.0,
      'rasbora': 4.0,
      
      // Medium community fish
      'platy': 8.0,
      'molly': 15.0,
      'swordtail': 15.0,
      'barb': 8.0,
      'corydoras': 15.0,
      'cory': 15.0,
      
      // Bettas and gouramis
      'betta': 20.0,
      'gourami': 40.0,
      
      // Larger fish
      'angelfish': 150.0,
      'angel': 150.0,
      'discus': 200.0,
      'oscar': 300.0,
      'goldfish': 75.0,
      'cichlid': 100.0,
    };
    
    // Pattern matching for fish names
    for (final pattern in defaultRequirements.keys) {
      if (fishNameLower.contains(pattern)) {
        return defaultRequirements[pattern]!;
      }
    }
    
    // Default fallback for unknown fish
    return 20.0;
  }

  // Generate detailed feed portion data for each fish species
  Map<String, dynamic> generateFeedPortionData(
    Map<String, int> fishSelections,
    Map<String, dynamic> feedingRecommendations,
  ) {
    final Map<String, dynamic> portionData = {};
    
    try {
      for (final fishEntry in fishSelections.entries) {
        final fishName = fishEntry.key;
        final fishCount = fishEntry.value;
        
        // Default feeding data based on fish type
        Map<String, dynamic> fishData = _getDefaultFishFeedingData(fishName);
        
        // Override with AI recommendations if available
        if (feedingRecommendations.isNotEmpty) {
          final aiSchedule = feedingRecommendations['feeding_schedule'];
          if (aiSchedule != null) {
            if (aiSchedule is Map<String, dynamic>) {
              fishData['feeding_frequency'] = aiSchedule['frequency'] ?? fishData['feeding_frequency'];
            } else if (aiSchedule is String) {
              // Handle string format - try to extract frequency from string
              final frequencyMatch = RegExp(r'(\d+)\s*times?').firstMatch(aiSchedule.toLowerCase());
              if (frequencyMatch != null) {
                final frequency = int.tryParse(frequencyMatch.group(1) ?? '2') ?? 2;
                fishData['feeding_frequency'] = frequency;
              }
            }
          }
          
          // Extract portion sizes from AI recommendations
          final dailyConsumption = feedingRecommendations['daily_consumption'] as Map<String, dynamic>?;
          if (dailyConsumption != null) {
            for (final feedEntry in dailyConsumption.entries) {
              final feedName = feedEntry.key;
              final totalDaily = double.tryParse(feedEntry.value.toString()) ?? 0.0;
              
              if (totalDaily > 0 && fishCount > 0) {
                final perFishDaily = totalDaily / fishCount;
                final frequency = fishData['feeding_frequency'] is int 
                    ? fishData['feeding_frequency'] as int
                    : int.tryParse(fishData['feeding_frequency'].toString()) ?? 2;
                final portionSize = perFishDaily / frequency;
                
                fishData['feed_portions'] ??= <String, dynamic>{};
                fishData['feed_portions'][feedName] = {
                  'portion_size_grams': portionSize,
                  'daily_total_grams': perFishDaily,
                };
              }
            }
          }
        }
        
        portionData[fishName] = fishData;
      }
    } catch (e) {
      print('Error generating feed portion data: $e');
    }
    
    return portionData;
  }

  // Get default feeding data for fish species
  Map<String, dynamic> _getDefaultFishFeedingData(String fishName) {
    final fishNameLower = fishName.toLowerCase();
    
    // Default feeding patterns based on fish type
    if (fishNameLower.contains('betta')) {
      return {
        'feeding_frequency': 2,
        'preferred_feeds': ['Pellets', 'Frozen Bloodworms', 'Brine Shrimp'],
        'portion_size_range': '2-3 pellets per feeding',
        'feeding_times': ['Morning', 'Evening'],
      };
    } else if (fishNameLower.contains('guppy')) {
      return {
        'feeding_frequency': 2,
        'preferred_feeds': ['Flakes', 'Micro Pellets', 'Frozen Brine Shrimp'],
        'portion_size_range': '2-3 pieces per feeding',
        'feeding_times': ['Morning', 'Evening'],
      };
    } else if (fishNameLower.contains('tetra')) {
      return {
        'feeding_frequency': 2,
        'preferred_feeds': ['Flakes', 'Micro Pellets', 'Frozen Bloodworms'],
        'portion_size_range': '1-2 pieces per feeding',
        'feeding_times': ['Morning', 'Evening'],
      };
    } else if (fishNameLower.contains('goldfish')) {
      return {
        'feeding_frequency': 2,
        'preferred_feeds': ['Goldfish Flakes', 'Pellets', 'Vegetables'],
        'portion_size_range': '3-5 pieces per feeding',
        'feeding_times': ['Morning', 'Evening'],
      };
    } else if (fishNameLower.contains('angelfish')) {
      return {
        'feeding_frequency': 2,
        'preferred_feeds': ['Flakes', 'Pellets', 'Frozen Bloodworms', 'Brine Shrimp'],
        'portion_size_range': '4-6 pieces per feeding',
        'feeding_times': ['Morning', 'Evening'],
      };
    } else {
      // Default for unknown fish
      return {
        'feeding_frequency': 2,
        'preferred_feeds': ['Flakes', 'Pellets'],
        'portion_size_range': '2-3 pieces per feeding',
        'feeding_times': ['Morning', 'Evening'],
      };
    }
  }

  // Get available fish species
  Future<List<String>> getAvailableFishSpecies() async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.fishListEndpoint),
        headers: {'Accept': 'application/json'}
      ).timeout(ApiConfig.timeout);
      
      if (response.statusCode == 200) {
        final List<dynamic> fishList = json.decode(response.body);
        final fishNames = fishList
            .map((fish) => fish['common_name'] as String)
            .toList();
        fishNames.sort();
        return fishNames;
      }
    } catch (e) {
      print('Error fetching fish species: $e');
    }
    
    return [];
  }

  // Load archived tanks
  Future<void> loadArchivedTanks() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      _archivedTanks.clear();
      notifyListeners();
      return;
    }

    try {
      final List<dynamic> tanksData = await _supabase
          .from('tanks')
          .select('*')
          .eq('user_id', user.id)
          .eq('archived', true)
          .order('created_at', ascending: false);
      
      _archivedTanks = tanksData.map((json) => Tank.fromJson(json)).toList();
      print('✅ Loaded ${_archivedTanks.length} archived tanks');
    } catch (e) {
      print('❌ Error loading archived tanks from Supabase: $e');
      _archivedTanks.clear();
    } finally {
      notifyListeners();
    }
  }

  // Restore archived tank
  Future<void> restoreTank(String tankId) async {
    Tank? tankToRestore;
    try {
      // Find the tank to restore
      tankToRestore = _archivedTanks.firstWhere((tank) => tank.id == tankId);

      // Remove from archived list first
      _archivedTanks.removeWhere((tank) => tank.id == tankId);
      notifyListeners();

      // Then update database
      await _supabase.from('tanks').update({'archived': false, 'archived_at': null}).eq('id', tankId);
      
      // Reload active tanks
      await loadTanks();
    } catch (e) {
      print('Error restoring tank from Supabase: $e');
      // Re-add to archived list if database update fails
      if (tankToRestore != null) {
        _archivedTanks.add(tankToRestore);
        notifyListeners();
      }
      rethrow;
    }
  }
}
