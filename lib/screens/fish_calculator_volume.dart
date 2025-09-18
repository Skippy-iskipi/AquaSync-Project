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
  const FishCalculatorVolume({super.key});

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
  
  // Debounce timer for volume changes
  Timer? _volumeChangeTimer;

  

  @override
  void initState() {
    super.initState();
    _loadFishSpecies();
    _loadFishData();
    
    // Add listener to volume controller for real-time compatibility checks
    _volumeController.addListener(_onVolumeChanged);
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
        
        if (hasIncompatiblePairs || hasConditionalPairs) {
          print('Processing compatibility issues...');
          // Combine both incompatible and conditional pairs
          final allProblematicPairs = [...incompatiblePairs, ...conditionalPairs];
          
          setState(() {
            _calculationData = {
              'error': hasIncompatiblePairs ? 'Incompatible Fish Combinations' : 'Conditional Fish Compatibility',
              'incompatible_pairs': incompatiblePairs,
              'conditional_pairs': conditionalPairs,
              'all_pairs': allProblematicPairs,
            };
            _isCalculating = false;
          });
          return;
        }
      }

      double volume;
      if (_selectedTankShape == 'bowl') {
        // Bowl tanks are hardcoded to 10L
        volume = 10.0;
      } else {
        volume = double.parse(_volumeController.text);
        if (_selectedUnit == 'gal') {
          volume = volume * 3.78541; // Convert gallons to liters
        }
      }

      // Use the tank management system's approach for fish quantity recommendations
      print('Using tank management system approach for fish quantity recommendations');
      final recommendedQuantities = await _calculateRecommendedFishQuantities(volume, _fishSelections);
      
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
        };
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
  Future<Map<String, int>> _calculateRecommendedFishQuantities(double tankVolume, Map<String, int> fishSelections) async {
    Map<String, int> recommendations = {};
    
    // Fetch fish data from database using the same approach as tank management
    final fishData = await _getFishDataFromDatabase(fishSelections.keys.toList());
    
    for (String fishName in fishSelections.keys) {
      final fishInfo = fishData[fishName];
      if (fishInfo != null) {
        final maxSizeCm = fishInfo['max_size_cm'] ?? 0.0;
        final minimumTankSizeL = fishInfo['minimum_tank_size_l'] ?? 0.0;
        final bioload = fishInfo['bioload'] ?? 1.0;
        
        // Calculate recommended quantity using database data
        int recommendedQty = 0;
        
        // Check if tank meets minimum requirements first
        if (minimumTankSizeL > 0 && tankVolume < minimumTankSizeL) {
          // Tank too small for this species - recommend 0
          recommendedQty = 0;
        } else {
          // Calculate based on fish behavior and tank capacity
          recommendedQty = _calculateFishQuantity(fishName, tankVolume, minimumTankSizeL, maxSizeCm, bioload);
        }
        
        // Ensure maximum of 20 for better stocking
        final finalQty = recommendedQty.clamp(0, 20);
        recommendations[fishName] = finalQty;
      } else {
        recommendations[fishName] = 1;
      }
    }
    return recommendations;
  }

  // Fetch fish data from database using the same approach as tank management
  Future<Map<String, Map<String, dynamic>>> _getFishDataFromDatabase(List<String> fishNames) async {
    final Map<String, Map<String, dynamic>> fishData = {};
    
    try {
      // Query fish_species table for the required data
      final response = await Supabase.instance.client
          .from('fish_species')
          .select('common_name, "max_size_(cm)", "minimum_tank_size_(l)", bioload')
          .inFilter('common_name', fishNames);
      
      for (final fish in response) {
        final commonName = fish['common_name'] as String?;
        final maxSizeCm = fish['max_size_(cm)'];
        final minimumTankSizeL = fish['minimum_tank_size_(l)'];
        final bioload = fish['bioload'];
        
        if (commonName != null) {
          fishData[commonName] = {
            'max_size_cm': maxSizeCm != null ? double.tryParse(maxSizeCm.toString()) ?? 0.0 : 0.0,
            'minimum_tank_size_l': minimumTankSizeL != null ? double.tryParse(minimumTankSizeL.toString()) ?? 0.0 : 0.0,
            'bioload': bioload != null ? double.tryParse(bioload.toString()) ?? 1.0 : 1.0,
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
  int _calculateFishQuantity(String fishName, double tankVolume, double minimumTankSizeL, double maxSizeCm, double bioload) {
    final fishNameLower = fishName.toLowerCase();
    
    // Special handling for bettas
    if (fishNameLower.contains('betta') || fishNameLower.contains('fighting fish')) {
      // For bettas: 1 male OR 4-5 females (sorority)
      // Since we can't determine gender, recommend 1 (male) for safety
      // In a real app, you'd ask the user to specify gender
      return 1;
    }
    
    // Special handling for other territorial fish
    if (fishNameLower.contains('gourami') || 
        fishNameLower.contains('cichlid') ||
        fishNameLower.contains('angelfish') ||
        fishNameLower.contains('discus')) {
      // Most territorial fish should be kept alone or in pairs
      return 1;
    }
    
    // For other fish, calculate based on tank capacity
    if (minimumTankSizeL > 0) {
      // Use minimum tank size as a guide for maximum fish per tank
      // For example: if minimum is 20L, then 100L tank can hold 100/20 = 5 fish
      int maxFish = (tankVolume / minimumTankSizeL).floor();
      
      // Apply bioload factor
      if (bioload > 1.0) {
        maxFish = (maxFish / bioload).floor();
      }
      
      // Ensure at least 1 fish
      return maxFish.clamp(1, 10);
    } else if (maxSizeCm > 0) {
      // Fallback to size-based calculation
      final volumePerFish = _calculateVolumeFromSize(maxSizeCm);
      int calculatedQty = (tankVolume / volumePerFish).floor();
      
      // Apply bioload factor
      if (bioload > 1.0) {
        calculatedQty = (calculatedQty / bioload).floor();
      }
      
      return calculatedQty.clamp(1, 10);
    }
    
    // Default fallback
    return 1;
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
        return '$fishName (max size: ${size}cm, min tank: ${tankVolDisplay}) is too large for a bowl tank. Bowl tanks are limited to 10L and designed for nano fish under 8cm like bettas, small tetras, or shrimp.';
               
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
                                  _buildTankShapeSelector(),
                                  _buildVolumeInput(),
                                  _buildFishInput(),
                                  _buildTankShapeWarningsWidget(),
                                ],
                              )
                            else if (_calculationData!['tank_shape_issues'] != null)
                              _buildTankShapeIncompatibilityResults(_calculationData!)
                            else if (_calculationData!['incompatible_pairs'] != null || _calculationData!['conditional_pairs'] != null)
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
                            onPressed: _calculateRequirements,
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
                    else if ((_calculationData!['compatibility_issues'] == null || 
                           (_calculationData!['compatibility_issues'] as List).isEmpty) && 
                           !_calculationData!.containsKey('tank_shape_issues'))
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
    final incompatiblePairs = results['incompatible_pairs'] as List<Map<String, dynamic>>? ?? [];
    final conditionalPairs = results['conditional_pairs'] as List<Map<String, dynamic>>? ?? [];
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