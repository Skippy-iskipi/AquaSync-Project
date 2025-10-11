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
import 'dart:io';

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

  // Archived data lists
  List<WaterCalculation> _archivedCalculations = [];
  List<FishCalculation> _archivedFishCalculations = [];
  List<CompatibilityResult> _archivedCompatibilityResults = [];
  List<FishPrediction> _archivedPredictions = [];
  List<DietCalculation> _archivedDietCalculations = [];
  List<FishVolumeCalculation> _archivedFishVolumeCalculations = [];
  List<Tank> _archivedTanks = [];

  List<WaterCalculation> get archivedCalculations => _archivedCalculations;
  List<FishCalculation> get archivedFishCalculations => _archivedFishCalculations;
  List<CompatibilityResult> get archivedCompatibilityResults => _archivedCompatibilityResults;
  List<FishPrediction> get archivedPredictions => _archivedPredictions;
  List<DietCalculation> get archivedDietCalculations => _archivedDietCalculations;
  List<FishVolumeCalculation> get archivedFishVolumeCalculations => _archivedFishVolumeCalculations;
  List<Tank> get archivedTanks => _archivedTanks;

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
    
    // Clear archived data
    _archivedPredictions.clear();
    _archivedCalculations.clear();
    _archivedFishCalculations.clear();
    _archivedCompatibilityResults.clear();
    _archivedDietCalculations.clear();
    _archivedFishVolumeCalculations.clear();
    _archivedTanks.clear();
    
    notifyListeners();
  }

  Future<void> _loadData() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      _clearData();
      return;
    }

    try {
      // Load fish predictions (excluding archived)
      final List<dynamic> predictionsData = await _supabase
          .from('fish_predictions')
          .select('*')
          .eq('user_id', user.id)
          .or('archived.is.null,archived.eq.false');
      _savedPredictions = predictionsData.map((json) => FishPrediction.fromJson(json)).toList();

      // Load water calculations (excluding archived)
      final List<dynamic> waterCalculationsData = await _supabase
          .from('water_calculations')
          .select('*')
          .eq('user_id', user.id)
          .or('archived.is.null,archived.eq.false');
      _savedCalculations = waterCalculationsData.map((json) => WaterCalculation.fromJson(json)).toList();

      // Load fish calculations (excluding archived)
      final List<dynamic> fishCalculationsData = await _supabase
          .from('fish_calculations')
          .select('*')
          .eq('user_id', user.id)
          .or('archived.is.null,archived.eq.false');
      _savedFishCalculations = fishCalculationsData.map((json) => FishCalculation.fromJson(json)).toList();

      // Load compatibility results by calling the database function
      final List<dynamic> compatibilityResultsData = await _supabase.rpc('get_compatibility_results');

      print('Loaded raw compatibility results data via RPC: $compatibilityResultsData');

      final List<CompatibilityResult> parsedResults = [];
      for (final json in compatibilityResultsData) {
        try {
          // If the RPC returns an 'archived' flag, skip archived items
          final Map<String, dynamic> item = json as Map<String, dynamic>;
          if (item['archived'] == true) continue;
          parsedResults.add(CompatibilityResult.fromJson(item));
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
            .or('archived.is.null,archived.eq.false')
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
            .or('archived.is.null,archived.eq.false')
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
            // Exclude archived tanks from active list
            .or('archived.is.null,archived.eq.false')
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
      // Deduplicate: Ensure no archived items exist in active lists
      final archivedPredictionIds = _archivedPredictions.map((p) => p.id).toSet();
      _savedPredictions.removeWhere((p) => archivedPredictionIds.contains(p.id));

      final archivedCalculationIds = _archivedCalculations.map((c) => c.id).toSet();
      _savedCalculations.removeWhere((c) => archivedCalculationIds.contains(c.id));

      final archivedFishCalcIds = _archivedFishCalculations.map((c) => c.id).toSet();
      _savedFishCalculations.removeWhere((c) => archivedFishCalcIds.contains(c.id));

      final archivedCompatIds = _archivedCompatibilityResults.map((r) => r.id).toSet();
      _savedCompatibilityResults.removeWhere((r) => archivedCompatIds.contains(r.id));

      final archivedDietIds = _archivedDietCalculations.map((c) => c.id).toSet();
      _savedDietCalculations.removeWhere((c) => archivedDietIds.contains(c.id));

      final archivedFishVolIds = _archivedFishVolumeCalculations.map((c) => c.id).toSet();
      _savedFishVolumeCalculations.removeWhere((c) => archivedFishVolIds.contains(c.id));

      final archivedTankIds = _archivedTanks.map((t) => t.id).toSet();
      _savedTanks.removeWhere((t) => archivedTankIds.contains(t.id));

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
      String imageUrl = '';
      if (prediction.imagePath != null && prediction.imagePath!.isNotEmpty) {
        final imageFile = File(prediction.imagePath!);
        if (await imageFile.exists()) {
          final imageExt = prediction.imagePath!.split('.').last;
          final imagePathInStorage = '${user.id}/${DateTime.now().millisecondsSinceEpoch}.$imageExt';
          
          await _supabase.storage.from('fish_images').upload(
                imagePathInStorage,
                imageFile,
                fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
              );
          
          imageUrl = _supabase.storage.from('fish_images').getPublicUrl(imagePathInStorage);
        }
      }

      final response = await _supabase.from('fish_predictions').insert({
        'user_id': user.id,
        'common_name': prediction.commonName,
        'scientific_name': prediction.scientificName,
        'probability': prediction.probability,
        'image_path': imageUrl, // Save the public URL
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
  final item = response.first;
        if (item['archived'] != true) {
          _savedPredictions.add(FishPrediction.fromJson(item));
        } else {
          _archivedPredictions.insert(0, FishPrediction.fromJson(item));
        }
        notifyListeners();
      }
    } catch (e) {
      print('Error adding prediction to Supabase: $e');
      rethrow;
    }
  }

  Future<void> archivePrediction(FishPrediction prediction) async {
    try {
      // Remove from local list first to immediately update UI
      _savedPredictions.removeWhere((p) => p.id == prediction.id);
      // Add to archived list locally for immediate consistency
      _archivedPredictions.removeWhere((p) => p.id == prediction.id);
      _archivedPredictions.insert(0, prediction);
      notifyListeners();
      
      // Then update database
      await _supabase
          .from('fish_predictions')
          .update({'archived': true, 'archived_at': DateTime.now().toIso8601String()})
          .eq('id', prediction.id!);
    } catch (e) {
      print('Error archiving prediction from Supabase: $e');
      // Re-add to list if database update fails
      _savedPredictions.add(prediction);
      notifyListeners();
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
  final item = response.first;
        if (item['archived'] != true) {
          _savedCalculations.add(WaterCalculation.fromJson(item));
        } else {
          _archivedCalculations.insert(0, WaterCalculation.fromJson(item));
        }
        notifyListeners();
      }
    } catch (e) {
      print('Error adding water calculation to Supabase: $e');
    }
  }

  Future<void> archiveWaterCalculation(WaterCalculation calculation) async {
    try {
      print('Archiving water calculation: ${calculation.id}');
      
      // Create an updated calculation with archived status
      final updatedCalculation = WaterCalculation(
        id: calculation.id,
        minimumTankVolume: calculation.minimumTankVolume,
        fishSelections: calculation.fishSelections,
        recommendedQuantities: calculation.recommendedQuantities,
        dateCalculated: calculation.dateCalculated,
        phRange: calculation.phRange,
        temperatureRange: calculation.temperatureRange,
        tankStatus: calculation.tankStatus,
        tankShape: calculation.tankShape,
        waterRequirements: calculation.waterRequirements,
        tankmateRecommendations: calculation.tankmateRecommendations,
        feedingInformation: calculation.feedingInformation,
        createdAt: calculation.createdAt,
        waterParametersResponse: calculation.waterParametersResponse,
        tankAnalysisResponse: calculation.tankAnalysisResponse,
        filtrationResponse: calculation.filtrationResponse,
        dietCareResponse: calculation.dietCareResponse,
        archived: true,
        archivedAt: DateTime.now(),
      );

      // Update local list first to immediately update UI
      _savedCalculations.removeWhere((c) => c.id == calculation.id);
      _archivedCalculations.add(updatedCalculation);
      notifyListeners();
      
      // Then update database using RPC
      try {
        print('archiveWaterCalculation - calling RPC for calculation ${calculation.id}');

        // Call the RPC function to archive the calculation
        final updateResponse = await _supabase
            .rpc('archive_water_calculation', params: {
              'calculation_id': calculation.id
            });

        print('archiveWaterCalculation - update response type: ${updateResponse.runtimeType}');
        print('archiveWaterCalculation - update response: $updateResponse');
        if (updateResponse.isEmpty) {
          // Query the row to see if it exists and check its current state
          final currentRow = await _supabase
              .from('water_calculations')
              .select()
              .eq('id', calculation.id!)
              .single();
          print('archiveWaterCalculation - current row state: $currentRow');
        }

        if (updateResponse.isEmpty) {
          // No rows returned -> update may have failed
          print('archiveWaterCalculation - warning: update returned no rows for id ${calculation.id}');
          // Check if the row exists again after failed update
          try {
            final rowAfterUpdate = await _supabase
                .from('water_calculations')
                .select()
                .eq('id', calculation.id!)
                .single();
            print('archiveWaterCalculation - row after failed update: $rowAfterUpdate');
          } catch (e) {
            print('archiveWaterCalculation - error checking row after update: $e');
          }
          
          // Revert local optimistic changes
          _savedCalculations.add(calculation);
          _archivedCalculations.removeWhere((c) => c.id == calculation.id);
          notifyListeners();
        } else {
          print('Successfully archived water calculation: ${calculation.id}');
        }
      } catch (e) {
        print('archiveWaterCalculation - error updating Supabase: $e');
        // Revert local changes without throwing to avoid crashing the app
        _savedCalculations.add(calculation);
        _archivedCalculations.removeWhere((c) => c.id == calculation.id);
        notifyListeners();
      }
    } catch (e) {
      print('Error archiving water calculation: $e');
      // Revert local changes
      _savedCalculations.add(calculation);
      _archivedCalculations.removeWhere((c) => c.id == calculation.id);
      notifyListeners();
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
  final item = response.first;
        if (item['archived'] != true) {
          _savedFishCalculations.add(FishCalculation.fromJson(item));
        } else {
          _archivedFishCalculations.insert(0, FishCalculation.fromJson(item));
        }
        notifyListeners();
      }
    } catch (e) {
      print('Error adding fish calculation to Supabase: $e');
    }
  }

  Future<void> archiveFishCalculation(FishCalculation calculation) async {
    try {
      // Remove from local list first to immediately update UI
      _savedFishCalculations.removeWhere((c) => c.id == calculation.id);
      // Add to archived list locally
      _archivedFishCalculations.removeWhere((c) => c.id == calculation.id);
      _archivedFishCalculations.insert(0, calculation);
      notifyListeners();
      
      // Then update database
      await _supabase
          .from('fish_calculations')
          .update({'archived': true, 'archived_at': DateTime.now().toIso8601String()})
          .eq('id', calculation.id!);
    } catch (e) {
      print('Error archiving fish calculation from Supabase: $e');
      // Re-add to list if database update fails
      _savedFishCalculations.add(calculation);
      notifyListeners();
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
  final item = response.first;
        final newResult = CompatibilityResult.fromJson(item);
        if (item['archived'] != true) {
          _savedCompatibilityResults.add(newResult);
        } else {
          _archivedCompatibilityResults.insert(0, newResult);
        }
        notifyListeners();
      }
    } catch (e) {
      print('Error adding compatibility result to Supabase: $e');
    }
  }

  Future<void> archiveCompatibilityResult(CompatibilityResult result) async {
    try {
      // Remove from local list first to immediately update UI
      _savedCompatibilityResults.removeWhere((r) => r.id == result.id);
      // Add to archived list locally
      _archivedCompatibilityResults.removeWhere((r) => r.id == result.id);
      _archivedCompatibilityResults.insert(0, result);
      notifyListeners();
      
      // Then update database
      await _supabase
          .from('compatibility_results')
          .update({'archived': true, 'archived_at': DateTime.now().toIso8601String()})
          .eq('id', result.id!);
    } catch (e) {
      print('Error archiving compatibility result from Supabase: $e');
      // Re-add to list if database update fails
      _savedCompatibilityResults.add(result);
      notifyListeners();
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
        .or('archived.is.null,archived.eq.false')
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
  final item = response.first;
        if (item['archived'] != true) {
          _savedDietCalculations.insert(0, DietCalculation.fromJson(item));
        } else {
          _archivedDietCalculations.insert(0, DietCalculation.fromJson(item));
        }
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

  Future<void> archiveDietCalculation(DietCalculation calculation) async {
    try {
      // Remove from local list first to immediately update UI
      _savedDietCalculations.removeWhere((c) => c.id == calculation.id);
      // Add to archived list locally
      _archivedDietCalculations.removeWhere((c) => c.id == calculation.id);
      _archivedDietCalculations.insert(0, calculation);
      notifyListeners();
      
      // Then update database
      await _supabase
          .from('diet_calculations')
          .update({'archived': true, 'archived_at': DateTime.now().toIso8601String()})
          .eq('id', calculation.id!);
    } catch (e) {
      print('Error archiving diet calculation from Supabase: $e');
      // Re-add to list if database update fails
      _savedDietCalculations.add(calculation);
      notifyListeners();
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
        .or('archived.is.null,archived.eq.false')
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
  final item = response.first;
        if (item['archived'] != true) {
          _savedFishVolumeCalculations.insert(0, FishVolumeCalculation.fromJson(item));
        } else {
          _archivedFishVolumeCalculations.insert(0, FishVolumeCalculation.fromJson(item));
        }
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

  Future<void> archiveFishVolumeCalculation(FishVolumeCalculation calculation) async {
    try {
      // Remove from local list first to immediately update UI
      _savedFishVolumeCalculations.removeWhere((c) => c.id == calculation.id);
      // Add to archived list locally
      _archivedFishVolumeCalculations.removeWhere((c) => c.id == calculation.id);
      _archivedFishVolumeCalculations.insert(0, calculation);
      notifyListeners();
      
      // Then update database
      await _supabase
          .from('fish_volume_calculations')
          .update({'archived': true, 'archived_at': DateTime.now().toIso8601String()})
          .eq('id', calculation.id!);
    } catch (e) {
      print('Error archiving fish volume calculation from Supabase: $e');
      // Re-add to list if database update fails
      _savedFishVolumeCalculations.add(calculation);
      notifyListeners();
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
        .or('archived.is.null,archived.eq.false')
        .order('date_calculated', ascending: false);

    _savedFishVolumeCalculations = response
        .map((json) => FishVolumeCalculation.fromJson(json))
        .toList();
    notifyListeners();
  }

  // Load archived data
  Future<void> loadArchivedData() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      _clearArchivedData();
      return;
    }

    try {
      print('=== LOADING ARCHIVED DATA ===');
      
      // Load archived fish predictions
      print('Loading archived fish predictions...');
      final List<dynamic> archivedPredictionsData = await _supabase
          .from('fish_predictions')
          .select('*')
          .eq('user_id', user.id)
          .eq('archived', true);
      _archivedPredictions = archivedPredictionsData.map((json) => FishPrediction.fromJson(json)).toList();
      print('Loaded ${_archivedPredictions.length} archived fish predictions');

      // Load archived water calculations
      print('Loading archived water calculations...');
      final List<dynamic> archivedWaterCalculationsData = await _supabase
          .from('water_calculations')
          .select('*')
          .eq('user_id', user.id)
          .eq('archived', true);
      print('Raw water calculations data from DB: $archivedWaterCalculationsData');
      _archivedCalculations = archivedWaterCalculationsData.map((json) => WaterCalculation.fromJson(json)).toList();
      print('Mapped ${_archivedCalculations.length} archived water calculations');

      // Load archived fish calculations
      print('Loading archived fish calculations...');
      final List<dynamic> archivedFishCalculationsData = await _supabase
          .from('fish_calculations')
          .select('*')
          .eq('user_id', user.id)
          .eq('archived', true);
      _archivedFishCalculations = archivedFishCalculationsData.map((json) => FishCalculation.fromJson(json)).toList();
      print('Loaded ${_archivedFishCalculations.length} archived fish calculations');

      // Load archived compatibility results
      print('Loading archived compatibility results...');
      final List<dynamic> archivedCompatibilityResultsData = await _supabase
          .from('compatibility_results')
          .select('*')
          .eq('user_id', user.id)
          .eq('archived', true);
      _archivedCompatibilityResults = archivedCompatibilityResultsData.map((json) => CompatibilityResult.fromJson(json)).toList();
      print('Loaded ${_archivedCompatibilityResults.length} archived compatibility results');

      // Load archived diet calculations
      print('Loading archived diet calculations...');
      final List<dynamic> archivedDietCalculationsData = await _supabase
          .from('diet_calculations')
          .select('*')
          .eq('user_id', user.id)
          .eq('archived', true);
      _archivedDietCalculations = archivedDietCalculationsData.map((json) => DietCalculation.fromJson(json)).toList();
      print('Loaded ${_archivedDietCalculations.length} archived diet calculations');

      // Load archived fish volume calculations
      print('Loading archived fish volume calculations...');
      final List<dynamic> archivedFishVolumeCalculationsData = await _supabase
          .from('fish_volume_calculations')
          .select('*')
          .eq('user_id', user.id)
          .eq('archived', true);
      _archivedFishVolumeCalculations = archivedFishVolumeCalculationsData.map((json) => FishVolumeCalculation.fromJson(json)).toList();
      print('Loaded ${_archivedFishVolumeCalculations.length} archived fish volume calculations');

      // Load archived tanks
      print('Loading archived tanks...');
      final List<dynamic> archivedTanksData = await _supabase
          .from('tanks')
          .select('*')
          .eq('user_id', user.id)
          .eq('archived', true);
      _archivedTanks = archivedTanksData.map((json) => Tank.fromJson(json)).toList();
      print('Loaded ${_archivedTanks.length} archived tanks');
      
      print('=== FINISHED LOADING ARCHIVED DATA ===');

    } catch (e) {
      print('Error loading archived data from Supabase: $e');
      _clearArchivedData();
    } finally {
      // Deduplicate: remove any archived items that might still exist in active lists
      final archivedPredictionIds = _archivedPredictions.map((p) => p.id).toSet();
      _savedPredictions.removeWhere((p) => archivedPredictionIds.contains(p.id));

      final archivedCalculationIds = _archivedCalculations.map((c) => c.id).toSet();
      _savedCalculations.removeWhere((c) => archivedCalculationIds.contains(c.id));

      final archivedFishCalcIds = _archivedFishCalculations.map((c) => c.id).toSet();
      _savedFishCalculations.removeWhere((c) => archivedFishCalcIds.contains(c.id));

      final archivedCompatIds = _archivedCompatibilityResults.map((r) => r.id).toSet();
      _savedCompatibilityResults.removeWhere((r) => archivedCompatIds.contains(r.id));

      final archivedDietIds = _archivedDietCalculations.map((c) => c.id).toSet();
      _savedDietCalculations.removeWhere((c) => archivedDietIds.contains(c.id));

      final archivedFishVolIds = _archivedFishVolumeCalculations.map((c) => c.id).toSet();
      _savedFishVolumeCalculations.removeWhere((c) => archivedFishVolIds.contains(c.id));

      final archivedTankIds = _archivedTanks.map((t) => t.id).toSet();
      _savedTanks.removeWhere((t) => archivedTankIds.contains(t.id));

      notifyListeners();
    }
  }

  // Clear archived data
  void _clearArchivedData() {
    _archivedPredictions.clear();
    _archivedCalculations.clear();
    _archivedFishCalculations.clear();
    _archivedCompatibilityResults.clear();
    _archivedDietCalculations.clear();
    _archivedFishVolumeCalculations.clear();
    _archivedTanks.clear();
    notifyListeners();
  }

  // Restore archived prediction
  Future<void> restorePrediction(FishPrediction prediction) async {
    try {
      // Remove from archived list first
      _archivedPredictions.removeWhere((p) => p.id == prediction.id);
      notifyListeners();
      
      // Update database to unarchive
      await _supabase
          .from('fish_predictions')
          .update({'archived': false, 'archived_at': null})
          .eq('id', prediction.id!);
      
      // Reload active data
      await _loadData();
    } catch (e) {
      print('Error restoring prediction from Supabase: $e');
      // Re-add to archived list if database update fails
      _archivedPredictions.add(prediction);
      notifyListeners();
    }
  }

  // Restore archived water calculation
  Future<void> restoreWaterCalculation(WaterCalculation calculation) async {
    try {
      print('Restoring water calculation: ${calculation.id}');
      
      // Create an updated calculation with archived status cleared
      final updatedCalculation = WaterCalculation(
        id: calculation.id,
        minimumTankVolume: calculation.minimumTankVolume,
        fishSelections: calculation.fishSelections,
        recommendedQuantities: calculation.recommendedQuantities,
        dateCalculated: calculation.dateCalculated,
        phRange: calculation.phRange,
        temperatureRange: calculation.temperatureRange,
        tankStatus: calculation.tankStatus,
        tankShape: calculation.tankShape,
        waterRequirements: calculation.waterRequirements,
        tankmateRecommendations: calculation.tankmateRecommendations,
        feedingInformation: calculation.feedingInformation,
        createdAt: calculation.createdAt,
        waterParametersResponse: calculation.waterParametersResponse,
        tankAnalysisResponse: calculation.tankAnalysisResponse,
        filtrationResponse: calculation.filtrationResponse,
        dietCareResponse: calculation.dietCareResponse,
        archived: false,
        archivedAt: null,
      );

      // Update local lists first for immediate UI update
      _archivedCalculations.removeWhere((c) => c.id == calculation.id);
      _savedCalculations.add(updatedCalculation);
      notifyListeners();
      
      // Update database to unarchive
      await _supabase
          .from('water_calculations')
          .update({
            'archived': false, 
            'archived_at': null
          })
          .eq('id', calculation.id!);
          
      print('Successfully restored water calculation: ${calculation.id}');
    } catch (e) {
      print('Error restoring water calculation from Supabase: $e');
      // Revert local changes if database update fails
      _archivedCalculations.add(calculation);
      _savedCalculations.removeWhere((c) => c.id == calculation.id);
      notifyListeners();
      rethrow; // Re-throw to allow error handling upstream
    }
  }

  // Restore archived fish calculation
  Future<void> restoreFishCalculation(FishCalculation calculation) async {
    try {
      // Remove from archived list first
      _archivedFishCalculations.removeWhere((c) => c.id == calculation.id);
      notifyListeners();
      
      // Update database to unarchive
      await _supabase
          .from('fish_calculations')
          .update({'archived': false, 'archived_at': null})
          .eq('id', calculation.id!);
      
      // Reload active data
      await _loadData();
    } catch (e) {
      print('Error restoring fish calculation from Supabase: $e');
      // Re-add to archived list if database update fails
      _archivedFishCalculations.add(calculation);
      notifyListeners();
    }
  }

  // Restore archived diet calculation
  Future<void> restoreDietCalculation(DietCalculation calculation) async {
    try {
      // Remove from archived list first
      _archivedDietCalculations.removeWhere((c) => c.id == calculation.id);
      notifyListeners();
      
      // Update database to unarchive
      await _supabase
          .from('diet_calculations')
          .update({'archived': false, 'archived_at': null})
          .eq('id', calculation.id!);
      
      // Reload active data
      await _loadData();
    } catch (e) {
      print('Error restoring diet calculation from Supabase: $e');
      // Re-add to archived list if database update fails
      _archivedDietCalculations.add(calculation);
      notifyListeners();
    }
  }

  // Restore archived fish volume calculation
  Future<void> restoreFishVolumeCalculation(FishVolumeCalculation calculation) async {
    try {
      // Remove from archived list first
      _archivedFishVolumeCalculations.removeWhere((c) => c.id == calculation.id);
      notifyListeners();
      
      // Update database to unarchive
      await _supabase
          .from('fish_volume_calculations')
          .update({'archived': false, 'archived_at': null})
          .eq('id', calculation.id!);
      
      // Reload active data
      await _loadData();
    } catch (e) {
      print('Error restoring fish volume calculation from Supabase: $e');
      // Re-add to archived list if database update fails
      _archivedFishVolumeCalculations.add(calculation);
      notifyListeners();
    }
  }

  // Restore archived compatibility result
  Future<void> restoreCompatibilityResult(CompatibilityResult result) async {
    try {
      // Remove from archived list first
      _archivedCompatibilityResults.removeWhere((r) => r.id == result.id);
      notifyListeners();
      
      // Update database to unarchive
      await _supabase
          .from('compatibility_results')
          .update({'archived': false, 'archived_at': null})
          .eq('id', result.id!);
      
      // Reload active data
      await _loadData();
    } catch (e) {
      print('Error restoring compatibility result from Supabase: $e');
      // Re-add to archived list if database update fails
      _archivedCompatibilityResults.add(result);
      notifyListeners();
    }
  }

}
