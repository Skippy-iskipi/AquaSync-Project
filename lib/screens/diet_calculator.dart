import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/api_config.dart';
import '../widgets/custom_notification.dart';
import '../screens/logbook_provider.dart';
import '../services/openai_service.dart';
import '../models/diet_calculation.dart';
import 'dart:async';
import '../widgets/expandable_reason.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:lottie/lottie.dart';

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
                final detailed = await OpenAIService.getOrExplainIncompatibilityReasons(
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
      int totalLow = 0;
      int totalHigh = 0;
      final List<int> feedingsPerDayCandidates = [];
      
      // Get portion data from OpenAI for each fish type
      for (String fishName in fishSelections.keys) {
        final quantity = fishSelections[fishName]!;
        
        // Get OpenAI care recommendations
        final careData = await OpenAIService.generateCareRecommendations(fishName, '');
        
        if (careData.containsKey('error')) {
          throw Exception('Failed to get portion data for $fishName');
        }
        
        // Extract portion options (handle multiple options like "2-3 small flakes or 1-2 brine shrimp")
        final portionSize = (careData['portion_size'] ?? '2-3 small pellets').toString();
        final optionParts = portionSize
            .split(RegExp(r'\bor\b', caseSensitive: false))
            .map((s) => s.trim().replaceAll(RegExp(r'^,\s*'), ''))
            .where((s) => s.isNotEmpty)
            .toList();

        // Build species-wide segments for each option and accumulate simple numeric totals from the first option
        final List<String> speciesSegments = [];
        for (int idx = 0; idx < optionParts.length; idx++) {
          final opt = optionParts[idx];
          final (low, high) = _extractPortionRange(opt);
          final fishLow = low * quantity;
          final fishHigh = high * quantity;
          final perFishRange = low == high ? '$low' : '$low-$high';
          final fishRange = fishLow == fishHigh ? '$fishLow' : '$fishLow-$fishHigh';
          // Keep option text concise inside parentheses
          final optLabel = _concisePortionOption(opt);
          speciesSegments.add('$quantity × $perFishRange = $fishRange portions ($optLabel each)');
          if (idx == 0) {
            totalLow += fishLow;
            totalHigh += fishHigh;
          }
        }

        // Join multiple option segments with ' OR '
        fishPortions[fishName] = speciesSegments.join(' OR ');

        // Extract feeding frequency per day if present, e.g., "2 times per day"
        final freqText = (careData['feeding_frequency'] ?? '').toString();
        final freqMatch = RegExp(r'(\d+)').firstMatch(freqText);
        if (freqMatch != null) {
          final f = int.tryParse(freqMatch.group(1)!) ?? 0;
          if (f > 0) feedingsPerDayCandidates.add(f);
        }
      }
      
      // Generate feeding notes using OpenAI
      String feedingNotes = 'Feed 2-3 times daily in small amounts. Remove uneaten food after 5 minutes. Adjust portions based on fish activity and appetite.';
      try {
        feedingNotes = await _generateFeedingNotes(fishPortions.keys.toList());
        // Remove any heading like "Feeding Notes:" that the model might include
        feedingNotes = feedingNotes
            .replaceFirst(RegExp(r'^\s*feeding\s*notes\s*:?', caseSensitive: false), '')
            .trim();
        // Additional cleanup: strip bullets/numbering and drop placeholder labels
        final lines = feedingNotes.split(RegExp(r'\r?\n'));
        final cleanedLines = lines
            .map((l) => l
                .replaceFirst(RegExp(r'^\s*(?:[-–•\u2022]|\d+[\.)])\s*'), '') // bullets or numbering
                .trim())
            .where((l) => l.isNotEmpty)
            .where((l) => !RegExp(r'^feeding\s*frequency', caseSensitive: false).hasMatch(l))
            .where((l) => !RegExp(r'^food\s*removal', caseSensitive: false).hasMatch(l))
            .where((l) => !RegExp(r'^any\s*special\s*considerations', caseSensitive: false).hasMatch(l))
            .toList();
        if (cleanedLines.isNotEmpty) {
          feedingNotes = cleanedLines.join('\n');
        }
      } catch (e) {
        print('Error generating feeding notes: $e');
        // Keep default feeding notes if OpenAI fails
      }
      
      // Choose a tank-wide feeding frequency. Strategy: use the maximum suggested per-day frequency among species.
      int? feedingsPerDay;
      if (feedingsPerDayCandidates.isNotEmpty) {
        feedingsPerDay = feedingsPerDayCandidates.reduce((a, b) => a > b ? a : b);
      }

      // Build descriptive tank totals per feeding (grouped by food type), including all options
      final Map<String, ({int low, int high})> tankTotals = {};
      fishPortions.forEach((fishName, rawVal) {
        final text = (rawVal ?? '').toString();
        if (text.isEmpty) return;
        final entries = _extractSpeciesTotalsWithLabels(text);
        for (final e in entries) {
          if (!tankTotals.containsKey(e.label)) {
            tankTotals[e.label] = (low: e.low, high: e.high);
          } else {
            final cur = tankTotals[e.label]!;
            tankTotals[e.label] = (low: cur.low + e.low, high: cur.high + e.high);
          }
        }
      });

      final List<String> totalStrings = tankTotals.entries.map((e) {
        final r = e.value;
        final rangeStr = r.low == r.high ? '${r.low}' : '${r.low}–${r.high}';
        if (e.key == 'food') {
          return '$rangeStr pcs';
        }
        return '$rangeStr pcs of ${e.key}';
      }).toList();
      final descriptiveTotalRange = totalStrings.join('; ');

      final result = {
        'fish_portions': fishPortions,
        // Keep numeric total_portion for compatibility (use low bound)
        'total_portion': totalLow,
        // New: human-readable descriptive string
        'total_portion_range': descriptiveTotalRange.isNotEmpty
            ? descriptiveTotalRange
            : (totalLow == totalHigh ? '$totalLow pcs' : '$totalLow–$totalHigh pcs'),
        if (feedingsPerDay != null) 'feedings_per_day': feedingsPerDay,
        'feeding_notes': feedingNotes,
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
      padding: const EdgeInsets.all(16),
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
  List<Widget> _buildFeedingNotesList() {
    final notes = (_calculationResult?['feeding_notes'] as String?)?.trim();
    if (notes == null || notes.isEmpty) return [];

    // Split by newlines first; if none, split by sentence endings.
    List<String> parts = notes.contains('\n')
        ? notes.split('\n')
        : notes.split(RegExp(r'(?<=[.!?])\s+'));

    final items = parts
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    return items
        .map((line) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '•',
                    style: TextStyle(fontSize: 16, color: Colors.black87),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      line,
                      style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.5),
                    ),
                  ),
                ],
              ),
            ))
        .toList();
  }

  // Infer a concise food label (e.g., 'pellets', 'flakes') from portion strings
  String _inferFoodLabel() {
    final map = _calculationResult?['fish_portions'] as Map<String, dynamic>?;
    if (map == null || map.isEmpty) return 'food';

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
    }

    if (foods.isEmpty) return 'food';
    if (foods.length == 1) return foods.first;
    return 'mixed food';
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
    return cleaned.isNotEmpty ? cleaned : 'recommended food';
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
    return _inferFoodLabel() ?? 'food';
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
        canonical = rawLabel; // fall back to the literal label rather than generic 'food'
      }
      if (canonical.isEmpty) canonical = 'food';
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
      if (canonical.isEmpty) canonical = 'food';
      entries.add((label: canonical, low: n, high: n));
    }

    return entries;
  }

  Map<String, ({int low, int high})> _aggregateTankPortionsPerFeeding() {
    final map = _calculationResult?['fish_portions'] as Map<String, dynamic>?;
    if (map == null || map.isEmpty) return {};

    final totals = <String, ({int low, int high})>{};

    map.forEach((fishName, rawVal) {
      final portionText = (rawVal ?? '').toString();
      if (portionText.isEmpty) return;
      final parts = _extractSpeciesTotalsWithLabels(portionText);
      for (final p in parts) {
        if (!totals.containsKey(p.label)) {
          totals[p.label] = (low: p.low, high: p.high);
        } else {
          final cur = totals[p.label]!;
          totals[p.label] = (low: cur.low + p.low, high: cur.high + p.high);
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
      final rangeStr = r.low == r.high ? '${r.low}' : '${r.low}–${r.high}';
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
        feedingsPerDay: feedingsPerDay,
        dateCalculated: DateTime.now(),
      );

      // Get auth token for authenticated request
      final supabase = Supabase.instance.client;
      final session = supabase.auth.currentSession;
      
      if (session == null) {
        throw Exception('Please login to save diet calculations');
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
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color(0xFFE0F7FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFF00BCD4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.set_meal, color: Color(0xFF00BCD4), size: 24),
              SizedBox(width: 8),
              Text(
                'Diet Recommendation',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF00BCD4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_calculationResult!['fish_portions'] != null) ...[
            const Text(
              'Individual Fish Portions:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF006064),
              ),
            ),
            const SizedBox(height: 8),
            ...(_calculationResult!['fish_portions'] as Map<String, dynamic>).entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '• ${entry.key}: ${entry.value}',
                  style: const TextStyle(fontSize: 14),
                  textAlign: TextAlign.justify,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (_calculationResult!['total_portion'] != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(
                color: const Color(0xFF00BCD4).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if ((_calculationResult?['feedings_per_day'] is int) && (_calculationResult!['feedings_per_day'] as int) > 0)
                    Text(
                      'Feed the tank ${_calculationResult!['feedings_per_day']} time${_calculationResult!['feedings_per_day'] == 1 ? '' : 's'} per day',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00BCD4),
                      ),
                    ),
                  const SizedBox(height: 8),
                  _buildTankTotalsPerFeeding(),
                ],
              ),
            ),
          ],
          if (_calculationResult!['feeding_notes'] != null) ...[
            const SizedBox(height: 16),
            ..._buildFeedingNotesList(),
          ],
          const SizedBox(height: 20),
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
                    'Try Again',
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

        // Full-screen loading overlay (covers entire phone screen including AppBar)
        if (_isCalculating)
          Positioned.fill(
            child: AbsorbPointer(
              absorbing: true,
              child: Container(
                color: Colors.transparent,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Lottie.asset(
                        'lib/lottie/BowlAnimation.json',
                        width: 160,
                        height: 160,
                        repeat: true, 
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Calculating diet... ',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
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
    final openAIService = OpenAIService();
    final response = await openAIService.getChatResponse(prompt);
    
    // Return the response if it's not an error message
    if (!response.startsWith('Error:') && !response.contains('API key not found')) {
      return response;
    }
    
    // Fallback to default if OpenAI fails
    return 'Feed 2-3 times daily in small amounts. Remove uneaten food after 5 minutes. Adjust portions based on fish activity and appetite.';
  }
}