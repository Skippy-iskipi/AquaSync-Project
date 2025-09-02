import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/api_config.dart';
import '../widgets/custom_notification.dart';
import '../screens/logbook_provider.dart';
import '../services/openai_service.dart'; // OpenAI AI service
import '../models/diet_calculation.dart';
import 'dart:async';
import '../widgets/expandable_reason.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:lottie/lottie.dart';
import '../widgets/auth_required_dialog.dart';

class DietFishCard {
  final TextEditingController fishController;
  final TextEditingController quantityController;
  final FocusNode fishFocusNode;
  final FocusNode quantityFocusNode;
  final int id;

  DietFishCard({
    required this.id,
  }) : fishController = TextEditingController(),
       quantityController = TextEditingController(),
       fishFocusNode = FocusNode(),
       quantityFocusNode = FocusNode();

  void dispose() {
    fishController.dispose();
    quantityController.dispose();
    fishFocusNode.dispose();
    quantityFocusNode.dispose();
  }
}


class DietCalculator extends StatefulWidget {
  const DietCalculator({super.key});

  @override
  _DietCalculatorState createState() => _DietCalculatorState();
}

class _DietCalculatorState extends State<DietCalculator> with SingleTickerProviderStateMixin {
  List<DietFishCard> _fishCards = [];
  final Map<String, int> _fishSelections = {};
  List<String> _availableFish = [];
  bool _isLoading = false;
  bool _isCalculating = false; // only for diet calculation overlay
  Map<String, dynamic>? _calculationResult;
  bool _hasCompatibilityIssue = false;
  String _compatibilityReason = '';
  List<Map<String, dynamic>>? _incompatiblePairs;
  bool _isSaving = false; // disable save button while saving
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _addFishCard(); // Add initial card
    _loadFishData();
  }

  @override
  void dispose() {
    for (var card in _fishCards) {
      card.dispose();
    }
    _tabController.dispose();
    super.dispose();
  }

  void _addFishCard() {
    setState(() {
      _fishCards.add(DietFishCard(id: _fishCards.length));
    });
  }

  void _removeFishCard(int id) {
    setState(() {
      // Find the card index
      final index = _fishCards.indexWhere((card) => card.id == id);
      if (index != -1) {
        // Get the fish name before removing
        final fishName = _fishCards[index].fishController.text;
        
        // Remove from selections if it exists
        if (fishName.isNotEmpty) {
          _fishSelections.remove(fishName);
        }

        // Dispose and remove the card
        _fishCards[index].dispose();
        _fishCards.removeAt(index);
      }
    });
  }

  void _addFish(String fishName, int index) {
    if (fishName.isEmpty) return;
    setState(() {
      _fishSelections[fishName] = (_fishSelections[fishName] ?? 0) + 1;
      print("Added fish: $fishName, count: ${_fishSelections[fishName]}");
    });
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
    Map<String, int> fishSelections = {};
    
    // Validate that each visible card has a fish name
    for (final card in _fishCards) {
      final fishName = card.fishController.text.trim();
      if (fishName.isEmpty) {
        _showNotification('Please fill in all fish names', isError: true);
        return;
      }
    }
    
    // Build selections from current cards using shared quantities map
    final Set<String> fishNamesOnCards = _fishCards
        .map((card) => card.fishController.text.trim())
        .where((name) => name.isNotEmpty)
        .toSet();
        
    for (final name in fishNamesOnCards) {
      final qty = _fishSelections[name] ?? 0;
      if (qty <= 0) {
        _showNotification('Please set a valid quantity for $name (greater than 0).', isError: true);
        return;
      }
      fishSelections[name] = qty;
    }
    
    if (fishSelections.isEmpty) {
      _showNotification('Please add at least one fish.', isError: true);
      return;
    }

    setState(() {
      _isLoading = true; // still used to disable buttons
      _isCalculating = true; // drives the Lottie overlay
      _calculationResult = null;
      _hasCompatibilityIssue = false;
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
                final detailed = await OpenAIService.explainIncompatibilityReasons(
                  pair[0].toString(),
                  pair[1].toString(),
                  reasons,
                );
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
            _hasCompatibilityIssue = true;
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
      final Map<String, Map<String, int>> tankTotalsByFoodType = {};
      
      // Generate AI-based diet recommendations for the entire tank
      final dietRecommendations = await _generateAIDietRecommendations(fishSelections);
      
      if (dietRecommendations.containsKey('error')) {
        throw Exception('Failed to generate AI diet recommendations');
      }
      
      // Process AI-generated food types and portions
      final aiFoodTypes = dietRecommendations['food_types'] as List<String>? ?? [];
      final aiFeedingSchedule = dietRecommendations['feeding_schedule'] as Map<String, dynamic>? ?? {};
      final aiFeedingNotes = dietRecommendations['feeding_notes'] as String? ?? '';
      
      // Generate portion data for each fish type using AI
      for (String fishName in fishSelections.keys) {
        final quantity = fishSelections[fishName]!;
        
        // Get AI-generated portion recommendation for this specific fish
        final fishPortionData = await _generateFishPortionRecommendation(fishName, quantity, aiFoodTypes);
        
        if (fishPortionData.containsKey('error')) {
          throw Exception('Failed to get portion data for $fishName');
        }
        
        final portionSize = fishPortionData['portion_size'] as String;
        final foodType = fishPortionData['food_type'] as String;
        final (low, high) = _extractPortionRange(portionSize);
        final fishLow = low * quantity;
        final fishHigh = high * quantity;
        
        // Store fish-specific portion info
        fishPortions[fishName] = {
          'per_fish': portionSize,
          'quantity': quantity,
          'total_low': fishLow,
          'total_high': fishHigh,
          'food_type': foodType,
        };
        
        // Accumulate tank totals by food type
        if (!tankTotalsByFoodType.containsKey(foodType)) {
          tankTotalsByFoodType[foodType] = {'low': fishLow, 'high': fishHigh};
        } else {
          final current = tankTotalsByFoodType[foodType]!;
          tankTotalsByFoodType[foodType] = {
            'low': (current['low'] ?? 0) + fishLow, 
            'high': (current['high'] ?? 0) + fishHigh
          };
        }
      }
      
      // Build clear, user-friendly tank totals
      final List<String> tankTotalStrings = tankTotalsByFoodType.entries.map((e) {
        final foodType = e.key;
        final range = e.value;
        final low = range['low'] ?? 0;
        final high = range['high'] ?? 0;
        // If low and high are the same, show just one number to avoid "4-4 pellets"
        final rangeStr = low == high ? '$low' : '$low–$high';
        return '$rangeStr $foodType';
      }).toList();

      // Generate AI feeding tips
      final aiFeedingTips = await _generateAIFeedingTips(fishSelections.keys.toList());
      
      final result = {
        'fish_portions': fishPortions,
        'tank_totals_by_food': tankTotalsByFoodType,
        'tank_total_display': tankTotalStrings.join('; '),
        'total_portion': tankTotalsByFoodType.values.fold<int>(0, (sum, range) => sum + (range['low'] ?? 0)),
        'total_portion_range': tankTotalStrings.join('; '),
        'feedings_per_day': aiFeedingSchedule['frequency'] ?? 2,
        'feeding_times': aiFeedingSchedule['times'] ?? 'Morning and evening',
        'feeding_notes': aiFeedingNotes,
        'feeding_tips': aiFeedingTips,
        'ai_food_types': aiFoodTypes,
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
      });
      _showNotification('Error calculating diet portions: $e', isError: true);
    }
  }
  
  int _extractNumericPortion(String portionText) {
    // Prefer lower bound when a range is provided (e.g., '2-3 pellets').
    final text = portionText.toLowerCase();
    final rangeMatch = RegExp(r'(\d+)\s*[-–]\s*(\d+)').firstMatch(text);
    if (rangeMatch != null) {
      final low = int.tryParse(rangeMatch.group(1)!) ?? 2;
      // final high = int.tryParse(rangeMatch.group(2)!) ?? low; // kept for possible future average logic
      return low; // safer lower bound to avoid overfeeding
    }
    final singleMatch = RegExp(r'(\d+)').firstMatch(text);
    if (singleMatch != null) {
      return int.tryParse(singleMatch.group(1)!) ?? 2;
    }
    return 2; // Default portion size
  }

  // Extract a portion range (low, high) from a text like '2-3 small pellets'.
  // If only a single value exists, returns (n, n).
  (int low, int high) _extractPortionRange(String portionText) {
    final text = portionText.toLowerCase();
    final rangeMatch = RegExp(r'(\d+)\s*[-–]\s*(\d+)').firstMatch(text);
    if (rangeMatch != null) {
      final low = int.tryParse(rangeMatch.group(1)!) ?? 2;
      final high = int.tryParse(rangeMatch.group(2)!) ?? low;
      // If low and high are the same, return just one value to avoid "4-4 pellets"
      if (low == high) return (low, low);
      if (high < low) return (low, low);
      return (low, high);
    }
    final singleMatch = RegExp(r'(\d+)').firstMatch(text);
    if (singleMatch != null) {
      final n = int.tryParse(singleMatch.group(1)!) ?? 2;
      return (n, n);
    }
    return (2, 2);
  }

  // Clean and format portion text for display
  String _formatPortionForDisplay(String portionText) {
    final text = portionText.toLowerCase();
    
    // Handle ranges like "2-3 small pellets"
    final rangeMatch = RegExp(r'(\d+)\s*[-–]\s*(\d+)').firstMatch(text);
    if (rangeMatch != null) {
      final low = int.tryParse(rangeMatch.group(1)!) ?? 2;
      final high = int.tryParse(rangeMatch.group(2)!) ?? low;
      if (high < low) return '${low} ${_extractFoodTypeFromText(text)}';
      return '${low}-${high} ${_extractFoodTypeFromText(text)}';
    }
    
    // Handle single numbers like "2 small pellets"
    final singleMatch = RegExp(r'(\d+)').firstMatch(text);
    if (singleMatch != null) {
      final n = int.tryParse(singleMatch.group(1)!) ?? 2;
      return '${n} ${_extractFoodTypeFromText(text)}';
    }
    
    return '2 ${_extractFoodTypeFromText(text)}';
  }

  // Extract food type from portion text
  String _extractFoodTypeFromText(String text) {
    if (text.contains('pellet')) return 'pellets';
    if (text.contains('flake')) return 'flakes';
    if (text.contains('algae wafer') || text.contains('wafer')) return 'algae wafers';
    if (text.contains('bloodworm')) return 'bloodworms';
    if (text.contains('brine shrimp')) return 'brine shrimp';
    if (text.contains('daphnia')) return 'daphnia';
    if (text.contains('pea')) return 'cooked peas';
    if (text.contains('micropellet')) return 'micro-pellets';
    if (text.contains('mini pellet')) return 'mini pellets';
    return 'fish food';
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

  // Validate and normalize portion text to ensure reasonable values
  String _validateAndNormalizePortion(String portionText) {
    final text = portionText.toLowerCase().trim();
    
    // Extract numeric values
    final rangeMatch = RegExp(r'(\d+)\s*[-–]\s*(\d+)').firstMatch(text);
    if (rangeMatch != null) {
      final low = int.tryParse(rangeMatch.group(1)!) ?? 2;
      final high = int.tryParse(rangeMatch.group(2)!) ?? low;
      
      // Validate reasonable portion sizes
      final validatedLow = low.clamp(1, 10);
      final validatedHigh = high.clamp(validatedLow, 15);
      
      // Reconstruct the portion text with validated values
      final baseText = text.replaceAll(RegExp(r'\d+\s*[-–]\s*\d+'), '$validatedLow-$validatedHigh');
      return baseText;
    }
    
    final singleMatch = RegExp(r'(\d+)').firstMatch(text);
    if (singleMatch != null) {
      final value = int.tryParse(singleMatch.group(1)!) ?? 2;
      final validatedValue = value.clamp(1, 10);
      return text.replaceFirst(RegExp(r'\d+'), validatedValue.toString());
    }
    
    return '2-3 small pellets'; // Default fallback
  }

  // Extract food type from portion text
  String _extractFoodType(String portionText) {
    final text = portionText.toLowerCase();
    
    // Define common food types with their keywords
    final foodTypes = {
      'pellets': ['pellet', 'pellets', 'granule', 'granules', 'micro pellets', 'micropellets'],
      'flakes': ['flake', 'flakes', 'flake food'],
      'algae wafers': ['algae wafer', 'algae wafers', 'wafer', 'wafers'],
      'bloodworms': ['bloodworm', 'bloodworms'],
      'brine shrimp': ['brine shrimp', 'brine'],
      'daphnia': ['daphnia'],
      'tubifex': ['tubifex'],
      'cooked peas': ['cooked pea', 'cooked peas', 'pea', 'peas'],
      'frozen food': ['frozen', 'frozen food'],
      'live food': ['live', 'live food'],
      'vegetables': ['vegetable', 'vegetables', 'cucumber', 'zucchini'],
    };
    
    for (final entry in foodTypes.entries) {
      for (final keyword in entry.value) {
        if (text.contains(keyword)) {
          return entry.key;
        }
      }
    }
    
    // Try to extract more specific food type from the text
    if (text.contains('pinch')) {
      if (text.contains('flake')) return 'flakes';
      if (text.contains('pellet')) return 'pellets';
      return 'small food portions';
    }
    
    if (text.contains('tablet') || text.contains('wafer')) return 'algae wafers';
    if (text.contains('worm')) return 'bloodworms';
    if (text.contains('shrimp')) return 'brine shrimp';
    
    return 'fish food'; // More descriptive default fallback
  }

  // Clean up feeding notes to be more user-friendly
  String _cleanFeedingNotes(String notes) {
    if (notes.isEmpty) return notes;
    
    // Remove any heading like "Feeding Notes:" that the model might include
    var cleaned = notes
        .replaceFirst(RegExp(r'^\s*feeding\s*notes\s*:?', caseSensitive: false), '')
        .trim();
    
    // Split by newlines first; if none, split by sentence endings
    List<String> parts = cleaned.contains('\n')
        ? cleaned.split('\n')
        : cleaned.split(RegExp(r'(?<=[.!?])\s+'));
    
    final cleanedLines = parts
        .map((l) => l
            .replaceFirst(RegExp(r'^\s*(?:[-–•\u2022]|\d+[\.)])\s*'), '') // Remove bullets/numbering
            .trim())
        .where((l) => l.isNotEmpty)
        .where((l) => !RegExp(r'^feeding\s*frequency', caseSensitive: false).hasMatch(l))
        .where((l) => !RegExp(r'^food\s*removal', caseSensitive: false).hasMatch(l))
        .where((l) => !RegExp(r'^any\s*special\s*considerations', caseSensitive: false).hasMatch(l))
        .toList();
    
    if (cleanedLines.isNotEmpty) {
      return cleanedLines.join('\n');
    }
    
    return 'Feed 2-3 times daily in small amounts. Remove uneaten food after 5 minutes. Adjust portions based on fish activity and appetite.';
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


  // Infer a concise food label (e.g., 'pellets', 'flakes') from portion strings
  String _inferFoodLabel() {
    final map = _calculationResult?['fish_portions'] as Map<String, dynamic>?;
    if (map == null || map.isEmpty) return 'fish food';

    final foods = <String>{};
    for (final value in map.values) {
      final s = (value ?? '').toString().trim();
      if (s.isEmpty) continue;

      // Handle patterns like: '1 portion of pellets', '0.5 portion of flakes per day'
      final match = RegExp(r'\bof\s+([a-zA-Z ]+?)(?:\s*(?:per\s*day|/day|daily|\.|,|$))', caseSensitive: false)
          .firstMatch(s);
      if (match != null) {
        var label = match.group(1)!.trim();
        label = label.toLowerCase();
        // Remove generic words
        label = label.replaceAll(RegExp(r'\b(food|feeds?)\b'), '').trim();
        if (label.isNotEmpty) foods.add(label);
      }
      
      // Also check for food types in the per_fish field
      if (value is Map<String, dynamic> && value.containsKey('per_fish')) {
        final perFishText = (value['per_fish'] ?? '').toString().toLowerCase();
        if (perFishText.contains('pellet')) foods.add('pellets');
        if (perFishText.contains('flake')) foods.add('flakes');
        if (perFishText.contains('algae wafer') || perFishText.contains('wafer')) foods.add('algae wafers');
        if (perFishText.contains('bloodworm')) foods.add('bloodworms');
        if (perFishText.contains('brine shrimp')) foods.add('brine shrimp');
        if (perFishText.contains('daphnia')) foods.add('daphnia');
        if (perFishText.contains('pea')) foods.add('cooked peas');
      }
    }

    if (foods.isEmpty) return 'fish food';
    if (foods.length == 1) return foods.first;
    return 'mixed fish food';
  }
  
  // Try to infer a more descriptive phrase, e.g., 'small pinch of flakes' or 'small algae wafers'
  String? _inferFoodDescriptor() {
    final map = _calculationResult?['fish_portions'] as Map<String, dynamic>?;
    if (map == null || map.isEmpty) return null;

    // Primary: match explicit 'of' patterns first
    final ofPatterns = <RegExp>[
      RegExp(r'\b(small|medium|large|tiny|big)\s+(pinch|spoon|cube|tablet|sheet)\s+of\s+([a-zA-Z ]+?)(?=\s*(?:per\s*day|/day|daily|\.|,|$))', caseSensitive: false),
      RegExp(r'\b(pinch|spoon|cube|tablet|sheet)\s+of\s+([a-zA-Z ]+?)(?=\s*(?:per\s*day|/day|daily|\.|,|$))', caseSensitive: false),
      RegExp(r'\(([^)]+)\)\s*of\s+([a-zA-Z ]+?)(?=\s*(?:per\s*day|/day|daily|\.|,|$))', caseSensitive: false),
      RegExp(r'\bof\s+([a-zA-Z ]+?)(?=\s*(?:per\s*day|/day|daily|\.|,|$))', caseSensitive: false),
    ];

    final descriptorWords = <String>{'small','medium','large','tiny','big'};
    final measureWords = <String>{'pinch','spoon','cube','tablet','sheet'};
    final foodKeywords = <String>{
      'flakes','flake food','pellet','pellets','sinking pellets','micro pellets','granules',
      'algae wafer','algae wafers','wafer','wafers','bloodworms','brine shrimp','daphnia','tubifex'
    };

    for (final raw in map.values) {
      final s = (raw ?? '').toString();
      final lower = s.toLowerCase();

      // 1) Try 'of' patterns
      for (final re in ofPatterns) {
        final m = re.firstMatch(s);
        if (m != null) {
          String phrase;
          if (re.pattern.contains('(small|medium|large|tiny|big)')) {
            phrase = '${m.group(1)!.toLowerCase()} ${m.group(2)!.toLowerCase()} of ${m.group(3)!.trim().toLowerCase()}';
          } else if (re.pattern.contains('(pinch|spoon|cube|tablet|sheet)')) {
            phrase = '${m.group(1)!.toLowerCase()} of ${m.group(2)!.trim().toLowerCase()}';
          } else if (re.pattern.contains('\\(([^)]+)\\)')) {
            phrase = '${m.group(1)!.toLowerCase()} of ${m.group(2)!.trim().toLowerCase()}';
          } else {
            phrase = m.group(1)!.trim().toLowerCase();
          }
          phrase = phrase.replaceAll(RegExp(r'\b(food|feeds?)\b', caseSensitive: false), '').trim();
          if (phrase.isNotEmpty) return phrase;
        }
      }

      // 2) Heuristic without 'of': find descriptor + measure + food keywords
      String? foundFood;
      for (final k in foodKeywords) {
        if (lower.contains(k)) {
          foundFood = k;
          break;
        }
      }
      if (foundFood != null) {
        String? foundDescriptor;
        for (final d in descriptorWords) {
          if (lower.contains(d)) { foundDescriptor = d; break; }
        }
        String? foundMeasure;
        for (final m in measureWords) {
          if (lower.contains(m)) { foundMeasure = m; break; }
        }
        String phrase;
        if (foundMeasure != null) {
          phrase = '${foundDescriptor != null ? '$foundDescriptor ' : ''}$foundMeasure of $foundFood';
        } else {
          phrase = '${foundDescriptor != null ? '$foundDescriptor ' : ''}$foundFood';
        }
        phrase = phrase.replaceAll(RegExp(r'\b(food|feeds?)\b', caseSensitive: false), '').trim();
        if (phrase.isNotEmpty) return phrase;
      }
    }

    // 3) Fallback: parse feeding_notes for a descriptor
    final notes = (_calculationResult?['feeding_notes'] as String?)?.toLowerCase() ?? '';
    if (notes.isNotEmpty) {
      // Try the same 'of' patterns on notes
      for (final re in ofPatterns) {
        final m = re.firstMatch(notes);
        if (m != null) {
          String phrase;
          if (re.pattern.contains('(small|medium|large|tiny|big)')) {
            phrase = '${m.group(1)!.toLowerCase()} ${m.group(2)!.toLowerCase()} of ${m.group(3)!.trim().toLowerCase()}';
          } else if (re.pattern.contains('(pinch|spoon|cube|tablet|sheet)')) {
            phrase = '${m.group(1)!.toLowerCase()} of ${m.group(2)!.trim().toLowerCase()}';
          } else if (re.pattern.contains('\\(([^)]+)\\)')) {
            phrase = '${m.group(1)!.toLowerCase()} of ${m.group(2)!.trim().toLowerCase()}';
          } else {
            phrase = m.group(1)!.trim().toLowerCase();
          }
          phrase = phrase.replaceAll(RegExp(r'\b(food|feeds?)\b', caseSensitive: false), '').trim();
          if (phrase.isNotEmpty) return phrase;
        }
      }
      // Heuristic on notes without 'of'
      String? foundFood;
      for (final k in foodKeywords) {
        if (notes.contains(k)) { foundFood = k; break; }
      }
      if (foundFood != null) {
        String? foundDescriptor;
        for (final d in descriptorWords) {
          if (notes.contains(d)) { foundDescriptor = d; break; }
        }
        String? foundMeasure;
        for (final m in measureWords) {
          if (notes.contains(m)) { foundMeasure = m; break; }
        }
        String phrase;
        if (foundMeasure != null) {
          phrase = '${foundDescriptor != null ? '$foundDescriptor ' : ''}$foundMeasure of $foundFood';
        } else {
          phrase = '${foundDescriptor != null ? '$foundDescriptor ' : ''}$foundFood';
        }
        phrase = phrase.replaceAll(RegExp(r'\b(food|feeds?)\b', caseSensitive: false), '').trim();
        if (phrase.isNotEmpty) return phrase;
      }
    }
    
    // 4) Last resort: derive from the first portion string by stripping counts and boilerplate
    for (final raw in map.values) {
      final s = (raw ?? '').toString().toLowerCase();
      if (s.isEmpty) continue;
      // Remove leading counts like '1 portion', '2 portions', '0.5 portion(s)'
      var cleaned = s
          .replaceAll(RegExp(r'^\s*\d+[\d\./\s]*\s*portion(?:s)?\s*(of)?\s*'), '')
          .replaceAll(RegExp(r'\b(grams?|g|ml|mg)\b'), '')
          .replaceAll(RegExp(r'\b(food|feeds?)\b', caseSensitive: false), '')
          .trim();
      // Truncate at end markers
      final endMatch = RegExp(r'(?=\s*(?:per\s*day|/day|daily|\.|,|$))').firstMatch(cleaned);
      if (endMatch != null) {
        cleaned = cleaned.substring(0, endMatch.start).trim();
      }
      if (cleaned.isNotEmpty) return cleaned;
    }
    return null;
  }

  // Create a concise phrase for a single portion value string
  String _concisePortionOption(String raw) {
    final s = (raw).toString();
    // Reuse patterns from _inferFoodDescriptor
    final ofPatterns = <RegExp>[
      RegExp(r'\b(small|medium|large|tiny|big)\s+(pinch|spoon|cube|tablet|sheet)\s+of\s+([a-zA-Z ]+?)(?=\s*(?:per\s*day|/day|daily|\.|,|$))', caseSensitive: false),
      RegExp(r'\b(pinch|spoon|cube|tablet|sheet)\s+of\s+([a-zA-Z ]+?)(?=\s*(?:per\s*day|/day|daily|\.|,|$))', caseSensitive: false),
      RegExp(r'\(([^)]+)\)\s*of\s+([a-zA-Z ]+?)(?=\s*(?:per\s*day|/day|daily|\.|,|$))', caseSensitive: false),
      RegExp(r'\bof\s+([a-zA-Z ]+?)(?=\s*(?:per\s*day|/day|daily|\.|,|$))', caseSensitive: false),
    ];
    for (final re in ofPatterns) {
      final m = re.firstMatch(s);
      if (m != null) {
        String phrase;
        if (re.pattern.contains('(small|medium|large|tiny|big)')) {
          phrase = '${m.group(1)!.toLowerCase()} ${m.group(2)!.toLowerCase()} of ${m.group(3)!.trim().toLowerCase()}';
        } else if (re.pattern.contains('(pinch|spoon|cube|tablet|sheet)')) {
          phrase = '${m.group(1)!.toLowerCase()} of ${m.group(2)!.trim().toLowerCase()}';
        } else if (re.pattern.contains('\\(([^)]+)\\)')) {
          phrase = '${m.group(1)!.toLowerCase()} of ${m.group(2)!.trim().toLowerCase()}';
        } else {
          phrase = m.group(1)!.trim().toLowerCase();
        }
        phrase = phrase.replaceAll(RegExp(r'\b(food|feeds?)\b', caseSensitive: false), '').trim();
        return phrase;
      }
    }
    // Last resort: strip counts/boilerplate
    var cleaned = s.toLowerCase();
    cleaned = cleaned
        .replaceAll(RegExp(r'^\s*\d+[\d\./\s]*\s*portion(?:s)?\s*(of)?\s*'), '')
        .replaceAll(RegExp(r'\b(grams?|g|ml|mg)\b'), '')
        .replaceAll(RegExp(r'\b(food|feeds?)\b', caseSensitive: false), '')
        .trim();
    cleaned = cleaned.replaceAll(RegExp(r'\s*(per\s*day|/day|daily)\s*$', caseSensitive: false), '').trim();
    return cleaned.isNotEmpty ? cleaned : 'recommended fish food';
  }

  List<String> _collectPerFeedingOptions() {
    final map = _calculationResult?['fish_portions'] as Map<String, dynamic>?;
    if (map == null || map.isEmpty) return [];
    final set = <String>{};
    for (final v in map.values) {
      final opt = _concisePortionOption((v ?? '').toString());
      if (opt.isNotEmpty) set.add(opt);
    }
    return set.toList();
  }

  Widget _buildPerFeedingOptions() {
    final options = _collectPerFeedingOptions();
    if (options.isEmpty) return const SizedBox.shrink();
    final display = options.take(3).toList();
    final title = options.length > 1
        ? 'Per feeding for the whole tank (choose one):'
        : 'Per feeding for the whole tank:';
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF006064),
            ),
          ),
          const SizedBox(height: 4),
          ...display.map((o) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(color: Color(0xFF006064))),
                    Expanded(
                      child: Text(
                        o,
                        style: const TextStyle(fontSize: 14, color: Color(0xFF004D40)),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // ===== Tank total helpers (inside _DietCalculatorState) =====
  Map<String, int> _getFishSelectionsFromCards() {
    final selections = <String, int>{};
    for (final card in _fishCards) {
      final name = card.fishController.text.trim();
      if (name.isEmpty) continue;
      final qtyText = card.quantityController.text.trim();
      final qty = int.tryParse(qtyText.isEmpty ? '1' : qtyText) ?? 1;
      selections[name] = (selections[name] ?? 0) + qty;
    }
    return selections;
  }

  ({int low, int high}) _parseCountRange(String text) {
    // The constructed portion text looks like:
    //   "<qty> × <perFishRange> = <speciesTotalRange> portions (<portionSize> each)"
    // We must parse the species total AFTER '=' to avoid double multiplying by quantity.
    final lower = text.toLowerCase();
    // 1) Prefer an explicit range immediately after '=' and before 'portions'
    final afterEqRange = RegExp(r"=\s*(\d+)\s*[-–]\s*(\d+)\s*portions").firstMatch(lower);
    if (afterEqRange != null) {
      final a = int.tryParse(afterEqRange.group(1)!) ?? 0;
      final b = int.tryParse(afterEqRange.group(2)!) ?? a;
      return (low: a, high: b);
    }
    // 2) Or a single number after '=' before 'portions'
    final afterEqSingle = RegExp(r"=\s*(\d+)\s*portions").firstMatch(lower);
    if (afterEqSingle != null) {
      final n = int.tryParse(afterEqSingle.group(1)!) ?? 0;
      return (low: n, high: n);
    }
    // 3) Fallback: restrict search to substring before 'portions' to avoid matching numbers in '(portionSize each)'
    final idx = lower.indexOf('portions');
    final head = idx > 0 ? lower.substring(0, idx) : lower;
    final ranges = RegExp(r"(\d+)\s*[-–]\s*(\d+)").allMatches(head).toList();
    if (ranges.isNotEmpty) {
      final m = ranges.last; // take the last range before 'portions'
      final a = int.tryParse(m.group(1)!) ?? 0;
      final b = int.tryParse(m.group(2)!) ?? a;
      return (low: a, high: b);
    }
    final singles = RegExp(r"(\d+)").allMatches(head).toList();
    if (singles.isNotEmpty) {
      final m = singles.last; // last number before 'portions'
      final n = int.tryParse(m.group(1)!) ?? 0;
      return (low: n, high: n);
    }
    return (low: 0, high: 0);
  }

  String _normalizeFoodLabelFromText(String text) {
    final t = text.toLowerCase();
    // Canonical mapping of synonyms -> label
    final List<(String label, List<String> synonyms)> canon = [
      (
        'micropellets',
        ['micropellets', 'micro pellets', 'micro-pellets']
      ),
      (
        'mini pellets',
        ['mini pellets']
      ),
      (
        'small pellets',
        ['small pellets', 'pellets']
      ),
      (
        'flakes',
        ['flake food', 'flakes']
      ),
      (
        'algae wafers',
        ['algae wafers', 'wafers']
      ),
      (
        'bloodworms',
        ['bloodworms']
      ),
      (
        'brine shrimp',
        ['brine shrimp']
      ),
      (
        'daphnia',
        ['daphnia']
      ),
      (
        'cooked peas',
        ['cooked peas', 'cooked pea', 'pea', 'peas']
      ),
    ];
    for (final entry in canon) {
      for (final s in entry.$2) {
        if (t.contains(s)) return entry.$1;
      }
    }
    // Fallback to inferred generic label
    return _inferFoodLabel() ?? 'fish food';
  }

  // Extract all species-total segments and their food labels from a constructed text like:
  //   "3 × 1-2 = 3-6 portions (small flakes each) OR 3 × 1-1 = 3 portions (brine shrimp each)"
  // Returns a list of entries with canonicalized labels and low/high counts per species.
  List<({String label, int low, int high})> _extractSpeciesTotalsWithLabels(String text) {
    final s = text.toLowerCase();
    final entries = <({String label, int low, int high})>[];

    // Pattern 1: range totals with label inside parentheses before 'each'
    final rangeRe = RegExp(r"=\s*(\d+)\s*[-–]\s*(\d+)\s*portions\s*\(([^)]*?)\s*each\)");
    for (final m in rangeRe.allMatches(s)) {
      final a = int.tryParse(m.group(1)!) ?? 0;
      final b = int.tryParse(m.group(2)!) ?? a;
      var rawLabel = (m.group(3) ?? '').trim();
      // Normalize using existing mapping; feed as a phrase containing 'of <label>' so mapping matches
      var canonical = _normalizeFoodLabelFromText('of $rawLabel');
      if ((canonical == 'food' || canonical.isEmpty) && rawLabel.isNotEmpty) {
        canonical = rawLabel; // fall back to the literal label rather than generic 'fish food'
      }
      if (canonical.isEmpty) canonical = 'fish food';
      entries.add((label: canonical, low: a, high: b));
    }

    // Pattern 2: single totals with label
    final singleRe = RegExp(r"=\s*(\d+)\s*portions\s*\(([^)]*?)\s*each\)");
    for (final m in singleRe.allMatches(s)) {
      final n = int.tryParse(m.group(1)!) ?? 0;
      var rawLabel = (m.group(2) ?? '').trim();
      var canonical = _normalizeFoodLabelFromText('of $rawLabel');
      if ((canonical == 'food' || canonical.isEmpty) && rawLabel.isNotEmpty) {
        canonical = rawLabel;
      }
      if (canonical.isEmpty) canonical = 'fish food';
      entries.add((label: canonical, low: n, high: n));
    }

    return entries;
  }

  Map<String, Map<String, int>> _aggregateTankPortionsPerFeeding() {
    final map = _calculationResult?['fish_portions'] as Map<String, dynamic>?;
    if (map == null || map.isEmpty) return {};

    final totals = <String, Map<String, int>>{};

    map.forEach((fishName, rawVal) {
      final portionText = (rawVal ?? '').toString();
      if (portionText.isEmpty) return;
      final parts = _extractSpeciesTotalsWithLabels(portionText);
      for (final p in parts) {
        if (!totals.containsKey(p.label)) {
          totals[p.label] = {'low': p.low, 'high': p.high};
        } else {
          final cur = totals[p.label]!;
          totals[p.label] = {'low': (cur['low'] ?? 0) + p.low, 'high': (cur['high'] ?? 0) + p.high};
        }
      }
    });

    return totals;
  }

  Widget _buildTankTotalsPerFeeding() {
    final totals = _aggregateTankPortionsPerFeeding();
    if (totals.isEmpty) return const SizedBox.shrink();

    final items = totals.entries.map((e) {
      final label = e.key;
      final r = e.value;
      final low = r['low'] ?? 0;
      final high = r['high'] ?? 0;
      final rangeStr = low == high ? '$low' : '$low–$high';
      const unit = 'pcs';
      return '$rangeStr $unit of $label';
    }).toList();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tank total per feeding:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF006064),
            ),
          ),
          const SizedBox(height: 4),
          ...items.map((t) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(color: Color(0xFF006064))),
                    Expanded(
                      child: Text(
                        t,
                        style: const TextStyle(fontSize: 14, color: Color(0xFF004D40)),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
  
  Future<void> _saveDietCalculation() async {
    if (_calculationResult == null) return;
    if (_isSaving) return; // prevent double tap
    if (mounted) {
      setState(() {
        _isSaving = true;
      });
    }
    
    final fishSelections = <String, int>{};
    final Set<String> fishNamesOnCards = _fishCards
        .map((card) => card.fishController.text.trim())
        .where((name) => name.isNotEmpty)
        .toSet();
        
    for (final name in fishNamesOnCards) {
      final qty = _fishSelections[name] ?? 0;
      if (qty > 0) {
        fishSelections[name] = qty;
      }
    }
    
    final totalPortion = _calculationResult!['total_portion'] as int;
    final String? totalPortionRange = _calculationResult!['total_portion_range']?.toString();
    final feedingsPerDayRaw = _calculationResult!['feedings_per_day'];
    final int? feedingsPerDay = feedingsPerDayRaw is int
        ? feedingsPerDayRaw
        : int.tryParse(feedingsPerDayRaw?.toString() ?? '');
    final portionDetails = _calculationResult!['fish_portions'] as Map<String, dynamic>;
    try {
      final dietCalculation = DietCalculation(
        fishSelections: fishSelections,
        totalPortion: totalPortion,
        totalPortionRange: totalPortionRange,
        portionDetails: portionDetails,
        compatibilityIssues: _compatibilityReason.isNotEmpty ? [_compatibilityReason] : null,
        feedingNotes: _calculationResult!['feeding_notes'] as String,
        feedingTips: _calculationResult!['feeding_tips'] as String?,
        feedingsPerDay: feedingsPerDay,
        feedingTimes: _calculationResult!['feeding_times'] as String?,
        aiFoodTypes: _calculationResult!['ai_food_types'] as List<String>?,
        tankTotalsByFood: _calculationResult!['tank_totals_by_food'] as Map<String, dynamic>?,
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

      final response = await http.post(
        Uri.parse(ApiConfig.saveDietCalculationEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.accessToken}',
        },
        body: json.encode(dietCalculation.toJson()),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        print('Diet calculation save response: $responseData');
        
        // Add to logbook provider for recent activity
        if (mounted) {
          final logBookProvider = Provider.of<LogBookProvider>(context, listen: false);
          logBookProvider.addDietCalculation(dietCalculation);
          print('Added diet calculation to logbook provider');
          
          // Force reload data from database to ensure consistency
          await logBookProvider.init();
        }
        
        _showNotification('Diet calculation saved successfully!');
        
        // Clear inputs and results after successful save
        await Future.delayed(const Duration(milliseconds: 1500));
        if (mounted) {
          _tryAgain();
          _tabController.animateTo(0);
        }
      } else {
        print('Save failed with status: ${response.statusCode}');
        print('Response body: ${response.body}');
        throw Exception('Failed to save: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error saving diet calculation: $e');
      _showNotification('Error saving calculation: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _tryAgain() {
    setState(() {
      _hasCompatibilityIssue = false;
      _compatibilityReason = '';
      _incompatiblePairs = null;
      _calculationResult = null;
      
      // Clear all fish input cards
      for (var card in _fishCards) {
        card.dispose();
      }
      
      // Reset to single fish card
      _fishCards = [DietFishCard(id: 0)];
      _fishSelections.clear();
    });
  }

  Widget _buildFishInputCard(DietFishCard card, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFE0F7FA),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      FontAwesomeIcons.fish,
                      color: Color(0xFF006064),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Fish Species ${index + 1}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF006064),
                      ),
                    ),
                  ],
                ),
                if (_fishCards.length > 1)
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Color(0xFF006064),
                    ),
                    onPressed: () => _removeFishCard(card.id),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    splashRadius: 24,
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Autocomplete<String>(
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return const Iterable<String>.empty();
                      }
                      return _availableFish.where((String option) {
                        return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                      });
                    },
                    onSelected: (String selection) {
                      setState(() {
                        card.fishController.text = selection;
                        // Initialize with 1 if not already in selections
                        if (!_fishSelections.containsKey(selection)) {
                          _fishSelections[selection] = 1;
                        }
                      });
                    },
                    fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                      // Sync the card's controller with the autocomplete controller
                      textEditingController.text = card.fishController.text;
                      
                      return TextFormField(
                        controller: textEditingController,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          hintText: 'Search fish spe...',
                          prefixIcon: const Icon(Icons.search, color: Color(0xFF006064)),
                          filled: true,
                          fillColor: const Color(0xFFF5F5F5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                            borderSide: const BorderSide(color: Color(0xFF00BCD4)),
                          ),
                        ),
                        onChanged: (value) {
                          // Keep the card's controller in sync
                          card.fishController.text = value;
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F7FA),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove, color: Color(0xFF006064)),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        onPressed: () {
                          final fishName = card.fishController.text;
                          if (fishName.isEmpty) return;

                          setState(() {
                            final currentCount = _fishSelections[fishName] ?? 0;
                            if (currentCount <= 1) {
                              // Check if this is the only card with this fish name
                              final cardsWithSameFish = _fishCards.where((c) => c.fishController.text == fishName).length;
                              if (cardsWithSameFish <= 1) {
                                _fishSelections.remove(fishName);
                              }
                              _removeFishCard(card.id);
                            } else {
                              _fishSelections[fishName] = currentCount - 1;
                            }
                          });
                        },
                      ),
                      Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          border: Border.symmetric(
                            vertical: BorderSide(
                              color: Color(0xFF006064),
                              width: 0.5,
                            ),
                          ),
                        ),
                        child: Text(
                          _fishSelections[card.fishController.text]?.toString() ?? '0',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF006064),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add, color: Color(0xFF006064)),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        onPressed: () => _addFish(card.fishController.text, card.id),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
                borderRadius: BorderRadius.circular(12),
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
              borderRadius: BorderRadius.circular(16),
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
                      borderRadius: BorderRadius.circular(12),
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
              borderRadius: BorderRadius.circular(16),
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
                  borderRadius: BorderRadius.circular(8),
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

    return Container(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFFE0F7FA),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.set_meal, color: Color(0xFF00BCD4), size: 24),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Diet Recommendation',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00BCD4),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Feeding Schedule Section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Color(0xFF00BCD4).withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.schedule, color: Color(0xFF006064), size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Feeding Schedule',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF006064),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if ((_calculationResult?['feedings_per_day'] is int) && (_calculationResult!['feedings_per_day'] as int) > 0)
                  Text(
                    'Feed ${_calculationResult!['feedings_per_day']} time${_calculationResult!['feedings_per_day'] == 1 ? '' : 's'} per day',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF004D40),
                    ),
                  ),
                if ((_calculationResult?['feedings_per_day'] is int) && (_calculationResult!['feedings_per_day'] as int) > 0)
                  const SizedBox(height: 8),
                Text(
                  _getFeedingTimesText(),
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF004D40),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Tank Totals Section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Color(0xFF00BCD4).withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.restaurant, color: Color(0xFF006064), size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Feeding Guide & Portions',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF006064),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildTankTotalsDisplay(),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Feeding Notes Section (if available)
          if (_calculationResult!['feeding_notes'] != null && (_calculationResult!['feeding_notes'] as String).isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Color(0xFF00BCD4).withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.lightbulb_outline, color: Color(0xFF006064), size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Feeding Tips',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF006064),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _formatFeedingTips(_calculationResult!['feeding_tips'] ?? _calculationResult!['feeding_notes'] as String),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF004D40),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    _tryAgain();
                    _tabController.animateTo(0);
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: Color(0xFF00BCD4)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Calculate Again',
                    style: TextStyle(
                      color: Color(0xFF00BCD4),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveDietCalculation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00BCD4),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isSaving
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                            SizedBox(width: 8),
                            Text('Saving...'),
                          ],
                        )
                      : const Text('Save Results'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Helper method to get user-friendly food type display names
  String _getFoodTypeDisplayName(String foodType) {
    switch (foodType.toLowerCase()) {
      case 'pellets':
        return 'pellets';
      case 'flakes':
        return 'flakes';
      case 'algae wafers':
        return 'algae wafers';
      case 'bloodworms':
        return 'bloodworms';
      case 'brine shrimp':
        return 'brine shrimp';
      case 'daphnia':
        return 'daphnia';
      case 'cooked peas':
        return 'cooked peas';
      case 'micropellets':
        return 'micro-pellets';
      case 'mini pellets':
        return 'mini pellets';
      case 'small pellets':
        return 'small pellets';
      default:
        return foodType;
    }
  }

  // Helper method to format food type recommendations
  String _formatFoodTypeRecommendations(List<String> foodTypes) {
    if (foodTypes.isEmpty) return 'No specific recommendations available.';
    
    final formattedTypes = foodTypes.map((type) => _getFoodTypeDisplayName(type)).toList();
    
    if (formattedTypes.length == 1) {
      return 'Use ${formattedTypes.first} for optimal nutrition.';
    } else if (formattedTypes.length == 2) {
      return 'Use ${formattedTypes.first} and ${formattedTypes.last} for variety.';
    } else {
      final last = formattedTypes.last;
      final others = formattedTypes.take(formattedTypes.length - 1).join(', ');
      return 'Use $others, and $last for balanced nutrition.';
    }
  }

  Widget _buildTankTotalsDisplay() {
    final tankTotals = _calculationResult?['tank_totals_by_food'] as Map<String, dynamic>?;
    final aiFoodTypes = _calculationResult?['ai_food_types'] as List<String>?;
    final fishPortions = _calculationResult?['fish_portions'] as Map<String, dynamic>?;
    
    if (tankTotals == null || tankTotals.isEmpty) {
      return const Text(
        'No food totals available',
        style: TextStyle(
          fontSize: 14,
          color: Color(0xFF004D40),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main feeding summary
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF00BCD4).withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.restaurant, color: Color(0xFF006064), size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Total Food Per Feeding',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF006064),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...tankTotals.entries.map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(color: Color(0xFF006064), fontSize: 16)),
                    Expanded(
                      child: Text(
                        '${(entry.value['low'] ?? 0) == (entry.value['high'] ?? 0) ? (entry.value['low'] ?? 0) : '${entry.value['low'] ?? 0}-${entry.value['high'] ?? 0}'} ${_getFoodTypeDisplayName(entry.key)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF004D40),
                        ),
                      ),
                    ),
                  ],
                ),
              )),
            ],
          ),
        ),
        
        const SizedBox(height: 12),
        
                // Individual fish breakdown (if multiple fish)
        if (fishPortions != null && fishPortions.length > 1) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF00BCD4).withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const FaIcon(FontAwesomeIcons.fish, color: Color(0xFF006064), size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Per Fish Breakdown',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF006064),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...fishPortions.entries.map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const FaIcon(FontAwesomeIcons.fish, color: Color(0xFF006064), size: 16),
                      const SizedBox(width: 8),
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
                            Text(
                              '${entry.value['per_fish']} each',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF666666),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
              ],
            ),
          ),
        ],
        
        // Food type recommendations
        if (aiFoodTypes != null && aiFoodTypes.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF00BCD4).withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.lightbulb_outline, color: Color(0xFF006064), size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Recommended Food Types',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF006064),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _formatFoodTypeRecommendations(aiFoodTypes),
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF004D40),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMainTab() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Fish input cards
                ..._fishCards.asMap().entries.map((entry) {
                  final index = entry.key;
                  final card = entry.value;
                  return _buildFishInputCard(card, index);
                }).toList(),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        // Bottom action bar: Add Another Fish + Calculate side-by-side
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _addFishCard,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: Color(0xFF00BCD4)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.add, color: Color(0xFF00BCD4)),
                  label: const Text(
                    'Add Fish',
                    style: TextStyle(color: Color(0xFF00BCD4), fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _calculateDiet,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00BCD4),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Color(0xFF00BCD4),
                    disabledForegroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Calculate Diet',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
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

  String _getFeedingTimesText() {
    final feedingTimes = _calculationResult?['feeding_times'] as String?;
    if (feedingTimes != null && feedingTimes.isNotEmpty) {
      return feedingTimes;
    }
    
    final feedingsPerDay = _calculationResult?['feedings_per_day'] as int?;
    if (feedingsPerDay == null || feedingsPerDay <= 0) {
      return 'Best times: Morning, afternoon, and evening';
    }
    
    switch (feedingsPerDay) {
      case 1:
        return 'Best time: Morning (8-10 AM)';
      case 2:
        return 'Best times: Morning (8-10 AM) and evening (6-8 PM)';
      case 3:
        return 'Best times: Morning (8-10 AM), afternoon (2-4 PM), and evening (6-8 PM)';
      case 4:
        return 'Best times: Morning (8-9 AM), noon (12-1 PM), afternoon (3-4 PM), and evening (7-8 PM)';
      case 5:
        return 'Best times: Early morning (7-8 AM), late morning (10-11 AM), afternoon (2-3 PM), evening (6-7 PM), and night (9-10 PM)';
      default:
        return 'Best times: Morning, afternoon, and evening';
    }
  }

  Future<Map<String, dynamic>> _generateAIDietRecommendations(Map<String, int> fishSelections) async {
    try {
      print('🔄 Generating AI diet recommendations for: ${fishSelections.keys.join(', ')}');
      final result = await OpenAIService.generateDietRecommendations(fishSelections);
      print('✅ AI diet recommendations generated successfully');
      return result;
    } catch (e) {
      print('❌ Error generating AI diet recommendations: $e');
      print('🔄 Falling back to local recommendations...');
      return await _getFallbackDietRecommendations(fishSelections.keys.toList());
    }
  }


  Future<Map<String, dynamic>> _getFallbackDietRecommendations(List<String> fishList) async {
    return await OpenAIService.getFallbackDietRecommendations(fishList);
  }




  Future<Map<String, dynamic>> _generateFishPortionRecommendation(String fishName, int quantity, List<String> availableFoodTypes) async {
    try {
      final prompt = '''
Generate specific portion recommendations for $quantity $fishName fish.
Available food types: ${availableFoodTypes.join(', ')}

Provide:
1. PORTION SIZE: Specific portion size (e.g., "2-3 small pellets", "1 pinch of flakes")
2. FOOD TYPE: Choose the most appropriate food type from the available list
3. REASONING: Brief explanation of why this food type and portion size is recommended

Consider:
- Fish size and dietary needs
- Quantity of fish
- Food type compatibility
- Nutritional balance

Format as structured information.
''';

      final response = await OpenAIService.generatePortionRecommendation(fishName, quantity, availableFoodTypes);
      
      return response;
    } catch (e) {
      print('Error generating portion recommendation for $fishName: $e');
      return _getFallbackPortionRecommendation(fishName, quantity, availableFoodTypes);
    }
  }

  Future<Map<String, dynamic>> _getFallbackPortionRecommendation(String fishName, int quantity, List<String> availableFoodTypes) async {
    final foodType = availableFoodTypes.isNotEmpty ? availableFoodTypes.first : 'pellets';
    return {
      'portion_size': '2-3 small $foodType',
      'food_type': foodType,
      'reasoning': 'Standard portion for $quantity $fishName fish',
    };
  }



  Future<String> _generateFeedingNotes(List<String> fishNames) async {
    final prompt = """
Generate feeding notes for an aquarium with these fish: ${fishNames.join(', ')}.
Requirements:
- Output exactly 3 lines.
- Each line must be a short, plain sentence (no lists, no numbering, no extra text).
- Do not include species names, headings, or phrases like "Feeding Notes."
- Content of each line:
  1) Feeding frequency and timing.
  2) When to remove uneaten food to maintain water quality.
  3) A general care note relevant to mixed fish tanks.
- Keep it concise and user-friendly.
- Lines must be separated only by a newline.
""";
            final response = await OpenAIService.generateFeedingNotes(fishNames);
    
    return response;
  }

  Future<String> _generateAIFeedingTips(List<String> fishNames) async {
    try {
      final response = await OpenAIService.generateFeedingNotes(fishNames);
      return response;
    } catch (e) {
      print('Error generating AI feeding tips: $e');
      return 'Start with smaller portions and observe fish appetite. Remove uneaten food after 2-3 minutes. Adjust feeding based on fish activity and water quality.';
    }
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
}