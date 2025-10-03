import 'package:flutter/material.dart';
import '../models/fish_calculation.dart';
import 'package:provider/provider.dart';
import 'logbook_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../config/api_config.dart';
import '../widgets/custom_notification.dart';

import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../widgets/expandable_reason.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/auth_required_dialog.dart';
import '../widgets/fish_info_dialog.dart';
import '../widgets/fish_card_tankmates.dart';
 

class FishCalculatorDimensions extends StatefulWidget {
  const FishCalculatorDimensions({super.key});

  @override
  _FishCalculatorDimensionsState createState() => _FishCalculatorDimensionsState();
}

class _FishCalculatorDimensionsState extends State<FishCalculatorDimensions> {
  String _selectedUnit = 'CM';
  String _selectedTankShape = 'bowl';
  final TextEditingController _depthController = TextEditingController();
  final TextEditingController _widthController = TextEditingController();
  final TextEditingController _lengthController = TextEditingController();
  final TextEditingController _fishController1 = TextEditingController();
  final TextEditingController _fishController2 = TextEditingController();

  String? _selectedFish1;
  String? _selectedFish2;
  bool _isCalculating = false;
  Map<String, dynamic>? _calculationData;
  List<String> _availableFish = [];
  Map<String, int> _fishSelections = {};
  
  // Fish data from Supabase
  List<Map<String, dynamic>> _fishData = [];
  
  // Dropdown and search state
  Map<String, bool> _showDropdown = {};
  Map<String, String> _searchQueries = {};
  int _autocompleteKey = 0;
  
  // Tank shape compatibility warnings
  Map<String, String> _fishTankShapeWarnings = {};
  
  // Store conditional compatibility pairs for display
  List<Map<String, dynamic>> _conditionalCompatibilityPairs = [];
  
  // Collapsible sections state
  bool _isTankmatesExpanded = false;
  




  @override
  void initState() {
    super.initState();
    _loadFishSpecies();
    _loadFishData();
  }

