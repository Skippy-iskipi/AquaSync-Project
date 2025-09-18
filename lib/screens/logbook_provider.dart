import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Import Supabase
import '../models/fish_prediction.dart';
import '../models/water_calculation.dart';
import '../models/compatibility_result.dart';
import '../models/fish_calculation.dart';
import '../models/diet_calculation.dart';
import '../models/fish_volume_calculation.dart';
import '../models/tank.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_config.dart';

class LogBookProvider with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isInitialized = false;

  List<WaterCalculation> _savedCalculations = [];
  List<FishCalculation> _savedFishCalculations = [];
  List<CompatibilityResult> _savedCompatibilityResults = [];
  List<FishPrediction> _savedPredictions = [];
  List<DietCalculation> _savedDietCalculations = [];
  List<FishVolumeCalculation> _savedFishVolumeCalculations = [];
  List<Tank> _savedTanks = [];

  List<WaterCalculation> get savedCalculations => _savedCalculations;
  List<FishCalculation> get savedFishCalculations => _savedFishCalculations;
  List<CompatibilityResult> get savedCompatibilityResults => _savedCompatibilityResults;
  List<FishPrediction> get savedPredictions => _savedPredictions;
  List<DietCalculation> get savedDietCalculations => _savedDietCalculations;
  List<FishVolumeCalculation> get savedFishVolumeCalculations => _savedFishVolumeCalculations;
  List<Tank> get savedTanks => _savedTanks;

  LogBookProvider() {
    init();
  }

  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;

    _supabase.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      if (event == AuthChangeEvent.signedIn || event == AuthChangeEvent.initialSession) {
        _loadData();
      } else if (event == AuthChangeEvent.signedOut) {
        _clearData();
      }
    });

    // The listener above will handle the initial session, so this direct call is redundant
    // and can cause race conditions. Removing it makes the logic cleaner.
    /*
    if (_supabase.auth.currentUser != null) {
      _loadData();
    }
    */
  }

  // Clear local data when user signs out
  void _clearData() {
    _savedPredictions.clear();
    _savedCalculations.clear();
    _savedFishCalculations.clear();
    _savedCompatibilityResults.clear();
    _savedDietCalculations.clear();
    _savedFishVolumeCalculations.clear();
    _savedTanks.clear();
    notifyListeners();
  }

  Future<void> _loadData() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      _clearData();
      return;
    }

    try {
      // Load fish predictions
      final List<dynamic> predictionsData = await _supabase
          .from('fish_predictions')
          .select('*')
          .eq('user_id', user.id);
      _savedPredictions = predictionsData.map((json) => FishPrediction.fromJson(json)).toList();

      // Load water calculations
      final List<dynamic> waterCalculationsData = await _supabase
          .from('water_calculations')
          .select('*')
          .eq('user_id', user.id);
      _savedCalculations = waterCalculationsData.map((json) => WaterCalculation.fromJson(json)).toList();

      // Load fish calculations
      final List<dynamic> fishCalculationsData = await _supabase
          .from('fish_calculations')
          .select('*')
          .eq('user_id', user.id);
      _savedFishCalculations = fishCalculationsData.map((json) => FishCalculation.fromJson(json)).toList();

      // Load compatibility results by calling the database function
      final List<dynamic> compatibilityResultsData = await _supabase.rpc('get_compatibility_results');

      print('Loaded raw compatibility results data via RPC: $compatibilityResultsData');

      final List<CompatibilityResult> parsedResults = [];
      for (final json in compatibilityResultsData) {
        try {
          parsedResults.add(CompatibilityResult.fromJson(json as Map<String, dynamic>));
        } catch (e) {
          print('Error parsing compatibility result item: $json. Error: $e');
        }
      }
      _savedCompatibilityResults = parsedResults;
      
      print('Parsed ${_savedCompatibilityResults.length} compatibility results.');

      // Load diet calculations
      try {
        final List<dynamic> dietCalculationsData = await _supabase
            .from('diet_calculations')
            .select('*')
            .eq('user_id', user.id)
            .order('created_at', ascending: false);
        print('Raw diet calculations data: $dietCalculationsData');
        _savedDietCalculations = dietCalculationsData.map((json) => DietCalculation.fromJson(json)).toList();
        print('Loaded ${_savedDietCalculations.length} diet calculations');
      } catch (e) {
        print('Error loading diet calculations: $e');
        _savedDietCalculations = [];
      }

      // Load fish volume calculations
      try {
        final List<dynamic> fishVolumeCalculationsData = await _supabase
            .from('fish_volume_calculations')
            .select('*')
            .eq('user_id', user.id)
            .order('created_at', ascending: false);
        print('Raw fish volume calculations data: $fishVolumeCalculationsData');
        _savedFishVolumeCalculations = fishVolumeCalculationsData.map((json) => FishVolumeCalculation.fromJson(json)).toList();
        print('Loaded ${_savedFishVolumeCalculations.length} fish volume calculations');
      } catch (e) {
        print('Error loading fish volume calculations: $e');
        _savedFishVolumeCalculations = [];
      }

      // Load tanks
      try {
        final List<dynamic> tanksData = await _supabase
            .from('tanks')
            .select('*')
            .eq('user_id', user.id)
            .order('created_at', ascending: false);
        print('Raw tanks data: $tanksData');
        _savedTanks = tanksData.map((json) => Tank.fromJson(json)).toList();
        print('Loaded ${_savedTanks.length} tanks');
      } catch (e) {
        print('Error loading tanks: $e');
        _savedTanks = [];
      }

    } catch (e) {
      print('Error loading data from Supabase: $e');
      _clearData(); // Clear local data on error
    } finally {
      notifyListeners();
    }
  }




  // Simplified methods without plan restrictions
  Future<bool> addPredictionsWithPlan(BuildContext context, List<FishPrediction> predictions) async {
    return await addPredictions(predictions);
  }

  Future<void> addCompatibilityResultWithPlan(BuildContext context, CompatibilityResult result) async {
    await addCompatibilityResult(result);
  }


  Future<bool> addPredictions(List<FishPrediction> predictions) async {
    // Sort predictions by probability in descending order
    predictions.sort((a, b) {
      double probA = double.tryParse(a.probability.replaceAll('%', '')) ?? 0;
      double probB = double.tryParse(b.probability.replaceAll('%', '')) ?? 0;
      return probB.compareTo(probA);
    });

    // Add only the prediction with highest probability if it's not already saved
    if (predictions.isNotEmpty) {
      FishPrediction newPrediction = predictions.first;

      // Check if this fish is already in saved predictions (by common name for now)
      bool isDuplicate = _savedPredictions.any((saved) =>
        saved.commonName.toLowerCase() == newPrediction.commonName.toLowerCase()
      );

      // Only add if it's not a duplicate
      if (!isDuplicate) {
        await addPrediction(newPrediction); // Await the async call
        return true; // Successfully saved to Supabase
      }
    }
    return false; // Not saved (duplicate or empty predictions)
  }

  Future<void> addPrediction(FishPrediction prediction) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final response = await _supabase.from('fish_predictions').insert({
        'user_id': user.id,
        'common_name': prediction.commonName,
        'scientific_name': prediction.scientificName,
        'probability': prediction.probability,
        'image_path': prediction.imagePath,
        'description': prediction.description,
        'water_type': prediction.waterType,
        'max_size': prediction.maxSize,
        'temperament': prediction.temperament,
        'care_level': prediction.careLevel,
        'lifespan': prediction.lifespan,
        'temperature_range': prediction.temperatureRange,
        'ph_range': prediction.phRange,
        'minimum_tank_size': prediction.minimumTankSize,
        'social_behavior': prediction.socialBehavior,
        'diet': prediction.diet,
        'preferred_food': prediction.preferredFood,
        'feeding_frequency': prediction.feedingFrequency,
        'created_at': DateTime.now().toIso8601String(),
      }).select();

      if (response.isNotEmpty) {
        _savedPredictions.add(FishPrediction.fromJson(response.first));
        notifyListeners();
      }
    } catch (e) {
      print('Error adding prediction to Supabase: $e');
      rethrow;
    }
  }

  Future<void> removePrediction(FishPrediction prediction) async {
    try {
      await _supabase
          .from('fish_predictions')
          .delete()
          .eq('id', prediction.id!);
      _savedPredictions.removeWhere((p) => p.id == prediction.id);
      notifyListeners();
    } catch (e) {
      print('Error removing prediction from Supabase: $e');
    }
  }

  Future<void> addWaterCalculation(WaterCalculation calculation) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final response = await _supabase.from('water_calculations').insert({
        'user_id': user.id,
        'minimum_tank_volume': calculation.minimumTankVolume,
        'temperature_range': calculation.temperatureRange,
        'ph_range': calculation.phRange,
        'fish_selections': calculation.fishSelections, // JSONB
        'recommended_quantities': calculation.recommendedQuantities,
        'tank_shape': calculation.tankShape,
        'water_requirements': calculation.waterRequirements,
        'tankmate_recommendations': calculation.tankmateRecommendations,
        'feeding_information': calculation.feedingInformation,
        'date_calculated': calculation.dateCalculated.toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        // Keep old AI fields for backward compatibility
        'water_parameters_response': calculation.waterParametersResponse,
        'tank_analysis_response': calculation.tankAnalysisResponse,
        'filtration_response': calculation.filtrationResponse,
        'diet_care_response': calculation.dietCareResponse,
      }).select();

      if (response.isNotEmpty) {
        _savedCalculations.add(WaterCalculation.fromJson(response.first));
        notifyListeners();
      }
    } catch (e) {
      print('Error adding water calculation to Supabase: $e');
    }
  }

  Future<void> removeWaterCalculation(WaterCalculation calculation) async {
    try {
      await _supabase
          .from('water_calculations')
          .delete()
          .eq('id', calculation.id!);
      _savedCalculations.removeWhere((c) => c.id == calculation.id);
      notifyListeners();
    } catch (e) {
      print('Error removing water calculation from Supabase: $e');
    }
  }

  Future<void> addFishCalculation(FishCalculation calculation) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final response = await _supabase.from('fish_calculations').insert({
        'user_id': user.id,
        'tank_volume': calculation.tankVolume,
        'temperature_range': calculation.temperatureRange,
        'ph_range': calculation.phRange,
        'fish_selections': calculation.fishSelections, // JSONB
        'recommended_quantities': calculation.recommendedQuantities, // JSONB
        'tankmate_recommendations': calculation.tankmateRecommendations, // TEXT[]
        'feeding_information': calculation.feedingInformation, // JSONB
        'date_calculated': calculation.dateCalculated.toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      }).select();

      if (response.isNotEmpty) {
        _savedFishCalculations.add(FishCalculation.fromJson(response.first));
        notifyListeners();
      }
    } catch (e) {
      print('Error adding fish calculation to Supabase: $e');
    }
  }

  Future<void> removeFishCalculation(FishCalculation calculation) async {
    try {
      await _supabase
          .from('fish_calculations')
          .delete()
          .eq('id', calculation.id!);
      _savedFishCalculations.removeWhere((c) => c.id == calculation.id);
      notifyListeners();
    } catch (e) {
      print('Error removing fish calculation from Supabase: $e');
    }
  }

  Future<void> addCompatibilityResult(CompatibilityResult result) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final response = await _supabase.from('compatibility_results').insert({
        'user_id': user.id,
        'selected_fish': result.selectedFish, // JSONB
        'compatibility_level': result.compatibilityLevel,
        'reasons': result.reasons, // TEXT[]
        'pair_analysis': result.pairAnalysis, // JSONB
        'tankmate_recommendations': result.tankmateRecommendations, // JSONB
        'date_checked': result.dateChecked.toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      }).select();

      if (response.isNotEmpty) {
        // Create a new result from the database response and add it to the local list
        final newResult = CompatibilityResult.fromJson(response.first);
        _savedCompatibilityResults.add(newResult);
        notifyListeners();
      }
    } catch (e) {
      print('Error adding compatibility result to Supabase: $e');
    }
  }

  Future<void> removeCompatibilityResult(CompatibilityResult result) async {
    try {
      await _supabase
          .from('compatibility_results')
          .delete()
          .eq('id', result.id!);
      _savedCompatibilityResults.removeWhere((r) => r.id == result.id);
      notifyListeners();
    } catch (e) {
      print('Error removing compatibility result from Supabase: $e');
    }
  }

  List<CompatibilityResult> getRecentResults() {
    // Return the most recent 5 results, sorted by created_at from Supabase
    final sortedResults = List<CompatibilityResult>.from(_savedCompatibilityResults)
      ..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    return sortedResults;
  }

  List<FishCalculation> getRecentFishCalculations() {
    // Return the most recent 5 fish calculations, sorted by created_at from Supabase
    final sortedCalculations = List<FishCalculation>.from(_savedFishCalculations)
      ..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    return sortedCalculations;
  }

  List<WaterCalculation> getRecentWaterCalculations() {
    // Return the most recent 5 water calculations, sorted by created_at from Supabase
    final sortedCalculations = List<WaterCalculation>.from(_savedCalculations)
      ..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    return sortedCalculations;
  }

  List<dynamic> get allItems {
    final allItems = [
      ..._savedPredictions,
      ..._savedCalculations,
      ..._savedFishCalculations,
      ..._savedCompatibilityResults,
      ..._savedDietCalculations,
      ..._savedFishVolumeCalculations,
      ..._savedTanks,
    ]..sort((a, b) {
        DateTime dateA;
        DateTime dateB;

        if (a is FishPrediction) {
          dateA = a.createdAt ?? DateTime(0);
        } else if (a is WaterCalculation) {
          dateA = a.dateCalculated;
        } else if (a is FishCalculation) {
          dateA = a.dateCalculated;
        } else if (a is DietCalculation) {
          dateA = a.dateCalculated;
        } else if (a is FishVolumeCalculation) {
          dateA = a.dateCalculated;
        } else if (a is Tank) {
          dateA = a.createdAt ?? a.dateCreated;
        } else {
          dateA = (a as CompatibilityResult).createdAt ?? DateTime(0);
        }

        if (b is FishPrediction) {
          dateB = b.createdAt ?? DateTime(0);
        } else if (b is WaterCalculation) {
          dateB = b.dateCalculated;
        } else if (b is FishCalculation) {
          dateB = b.dateCalculated;
        } else if (b is DietCalculation) {
          dateB = b.dateCalculated;
        } else if (b is FishVolumeCalculation) {
          dateB = b.dateCalculated;
        } else if (b is Tank) {
          dateB = b.createdAt ?? b.dateCreated;
        } else {
          dateB = (b as CompatibilityResult).createdAt ?? DateTime(0);
        }

        return dateB.compareTo(dateA);
      });
    
    print('AllItems count: ${allItems.length} (Predictions: ${_savedPredictions.length}, Water: ${_savedCalculations.length}, Fish: ${_savedFishCalculations.length}, Compatibility: ${_savedCompatibilityResults.length}, Diet: ${_savedDietCalculations.length}, Fish Volume: ${_savedFishVolumeCalculations.length}, Tanks: ${_savedTanks.length})');
    return allItems;
  }

  Future<bool> saveFishCalculationToSupabase(Map<String, dynamic> calculationData) async {
    final url = ApiConfig.saveFishCalculationEndpoint;
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(calculationData),
      );
      if (response.statusCode == 200) {
        // Optionally parse response for the inserted row ID
        print('Calculation saved: ${response.body}');
        return true;
      } else {
        print('Failed to save calculation: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error saving calculation: $e');
      return false;
    }
  }

  Future<void> fetchFishCalculations() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final response = await Supabase.instance.client
        .from('fish_calculations')
        .select()
        .eq('user_id', userId)
        .order('date_calculated', ascending: false);

    _savedFishCalculations = response
        .map((json) => FishCalculation.fromJson(json))
        .toList();
    notifyListeners();
  }

  Future<void> addDietCalculation(DietCalculation calculation) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final response = await _supabase.from('diet_calculations').insert({
        'user_id': user.id,
        'fish_selections': calculation.fishSelections,
        'total_portion': calculation.totalPortion,
        'portion_details': calculation.portionDetails,
        'compatibility_issues': calculation.compatibilityIssues,
        'feeding_notes': calculation.feedingNotes,
        'feeding_schedule': calculation.feedingSchedule,
        'total_food_per_feeding': calculation.totalFoodPerFeeding,
        'per_fish_breakdown': calculation.perFishBreakdown,
        'recommended_food_types': calculation.recommendedFoodTypes,
        'feeding_tips': calculation.feedingTips,
        'date_calculated': calculation.dateCalculated.toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        'saved_plan': calculation.savedPlan,
      }).select();

      if (response.isNotEmpty) {
        _savedDietCalculations.insert(0, DietCalculation.fromJson(response.first));
        print('Diet calculation added to provider. Total count: ${_savedDietCalculations.length}');
        notifyListeners();
      }
    } catch (e) {
      print('Error adding diet calculation to Supabase: $e');
      // Still add to local list as fallback
      _savedDietCalculations.insert(0, calculation);
      notifyListeners();
    }
  }

  Future<void> removeDietCalculation(DietCalculation calculation) async {
    try {
      await _supabase
          .from('diet_calculations')
          .delete()
          .eq('id', calculation.id!);
      _savedDietCalculations.removeWhere((c) => c.id == calculation.id);
      notifyListeners();
    } catch (e) {
      print('Error removing diet calculation from Supabase: $e');
    }
  }

  // Method to add diet calculation to local list without saving to Supabase
  void addDietCalculationLocally(DietCalculation calculation) {
    _savedDietCalculations.insert(0, calculation);
    notifyListeners();
  }

  Future<void> fetchDietCalculations() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final response = await Supabase.instance.client
        .from('diet_calculations')
        .select()
        .eq('user_id', userId)
        .order('date_calculated', ascending: false);

    _savedDietCalculations = response
        .map((json) => DietCalculation.fromJson(json))
        .toList();
    notifyListeners();
  }

  // Get the count of compatibility checks made by the user
  int getCompatibilityChecksCount() {
    return _savedCompatibilityResults.length;
  }

  // Fish Volume Calculation methods
  Future<void> addFishVolumeCalculation(FishVolumeCalculation calculation) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final response = await _supabase.from('fish_volume_calculations').insert({
        'user_id': user.id,
        'tank_shape': calculation.tankShape,
        'tank_volume': calculation.tankVolume,
        'fish_selections': calculation.fishSelections,
        'recommended_quantities': calculation.recommendedQuantities,
        'tankmate_recommendations': calculation.tankmateRecommendations,
        'water_requirements': calculation.waterRequirements,
        'feeding_information': calculation.feedingInformation,
        'date_calculated': calculation.dateCalculated.toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      }).select();

      if (response.isNotEmpty) {
        _savedFishVolumeCalculations.insert(0, FishVolumeCalculation.fromJson(response.first));
        print('Fish volume calculation added to provider. Total count: ${_savedFishVolumeCalculations.length}');
        notifyListeners();
      }
    } catch (e) {
      print('Error adding fish volume calculation to Supabase: $e');
      // Still add to local list as fallback
      _savedFishVolumeCalculations.insert(0, calculation);
      notifyListeners();
    }
  }

  Future<void> removeFishVolumeCalculation(FishVolumeCalculation calculation) async {
    try {
      await _supabase
          .from('fish_volume_calculations')
          .delete()
          .eq('id', calculation.id!);
      _savedFishVolumeCalculations.removeWhere((c) => c.id == calculation.id);
      notifyListeners();
    } catch (e) {
      print('Error removing fish volume calculation from Supabase: $e');
    }
  }

  // Method to add fish volume calculation to local list without saving to Supabase
  void addFishVolumeCalculationLocally(FishVolumeCalculation calculation) {
    _savedFishVolumeCalculations.insert(0, calculation);
    notifyListeners();
  }

  Future<void> fetchFishVolumeCalculations() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final response = await Supabase.instance.client
        .from('fish_volume_calculations')
        .select()
        .eq('user_id', userId)
        .order('date_calculated', ascending: false);

    _savedFishVolumeCalculations = response
        .map((json) => FishVolumeCalculation.fromJson(json))
        .toList();
    notifyListeners();
  }

}
