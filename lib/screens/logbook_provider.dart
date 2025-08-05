import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Import Supabase
import '../models/fish_prediction.dart';
import '../models/water_calculation.dart';
import '../models/compatibility_result.dart';
import '../models/fish_calculation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_config.dart';
import 'package:provider/provider.dart';
import '../providers/user_plan_provider.dart';

class LogBookProvider with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isInitialized = false;

  List<WaterCalculation> _savedCalculations = [];
  List<FishCalculation> _savedFishCalculations = [];
  List<CompatibilityResult> _savedCompatibilityResults = [];
  List<FishPrediction> _savedPredictions = [];

  List<WaterCalculation> get savedCalculations => _savedCalculations;
  List<FishCalculation> get savedFishCalculations => _savedFishCalculations;
  List<CompatibilityResult> get savedCompatibilityResults => _savedCompatibilityResults;
  List<FishPrediction> get savedPredictions => _savedPredictions;

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

    } catch (e) {
      print('Error loading data from Supabase: $e');
      _clearData(); // Clear local data on error
    } finally {
      notifyListeners();
    }
  }

  // Utility methods for plan-based boundaries
  static bool canSaveFish(String plan, int savedCount) {
    if (plan == 'free') return savedCount < 5;
    // Pro tier has unlimited captures
    if (plan == 'pro') return true;
    return true;
  }

  static bool canSyncCompatibility(String plan, int syncCount) {
    if (plan == 'free') return syncCount < 2;
    return true;
  }

  static bool canShowSaveCompatibility(String plan) {
    return plan == 'pro';
  }

  static bool canShowDetailedReasons(String plan) {
    return plan == 'pro';
  }

  static bool canShowMoreDetailedBreakdown(String plan) {
    return plan == 'pro';
  }

  // Modified addPredictions to enforce plan boundaries
  Future<bool> addPredictionsWithPlan(BuildContext context, List<FishPrediction> predictions) async {
    final plan = Provider.of<UserPlanProvider>(context, listen: false).plan;
    final savedCount = _savedPredictions.length;
    if (!canSaveFish(plan, savedCount)) {
      _showUpgradeDialog(context, 'You have reached the limit for saving fish in your current plan.');
      return false;
    }
    return await addPredictions(predictions);
  }

  // Modified addCompatibilityResult to enforce plan boundaries
  Future<void> addCompatibilityResultWithPlan(BuildContext context, CompatibilityResult result) async {
    final plan = Provider.of<UserPlanProvider>(context, listen: false).plan;
    final syncCount = _savedCompatibilityResults.length;
    if (!canSyncCompatibility(plan, syncCount)) {
      _showUpgradeDialog(context, 'You have reached the limit for compatibility checks in your current plan.');
      return;
    }
    await addCompatibilityResult(result);
  }

  void _showUpgradeDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Upgrade to Pro'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/subscription');
            },
            child: const Text('Upgrade to Pro'),
          ),
        ],
      ),
    );
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
        'oxygen_needs': calculation.oxygenNeeds,
        'filtration_needs': calculation.filtrationNeeds,
        'date_calculated': calculation.dateCalculated.toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
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
        'fish1_name': result.fish1Name,
        'fish1_image_path': result.fish1ImagePath,
        'fish2_name': result.fish2Name,
        'fish2_image_path': result.fish2ImagePath,
        'is_compatible': result.isCompatible,
        'reasons': result.reasons, // TEXT[]
        'date_checked': result.dateChecked.toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        'saved_plan': result.savedPlan, // Save the plan at the time of saving
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
    ]..sort((a, b) {
        DateTime dateA;
        DateTime dateB;

        if (a is FishPrediction) {
          dateA = a.createdAt ?? DateTime(0);
        } else if (a is WaterCalculation) {
          dateA = a.dateCalculated;
        } else if (a is FishCalculation) {
          dateA = a.dateCalculated;
        } else {
          dateA = (a as CompatibilityResult).createdAt ?? DateTime(0);
        }

        if (b is FishPrediction) {
          dateB = b.createdAt ?? DateTime(0);
        } else if (b is WaterCalculation) {
          dateB = b.dateCalculated;
        } else if (b is FishCalculation) {
          dateB = b.dateCalculated;
        } else {
          dateB = (b as CompatibilityResult).createdAt ?? DateTime(0);
        }

        return dateB.compareTo(dateA);
      });
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

  // Get the count of compatibility checks made by the user
  int getCompatibilityChecksCount() {
    return _savedCompatibilityResults.length;
  }
}