  @override
  void dispose() {
    _depthController.dispose();
    _widthController.dispose();
    _lengthController.dispose();
    _fishController1.dispose();
    _fishController2.dispose();
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
        final List<dynamic> fishList = json.decode(response.body);
        setState(() {
          _availableFish = fishList
              .map((fish) => fish['common_name'] as String)
              .toList();
          _availableFish.sort(); // Sort alphabetically
        });
      } else {
        throw Exception('Failed to load fish list: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching fish list: $e');
      showCustomNotification(
        context,
        'Error loading fish list: ${e.toString()}',
        isError: true,
      );
    }
  }

  Future<void> _loadFishData() async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.fishListEndpoint),
        headers: {'Accept': 'application/json'}
      ).timeout(ApiConfig.timeout);
      
      if (response.statusCode == 200) {
        final List<dynamic> fishList = json.decode(response.body);
        setState(() {
          _fishData = fishList.cast<Map<String, dynamic>>();
        });
      }
    } catch (e) {
      print('Error loading fish data: $e');
    }
  }


  Future<Map<String, dynamic>> _getWaterRequirements() async {
    try {
      final fishNames = _fishSelections.keys.toList();
      if (fishNames.isEmpty) return {};

      // Get water requirements from fish data
      String? temperatureRange;
      String? phRange;

      for (final fishName in fishNames) {
        final fishInfo = _fishData.firstWhere(
          (fish) => fish['common_name']?.toString().toLowerCase() == fishName.toLowerCase(),
          orElse: () => {},
        );

        if (fishInfo.isNotEmpty) {
          final temp = fishInfo['temperature_range']?.toString();
          final ph = fishInfo['ph_range']?.toString();
          
          if (temp != null && temperatureRange == null) temperatureRange = temp;
          if (ph != null && phRange == null) phRange = ph;
        }
      }

      return {
        'temperature': temperatureRange ?? '22-26°C',
        'ph': phRange ?? '6.5-7.5',
      };
    } catch (e) {
      print('Error getting water requirements: $e');
      return {
        'temperature': '22-26°C',
        'ph': '6.5-7.5',
      };
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: Color(0xFF00BCD4),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF006064),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  Future<Map<String, dynamic>> _getFeedingInformation() async {
    try {
      final fishNames = _fishSelections.keys.toList();
      if (fishNames.isEmpty) return {};

      Map<String, dynamic> feedingInfo = {};
      
      for (String fishName in fishNames) {
        final fishInfo = _fishData.firstWhere(
          (fish) => fish['common_name']?.toString().toLowerCase() == fishName.toLowerCase(),
          orElse: () => {},
        );

        if (fishInfo.isNotEmpty) {
          Map<String, dynamic> fishFeedingInfo = {};
          
          if (fishInfo['portion_grams'] != null && fishInfo['portion_grams'].toString().isNotEmpty) {
            fishFeedingInfo['portion_grams'] = fishInfo['portion_grams'];
          }
          if (fishInfo['preferred_food'] != null && fishInfo['preferred_food'].toString().isNotEmpty) {
            fishFeedingInfo['preferred_food'] = fishInfo['preferred_food'];
          }
          if (fishInfo['feeding_notes'] != null && fishInfo['feeding_notes'].toString().isNotEmpty) {
            fishFeedingInfo['feeding_notes'] = fishInfo['feeding_notes'];
          }
          if (fishInfo['overfeeding_risks'] != null && fishInfo['overfeeding_risks'].toString().isNotEmpty) {
            fishFeedingInfo['overfeeding_risks'] = fishInfo['overfeeding_risks'];
          }
          
          if (fishFeedingInfo.isNotEmpty) {
            feedingInfo[fishName] = fishFeedingInfo;
          }
        }
      }
      
      return feedingInfo;
    } catch (e) {
      print('Error getting feeding information: $e');
      return {};
    }
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
            print('🐠 Raw response for $fishName: $response');
            
            // Add fully compatible tankmates
            if (response['fully_compatible_tankmates'] != null) {
              final fullyCompatibleData = response['fully_compatible_tankmates'];
              print('🐠 Fully compatible data type: ${fullyCompatibleData.runtimeType}, value: $fullyCompatibleData');
              List<String> fullyCompatible = [];
              if (fullyCompatibleData is List) {
                fullyCompatible = List<String>.from(fullyCompatibleData);
              } else if (fullyCompatibleData is Map) {
                // If it's a Map, extract the values
                fullyCompatible = fullyCompatibleData.values.map((e) => e.toString()).toList();
              } else if (fullyCompatibleData is String) {
                // If it's a JSON string, try to parse it
                try {
                  final parsed = json.decode(fullyCompatibleData);
                  if (parsed is List) {
                    fullyCompatible = List<String>.from(parsed);
                  }
                } catch (e) {
                  print('🐠 Error parsing fully compatible JSON: $e');
                }
              }
              fishFullyCompatible[fishName] = fullyCompatible.toSet();
              print('🐠 Processed fully compatible for $fishName: $fullyCompatible');
            }
            
            // Add conditional tankmates
            if (response['conditional_tankmates'] != null) {
              final conditionalData = response['conditional_tankmates'];
              print('🐠 Conditional data type: ${conditionalData.runtimeType}, value: $conditionalData');
              List<String> conditional = [];
              if (conditionalData is List) {
                conditional = List<String>.from(conditionalData);
              } else if (conditionalData is Map) {
                // If it's a Map, extract the values
                conditional = conditionalData.values.map((e) => e.toString()).toList();
              } else if (conditionalData is String) {
                // If it's a JSON string, try to parse it
                try {
                  final parsed = json.decode(conditionalData);
                  if (parsed is List) {
                    conditional = List<String>.from(parsed);
                  }
                } catch (e) {
                  print('🐠 Error parsing conditional JSON: $e');
                }
              }
              fishConditional[fishName] = conditional.toSet();
              print('🐠 Processed conditional for $fishName: $conditional');
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
        // Start with the first fish's tankmates, then intersect with others
        commonFullyCompatible = fishFullyCompatible.values.first;
        for (var tankmates in fishFullyCompatible.values.skip(1)) {
          commonFullyCompatible = commonFullyCompatible.intersection(tankmates);
        }
      }
      
      if (fishConditional.isNotEmpty) {
        // Start with the first fish's tankmates, then intersect with others
        commonConditional = fishConditional.values.first;
        for (var tankmates in fishConditional.values.skip(1)) {
          commonConditional = commonConditional.intersection(tankmates);
        }
      }
      
      // Convert to lists and sort
      final fullyCompatible = commonFullyCompatible.toList()..sort();
      final conditional = commonConditional.toList()..sort();
      
      print('🐠 Found ${fullyCompatible.length} fully compatible and ${conditional.length} conditional tankmates from Supabase');
      print('🐠 Fully compatible: $fullyCompatible');
      print('🐠 Conditional: $conditional');
      
      return {
        'fully_compatible': fullyCompatible,
        'conditional': conditional,
      };
    } catch (e) {
      print('🐠 Tankmate recommendations failed: $e');
      return {'fully_compatible': [], 'conditional': []};
    }
  }

  Widget _buildTankmateSection(String title, List<String> fish, IconData icon, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: fish.take(5).map((fishName) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Text(
              fishName,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          )).toList(),
        ),
      ],
    );
  }

  // Get unique fish species from selections
  List<String> _getUniqueFishSpecies() {
    return _fishSelections.keys.toSet().toList();
  }

  // Get portion display text for a fish
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

  // Calculate recommended fish quantities using Supabase data
  Future<Map<String, int>> _calculateRecommendedFishQuantities(double tankVolume, Map<String, int> fishSelections) async {
    Map<String, int> recommendations = {};
    
    try {
      // Fetch fish data from Supabase
      final fishData = await _getFishDataFromSupabase(fishSelections.keys.toList());
      
      for (String fishName in fishSelections.keys) {
        final fishInfo = fishData[fishName];
        if (fishInfo != null) {
          final maxSizeCm = fishInfo['max_size_cm'] ?? 0.0;
          final minimumTankSizeL = fishInfo['minimum_tank_size_l'] ?? 0.0;
          final bioload = fishInfo['bioload'] ?? 1.0;
          
          // Calculate recommended quantity using the same logic as volume calculator
          int recommendedQty = _calculateFishQuantity(fishName, tankVolume, minimumTankSizeL, maxSizeCm, bioload);
          
          // Ensure maximum of 20 for better stocking
          final finalQty = recommendedQty.clamp(0, 20);
          recommendations[fishName] = finalQty;
        } else {
          recommendations[fishName] = 1;
        }
      }
    } catch (e) {
      print('Error calculating recommended quantities: $e');
      // Fallback to 1 for each fish
      for (String fishName in fishSelections.keys) {
        recommendations[fishName] = 1;
      }
    }
    
    return recommendations;
  }

  // Fetch fish data from Supabase
  Future<Map<String, Map<String, dynamic>>> _getFishDataFromSupabase(List<String> fishNames) async {
    final Map<String, Map<String, dynamic>> fishData = {};
    
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('fish_species')
          .select('common_name, "max_size_(cm)", "minimum_tank_size_(l)", bioload')
          .eq('active', true)
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
      print('Error fetching fish data from Supabase: $e');
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

  // Calculate fish quantity based on behavior and tank capacity (same logic as volume calculator)
  int _calculateFishQuantity(String fishName, double tankVolume, double minimumTankSizeL, double maxSizeCm, double bioload) {
    final fishNameLower = fishName.toLowerCase();
    
    // Special handling for bettas
    if (fishNameLower.contains('betta') || fishNameLower.contains('fighting fish')) {
      // For bettas: 1 male OR 4-5 females (sorority)
      // Since we can't determine gender, recommend 1 (male) for safety
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

  // Calculate volume requirement from fish size (same logic as volume calculator)
  double _calculateVolumeFromSize(double sizeCm) {
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


  void _addFishByName(String fishName) {
    if (!_availableFish.contains(fishName)) return;
    
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
  }

  void _clearFishInputs() {
    setState(() {
      _selectedFish1 = null;
      _selectedFish2 = null;
      _fishController1.clear();
      _fishController2.clear();
      _fishSelections = {};
      _calculationData = null;
      _showDropdown.clear();
      _searchQueries.clear();
      _fishTankShapeWarnings.clear();
      _conditionalCompatibilityPairs.clear();
      // Clear dimension inputs
      _depthController.clear();
      _widthController.clear();
      _lengthController.clear();
    });
  }

  // Tank shape compatibility checking methods
  void _checkFishTankShapeCompatibility(String fishName) {
    // Get fish data to check compatibility
    final fishInfo = _fishData.firstWhere(
      (fish) => fish['common_name']?.toString().toLowerCase() == fishName.toLowerCase(),
      orElse: () => {},
    );

    if (fishInfo.isNotEmpty) {
      final maxSize = fishInfo['max_size'];
      final minTankSize = fishInfo['minimum_tank_size_l'];
      
      if (_isFishIncompatibleWithTankShapeAndVolume(fishName, maxSize, minTankSize, _selectedTankShape, _calculateVolume())) {
        setState(() {
          _fishTankShapeWarnings[fishName] = _getTankShapeIncompatibilityReason(fishName, maxSize, minTankSize, _selectedTankShape, _calculateVolume());
        });
      } else {
        setState(() {
          _fishTankShapeWarnings.remove(fishName);
        });
      }
    }
  }

  bool _isFishIncompatibleWithTankShapeAndVolume(String fishName, dynamic maxSize, dynamic minTankSize, String tankShape, double volume) {
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

    switch (tankShape) {
      case 'bowl':
        // Bowl tanks are hardcoded to 10L - check if fish is too large or needs more space
        return (fishMaxSize != null && fishMaxSize > 8) || 
               (fishMinTankSize != null && fishMinTankSize > 10);
               
      case 'cylinder':
        // Cylinder tanks - check fish size and volume requirements
        return (fishMaxSize != null && fishMaxSize > 20) || 
               (fishMinTankSize != null && fishMinTankSize > volume);
               
      case 'rectangle':
      default:
        // Rectangle tanks - check volume requirements
        return fishMinTankSize != null && fishMinTankSize > volume;
    }
  }

  String _getTankShapeIncompatibilityReason(String fishName, dynamic maxSize, dynamic minTankSize, String tankShape, double volume) {
    final size = maxSize?.toString() ?? 'N/A';
    final tankVol = minTankSize?.toString() ?? 'N/A';
    
    switch (tankShape) {
      case 'bowl':
        return '$fishName (max size: ${size}cm. Bowl tanks are limited to 10L and suitable for nano fish under 8cm.';
        
      case 'cylinder':
        return '$fishName (max size: ${size}cm, min tank: ${tankVol}L) needs more space than this cylinder tank provides. Consider a larger tank or different fish.';
        
      case 'rectangle':
      default:
        return '$fishName (min tank: ${tankVol}L) needs a larger tank than ${volume.toStringAsFixed(1)}L. Consider increasing tank size or choosing smaller fish.';
    }
  }

  List<String> _getFilteredFish(String cardId) {
    final query = _searchQueries[cardId] ?? '';
    if (query.isEmpty) {
      return _availableFish;
    }
    return _availableFish.where((fish) =>
        fish.toLowerCase().contains(query.toLowerCase())).toList();
  }

  double _getCurrentVolume() {
    return _calculateVolume();
  }

  Widget _buildVolumeDisplay() {
    final volume = _getCurrentVolume();
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE0F7FA),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF00BCD4).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.water_drop,
            color: Color(0xFF00BCD4),
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            'Calculated Volume: ',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF006064),
            ),
          ),
          Text(
            volume > 0 ? '${volume.toStringAsFixed(2)} L' : 'Enter dimensions',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: volume > 0 ? const Color(0xFF00BCD4) : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }


  Future<void> _calculateRequirements() async {
    if (_fishSelections.isEmpty) {
      showCustomNotification(
        context,
        'Please add at least one fish',
        isError: true,
      );
      return;
    }

    final volume = _calculateVolume();
    // Skip volume validation for bowl tanks since they're hardcoded to 10L
    if (volume <= 0 && _selectedTankShape != 'bowl') {
      showCustomNotification(
        context,
        'Please enter valid tank dimensions',
        isError: true,
      );
      return;
    }

    setState(() => _isCalculating = true);
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

      // Check fish-to-fish compatibility if we have multiple fish
      if (_fishSelections.length >= 2) {
        print('Checking fish-to-fish compatibility for ${_fishSelections.length} fish species');
        
        // Expand fish selections to individual fish names for compatibility check
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
          body: json.encode({'fish_names': expandedFishNames}),
        ).timeout(ApiConfig.timeout);

        print('Compatibility check completed successfully');
        final compatibilityData = json.decode(compatibilityResponse.body);
        print('Compatibility results: ${compatibilityData['results']?.length ?? 0} pairs checked');
        bool hasIncompatiblePairs = false;
        bool hasConditionalPairs = false;
        final List<Map<String, dynamic>> incompatiblePairs = [];
        final List<Map<String, dynamic>> conditionalPairs = [];

        if (compatibilityData['results'] != null) {
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
            };
            _isCalculating = false;
          });
          return;
        }
        
        // Store conditional pairs for warning display but continue calculation
        if (hasConditionalPairs) {
          print('Found conditional compatibility issues, proceeding with warnings...');
          _conditionalCompatibilityPairs = conditionalPairs;
          print('Stored ${_conditionalCompatibilityPairs.length} conditional pairs');
        }
      }
      // Use local calculation logic with Supabase data
      print('Using local calculation logic with Supabase data for fish quantity recommendations');
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
          },
        });
      }
      
      setState(() {
        _calculationData = {
          'tank_details': {
            'volume': '${volume.toStringAsFixed(1)} L',
            'status': 'Optimal',
          },
          'fish_details': fishDetails,
          'fish_selections': _fishSelections,
          'recommended_quantities': recommendedQuantities,
        };
        // Add conditional compatibility warnings to results if they exist
        if (_conditionalCompatibilityPairs.isNotEmpty) {
          _calculationData!['conditional_compatibility_warnings'] = _conditionalCompatibilityPairs;
          print('Added ${_conditionalCompatibilityPairs.length} conditional pairs to calculation data');
        } else {
          print('No conditional pairs to add to calculation data');
        }
        _isCalculating = false;
      });
      
    } catch (e) {
      print('Error calculating capacity: $e');
      showCustomNotification(
        context,
        'Error calculating capacity. Please try again.',
        isError: true,
      );
      setState(() {
        _calculationData = null;
      });
    } finally {
      setState(() => _isCalculating = false);
    }
  }

  Future<void> _saveCalculation() async {
    if (_calculationData == null) {
      print('No calculation data to save');
      showCustomNotification(
        context,
        'No calculation data to save',
        isError: true,
      );
      return;
    }

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

    try {
      print('Saving calculation with data: $_calculationData');
      
      // Extract recommended quantities from fish details
      Map<String, int> recommendedQuantities = {};
      if (_calculationData!.containsKey('fish_details')) {
        for (var fish in _calculationData!['fish_details']) {
          final name = fish['name'] as String;
          final recommended = fish['recommended_quantity'];
          if (recommended != null && recommended != "N/A") {
            // Handle case where recommended is a String instead of int
            if (recommended is int) {
              recommendedQuantities[name] = recommended;
            } else if (recommended is String) {
              recommendedQuantities[name] = int.tryParse(recommended) ?? 1;
            }
          }
        }
      }

      final tankVolume = _calculateVolume().toStringAsFixed(1) + " L";
      final waterConditions = _calculationData!['water_conditions'] ?? {};
      final tankDetails = _calculationData!['tank_details'] ?? {};
      
      // Check if there are compatibility issues (only block on truly incompatible pairs)
      final compatibilityIssues = _calculationData!['compatibility_issues'] as List?;
      if (compatibilityIssues != null && compatibilityIssues.isNotEmpty) {
        // Check if any issues are truly incompatible (not conditional)
        bool hasIncompatibleIssues = compatibilityIssues.any((issue) {
          // If the issue doesn't specify it's conditional, treat as incompatible
          return issue['type'] != 'conditional';
        });
        
        if (hasIncompatibleIssues) {
          showCustomNotification(
            context,
            'Cannot save: Fish are not compatible with each other',
            isError: true,
          );
          return;
        }
      }
      
      // Get tankmate recommendations
      final tankmateData = await _getGroupedTankmateRecommendations();
      final allTankmates = <String>[
        ...(tankmateData['fully_compatible'] ?? []),
        ...(tankmateData['conditional'] ?? []),
      ];

      // Get feeding information
      final feedingInfo = await _getFeedingInformation();

      final calculation = FishCalculation(
        tankVolume: tankVolume,
        fishSelections: Map<String, int>.from(_fishSelections),
        recommendedQuantities: recommendedQuantities,
        dateCalculated: DateTime.now(),
        phRange: waterConditions['pH_range'] ?? "6.0 - 7.0",
        temperatureRange: waterConditions['temperature_range'] ?? "22°C - 26°C",
        tankStatus: tankDetails['status'] ?? "Unknown",
        currentBioload: tankDetails['current_bioload'] ?? "0%",
        waterParametersResponse: null,
        tankAnalysisResponse: null,
        filtrationResponse: null,
        dietCareResponse: null,
        tankmateRecommendations: allTankmates,
        feedingInformation: feedingInfo,
      );

      final logBookProvider = Provider.of<LogBookProvider>(context, listen: false);
      logBookProvider.addFishCalculation(calculation);

      showCustomNotification(context, 'Fish calculation saved to history');
      
      // Clear all inputs and reset state
      setState(() {
        _selectedFish1 = null;
        _selectedFish2 = null;
        _fishController1.clear();
        _fishController2.clear();
        _fishSelections = {};
        _calculationData = null;
        _showDropdown.clear();
        _searchQueries.clear();
        _fishTankShapeWarnings.clear();
        _conditionalCompatibilityPairs.clear();
        // Clear dimension inputs
        _depthController.clear();
        _widthController.clear();
        _lengthController.clear();
      });
    } catch (e) {
      print('Error saving calculation: $e');
      showCustomNotification(
        context,
        'Error saving calculation: ${e.toString()}',
        isError: true,
      );
    }
  }

  Widget _buildFishInput() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
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
                      child: Column(
                        children: [
                          Row(
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
                                if (_selectedFish1 == entry.key) {
                                  _selectedFish1 = null;
                                } else if (_selectedFish2 == entry.key) {
                                  _selectedFish2 = null;
                                }
                                _fishSelections.remove(entry.key);
                                    _fishTankShapeWarnings.remove(entry.key);
                              });
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            iconSize: 20,
                          ),
                            ],
                          ),
                          // Tank size warning for this fish
                          if (_fishTankShapeWarnings.containsKey(entry.key)) ...[
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.orange.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.warning_amber_rounded,
                                    color: Colors.orange.shade700,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _fishTankShapeWarnings[entry.key]!,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.orange.shade700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
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
                      return _availableFish.where((String fish) =>
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
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF006064),
                  Color(0xFF00ACC1),
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
            child: Stack(
              children: [
                Positioned(
                  right: -20,
                  bottom: -20,
                  child: Icon(
                    Icons.water,
                    size: 100,
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tank Volume',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_calculateVolume().toStringAsFixed(1)} L',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Tank shape information
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.white.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                              Icons.crop_square,
                                color: Colors.white70,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                              '${_getShapeLabel(_selectedTankShape)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white70,
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
          
          const SizedBox(height: 20),
          // Water Parameters Card
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
          ),
          // Conditional Compatibility Warnings (if any)
          if (_calculationData != null && _calculationData!['conditional_compatibility_warnings'] != null)
            _buildConditionalCompatibilityWarning(),
          const SizedBox(height: 20),
          // Water Parameters Card
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
                            'Water Parameters',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF006064),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      FutureBuilder<Map<String, dynamic>>(
                        future: _getWaterRequirements(),
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
                                  'Loading water requirements...',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF006064),
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            );
                          } else if (snapshot.hasData) {
                            final waterData = snapshot.data!;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildInfoRow('Temperature', waterData['temperature'] ?? '22-26°C'),
                                  const SizedBox(height: 8),
                                _buildInfoRow('pH Range', waterData['ph'] ?? '6.5-7.5'),
                                const SizedBox(height: 8),
                              ],
                            );
                          } else {
                            return const Text(
                              'Maintain temperature 24-26°C, pH 6.5-7.5, ammonia/nitrite 0ppm, nitrate <20ppm. Test weekly, change 25% water bi-weekly.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                                height: 1.5,
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Tankmate Recommendations Card
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
                // Collapsible header
                InkWell(
                  onTap: () {
                    setState(() {
                      _isTankmatesExpanded = !_isTankmatesExpanded;
                    });
                  },
                  child: Padding(
                  padding: const EdgeInsets.all(20),
                    child: Row(
                        children: [
                          Container(
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
                          const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Tankmate Recommendations',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF006064),
                            ),
                          ),
                        ),
                        Icon(
                          _isTankmatesExpanded ? Icons.expand_less : Icons.expand_more,
                          color: const Color(0xFF006064),
                          size: 24,
                          ),
                        ],
                      ),
                  ),
                ),
                // Collapsible content
                if (_isTankmatesExpanded) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Divider(height: 1, color: Colors.grey),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                          } else if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                            final groupedRecommendations = snapshot.data!;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (groupedRecommendations['fully_compatible']?.isNotEmpty == true) ...[
                                  _buildTankmateSection(
                                    'Fully Compatible',
                                    groupedRecommendations['fully_compatible']!,
                                    Icons.check_circle,
                                    const Color(0xFF4CAF50),
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                if (groupedRecommendations['conditional']?.isNotEmpty == true) ...[
                                  _buildTankmateSection(
                                    'Conditionally Compatible',
                                    groupedRecommendations['conditional']!,
                                    Icons.warning,
                                    const Color(0xFFFF9800),
                                  ),
                                ],
                              ],
                            );
                          } else {
                            return const Text(
                              'Consider peaceful community fish like tetras, rasboras, or corydoras.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                                height: 1.5,
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Feeding Information Card (Collapsible)
          if (_fishSelections.isNotEmpty)
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
                      final fishInfo = _fishData.firstWhere(
                        (fish) => fish['common_name']?.toString().toLowerCase() == fishName.toLowerCase(),
                        orElse: () => {},
                      );
                      
                      if (fishInfo.isEmpty) return const SizedBox.shrink();
                      
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
                            if (fishInfo['portion_grams'] != null && fishInfo['portion_grams'].toString().isNotEmpty) ...[
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
                                          _getPortionDisplay(fishName, fishInfo['portion_grams']),
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
                            if (fishInfo['preferred_food'] != null && fishInfo['preferred_food'].toString().isNotEmpty) ...[
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
                                          fishInfo['preferred_food'].toString(),
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
                            if (fishInfo['feeding_notes'] != null && fishInfo['feeding_notes'].toString().isNotEmpty) ...[
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
                                          fishInfo['feeding_notes'].toString(),
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
                            if (fishInfo['overfeeding_risks'] != null && fishInfo['overfeeding_risks'].toString().isNotEmpty) ...[
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
                                          fishInfo['overfeeding_risks'].toString(),
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
                            if ((fishInfo['portion_grams'] == null || fishInfo['portion_grams'].toString().isEmpty) &&
                                (fishInfo['preferred_food'] == null || fishInfo['preferred_food'].toString().isEmpty) &&
                                (fishInfo['feeding_notes'] == null || fishInfo['feeding_notes'].toString().isEmpty) &&
                                (fishInfo['overfeeding_risks'] == null || fishInfo['overfeeding_risks'].toString().isEmpty))
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

  // AI rationale card removed entirely


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

  Widget _buildConditionalCompatibilityWarning() {
    final conditionalPairs = _calculationData!['conditional_compatibility_warnings'] as List<Map<String, dynamic>>? ?? [];
    print('Building conditional compatibility warning with ${conditionalPairs.length} pairs');
    
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
                      hasIncompatible ? Icons.warning_rounded : Icons.warning,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasIncompatible ? 'Incompatible Fish Combinations' : 'Conditional Fish Compatibility',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          hasIncompatible 
                            ? 'Selected fish cannot coexist safely'
                            : 'Selected fish need special attention and monitoring',
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
          // Action Button
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
    final fishPair = pair['pair'] as List;
    final reasons = pair['reasons'] as List;
    final color = isIncompatible ? const Color(0xFFFF6B6B) : const Color(0xFFFF9800);

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
                  isIncompatible ? Icons.cancel : Icons.warning,
                  color: color,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${fishPair[0]} + ${fishPair[1]}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: color.withOpacity(0.3)),
                  ),
                  child: Text(
                    isIncompatible ? 'Incompatible' : 'Conditional',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Reasons
            ...reasons.map((reason) => Padding(
              padding: const EdgeInsets.only(left: 32, bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: color,
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
                      ..._fishSelections.entries.map((entry) => Padding(
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
                      )).toList(),
                    ],
                  ),
                ),
                if (_calculationData != null && _calculationData!['compatibility_issues'] != null && (_calculationData!['compatibility_issues'] as List).isNotEmpty)
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
                  onPressed: _clearFishInputs,
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




  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Colors.white,
        child: Stack(
          children: [
            if (_isCalculating)
              Container(
                width: double.infinity,
                height: double.infinity,
                color: Colors.white,
                child: const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF00BCD4),
                  ),
                ),
              )
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
                                  if (_selectedTankShape != 'bowl') _buildDimensionsInput(),
                                  _buildFishInput(),
                                ],
                              )
                            else if (_calculationData!['tank_shape_issues'] != null)
                              _buildTankShapeIncompatibilityResults(_calculationData!)
                            else if (_calculationData!['incompatible_pairs'] != null)
                              _buildCompatibilityResults(_calculationData!)
                            else if (_calculationData!['compatibility_issues'] != null && (_calculationData!['compatibility_issues'] as List).isNotEmpty)
                              // Check if there are truly incompatible issues (not conditional)
                              _calculationData!['compatibility_issues'].any((issue) => issue['type'] != 'conditional') 
                                ? _buildIncompatibilityResult()
                                : _buildResultDisplay()
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
                    else if (_calculationData != null && !_calculationData!.containsKey('tank_shape_issues') && !_calculationData!.containsKey('incompatible_pairs'))
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () {
                                  setState(() {
                                    _clearFishInputs();
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

  Widget _buildDimensionsInput() {
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
                Row(
                  children: [
                    const Icon(
                      FontAwesomeIcons.ruler,
                color: Color(0xFF00BCD4),
                size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Tank Dimensions',
                      style: TextStyle(
                        fontSize: 16,
                  fontWeight: FontWeight.w600,
                        color: Color(0xFF006064),
                      ),
                    ),
              const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: DropdownButton<String>(
                    value: _selectedUnit,
                    items: ['CM', 'IN'].map((String unit) {
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
          const SizedBox(height: 12),
          _buildShapeSpecificInputs(),
        ],
      ),
    );
  }

  double _calculateVolume() {
    // For bowl tanks, hardcode to 10L
    if (_selectedTankShape == 'bowl') {
      return 10.0;
    }

    final depthInput = double.tryParse(_depthController.text) ?? 0;
    final widthInput = double.tryParse(_widthController.text) ?? 0;
    final lengthInput = double.tryParse(_lengthController.text) ?? 0;

    // Normalize all linear dimensions to centimeters
    final depthCm = _toCentimeters(depthInput);
    final widthCm = _toCentimeters(widthInput);
    final lengthCm = _toCentimeters(lengthInput);

    double volumeLiters;
    
    // Calculate volume based on tank shape (using cm for geometry)
    switch (_selectedTankShape) {
      case 'rectangle':
        volumeLiters = _ccToLiters(depthCm * widthCm * lengthCm);
        break;
      case 'cylinder':
        // For cylinder: V = πr²h, using width as diameter, length as height
        final radius = (widthCm / 2.0);
        final height = lengthCm;
        final cc = 3.14159 * radius * radius * height;
        volumeLiters = _ccToLiters(cc);
        break;
      default:
        volumeLiters = _ccToLiters(depthCm * widthCm * lengthCm);
    }

    return volumeLiters;
  }

  // --- Unit helpers: normalize to cm and liters ---
  double _toCentimeters(double value) {
    if (_selectedUnit == 'CM') return value;
    // inches to centimeters
    return value * 2.54;
  }

  double _ccToLiters(double cubicCentimeters) {
    return cubicCentimeters / 1000.0;
  }


  Future<Map<String, dynamic>?> _validateTankShapeCompatibility() async {
    try {
      print('Validating tank shape compatibility for: $_selectedTankShape');
      
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

      // Check each selected fish against tank shape
      for (var fishName in _fishSelections.keys) {
        final fishData = fishList.firstWhere(
          (fish) => fish['common_name']?.toString().toLowerCase() == fishName.toLowerCase(),
          orElse: () => null,
        );

        if (fishData != null) {
          final maxSize = fishData['max_size'];
          final minTankSize = fishData['minimum_tank_size_l'];
          
          if (_isFishIncompatibleWithTankShape(fishName, maxSize, minTankSize, _selectedTankShape)) {
            incompatibleFish.add({
              'fish_name': fishName,
              'max_size': maxSize,
              'min_tank_size': minTankSize,
              'reason': _getTankShapeIncompatibilityReason(fishName, maxSize, minTankSize, _selectedTankShape, _calculateVolume()),
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

  bool _isFishIncompatibleWithTankShape(String fishName, dynamic maxSize, dynamic minTankSize, String tankShape) {
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

    switch (tankShape) {
      case 'bowl':
        // BEGINNER: Bowl tanks (2-20L) - Only for nano fish
        return (fishMaxSize != null && fishMaxSize > 8) || 
               (fishMinTankSize != null && fishMinTankSize > 20);
               
      case 'cylinder':
        // HOBBYIST: Cylinder tanks (20-200L) - Limited horizontal swimming space
        return (fishMaxSize != null && fishMaxSize > 20) || 
               (fishMinTankSize != null && fishMinTankSize > 200);
               
               
      case 'rectangle':
      default:
        // MONSTER KEEPERS: Rectangle tanks (20L-2000L+) - Most versatile for all sizes
        return false;
    }
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
      onTap: () {
        setState(() {
          _selectedTankShape = value;
          // Clear input fields when changing tank shape for clarity
          _lengthController.clear();
          _widthController.clear();
          _depthController.clear();
        });
        
        // Check compatibility for all selected fish when tank shape changes
        for (String fishName in _fishSelections.keys) {
          _checkFishTankShapeCompatibility(fishName);
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


  Widget _buildShapeSpecificInputs() {
    switch (_selectedTankShape) {
      case 'rectangle':
        return Column(
          children: [
                TextField(
                  controller: _lengthController,
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    setState(() {
                      // Trigger rebuild to update volume display
                    });
                    
                    // Check compatibility for all selected fish when dimensions change
                    for (String fishName in _fishSelections.keys) {
                      _checkFishTankShapeCompatibility(fishName);
                    }
                  },
                  decoration: InputDecoration(
                labelText: 'Length (longest side)',
                    hintText: 'Enter length',
                    filled: true,
                fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Color(0xFF00BCD4)),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _widthController,
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    setState(() {
                      // Trigger rebuild to update volume display
                    });
                    
                    // Check compatibility for all selected fish when dimensions change
                    for (String fishName in _fishSelections.keys) {
                      _checkFishTankShapeCompatibility(fishName);
                    }
                  },
                  decoration: InputDecoration(
                labelText: 'Width',
                    hintText: 'Enter width',
                    filled: true,
                fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Color(0xFF00BCD4)),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _depthController,
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    setState(() {
                      // Trigger rebuild to update volume display
                    });
                    
                    // Check compatibility for all selected fish when dimensions change
                    for (String fishName in _fishSelections.keys) {
                      _checkFishTankShapeCompatibility(fishName);
                    }
                  },
                  decoration: InputDecoration(
                labelText: 'Height',
                hintText: 'Enter height',
                    filled: true,
                fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Color(0xFF00BCD4)),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
                _buildVolumeDisplay(),
              ],
        );


      case 'bowl':
        return Column(
          children: [
            // Fixed volume display for bowl tanks
            Container(
              margin: const EdgeInsets.only(top: 12),
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
            ),
          ],
        );

      case 'cylinder':
        return Column(
          children: [
            TextField(
              controller: _widthController,
              keyboardType: TextInputType.number,
              onChanged: (value) {
                setState(() {
                  // Trigger rebuild to update volume display
                });
                
                // Check compatibility for all selected fish when dimensions change
                for (String fishName in _fishSelections.keys) {
                  _checkFishTankShapeCompatibility(fishName);
                }
              },
              decoration: InputDecoration(
                labelText: 'Diameter',
                hintText: 'Enter cylinder diameter',
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Color(0xFF00BCD4)),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _lengthController,
              keyboardType: TextInputType.number,
              onChanged: (value) {
                setState(() {
                  // Trigger rebuild to update volume display
                });
                
                // Check compatibility for all selected fish when dimensions change
                for (String fishName in _fishSelections.keys) {
                  _checkFishTankShapeCompatibility(fishName);
                }
              },
              decoration: InputDecoration(
                labelText: 'Height',
                hintText: 'Enter cylinder height',
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Color(0xFF00BCD4)),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
            _buildVolumeDisplay(),
          ],
        );

      default:
        return Column(
          children: [
            TextField(
              controller: _lengthController,
              keyboardType: TextInputType.number,
              onChanged: (value) {
                setState(() {
                  // Trigger rebuild to update volume display
                });
              },
              decoration: InputDecoration(
                labelText: 'Length',
                hintText: 'Enter length',
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Color(0xFF00BCD4)),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _widthController,
              keyboardType: TextInputType.number,
              onChanged: (value) {
                setState(() {
                  // Trigger rebuild to update volume display
                });
              },
              decoration: InputDecoration(
                labelText: 'Width',
                hintText: 'Enter width',
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Color(0xFF00BCD4)),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _depthController,
              keyboardType: TextInputType.number,
              onChanged: (value) {
                setState(() {
                  // Trigger rebuild to update volume display
                });
              },
              decoration: InputDecoration(
                labelText: 'Height',
                hintText: 'Enter height',
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Color(0xFF00BCD4)),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
            _buildVolumeDisplay(),
          ],
        );
    }
  }
} 