import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/api_config.dart';
import '../widgets/custom_notification.dart';
import '../screens/logbook_provider.dart';
import '../services/fish_species_service.dart'; // Fish species database service
import '../models/diet_calculation.dart';
import 'dart:async';
import '../widgets/expandable_reason.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:lottie/lottie.dart';
import '../widgets/auth_required_dialog.dart';
import '../widgets/fish_info_dialog.dart';
import '../widgets/fish_selection_widget.dart';
import '../widgets/beginner_guide_dialog.dart';



class DietCalculator extends StatefulWidget {
  const DietCalculator({super.key});

  @override
  _DietCalculatorState createState() => _DietCalculatorState();
}

class _DietCalculatorState extends State<DietCalculator> with SingleTickerProviderStateMixin {
  final Map<String, int> _fishSelections = {};
  List<Map<String, dynamic>> _availableFish = [];
  bool _isLoading = false;
  bool _isCalculating = false; // only for diet calculation overlay
  Map<String, dynamic>? _calculationResult;
  String _compatibilityReason = '';
  List<Map<String, dynamic>>? _incompatiblePairs;
  bool _showPerFishBreakdown = false;
  bool _showFeedingTips = false;
  bool _showFoodTypes = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadFishData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onFishSelectionChanged(Map<String, int> newSelections) {
    setState(() {
      _fishSelections.clear();
      _fishSelections.addAll(newSelections);
    });
  }


  // Real-time compatibility check method
  Future<Map<String, dynamic>> _getRealTimeCompatibilityResults() async {
    try {
      final fishNames = _fishSelections.keys.toList();
      if (fishNames.length < 2) {
        return {'incompatible_pairs': [], 'conditional_pairs': []};
      }

      // Expand fish names by quantity for accurate compatibility checking
      final expandedFishNames = _fishSelections.entries
          .expand((e) => List.filled(e.value, e.key))
          .toList();
      
      final response = await http.post(
        Uri.parse(ApiConfig.checkGroupEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        },
        body: json.encode({'fish_names': expandedFishNames}),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        return {'incompatible_pairs': [], 'conditional_pairs': []};
      }

      final data = json.decode(response.body);
      final results = data['results'] as List? ?? [];
      
      final List<Map<String, dynamic>> incompatiblePairs = [];
      final List<Map<String, dynamic>> conditionalPairs = [];
      final Set<String> seenPairs = {};
      
      for (var result in results) {
        final compatibility = result['compatibility'];
        
        if (compatibility == 'Not Compatible' || compatibility == 'Conditional' || compatibility == 'Conditionally Compatible') {
          final pair = List<String>.from(result['pair'].map((e) => e.toString()));
          if (pair.length == 2) {
            final a = pair[0].toLowerCase();
            final b = pair[1].toLowerCase();
            final key = ([a, b]..sort()).join('|');
            if (!seenPairs.contains(key)) {
              seenPairs.add(key);
              
              if (compatibility == 'Not Compatible') {
                incompatiblePairs.add({
                  'pair': result['pair'],
                  'reasons': result['reasons'],
                  'type': 'incompatible',
                });
              } else if (compatibility == 'Conditional' || compatibility == 'Conditionally Compatible') {
                conditionalPairs.add({
                  'pair': result['pair'],
                  'reasons': result['reasons'],
                  'type': 'conditional',
                });
              }
            }
          }
        }
      }

      return {
        'has_incompatible_pairs': incompatiblePairs.isNotEmpty,
        'has_conditional_pairs': conditionalPairs.isNotEmpty,
        'incompatible_pairs': incompatiblePairs,
        'conditional_pairs': conditionalPairs,
      };
    } catch (e) {
      print('Error getting real-time compatibility results: $e');
      return {
        'has_incompatible_pairs': false,
        'has_conditional_pairs': false,
        'incompatible_pairs': [],
        'conditional_pairs': [],
      };
    }
  }

