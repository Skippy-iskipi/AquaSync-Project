import 'package:flutter/material.dart';
import '../models/fish_volume_calculation.dart';
import 'package:provider/provider.dart';
import 'logbook_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../config/api_config.dart';
import '../widgets/custom_notification.dart';
import 'package:lottie/lottie.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../widgets/expandable_reason.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/auth_required_dialog.dart';
import '../widgets/fish_info_dialog.dart';
import '../widgets/fish_card_tankmates.dart';
import '../widgets/beginner_guide_dialog.dart';

class FishCalculatorVolume extends StatefulWidget {
  final VoidCallback? onBack;
  
  const FishCalculatorVolume({super.key, this.onBack});

  @override
  _FishCalculatorVolumeState createState() => _FishCalculatorVolumeState();
}

class _FishCalculatorVolumeState extends State<FishCalculatorVolume> {
  String _selectedUnit = 'L';
  String _selectedTankShape = 'bowl';
  final TextEditingController _volumeController = TextEditingController();
  final TextEditingController _fishController1 = TextEditingController();
  List<String> _fishSpecies = [];
  bool _isCalculating = false;
  Map<String, int> _fishSelections = {};
  Map<String, dynamic>? _calculationData;

  // Fish data from Supabase
  Map<String, dynamic>? _fishData;
  
  // Dropdown state
  Map<String, bool> _showDropdown = {};
  Map<String, String> _searchQueries = {};
  
  // Key to reset autocomplete field
  int _autocompleteKey = 0;
  
  // Tank shape compatibility warnings
  Map<String, String> _fishTankShapeWarnings = {};
  
  // Store conditional compatibility pairs for display
  List<Map<String, dynamic>> _conditionalCompatibilityPairs = [];
  
  // Debounce timer for volume changes
  Timer? _volumeChangeTimer;

  // Live group compatibility preview (disable Calculate if incompatible)
  bool _isGroupIncompatible = false;
  List<Map<String, dynamic>> _groupIncompatibilityPairs = [];

  // Suggestions state
  bool _isSuggestionsExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadFishSpecies();
    _loadFishData();
    