  Future<void> _loadFishData() async {
    setState(() => _isLoading = true);
    try {
      // First check server connection
      final isConnected = await ApiConfig.checkServerConnection();
      if (!isConnected) {
        throw Exception('Cannot connect to server. Please check your connection.');
      }

      final response = await http.get(
        Uri.parse(ApiConfig.fishListEndpoint),
        headers: {'Accept': 'application/json'}
      ).timeout(ApiConfig.timeout);
      
      if (response.statusCode == 200) {
        final List<dynamic> fishList = json.decode(response.body);
        setState(() {
          _availableFish = fishList.cast<Map<String, dynamic>>();
          // Sort by common name
          _availableFish.sort((a, b) => (a['common_name'] as String).compareTo(b['common_name'] as String));
        });
      } else {
        throw Exception('Failed to load fish list: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching fish list: $e');
      _showNotification(
        'Error loading fish list: ${e.toString()}',
        isError: true,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _calculateDiet() async {
    // Validate inputs
    if (_fishSelections.isEmpty) {
      _showNotification('Please add at least one fish.', isError: true);
        return;
    }
    
    // Validate quantities
    for (final entry in _fishSelections.entries) {
      if (entry.value <= 0) {
        _showNotification('Please set a valid quantity for ${entry.key} (greater than 0).', isError: true);
        return;
      }
    }
    
    final fishSelections = Map<String, int>.from(_fishSelections);

    setState(() {
      _isLoading = true; // still used to disable buttons
      _isCalculating = true; // drives the Lottie overlay
      _calculationResult = null;
      _compatibilityReason = '';
    });

    try {
      // STEP 1: Check compatibility FIRST (faster check)
      final totalCount = fishSelections.values.fold<int>(0, (sum, v) => sum + v);
      if (totalCount >= 2) {
        final isCompatible = await _checkCompatibility(fishSelections);
        if (!isCompatible) {
          // Show incompatibility results immediately
          final incompatiblePairs = await _getIncompatiblePairs(fishSelections);

          // Enrich reasons with AI explanations (cached) before presenting
          for (final item in incompatiblePairs) {
            final pair = (item['pair'] as List).cast<dynamic>();
            if (pair.length == 2) {
              final reasons = (item['reasons'] as List).cast<String>();
              try {
                // Use base reasons directly from database
                final detailed = reasons;
                if (detailed.isNotEmpty) {
                  item['reasons'] = detailed;
                }
              } catch (_) {
                // keep base reasons on failure
              }
            }
          }

          setState(() {
            _calculationResult = {
              'error': 'Incompatible Fish Combinations',
              'incompatibility_reasons': _compatibilityReason,
              'fish_selections': fishSelections,
            };
            _incompatiblePairs = incompatiblePairs;
            _isLoading = false;
            _isCalculating = false;
          });
          // Switch to compatibility tab
          _tabController.animateTo(1);
          return;
        }
      }

      // STEP 2: Only if compatible, proceed with diet calculation (slower API calls)
      // Pre-switch to Results tab to avoid showing Compatibility briefly.
      if (mounted) {
        // Immediate switch, no animation to prevent flicker
        _tabController.index = 2;
      }
      await _calculateDietPortions(fishSelections);
    } catch (e) {
      _showNotification('Error calculating diet: $e', isError: true);
      setState(() {
        _isLoading = false;
        _isCalculating = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _getIncompatiblePairs(Map<String, int> fishSelections) async {
    try {
      final List<Map<String, dynamic>> incompatiblePairs = [];
      
      // STEP 1: Check individual species compatibility (same species with multiple quantities)
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
                final reasons = List<String>.from(result['reasons'] ?? []);
                incompatiblePairs.add({
                  'pair': [fishName, fishName],
                  'reasons': reasons,
                  'type': 'same_species',
                  'quantity': quantity,
                });
                break; // Only need one incompatibility reason per species
              }
            }
          }
        }
      }
      
      // STEP 2: Check cross-species compatibility (if multiple species)
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
          final Set<String> seenPairs = {};
          
          for (var result in crossSpeciesData['results']) {
            if (result['compatibility'] == 'Not Compatible') {
              final pair = List<String>.from(result['pair'].map((e) => e.toString()));
              if (pair.length == 2) {
                final a = pair[0].toLowerCase();
                final b = pair[1].toLowerCase();
                final key = ([a, b]..sort()).join('|');
                
                // Only add cross-species incompatibilities (not same species)
                if (a != b && !seenPairs.contains(key)) {
                  seenPairs.add(key);
                  final reasons = List<String>.from(result['reasons'] ?? []);
                  incompatiblePairs.add({
                    'pair': result['pair'],
                    'reasons': reasons,
                    'type': 'cross_species',
                  });
                }
              }
            }
          }
        }
      }

      return incompatiblePairs;
    } catch (e) {
      print('Error getting incompatible pairs: $e');
      return [];
    }
  }

  Future<bool> _checkCompatibility(Map<String, int> fishSelections) async {
    try {
      final incompatiblePairs = await _getIncompatiblePairs(fishSelections);
      
      if (incompatiblePairs.isNotEmpty) {
        final List<String> incompatibilityReasons = [];
        
        for (var pair in incompatiblePairs) {
          if (pair['type'] == 'same_species') {
            final fishName = pair['pair'][0];
            final quantity = pair['quantity'];
            final reasons = List<String>.from(pair['reasons']);
            incompatibilityReasons.add('$quantity $fishName together: ${reasons.join(", ")}');
          } else {
            final pairNames = pair['pair'];
            final reasons = List<String>.from(pair['reasons']);
            incompatibilityReasons.add('${pairNames[0]} + ${pairNames[1]}: ${reasons.join(", ")}');
          }
        }
        
        setState(() {
          _compatibilityReason = incompatibilityReasons.join('\n\n');
          _incompatiblePairs = incompatiblePairs;
        });
        return false;
      }
      
      return true;
    } catch (e) {
      print('Error checking compatibility: $e');
      _showNotification('Error checking compatibility: $e', isError: true);
      return true; // Default to compatible if check fails
    }
  }

  Future<void> _calculateDietPortions(Map<String, int> fishSelections) async {
    try {
      Map<String, dynamic> fishPortions = {};
      // tankTotalsByFoodType removed as it's no longer saved to database
      
      // Fetch fish species data from database
      final fishData = await FishSpeciesService.getFishSpeciesByNames(fishSelections.keys.toList());
      
      if (fishData.isEmpty) {
        throw Exception('No fish data found in database');
      }
      
      // Process each fish species
      for (String fishName in fishSelections.keys) {
        final quantity = fishSelections[fishName]!;
        final fishInfo = fishData[fishName];
        
        if (fishInfo == null) {
          print('No data found for fish: $fishName');
          continue;
        }
        
        // Get portion data from database
        final portionGrams = FishSpeciesService.parsePortionGrams(fishInfo['portion_grams']);
        final preferredFoods = FishSpeciesService.parsePreferredFood(fishInfo['preferred_food']);
        
        // Calculate total portion for this species
        final totalPortionGrams = FishSpeciesService.calculateTotalPortion(portionGrams, quantity);
        final portionDisplay = FishSpeciesService.formatPortionDisplay(totalPortionGrams);
        
        // Use the first preferred food as the primary food type
        final primaryFoodType = preferredFoods.isNotEmpty ? preferredFoods.first : 'fish food';
        
        // Store fish-specific portion info
        fishPortions[fishName] = {
          'portion_grams': FishSpeciesService.formatPortionDisplay(portionGrams),
          'quantity': quantity,
          'total_portion': FishSpeciesService.formatPortionDisplay(totalPortionGrams),
          'per_fish': FishSpeciesService.formatPortionDisplay(portionGrams),
          'total_grams': totalPortionGrams,
          'total_display': portionDisplay,
          'food_type': primaryFoodType,
          'preferred_foods': preferredFoods,
        };
        
        // Tank totals by food type accumulation removed as it's no longer saved to database
      }
      
      // Calculate total combined portion for all fish
      double totalPortionGrams = 0.0;
      
      for (final fishData in fishPortions.values) {
        totalPortionGrams += fishData['total_grams'] as double;
      }
      
      // Format as simple portion display (e.g., "60.0g")
      final totalDisplay = FishSpeciesService.formatPortionDisplay(totalPortionGrams);
      
      // Build single total string
      final List<String> tankTotalStrings = [totalDisplay];

      // Get feeding frequency display for multiple fish
      final feedingFrequencyDisplay = _getFeedingFrequencyDisplay(fishData);

      // Generate feeding notes from database data
      final feedingNotes = FishSpeciesService.generateFeedingNotes(fishData);
      
      // Get all unique food types
      final allFoodTypes = fishData.values
          .expand((fish) => FishSpeciesService.parsePreferredFood(fish['preferred_food']))
          .toSet()
          .toList();
      
      
      final result = {
        'fish_portions': fishPortions,
        // tank_totals_by_food removed as it's no longer saved to database
        'tank_total_display': tankTotalStrings.join('; '),
        'total_portion': totalPortionGrams,
        'total_portion_range': tankTotalStrings.join('; '),
        'feedings_per_day': feedingFrequencyDisplay,
        'feeding_notes': feedingNotes,
        'feeding_tips': feedingNotes, // Use same as feeding notes
        'ai_food_types': allFoodTypes,
        'fish_data': fishData, // Store fish data for header display
        'calculation_date': DateTime.now().toIso8601String()
      };
      setState(() {
        _calculationResult = result;
        _isLoading = false;
        _isCalculating = false;
      });
      
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isCalculating = false;
      });
      _showNotification('Error calculating diet portions: $e', isError: true);
    }
  }

  // Format feeding tips for display
  String _formatFeedingTips(String tips) {
    if (tips.isEmpty) return tips;
    
    // Split by newlines and format each line
    final lines = tips.split('\n').where((line) => line.trim().isNotEmpty).toList();
    
    if (lines.isEmpty) return tips;
    
    // Format as bullet points
    return lines.map((line) => '• ${line.trim()}').join('\n');
  }

  void _showNotification(String message, {bool isError = false}) {
    if (!mounted) return;
    showCustomNotification(
      context,
      message,
      isError: isError,
    );
  }

  Widget _buildResultsTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_calculationResult == null || !_calculationResult!.containsKey('fish_portions')) ...[
            const SizedBox(height: 12),
          ] else ...[
            _buildResults(),
          ],
        ],
      ),
    );
  }

  // Build feeding notes as bullet points instead of a single paragraph


  
  Future<void> _saveDietCalculation() async {
    if (_calculationResult == null) return;
    
    final fishSelections = Map<String, int>.from(_fishSelections);
    
    final totalPortion = _calculationResult!['total_portion'] as double;
    // Process portionDetails to convert any double values to int
    final rawPortionDetails = _calculationResult!['fish_portions'] as Map<String, dynamic>;
    final Map<String, dynamic> portionDetails = {};
    rawPortionDetails.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        final processedValue = <String, dynamic>{};
        value.forEach((subKey, subValue) {
          if (subValue is double) {
            processedValue[subKey] = subValue.round();
          } else {
            processedValue[subKey] = subValue;
          }
        });
        portionDetails[key] = processedValue;
      } else {
        portionDetails[key] = value;
      }
    });
    try {
      // tankTotalsByFood processing removed as it's no longer saved to database

      // Prepare the data for the new structure
      final feedingSchedule = _calculationResult!['feedings_per_day']?.toString() ?? '2 times per day';
      final totalFoodPerFeeding = _calculationResult!['tank_total_display'] as String;
      final perFishBreakdown = _calculationResult!['fish_portions'] as Map<String, dynamic>;
      final recommendedFoodTypes = _calculationResult!['ai_food_types'] as List<String>?;
      final feedingTips = _calculationResult!['feeding_tips'] as String?;

      final dietCalculation = DietCalculation(
        fishSelections: fishSelections,
        totalPortion: totalPortion.round(),
        portionDetails: portionDetails,
        compatibilityIssues: _compatibilityReason.isNotEmpty ? [_compatibilityReason] : null,
        feedingNotes: _calculationResult!['feeding_notes'] as String,
        feedingSchedule: feedingSchedule,
        totalFoodPerFeeding: totalFoodPerFeeding,
        perFishBreakdown: perFishBreakdown,
        recommendedFoodTypes: recommendedFoodTypes,
        feedingTips: feedingTips,
        dateCalculated: DateTime.now(),
      );

      // Get auth token for authenticated request
      final supabase = Supabase.instance.client;
      final session = supabase.auth.currentSession;
      
      if (session == null) {
        // Show auth required dialog instead of throwing exception
        showDialog(
          context: context,
          builder: (BuildContext context) => const AuthRequiredDialog(
            title: 'Sign In Required',
            message: 'You need to sign in to save diet calculations to your collection.',
          ),
        );
        return;
      }

      // Save directly to Supabase with only the fields that exist in the database
      try {
        final response = await supabase.from('diet_calculations').insert({
          'user_id': session.user.id,
          'fish_selections': dietCalculation.fishSelections,
          'total_portion': dietCalculation.totalPortion,
          'portion_details': dietCalculation.portionDetails,
          'compatibility_issues': dietCalculation.compatibilityIssues,
          'feeding_notes': dietCalculation.feedingNotes,
          'feeding_schedule': dietCalculation.feedingSchedule,
          'total_food_per_feeding': dietCalculation.totalFoodPerFeeding,
          'per_fish_breakdown': dietCalculation.perFishBreakdown,
          'recommended_food_types': dietCalculation.recommendedFoodTypes,
          'feeding_tips': dietCalculation.feedingTips,
          'date_calculated': dietCalculation.dateCalculated.toIso8601String(),
          'created_at': DateTime.now().toIso8601String(),
          'saved_plan': dietCalculation.savedPlan,
        }).select();

        if (response.isNotEmpty) {
          print('Diet calculation saved directly to Supabase: ${response.first}');
          
          // Update the diet calculation with the ID from Supabase response
          final savedCalculation = DietCalculation(
            id: response.first['id']?.toString(),
            fishSelections: dietCalculation.fishSelections,
            totalPortion: dietCalculation.totalPortion,
            portionDetails: dietCalculation.portionDetails,
            compatibilityIssues: dietCalculation.compatibilityIssues,
            feedingNotes: dietCalculation.feedingNotes,
            feedingSchedule: dietCalculation.feedingSchedule,
            totalFoodPerFeeding: dietCalculation.totalFoodPerFeeding,
            perFishBreakdown: dietCalculation.perFishBreakdown,
            recommendedFoodTypes: dietCalculation.recommendedFoodTypes,
            feedingTips: dietCalculation.feedingTips,
            dateCalculated: dietCalculation.dateCalculated,
            createdAt: DateTime.now(),
            savedPlan: dietCalculation.savedPlan,
          );
          
          // Add to logbook provider for recent activity (without saving to Supabase again)
          if (mounted) {
            final logBookProvider = Provider.of<LogBookProvider>(context, listen: false);
            logBookProvider.addDietCalculationLocally(savedCalculation);
            print('Added diet calculation to logbook provider');
          }
          
          _showNotification('Diet calculation saved successfully!');
          
          // Clear inputs and results after successful save
          await Future.delayed(const Duration(milliseconds: 1500));
          if (mounted) {
            _tryAgain();
            _tabController.animateTo(0);
          }
        } else {
          throw Exception('Failed to save: No response from Supabase');
        }
      } catch (e) {
        print('Error saving to Supabase: $e');
        throw Exception('Failed to save: $e');
      }
    } catch (e) {
      print('Error saving diet calculation: $e');
      _showNotification('Error saving calculation: $e', isError: true);
    }
  }

  void _tryAgain() {
    setState(() {
      _compatibilityReason = '';
      _incompatiblePairs = null;
      _calculationResult = null;
      _fishSelections.clear();
    });
  }







  Widget _buildCompatibilityTab() {
    if (_incompatiblePairs == null || _incompatiblePairs!.isEmpty) {
      // When compatible, just show the success notice. Results live in the Results tab.
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF00BCD4)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle, color: Color(0xFF00BCD4)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No compatibility issues found',
                      style: TextStyle(fontSize: 16, color: Color(0xFF00BCD4), fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Warning Header
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFF6B6B),
                  Color(0xFFFF8585),
                ],
              ),
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 2,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.warning_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'Incompatible Fish Combinations',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          
          // Incompatible Pairs List
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 2,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: _incompatiblePairs!.asMap().entries.map((entry) {
                final index = entry.key;
                final pair = entry.value;
                final isLast = index == _incompatiblePairs!.length - 1;
                
                return Container(
                  decoration: BoxDecoration(
                    border: isLast ? null : Border(
                      bottom: BorderSide(
                        color: Colors.grey.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const FaIcon(
                              FontAwesomeIcons.fish,
                              color: Color(0xFF006064),
                              size: 18,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                pair['type'] == 'same_species' 
                                    ? '${pair['quantity']} ${pair['pair'][0]} together'
                                    : '${pair['pair'][0]} + ${pair['pair'][1]}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF006064),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...(pair['reasons'] as List).map((reason) => Padding(
                          padding: const EdgeInsets.only(left: 16, bottom: 6),
                          child: ExpandableReason(
                            text: '• ${reason.toString()}',
                            maxSentences: 999, // rely on char limit
                            maxChars: 100,
                            textStyle: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                              height: 1.5,
                            ),
                            linkColor: Color(0xFF00BCD4),
                            textAlign: TextAlign.justify,
                          ),
                        )).toList(),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),

          // Try Again Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                _tryAgain();
                _tabController.animateTo(0); // Switch back to main tab
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00BCD4),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: const Text(
                'Try Again',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (_calculationResult == null) return const SizedBox();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fish Header Section
          _buildFishHeader(),
          
          const SizedBox(height: 16),

          // Key Information Cards - Always in same row with equal height
          IntrinsicHeight(
            child: Row(
              children: [
                // Feeding Schedule
                Expanded(
                  flex: 1,
                  child: _buildSimpleCard(
                    'Feeding Schedule',
                    _calculationResult!['feedings_per_day']?.toString() ?? '2 times per day',
                    FontAwesomeIcons.clock,
                    const Color(0xFF00BCD4),
                  ),
                ),
                const SizedBox(width: 12),
                // Total Food
                Expanded(
                  flex: 1,
                  child: _buildSimpleCard(
                    'Total Food Per Feeding',
                    _calculationResult!['tank_total_display'] as String,
                    Icons.scale,
                    const Color(0xFF00BCD4),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Detailed Information
          _buildDetailedInfo(),
          
          const SizedBox(height: 16),
          
          // Action Buttons - Always in one row with responsive sizing
          LayoutBuilder(
            builder: (context, constraints) {
              // Calculate responsive padding based on screen width
              final isSmallScreen = constraints.maxWidth < 400;
              final buttonPadding = isSmallScreen 
                  ? const EdgeInsets.symmetric(vertical: 12, horizontal: 8)
                  : const EdgeInsets.symmetric(vertical: 16, horizontal: 12);
              
              return Row(
                children: [
                  Expanded(
                    flex: isSmallScreen ? 1 : 1,
                    child: OutlinedButton(
                      onPressed: () {
                        _tryAgain();
                        _tabController.animateTo(0);
                      },
                      style: OutlinedButton.styleFrom(
                        padding: buttonPadding,
                        side: const BorderSide(color: Colors.grey),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: Text(
                        'Calculate Again',
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.w600,
                          fontSize: isSmallScreen ? 14 : 16,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: isSmallScreen ? 8 : 12),
                  Expanded(
                    flex: isSmallScreen ? 1 : 1,
                    child: ElevatedButton(
                      onPressed: _saveDietCalculation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00BCD4),
                        foregroundColor: Colors.white,
                        padding: buttonPadding,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: Text(
                        'Save Results',
                        style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          
          const SizedBox(height: 100), // Extra space for safe area
        ],
      ),
    );
  }


  // Helper method to build simple info cards
  Widget _buildSimpleCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF00BCD4).withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00BCD4).withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF00BCD4), size: 20),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.black54,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
            textAlign: TextAlign.left,
          ),
        ],
      ),
    );
  }

  // Helper method to build detailed information with expandable sections
  Widget _buildDetailedInfo() {
    return Column(
      children: [
        // Per Fish Breakdown (for any number of fish)
        if (_calculationResult!['fish_portions'] != null && 
            (_calculationResult!['fish_portions'] as Map).isNotEmpty) ...[
          _buildExpandableCard(
            'Per Fish Breakdown',
            FontAwesomeIcons.fish,
            const Color(0xFF00BCD4),
            _buildTankTotalsDisplay(),
            _showPerFishBreakdown,
            () => setState(() => _showPerFishBreakdown = !_showPerFishBreakdown),
          ),
          const SizedBox(height: 12),
        ],
        
        // Recommended Food Types
        if (_calculationResult!['ai_food_types'] != null) ...[
          _buildExpandableCard(
            'Recommended Food Types',
            Icons.restaurant,
            const Color(0xFF00BCD4),
            Text(
              _formatFoodTypeRecommendations(_calculationResult!['ai_food_types'] as List<String>),
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black,
                height: 1.4,
              ),
              textAlign: TextAlign.left,
            ),
            _showFoodTypes,
            () => setState(() => _showFoodTypes = !_showFoodTypes),
          ),
          const SizedBox(height: 12),
        ],
        
        // Feeding Tips
        if (_calculationResult!['feeding_tips'] != null && 
            (_calculationResult!['feeding_tips'] as String).isNotEmpty) ...[
          _buildExpandableCard(
            'Feeding Tips',
            Icons.lightbulb_outline,
            const Color(0xFF00BCD4),
            Text(
              _formatFeedingTips(_calculationResult!['feeding_tips'] as String),
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black,
                height: 1.4,
              ),
              textAlign: TextAlign.justify,
            ),
            _showFeedingTips,
            () => setState(() => _showFeedingTips = !_showFeedingTips),
          ),
        ],
      ],
    );
  }

  // Helper method to build expandable cards
  Widget _buildExpandableCard(String title, IconData icon, Color color, Widget content, bool isExpanded, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF00BCD4).withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00BCD4).withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(icon, color: const Color(0xFF00BCD4), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: const Color(0xFF00BCD4),
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            const Divider(height: 1, color: Colors.grey),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: content,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Helper method to format food type recommendations
  String _formatFoodTypeRecommendations(List<String> foodTypes) {
    if (foodTypes.isEmpty) return 'No specific recommendations available.';
    
    // If multiple food types, show as bullet points
    if (foodTypes.length > 1) {
      return foodTypes.map((food) => '• $food').join('\n');
    } else {
      return '• ${foodTypes.first}';
    }
  }


  Widget _buildTankTotalsDisplay() {
    final fishPortions = _calculationResult?['fish_portions'] as Map<String, dynamic>?;
    
    if (fishPortions == null || fishPortions.isEmpty) {
      return const Text(
        'No fish data available',
        style: TextStyle(
          fontSize: 14,
          color: Color(0xFF004D40),
        ),
        textAlign: TextAlign.left,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Individual fish breakdown
        ...fishPortions.entries.map((entry) => Padding(
          padding: const EdgeInsets.only(bottom: 0),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${entry.value['quantity']}x ${entry.key}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF006064),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${entry.value['per_fish']} × ${entry.value['quantity']} = ${entry.value['total_portion']}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF666666),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        )),
      ],
    );
  }

  // Helper method to build fish header with selected fish names and info buttons
  Widget _buildFishHeader() {
    final fishData = _calculationResult?['fish_data'] as Map<String, Map<String, dynamic>>?;
    
    if (fishData == null || fishData.isEmpty) {
      return const SizedBox();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF00BCD4).withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00BCD4).withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header title
          Row(
            children: [
              const Icon(
                FontAwesomeIcons.fish,
                color: Color(0xFF00BCD4),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Selected Fish',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF006064),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Fish list with info buttons
          ...fishData.entries.map((entry) {
            final fishName = entry.key;
            final fishInfo = entry.value;
            final scientificName = fishInfo['scientific_name'] as String? ?? 'Unknown';
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  // Fish name and scientific name
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fishName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF006064),
                          ),
                        ),
                        Text(
                          scientificName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                            color: Color(0xFF666666),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Eye icon button
                  GestureDetector(
                    onTap: () => _showFishInfoDialog(fishName),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00BCD4).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF00BCD4).withOpacity(0.3)),
                      ),
                      child: const Icon(
                        Icons.remove_red_eye,
                        color: Color(0xFF00BCD4),
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  // Show fish info dialog
  void _showFishInfoDialog(String fishName) {
    showDialog(
      context: context,
      builder: (context) => FishInfoDialog(fishName: fishName),
    );
  }

  Widget _buildMainTab() {
    return Column(
      children: [
        const SizedBox(height: 16),
        // Help button row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
              const Text(
                'Diet Calculator',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF006064),
                ),
              ),
              GestureDetector(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => const BeginnerGuideDialog(calculatorType: 'diet'),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00ACC1).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF00ACC1).withOpacity(0.3),
                      width: 1,
                    ),
                  ),
          child: Row(
                    mainAxisSize: MainAxisSize.min,
            children: [
                      const Icon(
                        Icons.help_outline,
                        color: Color(0xFF00ACC1),
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Help',
                        style: TextStyle(
                          color: Color(0xFF00ACC1),
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: FutureBuilder<Map<String, dynamic>>(
            future: _fishSelections.length >= 2 ? _getRealTimeCompatibilityResults() : Future.value({}),
            builder: (context, snapshot) {
              Map<String, dynamic> compatibilityResults = {};
              
              if (snapshot.hasData) {
                compatibilityResults = snapshot.data!;
              } else if (snapshot.connectionState == ConnectionState.waiting && _fishSelections.length >= 2) {
                // Show loading state for compatibility check
                compatibilityResults = {
                  'loading': true,
                };
              }
              
              return FishSelectionWidget(
                selectedFish: _fishSelections,
                onFishSelectionChanged: _onFishSelectionChanged,
                availableFish: _availableFish,
                canProceed: _fishSelections.isNotEmpty && !_isLoading,
                onNext: _calculateDiet,
                compatibilityResults: compatibilityResults,
                tankShapeWarnings: const {},
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Main app scaffold
        Scaffold(
          body: TabBarView(
            controller: _tabController,
            physics: const NeverScrollableScrollPhysics(), // hide tabs and disable swipe
            children: [
              _buildMainTab(),
              _buildCompatibilityTab(),
              _buildResultsTab(),
            ],
          ),
        ),

        // Full-screen dialog overlay
        if (_isCalculating) _buildCalculatingDialog(),
      ],
    );
  }



  Widget _buildCalculatingDialog() {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Center(
        child: SizedBox(
          width: 200,
          height: 200,
          child: Lottie.asset(
            'lib/lottie/BowlAnimation.json',
            fit: BoxFit.contain,
            repeat: true,
          ),
        ),
      ),
    );
  }

  /// Get feeding frequency display for multiple fish
  String _getFeedingFrequencyDisplay(Map<String, Map<String, dynamic>> fishData) {
    if (fishData.isEmpty) return '2 times per day';
    
    // Get unique feeding frequencies
    final frequencies = fishData.values
        .map((fish) => FishSpeciesService.getFeedingFrequencyDisplay(fish['feeding_frequency']))
        .toSet()
        .toList();
    
    if (frequencies.length == 1) {
      return frequencies.first;
    } else {
      // Multiple different frequencies - show each fish's frequency
      final List<String> frequencyList = [];
      fishData.forEach((name, fish) {
        final frequency = FishSpeciesService.getFeedingFrequencyDisplay(fish['feeding_frequency']);
        frequencyList.add('$name: $frequency');
      });
      return frequencyList.join('\n');
    }
  }
}