    // Add listener to volume controller for real-time compatibility checks
    _volumeController.addListener(_onVolumeChanged);
  }

  // Preview group compatibility (non-blocking). Sets _isGroupIncompatible for UI button state
  Future<void> _updateGroupCompatibilityPreview() async {
    try {
      final totalCount = _fishSelections.values.fold<int>(0, (s, v) => s + v);
      if (totalCount < 2) {
        setState(() {
          _isGroupIncompatible = false;
          _groupIncompatibilityPairs = [];
        });
        return;
      }
      final expandedFishNames = _fishSelections.entries
          .expand((e) => List.filled(e.value, e.key))
          .toList();
      final resp = await http
          .post(
            Uri.parse(ApiConfig.checkGroupEndpoint),
            headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
            body: jsonEncode({'fish_names': expandedFishNames}),
          )
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) {
        setState(() {
          _isGroupIncompatible = false; // don't block on API error
          _groupIncompatibilityPairs = [];
        });
        return;
      }
      final data = json.decode(resp.body);
      bool hasIncompat = false;
      final List<Map<String, dynamic>> incompatiblePairs = [];
      final Set<String> seen = {};
      if (data['results'] is List) {
        for (final result in (data['results'] as List)) {
          final compatibility = result['compatibility'];
          if (compatibility == 'Not Compatible') {
            final pair = List<String>.from(result['pair'].map((e) => e.toString()));
            if (pair.length == 2) {
              final key = ([pair[0].toLowerCase(), pair[1].toLowerCase()]..sort()).join('|');
              if (!seen.contains(key)) {
                seen.add(key);
                incompatiblePairs.add({
                  'pair': result['pair'],
                  'reasons': result['reasons'],
                  'type': 'incompatible',
                });
              }
            }
            hasIncompat = true;
          }
        }
      }
      setState(() {
        _isGroupIncompatible = hasIncompat;
        _groupIncompatibilityPairs = incompatiblePairs;
      });
    } catch (e) {
      // On any error, do not block calculation
      setState(() {
        _isGroupIncompatible = false;
        _groupIncompatibilityPairs = [];
      });
    }
  }

  @override
  void dispose() {
    _volumeController.removeListener(_onVolumeChanged);
    _volumeChangeTimer?.cancel();
    _volumeController.dispose();
    _fishController1.dispose();
    super.dispose();
  }

  Future<void> _loadFishSpecies() async {
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
        final List<dynamic> fishList = jsonDecode(response.body);
        setState(() {
          _fishSpecies = fishList
              .map((fish) => fish['common_name'] as String)
              .toList();
          _fishSpecies.sort(); // Sort alphabetically
        });
      } else {
        print('Error loading fish species: ${response.statusCode}');
      }
    } catch (e) {
      print('Error loading fish species: $e');
    }
  }

  Future<void> _loadFishData() async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.fishListEndpoint),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List<dynamic> fishList = jsonDecode(response.body);
        _fishData = {};
        for (var fish in fishList) {
          _fishData![fish['common_name']] = fish;
        }
        print('Loaded fish data for ${_fishData!.length} species');
        
        // Debug: Show sample fish data
        if (_fishData!.isNotEmpty) {
          final sampleFish = _fishData!.values.first;
          print('Sample fish data: $sampleFish');
          print('Sample fish max_size_cm: ${sampleFish['max_size_cm']}');
        }
      } else {
        print('Failed to load fish data: ${response.statusCode}');
      }
    } catch (e) {
      print('Error loading fish data: $e');
    }
  }

  // Get unique fish names from saved predictions for suggestions
  List<String> _getSuggestedFishNames() {
    try {
      final logBookProvider = Provider.of<LogBookProvider>(context, listen: false);
      final savedPredictions = logBookProvider.savedPredictions;
      
      // Get unique fish names from saved predictions
      final uniqueFishNames = <String>{};
      for (final prediction in savedPredictions) {
        if (prediction.commonName.isNotEmpty) {
          uniqueFishNames.add(prediction.commonName);
        }
      }
      
      return uniqueFishNames.toList()..sort();
    } catch (e) {
      print('Error getting suggested fish names: $e');
      return [];
    }
  }

  // Build back to methods button
  Widget _buildBackToMethodsButton() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                if (widget.onBack != null) {
                  widget.onBack!();
                } else if (Navigator.canPop(context)) {
                  Navigator.of(context).pop();
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF00BFB3).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF00BFB3).withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(
                      Icons.arrow_back_ios,
                      color: Color(0xFF00BFB3),
                      size: 16,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Back to Methods',
                      style: TextStyle(
                        color: Color(0xFF00BFB3),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Spacer(),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => const BeginnerGuideDialog(calculatorType: 'volume'),
                );
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF00BFB3).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF00BFB3).withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(
                      Icons.help_outline,
                      color: Color(0xFF00BFB3),
                      size: 16,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Help',
                      style: TextStyle(
                        color: Color(0xFF00BFB3),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Build suggestion section widget
  Widget _buildSuggestionSection() {
    return Consumer<LogBookProvider>(
      builder: (context, logBookProvider, child) {
        final suggestedFish = _getSuggestedFishNames();
        
        if (suggestedFish.isEmpty) {
          return const SizedBox.shrink();
        }
        
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey[200]!),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Collapsible header
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isSuggestionsExpanded = !_isSuggestionsExpanded;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00BCD4).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.history,
                            color: Color(0xFF00BCD4),
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Saved Fish Suggestions',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF006064),
                                ),
                              ),
                              Text(
                                '${suggestedFish.length} fish from your collection',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        AnimatedRotation(
                          turns: _isSuggestionsExpanded ? 0.5 : 0.0,
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            Icons.keyboard_arrow_down,
                            color: Colors.grey[600],
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Collapsible content
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  height: _isSuggestionsExpanded ? null : 0,
                  child: _isSuggestionsExpanded
                      ? Container(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Fish chips - aligned to left
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Wrap(
                                  alignment: WrapAlignment.start,
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: suggestedFish.take(8).map((fishName) {
                                    return GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          // Add fish to selections
                                          _fishSelections[fishName] = (_fishSelections[fishName] ?? 0) + 1;
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[50],
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                            color: Colors.grey[300]!,
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              fishName,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                color: Colors.black87,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            const Icon(
                                              Icons.add_circle_outline,
                                              size: 14,
                                              color: Color(0xFF00BCD4),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                              
                              // Show more indicator if needed
                              if (suggestedFish.length > 8) ...[
                                const SizedBox(height: 12),
                                Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    child: Text(
                                      '+${suggestedFish.length - 8} more available',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Real-time volume change handler with debouncing
  void _onVolumeChanged() {
    // Cancel previous timer
    _volumeChangeTimer?.cancel();
    
    // Clear warnings immediately if volume is empty
    if (_fishSelections.isNotEmpty && _volumeController.text.isEmpty) {
      setState(() {
        _fishTankShapeWarnings.clear();
      });
      return;
    }
    
    // Only check compatibility if there are selected fish and volume is valid
    if (_fishSelections.isNotEmpty && _volumeController.text.isNotEmpty) {
      final volumeValue = double.tryParse(_volumeController.text);
      if (volumeValue != null && volumeValue > 0) {
        // Debounce the compatibility check by 500ms
        _volumeChangeTimer = Timer(const Duration(milliseconds: 500), () {
          print('🔄 Volume changed to ${_volumeController.text}${_selectedUnit} - checking compatibility...');
          _checkAllFishTankShapeCompatibility();
        });
      }
    }
  }



  void _addFishByName(String fishName) {
    if (!_fishSpecies.contains(fishName)) return;
    
    setState(() {
      // Add new fish
      if (_fishSelections.containsKey(fishName)) {
        _fishSelections[fishName] = _fishSelections[fishName]! + 1;
      } else {
        _fishSelections[fishName] = 1;
      }
      
      // Clear search query to allow adding more fish
      _searchQueries['fish'] = '';
    });
    
    // Check tank shape compatibility for the new fish
    _checkFishTankShapeCompatibility(fishName);
    
    // Also check all fish for real-time updates
    _checkAllFishTankShapeCompatibility();
    // Update group compatibility preview
    _updateGroupCompatibilityPreview();
  }



  void _clearFishInputs() {
    setState(() {
      _fishSelections = {};
      _fishController1.clear();
      _volumeController.clear();
      _calculationData = null;
      _selectedTankShape = 'bowl';
      _showDropdown.clear();
      _searchQueries.clear();
      _fishTankShapeWarnings.clear();
      _conditionalCompatibilityPairs.clear();
      _isGroupIncompatible = false;
      _groupIncompatibilityPairs = [];
    });
  }

  Future<void> _saveCalculation() async {
    if (_calculationData == null) return;

    // Check authentication first
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      // Show auth required dialog
      showDialog(
        context: context,
        builder: (BuildContext context) => const AuthRequiredDialog(
          title: 'Sign In Required',
          message: 'You need to sign in to save fish calculations to your collection.',
        ),
      );
      return;
    }

    // Check if any fish are unsuitable for the tank volume
    if (_hasUnsuitableFish()) {
      showCustomNotification(
        context,
        'Cannot save: Tank volume is not suitable for selected fish',
        isError: true,
      );
      return;
    }

    // Check for compatibility issues first
    if (_calculationData!['compatibility_issues'] != null && 
        (_calculationData!['compatibility_issues'] as List).isNotEmpty) {
      showCustomNotification(
        context,
        'Cannot save: Fish are not compatible with each other',
        isError: true,
      );
      return;
    }

    // Extract recommended quantities from fish details
    Map<String, int> recommendedQuantities = {};
    for (var fish in _calculationData!['fish_details']) {
      final name = fish['name'] as String;
      final recommended = fish['recommended_quantity'];
      if (recommended != null && recommended != "N/A") {
        recommendedQuantities[name] = recommended as int;
      }
    }

    // Prepare water requirements
    Map<String, dynamic> waterRequirements = {
      'temperature_range': _getTemperatureRangeFromFishData(),
      'ph_range': _getPhRangeFromFishData(),
    };

    // Prepare feeding information for each fish
    Map<String, dynamic> feedingInformation = {};
    for (String fishName in _fishSelections.keys) {
      final fishData = _fishData?[fishName];
      if (fishData != null) {
        feedingInformation[fishName] = {
          'portion_grams': fishData['portion_grams'],
          'preferred_food': fishData['preferred_food'],
          'feeding_notes': fishData['feeding_notes'],
          'overfeeding_risks': fishData['overfeeding_risks'],
        };
      }
    }

    // Get tankmate recommendations
    final tankmateRecommendations = await _getTankmateRecommendations();

    final calculation = FishVolumeCalculation(
      tankShape: _selectedTankShape,
      tankVolume: _calculationData!['tank_details']['volume'],
      fishSelections: _fishSelections,
      recommendedQuantities: recommendedQuantities,
      tankmateRecommendations: tankmateRecommendations.isNotEmpty ? tankmateRecommendations : null,
      waterRequirements: waterRequirements,
      feedingInformation: feedingInformation,
      dateCalculated: DateTime.now(),
    );

    final logBookProvider = Provider.of<LogBookProvider>(context, listen: false);
    await logBookProvider.addFishVolumeCalculation(calculation);

    showCustomNotification(context, 'Fish volume calculation saved to history');
    
    // Clear all inputs and reset state
    setState(() {
      _clearFishInputs();
      _volumeController.clear();
      _calculationData = null;
    });
  }

  Future<void> _calculateRequirements() async {
    // Check if any fish are selected
    if (_fishSelections.isEmpty) {
      showCustomNotification(
        context,
        'Please add at least one fish to calculate requirements',
        isError: true,
      );
      return;
    }

    // For bowl tanks, skip volume validation since it's hardcoded to 10L
    if (_selectedTankShape != 'bowl') {
      if (_volumeController.text.isEmpty) {
        showCustomNotification(
          context,
          'Please enter tank volume or use the Dimensions Calculator if you don\'t know it',
          isError: true,
        );
        return;
      }

      // Validate that volume is greater than zero
      final volumeValue = double.tryParse(_volumeController.text);
      if (volumeValue == null || volumeValue <= 0) {
        showCustomNotification(
          context,
          'Tank volume must be greater than 0. Please enter valid tank dimensions.',
          isError: true,
        );
        return;
      }
    }

    setState(() {
      _isCalculating = true;
      _calculationData = null;
    });

    try {
      // First, validate tank shape compatibility with fish sizes
      final tankShapeValidation = await _validateTankShapeCompatibility();
      if (tankShapeValidation != null) {
        setState(() {
          _calculationData = tankShapeValidation;
          _isCalculating = false;
        });
        return;
      }

      // Compute volume early for consistent error handling and later reuse
      double volume;
      if (_selectedTankShape == 'bowl') {
        volume = 10.0; // Bowl tanks are hardcoded to 10L
      } else {
        volume = double.parse(_volumeController.text);
        if (_selectedUnit == 'gal') {
          volume = volume * 3.78541; // Convert gallons to liters
        }
      }

      // Check fish-to-fish compatibility for multiple fish
      final totalCount = _fishSelections.values.fold<int>(0, (sum, v) => sum + v);
      print('Total fish count: $totalCount');
      
      if (totalCount >= 2) {
        print('Checking compatibility for multiple fish...');
        final expandedFishNames = _fishSelections.entries
            .expand((e) => List.filled(e.value, e.key))
            .toList();

        print('Main calculation compatibility check - fish selections: $_fishSelections');
        print('Main calculation compatibility check - expanded fish names: $expandedFishNames');

        final compatibilityResponse = await http.post(
          Uri.parse(ApiConfig.checkGroupEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        },
          body: jsonEncode({'fish_names': expandedFishNames}),
        ).timeout(const Duration(seconds: 30));

        if (compatibilityResponse.statusCode != 200) {
          throw Exception('Failed to check compatibility: ${compatibilityResponse.statusCode}');
        }

        print('Compatibility check completed successfully');
        final compatibilityData = json.decode(compatibilityResponse.body);
        print('Compatibility results: ${compatibilityData['results']?.length ?? 0} pairs checked');
        bool hasIncompatiblePairs = false;
        bool hasConditionalPairs = false;
        final List<Map<String, dynamic>> incompatiblePairs = [];
        final List<Map<String, dynamic>> conditionalPairs = [];
        final Set<String> seenPairs = {};
        
        for (var result in compatibilityData['results']) {
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
                hasIncompatiblePairs = true;
                incompatiblePairs.add({
                  'pair': result['pair'],
                  'reasons': result['reasons'],
                    'type': 'incompatible',
                  });
                } else if (compatibility == 'Conditional' || compatibility == 'Conditionally Compatible') {
                  hasConditionalPairs = true;
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

        print('Found ${incompatiblePairs.length} incompatible pairs and ${conditionalPairs.length} conditional pairs');
        
        // Only block calculation for truly incompatible pairs, allow conditional compatibility
        if (hasIncompatiblePairs) {
          print('Processing incompatible compatibility issues...');
          
          setState(() {
            _calculationData = {
              'error': 'Incompatible Fish Combinations',
              'incompatible_pairs': incompatiblePairs,
              'conditional_pairs': [], // Clear conditional pairs for incompatible case
              'all_pairs': incompatiblePairs,
              // Provide safe defaults to avoid UI errors
              'tank_details': {
                'volume': '${volume.toStringAsFixed(1)} L',
                'status': 'Incompatible',
              },
              'fish_details': <Map<String, dynamic>>[],
            };
            _isCalculating = false;
          });
          showCustomNotification(
            context,
            'Selected fish are not compatible with each other. Please adjust your selection.',
            isError: true,
          );
          return;
        }
        
        // Store conditional pairs for warning display but continue calculation
        if (hasConditionalPairs) {
          print('Found conditional compatibility issues, proceeding with warnings...');
          _conditionalCompatibilityPairs = conditionalPairs;
        }
      }

      // volume already computed above

      // Use the tank management system's approach for fish quantity recommendations
      print('Using tank management system approach for fish quantity recommendations');
      final calcResult = await _calculateRecommendedFishQuantities(volume, _fishSelections);
      final Map<String, int> recommendedQuantities = (calcResult['quantities'] as Map).map((k, v) => MapEntry(k as String, (v as num).toInt()));
      final Map<String, String> stockingWarnings = (calcResult['warnings'] as Map?)?.map((k, v) => MapEntry(k as String, v as String)) ?? {};
      
      // Build fish details with recommended quantities
      final fishDetails = <Map<String, dynamic>>[];
      for (final entry in _fishSelections.entries) {
        final fishName = entry.key;
        final currentQuantity = entry.value;
        final recommendedQuantity = recommendedQuantities[fishName] ?? 0;
        
        fishDetails.add({
          'name': fishName,
          'current_quantity': currentQuantity,
          'recommended_quantity': recommendedQuantity,
          if (stockingWarnings.containsKey(fishName)) 'stocking_warning': stockingWarnings[fishName],
          'individual_requirements': {
            'minimum_tank_size': '${(volume * 0.8).toStringAsFixed(1)} L', // 80% of tank volume
            'bioload_factor': _getBioloadFactor(fishName),
            'volume_per_fish': _getVolumePerFish(fishName),
          },
        });
      }

      setState(() {
        _calculationData = {
          'tank_details': {
            'volume': '${volume.toStringAsFixed(1)} L',
            'status': 'Optimal',
            'current_bioload': _calculateCurrentBioload(_fishSelections),
            'recommended_bioload': _calculateRecommendedBioload(recommendedQuantities),
          },
          'fish_details': fishDetails,
          'fish_selections': _fishSelections,
          'recommended_quantities': recommendedQuantities,
          if (stockingWarnings.containsKey('_global')) 'global_warning': stockingWarnings['_global'],
        };
        // Add conditional compatibility warnings to results if they exist
        if (_conditionalCompatibilityPairs.isNotEmpty) {
          _calculationData!['conditional_compatibility_warnings'] = _conditionalCompatibilityPairs;
        }
        _isCalculating = false;
      });
      
    } catch (e) {
      print('Error calculating requirements: $e');
      showCustomNotification(
        context,
        'Error: ${e.toString()}',
        isError: true,
      );
    } finally {
      setState(() {
        _isCalculating = false;
      });
    }
  }

  // Calculate recommended fish quantities using database data
  Future<Map<String, dynamic>> _calculateRecommendedFishQuantities(double tankVolume, Map<String, int> fishSelections) async {
    Map<String, int> recommendations = {};
    Map<String, String> stockingWarnings = {};
    
    print('\n🐠 === FISH QUANTITY CALCULATION DEBUG ===');
    print('Tank Volume: ${tankVolume.toStringAsFixed(1)}L');
    print('Selected Fish: ${fishSelections.keys.join(", ")}');
    
    // Fetch fish data from database using the same approach as tank management
    final fishData = await _getFishDataFromDatabase(fishSelections.keys.toList());
    
    // 1) Shared-capacity validation across species before per-species calc
    //    - If one species alone consumes the entire tank, mixing is not allowed
    //    - If the sum of minimums for one of each selected species exceeds tank volume, combination is not suitable
    if (fishSelections.length >= 2) {
      // Build per-species minimum liters per unit (handle schooling vs non-schooling)
      final Map<String, double> perUnitMinL = {};
      double totalMinForOneEach = 0.0;
      String? fullTankSpecies; // species whose minimum equals/exceeds tank volume
      for (final name in fishSelections.keys) {
        final info = fishData[name];
        if (info == null) continue;
        final minTankL = (info['minimum_tank_size_l'] ?? 0.0) as double;
        final behavior = (info['social_behavior'] ?? 'solitary').toString().toLowerCase();
        final isSchooling = behavior.contains('school') || behavior.contains('shoal') || behavior.contains('colonial');
        final perUnit = isSchooling && minTankL > 0 ? (minTankL / 6.0) : minTankL; // interpret schooling min as for ~6
        final perUnitClamped = perUnit > 0 ? perUnit : 0.0;
        perUnitMinL[name] = perUnitClamped;
        totalMinForOneEach += perUnitClamped;
        if (minTankL > 0 && minTankL >= tankVolume - 1e-6) {
          fullTankSpecies = name;
        }
      }
      // Case A: one species consumes the whole tank → mixing not suitable (set all to 0)
      if (fullTankSpecies != null) {
        print('❗ Shared check: "$fullTankSpecies" minimum equals/exceeds tank volume. Disallow mixing.');
        fishSelections.keys.forEach((name) {
          recommendations[name] = 0;
        });
        stockingWarnings['_global'] = 'Tank volume is fully used by $fullTankSpecies alone (${tankVolume.toStringAsFixed(1)}L). The selected combination is not suitable.';
        return {
          'quantities': recommendations,
          'warnings': stockingWarnings,
        };
      }
      // Case B: minimums for one of each exceed tank → combination not suitable
      if (totalMinForOneEach > tankVolume) {
        print('❗ Shared check: Sum of one-each minimums (${totalMinForOneEach.toStringAsFixed(1)}L) exceeds tank (${tankVolume.toStringAsFixed(1)}L).');
        fishSelections.keys.forEach((name) {
          recommendations[name] = 0;
        });
        stockingWarnings['_global'] = 'Selected combination requires at least ${totalMinForOneEach.toStringAsFixed(1)}L (one of each), but tank is ${tankVolume.toStringAsFixed(1)}L. Not suitable.';
        return {
          'quantities': recommendations,
          'warnings': stockingWarnings,
        };
      }
    }
    
    for (String fishName in fishSelections.keys) {
      print('\n--- Calculating for: $fishName ---');
      final fishInfo = fishData[fishName];
      if (fishInfo != null) {
        final maxSizeCm = fishInfo['max_size_cm'] ?? 0.0;
        final minimumTankSizeL = fishInfo['minimum_tank_size_l'] ?? 0.0;
        final bioload = fishInfo['bioload'] ?? 1.0;
        final socialBehavior = fishInfo['social_behavior'] ?? 'solitary';
        
        print('Database Values:');
        print('  - max_size_cm: $maxSizeCm cm');
        print('  - minimum_tank_size_l: $minimumTankSizeL L');
        print('  - bioload: $bioload');
        print('  - social_behavior: $socialBehavior');
        
        // Calculate recommended quantity using database data
        int recommendedQty = 0;
        
        // Check if tank meets minimum requirements first
        if (minimumTankSizeL > 0 && tankVolume < minimumTankSizeL) {
          // Tank too small for this species - recommend 0
          print('❌ Tank too small! ${tankVolume.toStringAsFixed(1)}L < $minimumTankSizeL L');
          recommendedQty = 0;
        } else {
          // Calculate based on fish behavior and tank capacity
          final result = _calculateFishQuantity(fishName, tankVolume, minimumTankSizeL, maxSizeCm, bioload, socialBehavior);
          final conservative = result['conservative'];
          final typical = result['typical'];
          final theoreticalMax = result['theoretical_max'];
          final warning = result['stocking_warning'];
          
          // Use typical as the recommended quantity
          recommendedQty = typical;
          if (warning != null && warning is String && warning.isNotEmpty) {
            stockingWarnings[fishName] = warning;
          }
          
          print('✅ Stocking Levels:');
          print('   Conservative (adult-safe): $conservative fish');
          print('   Typical (hobbyist): $typical fish ← RECOMMENDED');
          print('   Theoretical Max (top filtration): $theoreticalMax fish');
        }
        
        // Ensure maximum of 20 for better stocking
        final finalQty = recommendedQty.clamp(0, 20);
        print('Final recommended quantity: $finalQty');
        recommendations[fishName] = finalQty;
      } else {
        print('⚠️ No database info found, defaulting to 1');
        recommendations[fishName] = 1;
      }
    }
    
    print('\n🐠 === END CALCULATION DEBUG ===\n');
    return {
      'quantities': recommendations,
      'warnings': stockingWarnings,
    };
  }

  // Fetch fish data from database using the same approach as tank management
  Future<Map<String, Map<String, dynamic>>> _getFishDataFromDatabase(List<String> fishNames) async {
    final Map<String, Map<String, dynamic>> fishData = {};
    
    try {
      // Query fish_species table for the required data
      final response = await Supabase.instance.client
          .from('fish_species')
          .select('common_name, "max_size_(cm)", "minimum_tank_size_(l)", bioload, social_behavior')
          .inFilter('common_name', fishNames);
      
      for (final fish in response) {
        final commonName = fish['common_name'] as String?;
        final maxSizeCm = fish['max_size_(cm)'];
        final minimumTankSizeL = fish['minimum_tank_size_(l)'];
        final bioload = fish['bioload'];
        final socialBehavior = fish['social_behavior'];
        
        if (commonName != null) {
          fishData[commonName] = {
            'max_size_cm': maxSizeCm != null ? double.tryParse(maxSizeCm.toString()) ?? 0.0 : 0.0,
            'minimum_tank_size_l': minimumTankSizeL != null ? double.tryParse(minimumTankSizeL.toString()) ?? 0.0 : 0.0,
            'bioload': bioload != null ? double.tryParse(bioload.toString()) ?? 1.0 : 1.0,
            'social_behavior': socialBehavior?.toString() ?? 'solitary',
          };
        }
      }
      
      // Add fallback values for fish not found in database
      for (final fishName in fishNames) {
        if (!fishData.containsKey(fishName)) {
          // Try case-insensitive matching
          bool found = false;
          for (final dbFishName in fishData.keys) {
            if (dbFishName.toLowerCase() == fishName.toLowerCase()) {
              fishData[fishName] = fishData[dbFishName]!;
              found = true;
              break;
            }
          }
          
          if (!found) {
            // Use fallback values
            fishData[fishName] = {
              'max_size_cm': 10.0,
              'minimum_tank_size_l': 20.0,
              'bioload': 1.0,
              'social_behavior': 'solitary',
            };
          }
        }
      }
      
    } catch (e) {
      print('Error fetching fish data from database: $e');
      // Return fallback data for all fish
      for (final fishName in fishNames) {
        fishData[fishName] = {
          'max_size_cm': 10.0,
          'minimum_tank_size_l': 20.0,
          'bioload': 1.0,
        };
      }
    }
    
    return fishData;
  }

  // Calculate volume requirement from fish size (realistic aquarium stocking)
  double _calculateVolumeFromSize(double sizeCm) {
    // Calculate volume requirement based on fish size using realistic aquarium guidelines
    // More conservative approach for better fish welfare
    
    if (sizeCm <= 0) return 10.0; // Default fallback
    
    final sizeInches = sizeCm / 2.54;
    
    // Base volume calculation - 1 gallon per inch rule (more conservative)
    double baseVolume = sizeInches * 3.78; // 1 gallon = 3.78 liters
    
    // Adjust based on size categories - more realistic for aquarium stocking
    if (sizeCm <= 3.0) {
      // Very small fish (≤1.2 inches) - still need reasonable space
      baseVolume *= 0.8; // 80% of 1 gallon per inch
    } else if (sizeCm <= 5.0) {
      // Small fish (1.2-2 inches) - standard 1 gallon per inch
      baseVolume *= 1.0;
    } else if (sizeCm <= 8.0) {
      // Medium-small fish (2-3 inches) - need more space
      baseVolume *= 1.2;
    } else if (sizeCm <= 12.0) {
      // Medium fish (3-5 inches) - need significantly more space
      baseVolume *= 1.5;
    } else if (sizeCm <= 20.0) {
      // Large fish (5-8 inches) - need lots of space
      baseVolume *= 2.0;
    } else {
      // Very large fish (>8 inches) - need extensive space
      baseVolume *= 3.0;
    }
    
    return baseVolume.clamp(5.0, 200.0); // More conservative bounds
  }


  // Get bioload factor for a fish (based on size and temperament)
  double _getBioloadFactor(String fishName) {
    final fishData = _fishData?[fishName];
    
    if (fishData == null) return 1.0;
    
    final maxSizeCm = fishData['max_size_cm'] ?? 0.0;
    final temperament = fishData['temperament'] ?? 'peaceful';
    
    // Safety check: ensure fish size is valid
    if (maxSizeCm <= 0 || maxSizeCm.isNaN || maxSizeCm.isInfinite) {
      return 1.0;
    }
    
    // Base factor from size (larger fish = higher bioload)
    double sizeFactor = maxSizeCm / 10.0; // 1.0 for 10cm fish
    
    // Adjust based on temperament
    double temperamentMultiplier = 1.0;
    switch (temperament.toLowerCase()) {
      case 'aggressive':
        temperamentMultiplier = 1.5;
        break;
      case 'semi-aggressive':
        temperamentMultiplier = 1.2;
        break;
      case 'peaceful':
        temperamentMultiplier = 1.0;
        break;
      case 'shy':
        temperamentMultiplier = 0.8;
        break;
    }
    
    final result = sizeFactor * temperamentMultiplier;
    
    // Safety check: ensure result is valid
    if (result.isNaN || result.isInfinite) {
      return 1.0;
    }
    
    return result.clamp(0.1, 5.0);
  }

  // Get volume per fish in liters
  String _getVolumePerFish(String fishName) {
    final fishData = _fishData?[fishName];
    
    if (fishData == null) return '10 L';
    
    final maxSizeCm = fishData['max_size_cm'] ?? 0.0;
    final temperament = fishData['temperament'] ?? 'peaceful';
    
    // Safety check: ensure fish size is valid
    if (maxSizeCm <= 0 || maxSizeCm.isNaN || maxSizeCm.isInfinite) {
      return '10 L';
    }
    
    // Base volume calculation: 1 gallon per inch of fish
    final maxSizeInches = maxSizeCm / 2.54;
    
    // Safety check: ensure conversion is valid
    if (maxSizeInches <= 0 || maxSizeInches.isNaN || maxSizeInches.isInfinite) {
      return '10 L';
    }
    
    double baseVolumeGallons = maxSizeInches;
    
    // Adjust based on temperament
    double temperamentMultiplier = 1.0;
    switch (temperament.toLowerCase()) {
      case 'aggressive':
        temperamentMultiplier = 2.0;
        break;
      case 'semi-aggressive':
        temperamentMultiplier = 1.5;
        break;
      case 'peaceful':
        temperamentMultiplier = 1.0;
        break;
      case 'shy':
        temperamentMultiplier = 0.8;
        break;
    }
    
    final volumeLiters = baseVolumeGallons * temperamentMultiplier * 3.78541;
    
    // Safety check: ensure result is valid
    if (volumeLiters.isNaN || volumeLiters.isInfinite) {
      return '10 L';
    }
    
    final clampedVolume = volumeLiters.clamp(5.0, 200.0);
    return '${clampedVolume.toStringAsFixed(1)} L';
  }

  // Calculate current bioload based on selected fish
  double _calculateCurrentBioload(Map<String, int> fishSelections) {
    double totalBioload = 0.0;
    
    for (final entry in fishSelections.entries) {
      final fishName = entry.key;
      final quantity = entry.value;
      final bioloadFactor = _getBioloadFactor(fishName);
      totalBioload += bioloadFactor * quantity;
    }
    
    return totalBioload;
  }

  // Calculate recommended bioload based on recommended quantities
  double _calculateRecommendedBioload(Map<String, int> recommendedQuantities) {
    double totalBioload = 0.0;
    
    for (final entry in recommendedQuantities.entries) {
      final fishName = entry.key;
      final quantity = entry.value;
      final bioloadFactor = _getBioloadFactor(fishName);
      totalBioload += bioloadFactor * quantity;
    }
    
    return totalBioload;
  }

  // Calculate fish quantity based on behavior and tank capacity
  Map<String, dynamic> _calculateFishQuantity(String fishName, double tankVolume, double minimumTankSizeL, double maxSizeCm, double bioload, String socialBehavior) {
    final fishNameLower = fishName.toLowerCase();
    final socialBehaviorLower = socialBehavior.toLowerCase();
    
    print('Calculation Method:');
    print('  → Social Behavior: $socialBehavior');

    // Determine fish category from social_behavior database field
    final isSchoolingFish = socialBehaviorLower.contains('school') ||
                           socialBehaviorLower.contains('shoal') ||
                           socialBehaviorLower.contains('colonial');

    final isSolitaryFish = socialBehaviorLower.contains('solitary') ||
                          socialBehaviorLower.contains('territorial') ||
                          socialBehaviorLower.contains('predatory');

    final isPairFish = socialBehaviorLower.contains('pair');

    // Community fish are the default (sociable, peaceful, semi-social, small groups, community, etc.)
    final isCommunityFish = !isSchoolingFish && !isSolitaryFish && !isPairFish;

    // Log the detected category
    if (isSchoolingFish) {
      print('  → Category: Schooling Fish');
    } else if (isSolitaryFish) {
      print('  → Category: Solitary Fish');
    } else if (isPairFish) {
      print('  → Category: Pair Fish');
    } else if (isCommunityFish) {
      print('  → Category: Community Fish');
    } else {
      print('  → Category: Unknown/Community (default)');
    }
    
    // Special handling for solitary/territorial fish
    if (isSolitaryFish) {
      print('  → Solitary/Territorial species: Recommend 1');
      return {'conservative': 1, 'typical': 1, 'theoretical_max': 1};
    }
    
    // Special handling for pair fish
    if (isPairFish && !isSchoolingFish) {
      print('  → Pair species: Recommend 2');
      return {'conservative': 2, 'typical': 2, 'theoretical_max': 2};
    }
    
    // For other fish, calculate based on tank capacity
    if (minimumTankSizeL > 0) {
      // Interpret minimum_tank_size_l
      // - For schooling fish: it's typically the baseline volume for a proper group (~6)
      // - For non-schooling fish: use as-is (per fish baseline)
      double divisorLiters;
      if (isSchoolingFish) {
        // Derive per-fish liters from baseline group size of 6
        divisorLiters = (minimumTankSizeL / 6.0).clamp(1.0, double.infinity);
        print('  → Schooling species: treating min tank ${minimumTankSizeL.toStringAsFixed(1)}L as for 6 fish → per-fish ≈ ${divisorLiters.toStringAsFixed(2)}L');
      } else {
        divisorLiters = minimumTankSizeL;
      }

      // Base capacity from divisor
      double maxFish = tankVolume / divisorLiters;
      print('  → Base calculation: ${tankVolume.toStringAsFixed(1)}L / ${divisorLiters.toStringAsFixed(2)}L = ${maxFish.toStringAsFixed(2)} fish');
      
      // Apply bioload factor using species-specific calculation
      if (bioload != 1.0) {
        final originalMaxFish = maxFish;
        // Use bioload directly for more accurate biological calculation
        // Baseline bioload = 1.0 represents "average" fish waste production
        final bioloadMultiplier = bioload / 1.0; // Use 1.0 as baseline
        maxFish = maxFish / bioloadMultiplier;

        print('  → Bioload adjustment (${bioload}x): ${originalMaxFish.toStringAsFixed(2)} / ${bioloadMultiplier.toStringAsFixed(2)} = ${maxFish.toStringAsFixed(2)} fish');
        print('  → Species bioload: ${bioload}x (baseline = 1.0x average fish)');
      } else {
        print('  → Bioload: 1.0x (average waste production)');
      }
      
      // Calculate three stocking levels
      int conservative = 1, typical = 1, theoreticalMax = 1;
      
      if (isSchoolingFish) {
        // Schooling fish: allow partial schools with warnings
        if (maxFish >= 5.0) {
          print('  → Schooling fish: Tank can support proper school (${maxFish.toStringAsFixed(2)} capacity)');
          
          // Conservative: strict bioload, minimum school
          conservative = 6; // Minimum school size
          
          // Typical: standard calculation with 20% bonus
          typical = (maxFish * 1.2).floor();
          if (typical < 6) typical = 6;
          
          // Theoretical max: aggressive stocking with strong filtration
          theoreticalMax = (maxFish * 1.5).floor();
          if (theoreticalMax < 6) theoreticalMax = 6;
          
          print('  → Schooling levels: Conservative=$conservative, Typical=$typical, Max=$theoreticalMax');
        } else if (maxFish >= 1.0) {
          // Allow partial school or juvenile stocking with warnings
          print('  → Schooling fish: Partial school/juvenile stocking (${maxFish.toStringAsFixed(2)} capacity)');
          conservative = maxFish.floor().clamp(1, 20);
          typical = maxFish.round().clamp(1, 20);
          theoreticalMax = maxFish.ceil().clamp(1, 20);
          print('  → ⚠️ WARNING: Below ideal school size (6+), fish may experience stress');
        } else {
          // Tank too small even for juveniles
          print('  → Schooling fish: Tank too small even for juveniles (${maxFish.toStringAsFixed(2)} capacity)');
          return {'conservative': 0, 'typical': 0, 'theoretical_max': 0, 'warning': 'insufficient_space'};
        }
      } else if (isCommunityFish) {
        // Community fish: different rounding strategies
        print('  → Community fish: Calculating stocking levels for ${maxFish.toStringAsFixed(2)} capacity');
        
        // Conservative: floor (adult-safe, accounting for full growth)
        conservative = maxFish.floor();
        if (conservative < 1) conservative = 1;
        
        // Typical: round (hobbyist standard)
        typical = maxFish.round();
        if (typical < 1) typical = 1;
        
        // Theoretical max: ceiling + 20% with strong filtration
        theoreticalMax = (maxFish * 1.2).ceil();
        if (theoreticalMax < 1) theoreticalMax = 1;
        
        print('  → Community levels: Conservative=$conservative, Typical=$typical, Max=$theoreticalMax');
      }
      
      // Ensure maximum of 20 for practical stocking
      conservative = conservative.clamp(1, 20);
      typical = typical.clamp(1, 20);
      theoreticalMax = theoreticalMax.clamp(1, 20);
      
      // Track if stocking is below ideal for warnings
      String? stockingWarning;
      
      // Check for suboptimal stocking levels
      if (isSolitaryFish) {
        // Solitary species → min = 1
        conservative = conservative.clamp(1, 20);
        typical = typical.clamp(1, 20);
        theoreticalMax = theoreticalMax.clamp(1, 20);
        print('  → Solitary species: Enforced min=1 for all levels');
      } else if (isCommunityFish) {
        // Community/Sociable species → min = 2
        if (conservative < 2 || typical < 2 || theoreticalMax < 2) {
          stockingWarning = 'Community fish prefer groups of 2 or more for social interaction';
        }
        conservative = conservative.clamp(2, 20);
        typical = typical.clamp(2, 20);
        theoreticalMax = theoreticalMax.clamp(2, 20);
        print('  → Community species: Enforced min=2 for all levels');
      } else if (isSchoolingFish) {
        // Shoaling species → warn if below 6, but allow partial schools
        if (theoreticalMax < 6) {
          stockingWarning = 'Schooling fish require groups of 6+ for natural behavior. Current capacity allows partial school or juveniles only - consider upgrading tank size';
          print('  → ⚠️ Partial school warning: Below ideal size of 6 fish');
        } else {
          // Enforce minimum of 6 for proper schools
          conservative = conservative.clamp(6, 20);
          typical = typical.clamp(6, 20);
          theoreticalMax = theoreticalMax.clamp(6, 20);
          print('  → Shoaling species: Enforced min=6 for all levels');
        }
      }
      
      return {
        'conservative': conservative,
        'typical': typical,
        'theoretical_max': theoreticalMax,
        if (stockingWarning != null) 'stocking_warning': stockingWarning,
      };
    } else if (maxSizeCm > 0) {
      // Fallback to size-based calculation
      final volumePerFish = _calculateVolumeFromSize(maxSizeCm);
      print('  → Size-based calculation: Volume per fish = ${volumePerFish.toStringAsFixed(1)}L');
      
      double calculatedQty = tankVolume / volumePerFish;
      print('  → Base: ${tankVolume.toStringAsFixed(1)}L / ${volumePerFish.toStringAsFixed(1)}L = ${calculatedQty.toStringAsFixed(2)} fish');
      
      // Apply bioload factor using species-specific calculation
      if (bioload != 1.0) {
        final originalQty = calculatedQty;
        // Use bioload directly for more accurate biological calculation
        final bioloadMultiplier = bioload / 1.0; // Use 1.0 as baseline
        calculatedQty = calculatedQty / bioloadMultiplier;

        print('  → Bioload adjustment (${bioload}x): ${originalQty.toStringAsFixed(2)} / ${bioloadMultiplier.toStringAsFixed(2)} = ${calculatedQty.toStringAsFixed(2)} fish');
        print('  → Species bioload: ${bioload}x (baseline = 1.0x average fish)');
      } else {
        print('  → Bioload: 1.0x (average waste production)');
      }
      
      // Calculate three stocking levels
      int conservative = 1, typical = 1, theoreticalMax = 1;
      
      if (isSchoolingFish) {
        if (calculatedQty >= 5.0) {
          print('  → Schooling fish: Tank can support proper school (${calculatedQty.toStringAsFixed(2)} capacity)');
          conservative = 6;
          typical = (calculatedQty * 1.2).floor();
          if (typical < 6) typical = 6;
          theoreticalMax = (calculatedQty * 1.5).floor();
          if (theoreticalMax < 6) theoreticalMax = 6;
          print('  → Schooling levels: Conservative=$conservative, Typical=$typical, Max=$theoreticalMax');
        } else if (calculatedQty >= 1.0) {
          // Allow partial school or juvenile stocking with warnings
          print('  → Schooling fish: Partial school/juvenile stocking (${calculatedQty.toStringAsFixed(2)} capacity)');
          conservative = calculatedQty.floor().clamp(1, 20);
          typical = calculatedQty.round().clamp(1, 20);
          theoreticalMax = calculatedQty.ceil().clamp(1, 20);
          print('  → ⚠️ WARNING: Below ideal school size (6+), fish may experience stress');
        } else {
          print('  → Tank too small for schooling species (${calculatedQty.toStringAsFixed(2)} capacity)');
          return {'conservative': 0, 'typical': 0, 'theoretical_max': 0, 'warning': 'insufficient_space'};
        }
      } else if (isCommunityFish) {
        print('  → Community fish: Calculating stocking levels for ${calculatedQty.toStringAsFixed(2)} capacity');
        conservative = calculatedQty.floor();
        if (conservative < 1) conservative = 1;
        typical = calculatedQty.round();
        if (typical < 1) typical = 1;
        theoreticalMax = (calculatedQty * 1.2).ceil();
        if (theoreticalMax < 1) theoreticalMax = 1;
        print('  → Community levels: Conservative=$conservative, Typical=$typical, Max=$theoreticalMax');
      }
      
      conservative = conservative.clamp(1, 20);
      typical = typical.clamp(1, 20);
      theoreticalMax = theoreticalMax.clamp(1, 20);
      
      // Track if stocking is below ideal for warnings
      String? stockingWarning;
      
      // Enforce social behavior minimums for fallback calculation
      if (isSolitaryFish) {
        // Solitary species → min = 1
        conservative = conservative.clamp(1, 20);
        typical = typical.clamp(1, 20);
        theoreticalMax = theoreticalMax.clamp(1, 20);
        print('  → Solitary species: Enforced min=1 for all levels');
      } else if (isCommunityFish) {
        // Community/Sociable species → min = 2
        if (conservative < 2 || typical < 2 || theoreticalMax < 2) {
          stockingWarning = 'Community fish prefer groups of 2 or more for social interaction';
        }
        conservative = conservative.clamp(2, 20);
        typical = typical.clamp(2, 20);
        theoreticalMax = theoreticalMax.clamp(2, 20);
        print('  → Community species: Enforced min=2 for all levels');
      } else if (isSchoolingFish) {
        // Shoaling species → warn if below 6, but allow partial schools
        if (theoreticalMax < 6) {
          stockingWarning = 'Schooling fish require groups of 6+ for natural behavior. Current capacity allows partial school or juveniles only - consider upgrading tank size';
          print('  → ⚠️ Partial school warning: Below ideal size of 6 fish');
        } else {
          // Enforce minimum of 6 for proper schools
          conservative = conservative.clamp(6, 20);
          typical = typical.clamp(6, 20);
          theoreticalMax = theoreticalMax.clamp(6, 20);
          print('  → Shoaling species: Enforced min=6 for all levels');
        }
      }
      
      return {
        'conservative': conservative,
        'typical': typical,
        'theoretical_max': theoreticalMax,
        if (stockingWarning != null) 'stocking_warning': stockingWarning,
      };
    }
    
    // Default fallback
    print('  → Default fallback: 1 fish');
    return {'conservative': 1, 'typical': 1, 'theoretical_max': 1};
  }


  Widget _buildFishInput() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
          // Header
                  Row(
                    children: [
                      const Icon(
                        FontAwesomeIcons.fish,
                color: Color(0xFF00BCD4),
                size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                'Fish Species',
                        style: TextStyle(
                          fontSize: 16,
                  fontWeight: FontWeight.w600,
                          color: Color(0xFF006064),
                        ),
                      ),
                    ],
                  ),
          const SizedBox(height: 12),
          // Display selected fish
          if (_fishSelections.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  for (var entry in _fishSelections.entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          // Quantity display
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00BCD4).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFF00BCD4).withOpacity(0.3)),
                            ),
                            child: Text(
                              '${entry.value}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF00BCD4),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              entry.key,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF006064),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          // Eye icon for fish info
                          GestureDetector(
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => FishInfoDialog(fishName: entry.key),
                                );
                              },
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00BCD4).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(
                                Icons.remove_red_eye,
                                color: Color(0xFF00BCD4),
                                size: 16,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Color(0xFF006064)),
                            onPressed: () {
                              setState(() {
                                _fishSelections.remove(entry.key);
                                _fishTankShapeWarnings.remove(entry.key);
                              });
                              // Check remaining fish for real-time updates
                              _checkAllFishTankShapeCompatibility();
                              // Update group compatibility preview (re-enable Calculate when <2 fish)
                              _updateGroupCompatibilityPreview();
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            iconSize: 20,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          // Fish input field
          GestureDetector(
            onTap: () {
              // Close dropdown when tapping outside
              setState(() {
                _showDropdown['fish'] = false;
              });
            },
            child: Row(
              children: [
              // Fish name input field with autocomplete
              Expanded(
                flex: 3,
                child: Autocomplete<String>(
                  key: ValueKey(_autocompleteKey),
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    // Only show suggestions when user has typed something
                    if (textEditingValue.text.isEmpty) {
                      return const Iterable<String>.empty();
                    }
                    return _fishSpecies.where((String fish) =>
                        fish.toLowerCase().contains(textEditingValue.text.toLowerCase())).take(10);
                  },
                      onSelected: (String selection) {
                        setState(() {
                          _addFishByName(selection);
                          _showDropdown['fish'] = false; // Close dropdown
                        });
                      },
                  fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                    return TextFormField(
                        controller: textEditingController,
                        focusNode: focusNode,
                        onTap: () {
                          // Don't close dropdown when user taps input field - let them type
                          // Only close if they're not trying to open the dropdown
                        },
                        onChanged: (value) {
                          setState(() {
                            _searchQueries['fish'] = value;
                            _showDropdown['fish'] = value.isNotEmpty;
                          });
                        },
                      decoration: InputDecoration(
                        hintText: 'Search or type fish name...',
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(8),
                            bottomLeft: Radius.circular(8),
                            topRight: Radius.zero,
                            bottomRight: Radius.zero,
                          ),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(8),
                            bottomLeft: Radius.circular(8),
                            topRight: Radius.zero,
                            bottomRight: Radius.zero,
                          ),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(8),
                            bottomLeft: Radius.circular(8),
                            topRight: Radius.zero,
                            bottomRight: Radius.zero,
                          ),
                          borderSide: const BorderSide(color: Color(0xFF00BCD4)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    );
                  },
                ),
              ),
              // Separate dropdown button
              Container(
                height: 48,
                width: 50,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _showDropdown['fish'] = !(_showDropdown['fish'] ?? false);
                    });
                  },
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _showDropdown['fish'] = !(_showDropdown['fish'] ?? false);
                      });
                    },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.zero,
                        bottomLeft: Radius.zero,
                        topRight: Radius.circular(8),
                        bottomRight: Radius.circular(8),
                      ),
                      side: BorderSide(
                        color: Colors.grey.shade300,
                        width: 1,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: AnimatedRotation(
                    turns: (_showDropdown['fish'] ?? false) ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.arrow_drop_down,
                      color: Color(0xFF00BCD4),
                      size: 36,
                    ),
                  ),
                ),
                  ),
                ),
              ],
            ),
          ),
          // Dropdown list
          if (_showDropdown['fish'] == true) ...[
            const SizedBox(height: 8),
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: ListView.builder(
                itemCount: _getFilteredFish('fish').length,
                itemBuilder: (context, index) {
                  final fish = _getFilteredFish('fish')[index];
                  return ListTile(
                    title: Text(fish),
                    onTap: () {
                      setState(() {
                        _addFishByName(fish);
                        _showDropdown['fish'] = false;
                      });
                    },
                  );
                },
              ),
            ),
          ],
          // Show common tankmate recommendation for all selected fish
          if (_fishSelections.isNotEmpty)
            FishCardTankmates(
              selectedFishNames: _fishSelections.keys.toList(),
              fishQuantities: _fishSelections,
              onFishSelected: (selectedFish) {
                _addFishByName(selectedFish);
              },
            ),
        ],
      ),
    );
  }

  // Build tank shape warnings widget
  Widget _buildTankShapeWarningsWidget() {
    if (_fishTankShapeWarnings.isEmpty) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          collapsedIconColor: const Color(0xFF00BCD4),
          iconColor: const Color(0xFF00BCD4),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              Icons.info_outline,
              color: Colors.orange.shade600,
              size: 16,
            ),
          ),
          title: const Text(
            'Tank Size Notice',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF006064),
            ),
          ),
          subtitle: const Text(
            'Some fish may need a bigger tank',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var entry in _fishTankShapeWarnings.entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Icon(
                            FontAwesomeIcons.fish,
                            size: 14,
                            color: Colors.orange.shade600,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${entry.key}: ${entry.value}',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.orange.shade800,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultDisplay() {
    if (_calculationData == null) return const SizedBox.shrink();

    // Check if any fish are unsuitable for the tank volume
    if (_hasUnsuitableFish()) {
      // Show only the unsuitable volume warning
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.all(16),
        child: _buildUnsuitableVolumeWarning(),
      );
    }

    // All fish are suitable, show normal results
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Tank Volume Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF006064),
                  const Color(0xFF00ACC1),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.water_drop,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                      const Text(
                        'Tank Volume',
                        style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                      Text(
                        _calculationData!['tank_details']['volume'],
                        style: const TextStyle(
                    fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Fish Recommendations Card
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0F7FA),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                              FontAwesomeIcons.fish,
                              color: Color(0xFF006064),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Fish Recommendations',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF006064),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Fish Details
                      ..._calculationData!['fish_details'].map((fish) => Card(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE0F7FA),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(
                                  FontAwesomeIcons.fish,
                                  color: Color(0xFF006064),
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          fish['name'],
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        GestureDetector(
                                          onTap: () {
                                            showDialog(
                                              context: context,
                                              builder: (context) => FishInfoDialog(fishName: fish['name']),
                                            );
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFE0F7FA),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Icon(
                                              Icons.remove_red_eye,
                                              size: 14,
                                              color: Color(0xFF006064),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            if (fish['recommended_quantity'] > 0) ...[
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              decoration: BoxDecoration(
                                                gradient: const LinearGradient(
                                                  colors: [Color(0xFF00BCD4), Color(0xFF006064)],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                ),
                                                borderRadius: BorderRadius.circular(6),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black.withOpacity(0.1),
                                                    blurRadius: 4,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(
                                                    Icons.recommend,
                                                    color: Colors.white,
                                                    size: 14,
                                                  ),
                                                  const SizedBox(width: 5),
                                                  Text(
                                                    '${fish['recommended_quantity']}',
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            const Text(
                                              'recommended',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFF006064),
                                                ),
                                              ),
                                            ] else ...[
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: Colors.red.shade100,
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: Colors.red.shade300),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons.warning,
                                                  color: Colors.red,
                                                  size: 14,
                                                ),
                                                const SizedBox(width: 5),
                                                const Text(
                                                  'Not suitable',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.red,
                                          ),
                                        ),
                                      ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const Text(
                                            'tank too small',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.red,
                                            ),
                                          ),
                                        ],
                                          ],
                                        ),
                                        // Stocking warnings are kept for logs/calculation but not shown in UI.
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      )).toList(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Conditional Compatibility Warnings (if any)
          if (_calculationData != null && _calculationData!['conditional_compatibility_warnings'] != null)
            _buildConditionalCompatibilityWarning(),
          const SizedBox(height: 20),
          // Water Requirements Card
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0F7FA),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                              Icons.water_drop,
                              color: Color(0xFF006064),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Water Requirements',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF006064),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildInfoRow(
                        Icons.thermostat,
                        'Temperature Range',
                        _getTemperatureRangeFromFishData(),
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow(
                        Icons.science,
                        'pH Range',
                        _getPhRangeFromFishData(),
                      ),
                    ],
                                    ),
                                  ),
                                ],
            ),
          ),
          const SizedBox(height: 20),
          // Tankmate Recommendations Card (Collapsible)
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
            child: Theme(
              data: Theme.of(context).copyWith(
                dividerColor: Colors.transparent,
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
              ),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                childrenPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                collapsedIconColor: const Color(0xFF00BCD4),
                iconColor: const Color(0xFF00BCD4),
                leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0F7FA),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                              FontAwesomeIcons.users,
                              color: Color(0xFF006064),
                            ),
                          ),
                title: const Text(
                            'Tankmate Recommendations',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF006064),
                            ),
                          ),
                subtitle: FutureBuilder<Map<String, List<String>>>(
                        future: _getGroupedTankmateRecommendations(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Text(
                                  'Finding compatible tankmates...',
                                  style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                                  ),
                            );
                          } else if (snapshot.hasData) {
                            final fullyCompatible = snapshot.data!['fully_compatible'] ?? [];
                            final conditional = snapshot.data!['conditional'] ?? [];
                            final total = fullyCompatible.length + conditional.length;
                            
                            if (total > 0) {
                            return Text(
                                'Tap to view $total recommended tankmates (${fullyCompatible.length} fully compatible, ${conditional.length} conditional)',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                              ),
                            );
                          } else {
                            return const Text(
                                'No tankmate recommendations available',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                              ),
                            );
                          }
                          } else {
                            return const Text(
                        'No tankmate recommendations available',
                            style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                              ),
                            );
                          }
                        },
                ),
              children: [
                      FutureBuilder<Map<String, List<String>>>(
                        future: _getGroupedTankmateRecommendations(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return Row(
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00BCD4)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Finding compatible tankmates...',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF006064),
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            );
                          } else if (snapshot.hasData) {
                            final fullyCompatible = snapshot.data!['fully_compatible'] ?? [];
                            final conditional = snapshot.data!['conditional'] ?? [];
                            
                            if (fullyCompatible.isNotEmpty || conditional.isNotEmpty) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                  // Fully Compatible Section
                                  if (fullyCompatible.isNotEmpty) ...[
                                    _buildTankmateSection(
                                      title: 'Fully Compatible',
                                      tankmates: fullyCompatible,
                                      icon: Icons.check_circle,
                                      color: const Color(0xFF4CAF50),
                                      description: 'These fish are highly compatible with all your selected fish.',
                                    ),
                                    if (conditional.isNotEmpty) const SizedBox(height: 16),
                                  ],
                                  
                                  // Conditional Section
                                  if (conditional.isNotEmpty) ...[
                                    _buildTankmateSection(
                                      title: 'Conditionally Compatible',
                                      tankmates: conditional,
                                      icon: Icons.warning,
                                      color: const Color(0xFFFF9800),
                                      description: 'These fish may work with proper conditions and monitoring.',
                                    ),
                                  ],
                                  
                                  const SizedBox(height: 16),
                                  // Info text
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE0F7FA),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFF00BCD4).withOpacity(0.3)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.info_outline,
                                          color: Color(0xFF00BCD4),
                                          size: 16,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                    child: Text(
                                            'These ${fullyCompatible.length + conditional.length} fish are compatible with all your selected fish.',
                                      style: const TextStyle(
                                        fontSize: 12,
                                              color: Color(0xFF006064),
                                              fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                                    ),
                                  ),
                              ],
                            );
                          } else {
                              return const Text(
                                'No specific tankmate recommendations available.',
                                style: TextStyle(
                                fontSize: 14,
                                  color: Colors.grey,
                                  fontStyle: FontStyle.italic,
                                ),
                              );
                            }
                          } else {
                            return const Text(
                              'No specific tankmate recommendations available.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                                fontStyle: FontStyle.italic,
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
            ),
          ),
          const SizedBox(height: 20),
          // Feeding Information Card (Collapsible)
          if (_fishData != null && _fishSelections.isNotEmpty)
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
              child: Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: Colors.transparent,
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                ),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  childrenPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  collapsedIconColor: const Color(0xFF00BCD4),
                  iconColor: const Color(0xFF00BCD4),
                  leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0F7FA),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                      Icons.restaurant,
                              color: Color(0xFF006064),
                            ),
                          ),
                  title: const Text(
                    'Feeding Information',
                            style: TextStyle(
                      fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF006064),
                            ),
                          ),
                  subtitle: Text(
                    'Tap to view feeding details for ${_getUniqueFishSpecies().length} fish species',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
              children: [
                    // Display feeding info for each unique fish species
                    ..._getUniqueFishSpecies().map((fishName) {
                      final fishData = _fishData?[fishName];
                      if (fishData == null) return const SizedBox.shrink();
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FA),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: const Color(0xFF00BCD4).withOpacity(0.2),
                          ),
                        ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                                  padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                                    color: const Color(0xFF00BCD4).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                                    FontAwesomeIcons.fish,
                                    size: 16,
                                    color: Color(0xFF00BCD4),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  fishName,
                                  style: const TextStyle(
                                    fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF006064),
                            ),
                          ),
                        ],
                      ),
                            const SizedBox(height: 12),
                            // Portion Grams
                            if (fishData['portion_grams'] != null && fishData['portion_grams'].toString().isNotEmpty) ...[
                              Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                  const Icon(
                                    Icons.scale,
                                    size: 16,
                                    color: Color(0xFF4CAF50),
                                ),
                                const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                const Text(
                                          'Portion per Fish:',
                                  style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF4CAF50),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                Text(
                                          _getPortionDisplay(fishName, fishData['portion_grams']),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.black87,
                                            height: 1.4,
                                  ),
                                ),
                              ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                            ],
                            // Preferred Food
                            if (fishData['preferred_food'] != null && fishData['preferred_food'].toString().isNotEmpty) ...[
                              Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                  const Icon(
                                    Icons.restaurant_menu,
                                    size: 16,
                                    color: Color(0xFF9C27B0),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Preferred Food:',
                              style: TextStyle(
                                fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF9C27B0),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                Text(
                                          fishData['preferred_food'].toString(),
                                  style: const TextStyle(
                                            fontSize: 13,
                                    color: Colors.black87,
                                            height: 1.4,
                  ),
                ),
              ],
            ),
                ),
              ],
            ),
                              const SizedBox(height: 12),
                            ],
                            // Feeding Notes
                            if (fishData['feeding_notes'] != null && fishData['feeding_notes'].toString().isNotEmpty) ...[
                              Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                                  const Icon(
                                    Icons.note,
                                    size: 16,
                                    color: Color(0xFF00BCD4),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                          const Text(
                                          'Feeding Notes:',
                              style: TextStyle(
                                fontSize: 14,
                                            fontWeight: FontWeight.w600,
                              color: Color(0xFF006064),
                            ),
                          ),
                                        const SizedBox(height: 4),
                                        Text(
                                          fishData['feeding_notes'].toString(),
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Colors.black87,
                                            height: 1.4,
                  ),
                ),
              ],
            ),
                ),
              ],
            ),
                              const SizedBox(height: 12),
                            ],
                            // Overfeeding Risks
                            if (fishData['overfeeding_risks'] != null && fishData['overfeeding_risks'].toString().isNotEmpty) ...[
                              Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                                  const Icon(
                                    Icons.warning,
                                    size: 16,
                                    color: Colors.orange,
                                ),
                                const SizedBox(width: 8),
                                  Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                          const Text(
                                          'Overfeeding Risks:',
                            style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.orange,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                Text(
                                          fishData['overfeeding_risks'].toString(),
                                  style: const TextStyle(
                                            fontSize: 13,
                                    color: Colors.black87,
                                            height: 1.4,
                            ),
                          ),
                        ],
                      ),
                                  ),
                                ],
                              ),
                            ],
                            // Show message if no feeding info available
                            if ((fishData['portion_grams'] == null || fishData['portion_grams'].toString().isEmpty) &&
                                (fishData['preferred_food'] == null || fishData['preferred_food'].toString().isEmpty) &&
                                (fishData['feeding_notes'] == null || fishData['feeding_notes'].toString().isEmpty) &&
                                (fishData['overfeeding_risks'] == null || fishData['overfeeding_risks'].toString().isEmpty))
                                const Text(
                                'No specific feeding information available for this fish.',
                                  style: TextStyle(
                                    fontSize: 13,
                                  color: Colors.grey,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                  ),
                      );
                    }).toList(),
              ],
                ),
            ),
          ),
        ],
      ),
    );
  }


  Future<Map<String, List<String>>> _getGroupedTankmateRecommendations() async {
    try {
      final fishNames = _fishSelections.keys.toList();
      if (fishNames.isEmpty) return {'fully_compatible': [], 'conditional': []};

      // Get tankmate recommendations from Supabase for each selected fish
      final supabase = Supabase.instance.client;
      Map<String, Set<String>> fishFullyCompatible = {};
      Map<String, Set<String>> fishConditional = {};
      
      for (String fishName in fishNames) {
        try {
          final response = await supabase
              .from('fish_tankmate_recommendations')
              .select('fully_compatible_tankmates, conditional_tankmates')
              .ilike('fish_name', fishName)
              .maybeSingle();
          
          if (response != null) {
            print('🐠 Tankmate data for $fishName: $response');
            print('🐠 fully_compatible_tankmates type: ${response['fully_compatible_tankmates'].runtimeType}');
            print('🐠 conditional_tankmates type: ${response['conditional_tankmates'].runtimeType}');
            // Add fully compatible tankmates
            if (response['fully_compatible_tankmates'] != null) {
              final fullyCompatibleData = response['fully_compatible_tankmates'];
              List<String> fullyCompatible = [];
              
              try {
                if (fullyCompatibleData is List) {
                  fullyCompatible = fullyCompatibleData
                      .where((item) => item is String)
                      .cast<String>()
                      .toList();
                } else if (fullyCompatibleData is String) {
                  // Handle case where it might be a JSON string
                  final parsed = jsonDecode(fullyCompatibleData);
                  if (parsed is List) {
                    fullyCompatible = parsed
                        .where((item) => item is String)
                        .cast<String>()
                        .toList();
                  }
                } else if (fullyCompatibleData is Map) {
                  // Handle case where it might be a map with string keys
                  fullyCompatible = fullyCompatibleData.keys
                      .where((key) => key is String)
                      .cast<String>()
                      .toList();
                }
                
                print('🐠 Parsed fully_compatible_tankmates for $fishName: $fullyCompatible');
                fishFullyCompatible[fishName] = fullyCompatible.toSet();
              } catch (e) {
                print('Error parsing fully_compatible_tankmates for $fishName: $e');
                print('Raw data: $fullyCompatibleData');
              }
            }
            
            // Add conditional tankmates
            if (response['conditional_tankmates'] != null) {
              final conditionalData = response['conditional_tankmates'];
              List<String> conditional = [];
              
              try {
                if (conditionalData is List) {
                  conditional = conditionalData
                      .where((item) => item is String)
                      .cast<String>()
                      .toList();
                } else if (conditionalData is String) {
                  // Handle case where it might be a JSON string
                  final parsed = jsonDecode(conditionalData);
                  if (parsed is List) {
                    conditional = parsed
                        .where((item) => item is String)
                        .cast<String>()
                        .toList();
                  }
                } else if (conditionalData is Map) {
                  // Handle case where it might be a map with string keys
                  conditional = conditionalData.keys
                      .where((key) => key is String)
                      .cast<String>()
                      .toList();
                }
                
                print('🐠 Parsed conditional_tankmates for $fishName: $conditional');
                fishConditional[fishName] = conditional.toSet();
              } catch (e) {
                print('Error parsing conditional_tankmates for $fishName: $e');
                print('Raw data: $conditionalData');
              }
            }
          }
        } catch (e) {
          print('Error loading tankmate recommendations for $fishName: $e');
        }
      }
      
      // Find common tankmates across all selected fish
      Set<String> commonFullyCompatible = {};
      Set<String> commonConditional = {};
      
      if (fishFullyCompatible.isNotEmpty) {
        commonFullyCompatible = fishFullyCompatible.values.reduce((a, b) => a.intersection(b));
      }
      
      if (fishConditional.isNotEmpty) {
        commonConditional = fishConditional.values.reduce((a, b) => a.intersection(b));
      }
      
      // Convert to lists and sort
      final fullyCompatible = commonFullyCompatible.toList()..sort();
      final conditional = commonConditional.toList()..sort();
      
      print('🐠 Found ${fullyCompatible.length} fully compatible and ${conditional.length} conditional tankmates from Supabase');
      
      return {
        'fully_compatible': fullyCompatible,
        'conditional': conditional,
      };
    } catch (e) {
      print('🐠 Tankmate recommendations failed: $e');
      return {'fully_compatible': [], 'conditional': []};
    }
  }

  Future<List<String>> _getTankmateRecommendations() async {
    final grouped = await _getGroupedTankmateRecommendations();
    return [...grouped['fully_compatible']!, ...grouped['conditional']!];
  }

  Widget _buildTankmateSection({
    required String title,
    required List<String> tankmates,
    required IconData icon,
    required Color color,
    required String description,
  }) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
        // Section Header
        Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 8),
                                Text(
              title,
              style: TextStyle(
                                    fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
                                    child: Text(
                '${tankmates.length}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: color,
                                      ),
                                    ),
                                  ),
                                ],
        ),
        const SizedBox(height: 8),
        // Tankmate Chips
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: tankmates.map((tankmate) => _buildTankmateChip(tankmate, color: color)).toList(),
        ),
        const SizedBox(height: 8),
        // Description
        Text(
          description,
                              style: TextStyle(
            fontSize: 11,
            color: color.withOpacity(0.8),
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildTankmateChip(String tankmate, {Color? color}) {
    final chipColor = color ?? const Color(0xFF00BCD4);
    
    return InkWell(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => FishInfoDialog(fishName: tankmate),
        );
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: chipColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: chipColor.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              FontAwesomeIcons.fish,
              size: 12,
              color: chipColor,
            ),
            const SizedBox(width: 6),
            Text(
              tankmate,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: chipColor,
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => FishInfoDialog(fishName: tankmate),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: chipColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.remove_red_eye,
                  size: 10,
                  color: chipColor,
                ),
            ),
          ),
        ],
        ),
      ),
    );
  }

  String _getPhRangeFromFishData() {
    if (_fishData == null || _fishSelections.isEmpty) {
      print('DEBUG: No fish data or selections available for pH range');
      return 'Unknown';
    }
    
    List<String> phRanges = [];
    
    for (String fishName in _fishSelections.keys) {
      final fishData = _fishData![fishName];
      if (fishData == null) {
        print('DEBUG: No fish data for $fishName');
        continue;
      }
      
      // Try different possible field names for pH range
      String? phRange = fishData['ph_range']?.toString() ?? 
                       fishData['pH_range']?.toString() ?? 
                       fishData['pH']?.toString();
      
      print('DEBUG: pH range for $fishName: $phRange');
      
      if (phRange != null && phRange.isNotEmpty && phRange != 'null') {
        phRanges.add(phRange);
      }
    }
    
    print('DEBUG: All pH ranges found: $phRanges');
    
    if (phRanges.isEmpty) return 'Unknown';
    
    // If all fish have the same pH range, return it
    if (phRanges.toSet().length == 1) {
      return phRanges.first;
    }
    
    // If different pH ranges, calculate a combined range
    return _calculateCombinedPhRange(phRanges);
  }

  String _calculateCombinedPhRange(List<String> phRanges) {
    List<double> allPhValues = [];
    
    for (String phRange in phRanges) {
      // Parse different pH range formats like "6.5-7.5", "6.5 to 7.5", "6.5-7.5 pH", etc.
      final cleanRange = phRange.replaceAll(RegExp(r'[^\d.-]'), ' ').trim();
      final parts = cleanRange.split(RegExp(r'\s+'));
      
      for (String part in parts) {
        if (part.contains('-')) {
          // Handle range like "6.5-7.5"
          final rangeParts = part.split('-');
          if (rangeParts.length == 2) {
            final min = double.tryParse(rangeParts[0]);
            final max = double.tryParse(rangeParts[1]);
            if (min != null && max != null) {
              allPhValues.addAll([min, max]);
            }
          }
        } else {
          // Handle single value
          final value = double.tryParse(part);
          if (value != null) {
            allPhValues.add(value);
          }
        }
      }
    }
    
    if (allPhValues.isEmpty) {
      return phRanges.join(', ');
    }
    
    // Find the overall min and max pH values
    final minPh = allPhValues.reduce((a, b) => a < b ? a : b);
    final maxPh = allPhValues.reduce((a, b) => a > b ? a : b);
    
    // Round to 1 decimal place
    final minRounded = (minPh * 10).round() / 10;
    final maxRounded = (maxPh * 10).round() / 10;
    
    return '${minRounded.toStringAsFixed(1)}-${maxRounded.toStringAsFixed(1)}';
  }

  String _getTemperatureRangeFromFishData() {
    if (_fishData == null || _fishSelections.isEmpty) {
      print('DEBUG: No fish data or selections available for temperature range');
      return 'Unknown';
    }
    
    List<String> tempRanges = [];
    
    for (String fishName in _fishSelections.keys) {
      final fishData = _fishData![fishName];
      if (fishData == null) continue;
      
      String? tempRange = fishData['temperature_range']?.toString() ?? 
                         fishData['temp_range']?.toString();
      
      print('DEBUG: Temperature range for $fishName: $tempRange');
      
      if (tempRange != null && tempRange.isNotEmpty && tempRange != 'null') {
        tempRanges.add(tempRange);
      }
    }
    
    print('DEBUG: All temperature ranges found: $tempRanges');
    
    if (tempRanges.isEmpty) return 'Unknown';
    
    // If all fish have the same temperature range, return it
    if (tempRanges.toSet().length == 1) {
      return tempRanges.first;
    }
    
    // If different temperature ranges, calculate a combined range
    return _calculateCombinedTemperatureRange(tempRanges);
  }

  String _calculateCombinedTemperatureRange(List<String> tempRanges) {
    List<double> allTempValues = [];
    
    for (String tempRange in tempRanges) {
      // Parse different temperature range formats like "22-26°C", "22 to 26", "22-26°F", etc.
      final cleanRange = tempRange.replaceAll(RegExp(r'[^\d.-]'), ' ').trim();
      final parts = cleanRange.split(RegExp(r'\s+'));
      
      for (String part in parts) {
        if (part.contains('-')) {
          // Handle range like "22-26"
          final rangeParts = part.split('-');
          if (rangeParts.length == 2) {
            final min = double.tryParse(rangeParts[0]);
            final max = double.tryParse(rangeParts[1]);
            if (min != null && max != null) {
              allTempValues.addAll([min, max]);
            }
          }
        } else {
          // Handle single value
          final value = double.tryParse(part);
          if (value != null) {
            allTempValues.add(value);
          }
        }
      }
    }
    
    if (allTempValues.isEmpty) {
      return tempRanges.join(', ');
    }
    
    // Find the overall min and max temperature values
    final minTemp = allTempValues.reduce((a, b) => a < b ? a : b);
    final maxTemp = allTempValues.reduce((a, b) => a > b ? a : b);
    
    // Round to 1 decimal place
    final minRounded = (minTemp * 10).round() / 10;
    final maxRounded = (maxTemp * 10).round() / 10;
    
    return '${minRounded.toStringAsFixed(1)}-${maxRounded.toStringAsFixed(1)}°C';
  }

  List<String> _getUniqueFishSpecies() {
    return _fishSelections.keys.toSet().toList();
  }

  List<String> _getFilteredFish(String cardId) {
    final query = _searchQueries[cardId] ?? '';
    if (query.isEmpty) {
      return _fishSpecies;
    }
    return _fishSpecies.where((fish) =>
        fish.toLowerCase().contains(query.toLowerCase())).toList();
  }



  String _getPortionDisplay(String fishName, dynamic portionGrams) {
    try {
      final portionPerFish = double.parse(portionGrams.toString());
      final quantity = _fishSelections[fishName] ?? 1;
      
      // Convert to mg if portion is less than 0.1g for better readability
      if (portionPerFish < 0.1) {
        final portionMg = portionPerFish * 1000; // Convert g to mg
        if (quantity == 1) {
          return '${portionMg.toStringAsFixed(portionMg % 1 == 0 ? 0 : 1)} mg each';
        } else {
          final totalMg = portionMg * quantity;
          return '${portionMg.toStringAsFixed(portionMg % 1 == 0 ? 0 : 1)} mg each (${totalMg.toStringAsFixed(totalMg % 1 == 0 ? 0 : 1)} mg total)';
        }
      } else {
        // Use grams for larger portions
        if (quantity == 1) {
          return '${portionPerFish.toStringAsFixed(portionPerFish % 1 == 0 ? 0 : 1)} grams each';
        } else {
          final totalGrams = portionPerFish * quantity;
          return '${portionPerFish.toStringAsFixed(portionPerFish % 1 == 0 ? 0 : 1)} grams each (${totalGrams.toStringAsFixed(totalGrams % 1 == 0 ? 0 : 1)} grams total)';
        }
      }
    } catch (e) {
      return '${portionGrams.toString()} grams each';
    }
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF00BCD4), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF00BCD4),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  TextSpan(
                    text: value,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTankShapeIncompatibilityResults(Map<String, dynamic> results) {
    final incompatibleFish = results['tank_shape_issues'] as List<Map<String, dynamic>>? ?? [];
    final selectedShape = results['selected_tank_shape'] as String? ?? 'Unknown';
    
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Warning Card
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFF6B6B), Color(0xFFFF8585)],
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
                    child: Icon(
                      _getShapeIcon(selectedShape),
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tank Shape Incompatibility',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Selected fish are too large for ${_getShapeLabel(selectedShape)}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Incompatible Fish List
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
              children: incompatibleFish.map((fish) => Container(
                decoration: BoxDecoration(
                  border: Border(
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
                          const Icon(
                            FontAwesomeIcons.fish,
                            color: Color(0xFFFF6B6B),
                            size: 18,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              fish['fish_name'],
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFFF6B6B),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF6B6B).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFFF6B6B).withOpacity(0.3)),
                            ),
                            child: Text(
                              '${fish['max_size']}cm',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFFFF6B6B),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.only(left: 30),
                        child: Text(
                          fish['reason'],
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )).toList(),
            ),
          ),
          const SizedBox(height: 20),
          // Suggestion Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFE0F7FA),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF00BCD4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.lightbulb_outline, color: Color(0xFF006064), size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Recommendation',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF006064),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Consider switching to a Rectangle tank for the best compatibility with large fish, or choose smaller fish species that are suitable for ${_getShapeLabel(selectedShape).toLowerCase()}.',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF006064),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Try Again Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _clearFishInputs,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00BCD4),
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: const Text(
                'Choose Different Tank Shape or Fish',
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

  IconData _getShapeIcon(String shape) {
    switch (shape) {
      case 'rectangle':
        return Icons.crop_landscape;
      case 'bowl':
        return Icons.circle;
      case 'cylinder':
        return Icons.circle_outlined;
      default:
        return Icons.crop_landscape;
    }
  }

  String _getShapeLabel(String shape) {
    switch (shape) {
      case 'rectangle':
        return 'Rectangle/Square Tank';
      case 'bowl':
        return 'Bowl Tank';
      case 'cylinder':
        return 'Cylinder Tank';
      default:
        return 'Rectangle/Square Tank';
    }
  }

  // Check if any fish are unsuitable for the current tank volume
  bool _hasUnsuitableFish() {
    if (_calculationData == null || _calculationData!['fish_details'] == null) return false;
    
    for (var fish in _calculationData!['fish_details']) {
      if (fish['recommended_quantity'] == 0) {
        return true;
      }
    }
    return false;
  }

  // Get unsuitable fish with their requirements
  Future<List<Map<String, dynamic>>> _getUnsuitableFishDetails() async {
    if (_calculationData == null || _calculationData!['fish_details'] == null) return [];
    
    List<Map<String, dynamic>> unsuitableFish = [];
    
    // Get current tank volume
    final volumeStr = _calculationData!['tank_details']['volume'] as String;
    final currentVolume = double.parse(volumeStr.replaceAll(' L', ''));
    
    // Get unsuitable fish names
    List<String> unsuitableFishNames = [];
    for (var fish in _calculationData!['fish_details']) {
      if (fish['recommended_quantity'] == 0) {
        unsuitableFishNames.add(fish['name'] as String);
      }
    }
    
    if (unsuitableFishNames.isEmpty) return [];
    
    // Fetch fresh data from database using the same method as calculation
    print('🔍 Fetching unsuitable fish data from database for: ${unsuitableFishNames.join(", ")}');
    final fishDataFromDb = await _getFishDataFromDatabase(unsuitableFishNames);
    
    for (String fishName in unsuitableFishNames) {
      final fishInfo = fishDataFromDb[fishName];
      
      if (fishInfo != null) {
        final minimumTankSizeL = fishInfo['minimum_tank_size_l'] ?? 0.0;
        final maxSizeCm = fishInfo['max_size_cm'] ?? 0.0;
        
        print('📊 $fishName - min_tank: ${minimumTankSizeL}L, max_size: ${maxSizeCm}cm, current_tank: ${currentVolume}L');
        
        // Calculate volume needed for at least 1 fish
        final volumeNeededForOne = minimumTankSizeL > 0 ? minimumTankSizeL : _calculateVolumeFromSize(maxSizeCm);
        
        // Get temperament from _fishData (API) since it's not in the database query
        final temperament = _fishData?[fishName]?['temperament'] ?? 'peaceful';
        
        unsuitableFish.add({
          'name': fishName,
          'current_volume': currentVolume,
          'minimum_required': volumeNeededForOne,
          'max_size_cm': maxSizeCm,
          'temperament': temperament,
          'volume_deficit': volumeNeededForOne - currentVolume,
        });
        
        print('✅ Added unsuitable fish: $fishName (needs ${volumeNeededForOne}L, has ${currentVolume}L)');
      }
    }
    
    return unsuitableFish;
  }

  // Get smart recommendations based on unsuitable fish data
  Future<List<String>> _getSmartRecommendations() async {
    final unsuitableFish = await _getUnsuitableFishDetails();
    if (unsuitableFish.isEmpty) return [];
    
    List<String> recommendations = [];
    // Include global warning headline if present
    final globalWarning = _calculationData?['global_warning']?.toString();
    if (globalWarning != null && globalWarning.isNotEmpty) {
      recommendations.add(globalWarning);
    }
    
    // Get the actual user input volume instead of from calculation data
    final userInputVolume = double.tryParse(_volumeController.text) ?? 0.0;
    final currentVolume = userInputVolume > 0 ? userInputVolume : unsuitableFish[0]['current_volume'];
    
    print('🔍 Recommendation Debug:');
    print('  User input volume: $userInputVolume');
    print('  Using volume for recommendations: $currentVolume');
    
    
    // Shared-capacity analysis: for multi-species show math/option; for single-species show direct requirement
    try {
      final analysis = await _analyzeCombinationCapacity(currentVolume, _fishSelections.keys.toList());
      final sumMin = (analysis['sum_min_one_each'] as double?) ?? 0.0;
      final fullTankSpecies = analysis['full_tank_species'] as String?;
      final speciesCount = _fishSelections.length;
      if (speciesCount >= 2) {
        if (fullTankSpecies != null) {
          recommendations.add('Single-species option: Keep only $fullTankSpecies and remove other species.');
        } else if (sumMin > 0) {
          recommendations.add('Combination math: One-each requires ~${sumMin.toStringAsFixed(1)}L; tank is ${currentVolume.toStringAsFixed(1)}L.');
        }
      } else if (speciesCount == 1) {
        // Single-species: show direct requirement vs tank
        final f = unsuitableFish.first;
        final need = (f['minimum_required'] as num?)?.toDouble() ?? 0.0;
        final name = f['name']?.toString() ?? 'Selected fish';
        if (need > 0) {
          recommendations.add('$name requires at least ${need.toStringAsFixed(1)}L; tank is ${currentVolume.toStringAsFixed(1)}L.');
        }
      }
    } catch (e) {
      // ignore
    }
    
    return recommendations;
  }

  // Analyze combination capacity: returns sum of one-each minimum liters and any species that alone consumes the whole tank
  Future<Map<String, dynamic>> _analyzeCombinationCapacity(double tankVolume, List<String> fishNames) async {
    final data = await _getFishDataFromDatabase(fishNames);
    double totalMinForOneEach = 0.0;
    String? fullTankSpecies;
    for (final name in fishNames) {
      final info = data[name];
      if (info == null) continue;
      final minTankL = (info['minimum_tank_size_l'] ?? 0.0) as double;
      final behavior = (info['social_behavior'] ?? 'solitary').toString().toLowerCase();
      final isSchooling = behavior.contains('school') || behavior.contains('shoal') || behavior.contains('colonial');
      final perUnit = isSchooling && minTankL > 0 ? (minTankL / 6.0) : minTankL;
      final perUnitClamped = perUnit > 0 ? perUnit : 0.0;
      totalMinForOneEach += perUnitClamped;
      if (minTankL > 0 && minTankL >= tankVolume - 1e-6) {
        fullTankSpecies = name;
      }
    }
    return {
      'sum_min_one_each': totalMinForOneEach,
      'full_tank_species': fullTankSpecies,
    };
  }

  // Build unsuitable volume warning widget
  Widget _buildUnsuitableVolumeWarning() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getUnsuitableFishDetails(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }
        
        final unsuitableFish = snapshot.data!;
        
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFFECDD6), width: 2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF04438).withOpacity(0.08),
                spreadRadius: 2,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3F4),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE4E8),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.warning_rounded,
                        color: Color(0xFFD92D20),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Tank Volume Not Suitable',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF912018),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${unsuitableFish.length} fish species cannot be kept in this tank',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFFB42318),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Issue explanation
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFAEB),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFFEDF89)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: Color(0xFFDC6803),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _calculationData?['global_warning']?.toString() ?? 'The selected fish require more space than your current tank provides. Keeping them in insufficient space can lead to stress, stunted growth, and health issues.',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF93370D),
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                if (_calculationData != null && _calculationData!['tank_details'] != null)
                                  Builder(
                                    builder: (context) {
                                      try {
                                        final tankVolStr = _calculationData!['tank_details']['volume'] as String?;
                                        final tankVol = tankVolStr != null ? double.parse(tankVolStr.replaceAll(' L', '')) : null;
                                        // When available, show quick math summary using current selections
                                        if (tankVol != null && _fishSelections.isNotEmpty) {
                                          return FutureBuilder<Map<String, dynamic>>(
                                            future: _analyzeCombinationCapacity(tankVol, _fishSelections.keys.toList()),
                                            builder: (context, snap) {
                                              if (snap.hasData) {
                                                final d = snap.data!;
                                                final sumMin = (d['sum_min_one_each'] as double?) ?? 0.0;
                                                final fullTankSpecies = d['full_tank_species'] as String?;
                                                String line;
                                                if (fullTankSpecies != null) {
                                                  line = 'Reason: $fullTankSpecies requires ≥ ${tankVol.toStringAsFixed(1)}L by itself.';
                                                } else {
                                                  line = 'Math: One-each minimum = ${sumMin.toStringAsFixed(1)}L > Tank = ${tankVol.toStringAsFixed(1)}L';
                                                }
                                                return Text(
                                                  line,
                                                  style: const TextStyle(fontSize: 12, color: Color(0xFFB54708)),
                                                );
                                              }
                                              return const SizedBox.shrink();
                                            },
                                          );
                                        }
                                      } catch (_) {}
                                      return const SizedBox.shrink();
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Unsuitable fish details
                    Text(
                      'Unsuitable Fish:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...unsuitableFish.map((fish) => Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                FontAwesomeIcons.fish,
                                size: 14,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  fish['name'],
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => FishInfoDialog(fishName: fish['name']),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE0F2F1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Icon(
                                    Icons.remove_red_eye,
                                    size: 14,
                                    color: Color(0xFF00796B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _buildFishDetailRow(
                            'Current Tank:',
                            '${fish['current_volume'].toStringAsFixed(1)} L',
                            const Color(0xFFD92D20),
                          ),
                          _buildFishDetailRow(
                            'Minimum Required:',
                            '${fish['minimum_required'].toStringAsFixed(1)} L',
                            const Color(0xFFDC6803),
                          ),
                          _buildFishDetailRow(
                            'Max Size:',
                            '${fish['max_size_cm'].toStringAsFixed(1)} cm',
                            Colors.grey.shade700,
                          ),
                          _buildFishDetailRow(
                            'Temperament:',
                            fish['temperament'],
                            Colors.grey.shade700,
                          ),
                        ],
                      ),
                    )).toList(),
                    const SizedBox(height: 16),
                    // Recommendations
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF8FF),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFB2DDFF)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.lightbulb_outline,
                                color: Color(0xFF0086C9),
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Recommendations:',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF026AA2),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          FutureBuilder<List<String>>(
                            future: _getSmartRecommendations(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return const SizedBox.shrink();
                              }
                              
                              return Column(
                                children: snapshot.data!.map((rec) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(top: 6),
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF0086C9),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    rec,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF026AA2),
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )).toList(),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Try Again Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _clearFishInputs();
                            _volumeController.clear();
                            _calculationData = null;
                          });
                        },
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Try Again with Different Fish'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD92D20),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Helper widget for fish detail rows
  Widget _buildFishDetailRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.only(left: 22, bottom: 4),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConditionalCompatibilityWarning() {
    final conditionalPairs = _calculationData!['conditional_compatibility_warnings'] as List<Map<String, dynamic>>? ?? [];
    
    return Container(
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
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          childrenPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          collapsedIconColor: const Color(0xFFFF9800),
          iconColor: const Color(0xFFFF9800),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFF9800).withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.warning,
              color: Color(0xFFFF9800),
              size: 20,
            ),
          ),
          title: const Text(
            'Conditional Compatibility Notice',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFFFF9800),
            ),
          ),
          subtitle: Text(
            'Tap to view ${conditionalPairs.length} fish combinations that need special attention',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info message
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9800).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFFF9800).withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: Color(0xFFFF9800),
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'These fish can coexist but require careful monitoring and proper tank conditions.',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFFFF9800),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Conditional pairs
                ...conditionalPairs.map((pair) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9800).withOpacity(0.05),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFFF9800).withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.warning,
                            color: Color(0xFFFF9800),
                            size: 14,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${pair['pair'][0]} + ${pair['pair'][1]}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFFF9800),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Reasons
                      ...(pair['reasons'] as List).map((reason) => Padding(
                        padding: const EdgeInsets.only(left: 22, bottom: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 6),
                              width: 4,
                              height: 4,
                              decoration: const BoxDecoration(
                                color: Color(0xFFFF9800),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                reason.toString(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black87,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )).toList(),
                    ],
                  ),
                )).toList(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncompatibilityResult() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Warning Card
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
                      'Incompatible Fish',
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
          // Selected Fish Card
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0F7FA),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                              FontAwesomeIcons.fish,
                              color: Color(0xFF006064),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Selected Fish',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF006064),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      for (var entry in _fishSelections.entries)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE0F7FA),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${entry.value}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF006064),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  entry.key,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                if (_calculationData != null && _calculationData!['compatibility_issues'] != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFF3F3),
                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Compatibility Issues:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFE53935),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...(_calculationData!['compatibility_issues'] as List).map((issue) {
                          final pair = issue['pair'] as List;
                          final reasons = issue['reasons'] as List;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.warning_rounded,
                                      color: Color(0xFFE53935),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Builder(
                                        builder: (context) {
                                          final bool same = pair.length >= 2 && pair[0] == pair[1];
                                          final String label = same ? '${pair[0]}' : '${pair[0]} + ${pair[1]}';
                                          return Text(
                                            label,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                              color: Color(0xFFE53935),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ...reasons.map((reason) => Padding(
                                  padding: const EdgeInsets.only(left: 28, bottom: 4),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        margin: const EdgeInsets.only(top: 6),
                                        width: 6,
                                        height: 6,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFE53935),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: ExpandableReason(
                                          text: reason.toString(),
                                          textStyle: const TextStyle(
                                            fontSize: 14,
                                            color: Colors.black87,
                                            height: 1.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )).toList(),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Action Buttons
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      _clearFishInputs();
                      _volumeController.clear();
                      _calculationData = null;
                    });
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFF00BCD4),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: const Text(
                    'Try Again',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }


  Widget _buildVolumeInput() {
    // Hide volume input for bowl tanks since they're hardcoded to 10L
    if (_selectedTankShape == 'bowl') {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFE0F7FA),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF00BCD4).withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(
              FontAwesomeIcons.water,
              color: Color(0xFF00BCD4),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Bowl Tank Volume',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF006064),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Fixed at 10L (Bowl tanks are standardized)',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF006064),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
                Row(
                  children: [
                    const Icon(
                      FontAwesomeIcons.water,
                color: Color(0xFF00BCD4),
                size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Tank Volume',
                      style: TextStyle(
                        fontSize: 16,
                  fontWeight: FontWeight.w600,
                        color: Color(0xFF006064),
                      ),
                    ),
                  ],
                ),
          const SizedBox(height: 12),
          // Input field with unit selector
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _volumeController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Enter tank volume',
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(8),
                        bottomLeft: Radius.circular(8),
                        topRight: Radius.zero,
                        bottomRight: Radius.zero,
                      ),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(8),
                        bottomLeft: Radius.circular(8),
                        topRight: Radius.zero,
                        bottomRight: Radius.zero,
                      ),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(8),
                        bottomLeft: Radius.circular(8),
                        topRight: Radius.zero,
                        bottomRight: Radius.zero,
                      ),
                      borderSide: const BorderSide(color: Color(0xFF00BCD4)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
              ),
              // Unit selector
                Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.zero,
                    bottomLeft: Radius.zero,
                    topRight: Radius.circular(8),
                    bottomRight: Radius.circular(8),
                  ),
                  border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: DropdownButton<String>(
                    value: _selectedUnit,
                    items: ['L', 'gal'].map((String unit) {
                      return DropdownMenuItem<String>(
                        value: unit,
                        child: Text(unit),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedUnit = newValue;
                        });
                        // Check compatibility when unit changes (affects volume calculation)
                        if (_fishSelections.isNotEmpty && _volumeController.text.isNotEmpty) {
                          print('🔄 Unit changed to $newValue - checking compatibility...');
                          _checkAllFishTankShapeCompatibility();
                        }
                      }
                    },
                    style: const TextStyle(
                      color: Color(0xFF006064),
                    fontSize: 14,
                    ),
                    underline: Container(),
                  ),
                ),
              ],
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>?> _validateTankShapeCompatibility() async {
    try {
      print('Validating tank shape compatibility for: $_selectedTankShape');
      
      // Get user's input volume
      final userVolume = double.tryParse(_volumeController.text);
      if (userVolume == null || userVolume <= 0) {
        print('Invalid user volume input: ${_volumeController.text}');
        return null; // Continue with calculation if volume is invalid
      }

      // Convert to liters if needed
      double volumeInLiters = userVolume;
      if (_selectedUnit == 'gal') {
        volumeInLiters = userVolume * 3.78541;
      }

      // For bowl tanks, use hardcoded 10L limit
      if (_selectedTankShape == 'bowl') {
        volumeInLiters = 10.0;
      }

      print('Using volume for validation: ${volumeInLiters}L (user input: ${userVolume}${_selectedUnit})');
      
      // Get fish data to check sizes
      final response = await http.get(
        Uri.parse(ApiConfig.fishListEndpoint),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        print('Failed to load fish data for tank validation: ${response.statusCode}');
        return null; // Continue with calculation if fish data unavailable
      }

      final List<dynamic> fishList = json.decode(response.body);
      final List<Map<String, dynamic>> incompatibleFish = [];

      // Check each selected fish against tank shape and user's volume
      for (var fishName in _fishSelections.keys) {
        final fishData = fishList.firstWhere(
          (fish) => fish['common_name']?.toString().toLowerCase() == fishName.toLowerCase(),
          orElse: () => null,
        );

        if (fishData != null) {
          final maxSize = fishData['max_size'];
          final minTankSize = fishData['minimum_tank_size_l'];
          
          if (_isFishIncompatibleWithTankShapeAndVolume(fishName, maxSize, minTankSize, _selectedTankShape, volumeInLiters)) {
            incompatibleFish.add({
              'fish_name': fishName,
              'max_size': maxSize,
              'min_tank_size': minTankSize,
              'reason': _getTankShapeIncompatibilityReason(fishName, maxSize, minTankSize, _selectedTankShape, volumeInLiters),
            });
          }
        }
      }

      // If there are incompatible fish, return error result
      if (incompatibleFish.isNotEmpty) {
        return {
          'error': 'Tank Shape Incompatibility',
          'tank_shape_issues': incompatibleFish,
          'selected_tank_shape': _selectedTankShape,
        };
      }

      return null; // No issues found
    } catch (e) {
      print('Error validating tank shape compatibility: $e');
      return null; // Continue with calculation on error
    }
  }


  String _getTankShapeIncompatibilityReason(String fishName, dynamic maxSize, dynamic minTankSize, String tankShape, double userVolume) {
    final size = maxSize?.toString() ?? 'N/A';
    final tankVol = minTankSize?.toString() ?? 'N/A';
    
    print('🔍 Incompatibility reason for $fishName:');
    print('   - Max Size: $maxSize (raw) -> $size (formatted)');
    print('   - Min Tank Size: $minTankSize (raw) -> $tankVol (formatted)');
    print('   - Tank Shape: $tankShape');
    print('   - User Volume: ${userVolume}L');
    
    // Create a more informative tank volume display
    String tankVolDisplay = tankVol;
    if (tankVol == 'N/A' && maxSize != null) {
      // Calculate estimated tank size based on fish size
      final maxSizeNum = double.tryParse(maxSize.toString());
      if (maxSizeNum != null) {
        final maxSizeInches = maxSizeNum / 2.54;
        final estimatedTankSize = maxSizeInches * 3.78541; // Convert to liters
        tankVolDisplay = '${estimatedTankSize.toStringAsFixed(0)}L';
      } else {
        tankVolDisplay = 'estimated size';
      }
    } else if (tankVol != 'N/A') {
      // Format the tank volume nicely
      final tankVolNum = double.tryParse(tankVol);
      if (tankVolNum != null) {
        tankVolDisplay = '${tankVolNum.toStringAsFixed(0)}L';
      }
    }

    switch (tankShape) {
      case 'bowl':
        return '$fishName (max size: ${size}cm. Bowl tanks are limited to 10L and designed for nano fish under 8cm like bettas, small tetras, or shrimp.';
               
      case 'cylinder':
        return '$fishName (max size: ${size}cm, min tank: ${tankVolDisplay}) needs more horizontal swimming space than a cylinder tank provides. Your ${userVolume}L cylinder tank may not provide enough horizontal swimming space for this fish.';
               
      case 'rectangle':
        return '$fishName (min tank: ${tankVolDisplay}) needs more space than your ${userVolume}L ${tankShape} tank. Consider a larger tank or different fish.';
        
      default:
        return '$fishName is not suitable for the selected tank shape.';
    }
  }

  // Check if a fish is compatible with the selected tank shape
  Future<void> _checkFishTankShapeCompatibility(String fishName) async {
    try {
      print('🔍 Checking tank shape compatibility for: $fishName');
      
      // Get fish data from Supabase
      var response = await Supabase.instance.client
          .from('fish_species')
          .select('common_name, "max_size_(cm)", "minimum_tank_size_(l)"')
          .ilike('common_name', fishName)
          .maybeSingle();

      print('📊 Supabase response for $fishName: $response');
      
      // If no data found, try alternative column names
      if (response == null) {
        print('🔄 Trying alternative column names...');
        final altResponse = await Supabase.instance.client
            .from('fish_species')
            .select('common_name, max_size_cm, minimum_tank_size_l')
            .ilike('common_name', fishName)
            .maybeSingle();
        print('📊 Alternative response: $altResponse');
        
        // Also try to see what fish names are available
        print('🔍 Searching for similar fish names...');
        final similarFish = await Supabase.instance.client
            .from('fish_species')
            .select('common_name')
            .ilike('common_name', '%$fishName%')
            .limit(5);
        print('📊 Similar fish found: $similarFish');
        
        // If we found data with alternative columns, use it
        if (altResponse != null) {
          response = altResponse;
          print('✅ Using alternative response data');
        }
      }

      if (response != null) {
        // Try both column name formats
        final maxSize = response['max_size_(cm)'] ?? response['max_size_cm'];
        final minTankSize = response['minimum_tank_size_(l)'] ?? response['minimum_tank_size_l'];
        
        print('📏 Fish data - Max Size: $maxSize, Min Tank Size: $minTankSize');
        print('🔍 Raw response keys: ${response.keys.toList()}');
        print('🔍 Raw response values: ${response.values.toList()}');
        
        // Convert to double safely
        double? maxSizeDouble = maxSize != null ? double.tryParse(maxSize.toString()) : null;
        double? minTankSizeDouble = minTankSize != null ? double.tryParse(minTankSize.toString()) : null;
        
        print('🔢 Converted - Max Size: $maxSizeDouble, Min Tank Size: $minTankSizeDouble');
        
        // If minTankSize is null, calculate a reasonable estimate based on max size
        double? effectiveMinTankSize = minTankSizeDouble;
        if (minTankSizeDouble == null && maxSizeDouble != null) {
          // Estimate minimum tank size based on fish size (rough rule: 1 gallon per inch)
          final maxSizeInches = maxSizeDouble / 2.54;
          effectiveMinTankSize = maxSizeInches * 3.78541; // Convert to liters
          print('📊 Estimated min tank size based on ${maxSizeDouble}cm: ${effectiveMinTankSize}L');
        }
        
        // Get user's input volume for validation
        final userVolume = double.tryParse(_volumeController.text);
        if (userVolume != null && userVolume > 0) {
          // Convert to liters if needed
          double volumeInLiters = userVolume;
          if (_selectedUnit == 'gal') {
            volumeInLiters = userVolume * 3.78541;
          }

          // For bowl tanks, use hardcoded 10L limit
          if (_selectedTankShape == 'bowl') {
            volumeInLiters = 10.0;
          }

          print('🏠 Using user volume for validation: ${volumeInLiters}L (user input: ${userVolume}${_selectedUnit})');
          
          if (_isFishIncompatibleWithTankShapeAndVolume(fishName, maxSizeDouble, effectiveMinTankSize, _selectedTankShape, volumeInLiters)) {
            print('⚠️ Fish $fishName is incompatible with $_selectedTankShape tank');
            setState(() {
              _fishTankShapeWarnings[fishName] = _getSimpleWarningMessage(fishName, _getTankShapeIncompatibilityReason(fishName, maxSizeDouble, effectiveMinTankSize, _selectedTankShape, volumeInLiters));
            });
          } else {
            print('✅ Fish $fishName is compatible with $_selectedTankShape tank');
            setState(() {
              _fishTankShapeWarnings.remove(fishName);
            });
          }
        } else {
          print('⚠️ No valid volume input for compatibility check');
          setState(() {
            _fishTankShapeWarnings.remove(fishName);
          });
        }
    } else {
        print('❌ No fish data found for: $fishName');
      }
    } catch (e) {
      print('Error checking tank shape compatibility for $fishName: $e');
    }
  }

  // Check all selected fish for tank shape compatibility
  Future<void> _checkAllFishTankShapeCompatibility() async {
    for (String fishName in _fishSelections.keys) {
      await _checkFishTankShapeCompatibility(fishName);
    }
  }


  // Check if fish is incompatible with tank shape AND user's volume
  bool _isFishIncompatibleWithTankShapeAndVolume(String fishName, dynamic maxSize, dynamic minTankSize, String tankShape, double userVolume) {
    // Convert sizes to numbers for comparison
    double? fishMaxSize;
    double? fishMinTankSize;
    
    try {
      if (maxSize != null) fishMaxSize = double.tryParse(maxSize.toString());
      if (minTankSize != null) fishMinTankSize = double.tryParse(minTankSize.toString());
    } catch (e) {
      print('Error parsing fish size data: $e');
      return false; // Don't block if we can't parse the data
    }

    // Check if fish needs more space than the user's tank volume provides
    if (fishMinTankSize != null && fishMinTankSize > userVolume) {
      print('❌ Fish $fishName needs ${fishMinTankSize}L but user has ${userVolume}L');
      return true;
    }

    // Additional shape-specific checks
    switch (tankShape) {
      case 'bowl':
        // Bowl tanks are hardcoded to 10L - Only for nano fish under 8cm
        if (fishMaxSize != null && fishMaxSize > 8) {
          print('❌ Fish $fishName (${fishMaxSize}cm) too large for bowl tank (max 8cm)');
          return true;
        }
        // Also check if fish needs more than 10L
        if (fishMinTankSize != null && fishMinTankSize > 10) {
          print('❌ Fish $fishName needs ${fishMinTankSize}L but bowl is limited to 10L');
          return true;
        }
        return false;
        
      case 'cylinder':
        // Cylinder tanks - Limited horizontal swimming space, fish under 20cm
        if (fishMaxSize != null && fishMaxSize > 20) {
          print('❌ Fish $fishName (${fishMaxSize}cm) too large for cylinder tank (max 20cm)');
          return true;
        }
        // Also check volume requirement
        if (fishMinTankSize != null && fishMinTankSize > userVolume) {
          print('❌ Fish $fishName needs ${fishMinTankSize}L but cylinder has ${userVolume}L');
          return true;
        }
        return false;
        
      case 'rectangle':
      default:
        // Rectangle tanks - Most versatile, only check volume
        if (fishMinTankSize != null && fishMinTankSize > userVolume) {
          print('❌ Fish $fishName needs ${fishMinTankSize}L but rectangle has ${userVolume}L');
          return true;
        }
        return false;
    }
  }

  // Get simple warning message for user-friendly display
  String _getSimpleWarningMessage(String fishName, String technicalMessage) {
    if (technicalMessage.contains('bowl tank')) {
      return 'Too big for bowl tank (max 10L)';
    } else if (technicalMessage.contains('cylinder tank')) {
      return 'Needs more space than cylinder tank';
    } else if (technicalMessage.contains('needs more space')) {
      return 'Needs bigger tank than selected';
    } else {
      return 'Not suitable for selected tank';
    }
  }



  Widget _buildBowlLoadingAnimation() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.white,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Lottie Animation
          SizedBox(
            width: 200,
            height: 200,
            child: Lottie.asset(
              'lib/lottie/BowlAnimation.json',
              fit: BoxFit.contain,
              repeat: true,
            ),
          ),
          const SizedBox(height: 30),
          const Text(
            'Calculating Tank Volume...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF006064),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Determining optimal tank volume for your fish',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          const LinearProgressIndicator(
            backgroundColor: Color(0xFFE0F2F1),
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00BCD4)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Colors.white,
        child: Stack(
          children: [
            if (_isCalculating)
              _buildBowlLoadingAnimation()
            else
              Container(
                color: Colors.white,
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            if (_calculationData == null)
                              Column(
                                children: [
                                  _buildBackToMethodsButton(),
                                  _buildSuggestionSection(),
                                  _buildTankShapeSelector(),
                                  _buildVolumeInput(),
                                  _buildFishInput(),
                                  _buildTankShapeWarningsWidget(),
                                ],
                              )
                            else if (_calculationData!['tank_shape_issues'] != null)
                              _buildTankShapeIncompatibilityResults(_calculationData!)
                            else if (_calculationData!['incompatible_pairs'] != null)
                              _buildCompatibilityResults(_calculationData!)
                            else if (_calculationData!['compatibility_issues'] != null && 
                                   (_calculationData!['compatibility_issues'] as List).isNotEmpty)
                              _buildIncompatibilityResult()
                            else
                              _buildResultDisplay(),
                          ],
                        ),
                      ),
                    ),
                    if (_calculationData == null)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isGroupIncompatible ? null : _calculateRequirements,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00BCD4),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            child: const Text(
                              'Calculate',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      )
                    else if (_calculationData == null && _isGroupIncompatible)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Color(0xFFD92D20), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Selected fish are not compatible. Remove the incompatible combinations to continue.',
                                style: const TextStyle(fontSize: 12, color: Color(0xFFD92D20)),
                              ),
                            ),
                          ],
                        ),
                      )
                    else if ((_calculationData!['compatibility_issues'] == null || 
                           (_calculationData!['compatibility_issues'] as List).isEmpty) && 
                           !_calculationData!.containsKey('tank_shape_issues') &&
                           !_calculationData!.containsKey('incompatible_pairs') &&
                           !_hasUnsuitableFish())
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () {
                                  setState(() {
                                    _clearFishInputs();
                                    _volumeController.clear();
                                    _calculationData = null;
                                  });
                                },
                                style: TextButton.styleFrom(
                                  backgroundColor: Colors.grey[200],
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                child: const Text(
                                  'Clear',
                                  style: TextStyle(
                                    color: Colors.black87,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _saveCalculation,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00BCD4),
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                child: const Text(
                                  'Save',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTankShapeSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
                const Text(
                  'Tank Shape',
                  style: TextStyle(
                    fontSize: 16,
              fontWeight: FontWeight.w600,
                    color: Color(0xFF006064),
                  ),
                ),
                  const SizedBox(height: 12),
                      Row(
                        children: [
              Expanded(
                child: _buildMinimalShapeOption('bowl', 'Bowl', Icons.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMinimalShapeOption('rectangle', 'Rectangle', Icons.crop_landscape),
              ),
              const SizedBox(width: 8),
                            Expanded(
                child: _buildMinimalShapeOption('cylinder', 'Cylinder', Icons.circle_outlined),
                          ),
                        ],
                      ),
        ],
      ),
    );
  }

  Widget _buildMinimalShapeOption(String value, String label, IconData icon) {
    final isSelected = _selectedTankShape == value;
    return GestureDetector(
      onTap: () async {
        setState(() {
          _selectedTankShape = value;
        });
        // Check compatibility for all selected fish when tank shape changes
        if (_fishSelections.isNotEmpty) {
          print('🔄 Tank shape changed to $value - checking compatibility...');
          await _checkAllFishTankShapeCompatibility();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00BCD4).withOpacity(0.1) : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? const Color(0xFF00BCD4) : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
                    ),
                    child: Column(
                      children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF00BCD4) : Colors.grey.shade600,
              size: 20,
            ),
            const SizedBox(height: 4),
            Text(
              label,
                              style: TextStyle(
                                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isSelected ? const Color(0xFF00BCD4) : Colors.grey.shade700,
                              ),
              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
      ),
    );
  }

  Widget _buildCompatibilityResults(Map<String, dynamic> results) {
    final incompatiblePairs = (results['incompatible_pairs'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final conditionalPairs = (results['conditional_pairs'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final hasIncompatible = incompatiblePairs.isNotEmpty;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Warning Card
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: hasIncompatible
                    ? [const Color(0xFFFF6B6B), const Color(0xFFFF8585)]
                    : [const Color(0xFFFF9800), const Color(0xFFFFB74D)],
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
                    child: Icon(
                      hasIncompatible ? Icons.warning_rounded : Icons.info_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      hasIncompatible 
                          ? 'Incompatible Fish Combinations'
                          : 'Conditional Fish Compatibility',
                      style: const TextStyle(
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
          // Compatibility Issues List
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
                      children: [
                // Show incompatible pairs first
                ...incompatiblePairs.map((pair) => _buildCompatibilityPairCard(pair, isIncompatible: true)),
                // Then show conditional pairs
                ...conditionalPairs.map((pair) => _buildCompatibilityPairCard(pair, isIncompatible: false)),
                      ],
                    ),
                  ),
          const SizedBox(height: 20),
          // Try Again Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                  _clearFishInputs();
                  _volumeController.clear();
                  _calculationData = null;
                    });
                  },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00BCD4),
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

  Widget _buildCompatibilityPairCard(Map<String, dynamic> pair, {required bool isIncompatible}) {
    final pairColor = isIncompatible ? const Color(0xFFFF6B6B) : const Color(0xFFFF9800);
    final pairIcon = isIncompatible ? Icons.cancel : Icons.warning;
    
    return Container(
        decoration: BoxDecoration(
        border: Border(
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
            Icon(
                  pairIcon,
                  color: pairColor,
                  size: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
                  child: Text(
                    '${pair['pair'][0]} + ${pair['pair'][1]}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: pairColor,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: pairColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: pairColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    isIncompatible ? 'Incompatible' : 'Conditional',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: pairColor,
                    ),
              ),
            ),
          ],
            ),
            const SizedBox(height: 12),
            ...(pair['reasons'] as List).map((reason) => Padding(
              padding: const EdgeInsets.only(left: 30, bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
          children: [
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: pairColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      reason.toString(),
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            )).toList(),
          ],
        ),
      ),
    );
  }
} 