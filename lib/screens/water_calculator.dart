import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import '../screens/logbook_provider.dart';
import '../models/water_calculation.dart';
import '../config/api_config.dart';
import '../widgets/custom_notification.dart';
import 'dart:async';
import 'package:lottie/lottie.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../services/openai_service.dart'; // OpenAI AI service
import '../widgets/expandable_reason.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/auth_required_dialog.dart';
import '../widgets/fish_info_dialog.dart';
import '../widgets/fish_card_tankmates.dart';
import '../widgets/beginner_guide_dialog.dart';

class FishCard {
  final TextEditingController controller;
  final FocusNode focusNode;
  final int id;

  FishCard({
    required this.id,
  }) : controller = TextEditingController(),
       focusNode = FocusNode();

  void dispose() {
    controller.dispose();
    focusNode.dispose();
  }
}

class WaterCalculator extends StatefulWidget {
  const WaterCalculator({super.key});

  @override
  _WaterCalculatorState createState() => _WaterCalculatorState();
}

class _WaterCalculatorState extends State<WaterCalculator> {
  List<FishCard> _fishCards = [];
  final Map<String, int> _fishSelections = {};
  List<String> _availableFish = [];
  bool _isLoading = false;
  Map<String, dynamic>? _calculationResult;
  Map<String, String>? _careRecommendationsMap; // Per-fish recommendations
  bool _isGeneratingRecommendations = false;
  bool _isCalculating = false;
  String _selectedTankShape = 'bowl'; // New: tank shape selection (prioritized for beginners)
  bool _showAllShapes = false; // For show more/less tank shapes
  bool _bypassTemporaryHousingWarning = false; // Skip temporary housing validation once

  // State variables for See More/Less functionality
  bool _showFullTankAnalysis = false;
  bool _showFullFiltration = false;
  bool _showFullDietCare = false;
  bool _showFullWaterParameters = false;
  
  // State variables for AI responses
  List<String>? _tankmateRecommendations;
  
  // Store AI responses to avoid regeneration
  String? _tankAnalysisResponse;
  String? _filtrationResponse;
  String? _dietCareResponse;
  String? _waterParametersResponse;

  // Import the ExpandableReason widget

  @override
  void initState() {
    super.initState();
    _loadFishSpecies();
    _addNewTextField(); // Add initial card
  }

  @override
  void dispose() {
    // Dispose all fish cards
    for (var card in _fishCards) {
      card.dispose();
    }
    super.dispose();
  }

  void _addNewTextField() {
    setState(() {
      _fishCards.add(FishCard(id: _fishCards.length));
    });
  }

Widget buildRecommendationsList({
  required List<String> fishNames,
  required List<String> scientificNames,
  required Map<String, String> recommendations,
}) {
  return ListView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: fishNames.length,
    itemBuilder: (context, index) {
      final fishName = fishNames[index];
      final sciName = scientificNames[index];
      final recText = recommendations[fishName];
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.97, end: 1),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          builder: (context, scale, child) {
            return Transform.scale(
              scale: scale,
              child: Card(
                elevation: 3,
                color: isDark ? const Color(0xFF00363A) : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: const Color(0xFF00BCD4).withOpacity(0.18), width: 1.2),
                ),
                child: Theme(
                  data: Theme.of(context).copyWith(
                    dividerColor: Colors.transparent,
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                  ),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                    collapsedIconColor: const Color(0xFF00BCD4),
                    iconColor: const Color(0xFF00BCD4),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F7FA),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        FontAwesomeIcons.fish,
                        color: Color(0xFF00BCD4),
                        size: 20,
                      ),
                    ),
                    title: Row(
                      children: [
                        Flexible(
                          child: Text(
                            fishName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                              color: Color(0xFF006064),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (sciName.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00BCD4).withOpacity(0.10),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                sciName,
                                style: const TextStyle(fontSize: 12, color: Color(0xFF006064)),
                              ),
                            ),
                          ),
                      ],
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        child: recText != null && recText.trim().isNotEmpty
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: recText.split('\n').map((line) {
                                  final isOxygen = line.toLowerCase().contains('oxygen');
                                  final isFiltration = line.toLowerCase().contains('filtration');
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          isOxygen
                                              ? Icons.bubble_chart
                                              : isFiltration
                                                  ? Icons.filter_alt
                                                  : Icons.info_outline,
                                          color: isOxygen
                                              ? const Color(0xFF00BCD4)
                                              : isFiltration
                                                  ? const Color(0xFF006064)
                                                  : Colors.grey,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            line,
                                            style: TextStyle(
                                              fontSize: 15,
                                              color: isOxygen
                                                  ? const Color(0xFF00BCD4)
                                                  : isFiltration
                                                      ? const Color(0xFF006064)
                                                      : Colors.black87,
                                              fontWeight: isOxygen || isFiltration ? FontWeight.w500 : FontWeight.normal,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              )
                            : Row(
                                children: const [
                                  Icon(Icons.info_outline, color: Colors.grey, size: 20),
                                  SizedBox(width: 10),
                                  Text('No data available.', style: TextStyle(color: Colors.grey)),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    },
  );
}

  void _removeFishCard(int id) {
    setState(() {
      // Find the card index
      final index = _fishCards.indexWhere((card) => card.id == id);
      if (index != -1) {
        // Get the fish name before removing
        final fishName = _fishCards[index].controller.text;
        
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


Future<void> _generateAllRecommendations() async {
  setState(() {
    _isGeneratingRecommendations = true;
    _careRecommendationsMap = null;
  });

  final fishNames = _fishSelections.keys.toList();
  final scientificNames = List<String>.filled(fishNames.length, '');

  Map<String, String> recommendations = {};
  try {
    for (int i = 0; i < fishNames.length; i++) {
              final rec = await OpenAIService.generateOxygenAndFiltrationNeeds(fishNames[i], scientificNames[i]);
      // rec is expected to be a Map<String, String> with keys 'oxygen_needs' and 'filtration_needs'
      String display = '';
      if (rec['oxygen_needs'] != null && rec['oxygen_needs']!.isNotEmpty) {
        display += 'Oxygen Needs: ${rec['oxygen_needs']!}\n';
      }
      if (rec['filtration_needs'] != null && rec['filtration_needs']!.isNotEmpty) {
        display += 'Filtration Needs: ${rec['filtration_needs']!}';
      }
      if (display.isEmpty) display = 'No data available.';
      recommendations[fishNames[i]] = display.trim();
    }
  } catch (e) {
    print('Error generating oxygen/filtration needs: $e');
  }

  setState(() {
    _careRecommendationsMap = recommendations;
    _isGeneratingRecommendations = false;
  });
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

  Future<void> _calculateRequirements() async {
    if (_fishSelections.isEmpty) {
      showCustomNotification(
        context,
        'Please add at least one fish',
        isError: true,
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _isCalculating = true;
    });
    
    print('Starting calculation for fish: $_fishSelections');
    
    try {
      // First, validate tank shape compatibility with fish sizes
      final tankShapeValidation = await _validateTankShapeCompatibility();
      if (tankShapeValidation != null) {
        setState(() {
          _calculationResult = tankShapeValidation;
          _isCalculating = false;
          _isLoading = false;
        });
        return;
      }
      // Check compatibility for total count >= 2 using expanded list by quantity
      final totalCount = _fishSelections.values.fold<int>(0, (sum, v) => sum + v);
      print('Total fish count: $totalCount');
      
      if (totalCount >= 2) {
        print('Checking compatibility for multiple fish...');
        final expandedFishNames = _fishSelections.entries
            .expand((e) => List.filled(e.value, e.key))
            .toList();

        final compatibilityResponse = await http.post(
          Uri.parse(ApiConfig.checkGroupEndpoint),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json'
          },
          body: json.encode({'fish_names': expandedFishNames}),
        ).timeout(const Duration(seconds: 30)); // Increased timeout for compatibility check

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
          
          if (compatibility == 'Not Compatible' || compatibility == 'Conditional') {
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
                } else if (compatibility == 'Conditional') {
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
          
          // Enrich reasons with AI explanations (cached) before presenting/storing
          for (final item in allProblematicPairs) {
            final pair = (item['pair'] as List).cast<dynamic>();
            if (pair.length == 2) {
              final reasons = (item['reasons'] as List).cast<String>();
              try {
                final detailed = await OpenAIService.getOrExplainIncompatibilityReasons(
                  pair[0].toString(),
                  pair[1].toString(),
                  reasons,
                ).timeout(const Duration(seconds: 10)); // Add timeout for AI service
                if (detailed.isNotEmpty) {
                  item['reasons'] = detailed;
                }
              } catch (e) {
                print('AI explanation failed for ${pair[0]} + ${pair[1]}: $e');
                // keep base reasons on failure
              }
            }
          }
          
          setState(() {
            _calculationResult = {
              'error': hasIncompatiblePairs ? 'Incompatible Fish Combinations' : 'Conditional Fish Compatibility',
              'incompatible_pairs': incompatiblePairs,
              'conditional_pairs': conditionalPairs,
              'all_pairs': allProblematicPairs,
            };
            _isLoading = false;
          });
          return;
        }
      }

      print('No compatibility issues found, proceeding with water calculation...');
      // Calculate water requirements
      final waterResponse = await http.post(
        Uri.parse(ApiConfig.calculateRequirementsEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        },
        body: json.encode({
          'fish_selections': _fishSelections,
          'tank_shape': _selectedTankShape,
        }),
      ).timeout(const Duration(seconds: 30)); // Increased timeout for water calculation

      print('Water calculation API call completed with status: ${waterResponse.statusCode}');

      if (waterResponse.statusCode != 200) {
        throw Exception('Failed to calculate water requirements: ${waterResponse.statusCode}');
      }

      final responseData = json.decode(waterResponse.body);
      print('Water calculation successful, setting results...');
      setState(() {
        _calculationResult = responseData;
        _isCalculating = false;
        _isLoading = false; // Ensure loading is set to false
      });

      // After calculation, generate care recommendations for all fish (non-blocking)
      _generateAllRecommendations().catchError((e) {
        print('Error generating recommendations: $e');
        // Don't block the UI if recommendations fail
      });

    } catch (e) {
      print('Error calculating requirements: $e');
      showCustomNotification(
        context,
        'Error calculating requirements. Please try again.',
        isError: true,
      );
      setState(() {
        _calculationResult = null;
        _isCalculating = false;
        _isLoading = false;
      });
    } finally {
      // Ensure all loading states are reset
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isCalculating = false;
        });
      }
    }
  }

  void _addFish(String fishName, int index) {
    if (fishName.isEmpty) return;
    setState(() {
      _fishSelections[fishName] = (_fishSelections[fishName] ?? 0) + 1;
      print("Added fish: $fishName, count: ${_fishSelections[fishName]}");
    });
  }

  Widget _buildFishInput(FishCard card) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
                      'Fish Species ${_fishCards.indexOf(card) + 1}',
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
                      return _availableFish.where((String fish) =>
                          fish.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                    },
                    onSelected: (String selection) {
                      setState(() {
                        card.controller.text = selection;
                        _addFish(selection, card.id);
                      });
                    },
                    fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                      // Sync the card's controller with the autocomplete controller
                      textEditingController.text = card.controller.text;
                      
                      return TextFormField(
                        controller: textEditingController,
                        focusNode: focusNode,
                        onChanged: (value) {
                          // Keep the card's controller in sync
                          card.controller.text = value;
                        },
                        decoration: InputDecoration(
                          hintText: 'Search fish species...',
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
                          final fishName = card.controller.text;
                          if (fishName.isEmpty) return;

                          setState(() {
                            final currentCount = _fishSelections[fishName] ?? 0;
                            if (currentCount <= 1) {
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
                          _fishSelections[card.controller.text]?.toString() ?? '0',
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
                        onPressed: () => _addFish(card.controller.text, card.id),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Add tankmate recommendations if fish is selected
          if (card.controller.text.isNotEmpty && _availableFish.contains(card.controller.text))
            FishCardTankmates(
              fishName: card.controller.text,
              onFishSelected: (fishName) {
                // Find an empty card or create a new one
                bool added = false;
                for (var existingCard in _fishCards) {
                  if (existingCard.controller.text.isEmpty) {
                    existingCard.controller.text = fishName;
                    _addFish(fishName, existingCard.id);
                    added = true;
                    break;
                  }
                }
                if (!added) {
                  _addNewTextField();
                  if (_fishCards.isNotEmpty) {
                    _fishCards.last.controller.text = fishName;
                    _addFish(fishName, _fishCards.last.id);
                  }
                }
                setState(() {}); // Refresh UI
              },
          ),
        ],
      ),
    );
  }

  Widget _buildWaterRequirements() {
    if (_calculationResult == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Selected Fish Card
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
                              borderRadius: BorderRadius.circular(8),
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
                      // Fish List with care recommendations
                      ..._fishSelections.entries.map((entry) {
                        final fishName = entry.key;
                        final count = entry.value;
                        final recText = _careRecommendationsMap != null ? _careRecommendationsMap![fishName] : null;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Card(
                            elevation: 0,
                            margin: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Theme(
                              data: Theme.of(context).copyWith(
                                dividerColor: Colors.transparent,
                                splashColor: Colors.transparent,
                                highlightColor: Colors.transparent,
                              ),
                              child: ExpansionTile(
                                tilePadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                collapsedIconColor: const Color(0xFF00BCD4),
                                iconColor: const Color(0xFF00BCD4),
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE0F7FA),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    count.toString(),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF006064),
                                    ),
                                  ),
                                ),
                                title: InkWell(
                                  onTap: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) => FishInfoDialog(fishName: fishName),
                                    );
                                  },
                                  child: Text(
                                  fishName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                      color: Color(0xFF006064),
                                    fontWeight: FontWeight.bold,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                                children: [
                                  if (_isGeneratingRecommendations)
                                    const Padding(
                                      padding: EdgeInsets.all(16.0),
                                      child: Center(child: CircularProgressIndicator()),
                                    )
                                  else if (recText != null && recText.trim().isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: recText.split('\n').map((line) {
                                          final isOxygen = line.toLowerCase().contains('oxygen needs:');
                                          final isFiltration = line.toLowerCase().contains('filtration needs:');
                                          if (isOxygen || isFiltration) {
                                            final label = isOxygen ? 'Oxygen Needs:' : 'Filtration Needs:';
                                            final idx = line.indexOf(':');
                                            String desc = idx != -1 && idx + 1 < line.length ? line.substring(idx + 1).trim() : '';
                                            // Remove Moderate/High/Low/Very High/Very Low/Medium etc. from the start of the description
                                            final levelPattern = RegExp(r'^(very\s+)?(high|low|moderate|medium)\b[\s\-:]*', caseSensitive: false);
                                            desc = desc.replaceFirst(levelPattern, '');
                                            return Padding(
                                              padding: const EdgeInsets.only(bottom: 6),
                                              child: Row(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Icon(
                                                    isOxygen ? Icons.bubble_chart : Icons.filter_alt,
                                                    color: const Color(0xFF00BCD4),
                                                    size: 20,
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Expanded(
                                                    child: RichText(
                                                      text: TextSpan(
                                                        children: [
                                                          TextSpan(
                                                            text: label + (desc.isNotEmpty ? ' ' : ''),
                                                            style: const TextStyle(
                                                              fontSize: 15,
                                                              color: Color(0xFF00BCD4),
                                                              fontWeight: FontWeight.w500,
                                                            ),
                                                          ),
                                                          if (desc.isNotEmpty)
                                                            TextSpan(
                                                              text: desc,
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
                                          } else {
                                            return Padding(
                                              padding: const EdgeInsets.only(bottom: 6),
                                              child: Row(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  const Icon(Icons.info_outline, color: Colors.grey, size: 20),
                                                  const SizedBox(width: 10),
                                                  Expanded(
                                                    child: Text(
                                                      line,
                                                      style: const TextStyle(fontSize: 15, color: Colors.black87),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }
                                        }).toList(),
                                      ),
                                    )
                                  else
                                    Row(
                                      children: const [
                                        Icon(Icons.info_outline, color: Colors.grey, size: 20),
                                        SizedBox(width: 10),
                                        Text('No data available.', style: TextStyle(color: Colors.grey)),
                                      ],
                                    ),
                                ],
                              ),
                            ),
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
          // Tank Volume Card
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF006064),
                  const Color(0xFF00ACC1),
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
            child: Stack(
              children: [
                // Background wave pattern
                Positioned(
                  right: -20,
                  bottom: -20,
                  child: Icon(
                    Icons.water,
                    size: 100,
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
                // Content
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Minimum Tank Volume',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _calculationResult!['requirements']['minimum_tank_volume'] ?? 'Not specified',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Smart Tank Size Information
                      FutureBuilder<Map<String, dynamic>>(
                        future: _getSmartTankSizeInfo(),
                        builder: (context, snapshot) {
                          if (snapshot.hasData && snapshot.data!['is_accurate']) {
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white.withOpacity(0.3)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        color: Colors.white70,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Smart Calculation',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white70,
                        ),
                      ),
                    ],
                                  ),
                                  const SizedBox(height: 4),
                                                                          Text(
                                          snapshot.data!['explanation'],
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.white.withOpacity(0.9),
                                          ),
                                        ),
                                ],
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            _getShapeIcon(_selectedTankShape),
                            color: Colors.white70,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _getShapeLabel(_selectedTankShape),
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
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
          const SizedBox(height: 20),
          // Water Parameters Card
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
                              borderRadius: BorderRadius.circular(8),
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
                      FutureBuilder<String>(
                        future: _waterParametersResponse != null 
                          ? Future.value(_waterParametersResponse!)
                          : _generateWaterParameters().then((response) {
                              _waterParametersResponse = response;
                              return response;
                            }),
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
                                  'Generating water parameters...',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF006064),
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            );
                          } else if (snapshot.hasData) {
                            final fullText = snapshot.data!;
                            final shortText = fullText.length > 80 ? fullText.substring(0, 77) + '...' : fullText;
                            
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_showFullWaterParameters) ...[
                                  // Show full bullet points
                                  ...fullText.split('\n').map((line) => 
                                    line.trim().isNotEmpty ? Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          if (line.trim().startsWith('•')) ...[
                                            const Text('• ', style: TextStyle(fontSize: 14, color: Color(0xFF006064), fontWeight: FontWeight.bold)),
                                            Expanded(
                                              child: Text(
                                                line.trim().substring(1).trim(),
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.black87,
                                                  height: 1.5,
                                                ),
                                              ),
                                            ),
                                          ] else ...[
                                            Expanded(
                                              child: Text(
                                                line.trim(),
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.black87,
                                                  height: 1.5,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ) : const SizedBox.shrink()
                                  ).toList(),
                                ] else ...[
                                  // Show truncated text
                                  Text(
                                    shortText,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.black87,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                                if (fullText.length > 80) ...[
                                  const SizedBox(height: 8),
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _showFullWaterParameters = !_showFullWaterParameters;
                                      });
                                    },
                                    child: Text(
                                      _showFullWaterParameters ? 'See Less' : 'See More',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF00BCD4),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
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
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              FontAwesomeIcons.users,
                              color: Color(0xFF006064),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Tankmate Recommendations',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF006064),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      FutureBuilder<List<String>>(
                        future: _getTankmateRecommendations(),
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
                            final recommendations = snapshot.data!.take(3).join(', ');
                            return Text(
                              'Compatible tankmates: $recommendations.',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                                height: 1.5,
                              ),
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
            ),
          ),
          const SizedBox(height: 20),
          // Tank & Environment Analysis Card
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
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.home,
                              color: Color(0xFF006064),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Tank & Environment',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF006064),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      FutureBuilder<String>(
                        future: _tankAnalysisResponse != null 
                          ? Future.value(_tankAnalysisResponse!)
                          : _generateTankEnvironmentAnalysis().then((response) {
                              _tankAnalysisResponse = response;
                              return response;
                            }),
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
                                  'Analyzing tank environment...',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF006064),
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            );
                          } else if (snapshot.hasData) {
                            final fullText = snapshot.data!;
                            final shortText = fullText.length > 80 ? fullText.substring(0, 77) + '...' : fullText;
                            
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _showFullTankAnalysis ? fullText : shortText,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black87,
                                    height: 1.5,
                                  ),
                                ),
                                if (fullText.length > 80) ...[
                                  const SizedBox(height: 8),
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _showFullTankAnalysis = !_showFullTankAnalysis;
                                      });
                                    },
                                    child: Text(
                                      _showFullTankAnalysis ? 'See Less' : 'See More',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF00BCD4),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            );
                          } else {
                            return const Text(
                              'Optimal tank provides adequate space and surface area.',
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
          // Filtration Recommendations Card
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
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.filter_alt,
                              color: Color(0xFF006064),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Filtration & Equipment',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF006064),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      FutureBuilder<String>(
                        future: _filtrationResponse != null 
                          ? Future.value(_filtrationResponse!)
                          : _generateFiltrationRecommendations().then((response) {
                              _filtrationResponse = response;
                              return response;
                            }),
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
                                  'Generating filtration recommendations...',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF006064),
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            );
                          } else if (snapshot.hasData) {
                            final fullText = snapshot.data!;
                            final shortText = fullText.length > 80 ? fullText.substring(0, 77) + '...' : fullText;
                            
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _showFullFiltration ? fullText : shortText,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black87,
                                    height: 1.5,
                                  ),
                                ),
                                if (fullText.length > 80) ...[
                                  const SizedBox(height: 8),
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _showFullFiltration = !_showFullFiltration;
                                      });
                                    },
                                    child: Text(
                                      _showFullFiltration ? 'See Less' : 'See More',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF00BCD4),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            );
                          } else {
                            return const Text(
                              'Use filter rated for your tank size with 4-6x turnover rate.',
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
          // Diet & Care Card
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
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.restaurant,
                              color: Color(0xFF006064),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Diet & Care Tips',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF006064),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      FutureBuilder<String>(
                        future: _dietCareResponse != null 
                          ? Future.value(_dietCareResponse!)
                          : _generateDietAndCareTips().then((response) {
                              _dietCareResponse = response;
                              return response;
                            }),
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
                                  'Generating care recommendations...',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF006064),
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            );
                          } else if (snapshot.hasData) {
                            final fullText = snapshot.data!;
                            final shortText = fullText.length > 80 ? fullText.substring(0, 77) + '...' : fullText;
                            
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _showFullDietCare ? fullText : shortText,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black87,
                                    height: 1.5,
                                  ),
                                ),
                                if (fullText.length > 80) ...[
                                  const SizedBox(height: 8),
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _showFullDietCare = !_showFullDietCare;
                                      });
                                    },
                                    child: Text(
                                      _showFullDietCare ? 'See Less' : 'See More',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF00BCD4),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            );
                          } else {
                            return const Text(
                              'Feed 1-2 times daily and perform 25% weekly water changes.',
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
        ],
      ),
    );
  }

  Widget _buildParameterRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFE0F7FA),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: const Color(0xFF006064),
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _resetCalculator() {
    setState(() {
      _fishCards = [FishCard(id: 0)];  // Reset with one text controller
      _fishSelections.clear();
      _calculationResult = null;
      _careRecommendationsMap = null;
      _isLoading = false;
      _isCalculating = false;
      _selectedTankShape = 'bowl';
      _showAllShapes = false;
      _bypassTemporaryHousingWarning = false;
      
      // Reset AI responses and display states
      _tankAnalysisResponse = null;
      _filtrationResponse = null;
      _dietCareResponse = null;
      _waterParametersResponse = null;
      _showFullTankAnalysis = false;
      _showFullFiltration = false;
      _showFullDietCare = false;
      _showFullWaterParameters = false;
      
      // Clear AI responses
      _tankmateRecommendations = null;
    });
  }

  Widget _buildTankShapeSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFE0F7FA),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.crop_square,
                  color: Color(0xFF006064),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Tank Shape',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF006064),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // BEGINNER - Always visible (prioritized)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF00BCD4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.school, color: Color(0xFF006064), size: 16),
                          const SizedBox(width: 6),
                          const Text(
                            'BEGINNER',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF006064),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildShapeOption(
                        'bowl',
                        'Bowl Tank',
                        Icons.circle,
                        '2-20L • Nano fish <8cm',
                        isMainOption: true,
                      ),
                    ],
                  ),
                ),
                
                // MONSTER KEEPERS & HOBBYIST - Show if expanded
                if (_showAllShapes) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF00BCD4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.water, color: Color(0xFF006064), size: 16),
                            const SizedBox(width: 6),
                            const Text(
                              'MONSTER KEEPERS',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF006064),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildShapeOption(
                          'rectangle',
                          'Rectangle Tank',
                          Icons.crop_landscape,
                          '20L-2000L+ • All fish sizes',
                          isMainOption: true,
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF00BCD4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.pets, color: Color(0xFF006064), size: 16),
                            const SizedBox(width: 6),
                            const Text(
                              'HOBBYIST',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF006064),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _buildShapeOption(
                                'square',
                                'Square Tank',
                                Icons.crop_square,
                                '50-500L • Under 30cm',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildShapeOption(
                                'cylinder',
                                'Cylinder Tank',
                                Icons.circle_outlined,
                                '20-200L • Fish <20cm',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
                // Show more/less button
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _showAllShapes = !_showAllShapes;
                    });
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _showAllShapes ? 'See Less Options' : 'See More Tank Types',
                        style: const TextStyle(
                          color: Color(0xFF006064),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _showAllShapes ? Icons.expand_less : Icons.expand_more,
                        color: const Color(0xFF006064),
                        size: 20,
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

  Widget _buildShapeOption(String value, String label, IconData icon, String description, {bool isMainOption = false}) {
    final isSelected = _selectedTankShape == value;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedTankShape = value;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: isMainOption ? double.infinity : null,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE0F7FA) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF00BCD4) : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: isMainOption ? Row(
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF006064) : Colors.grey.shade600,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? const Color(0xFF006064) : Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected ? const Color(0xFF006064) : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ) : Column(
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF006064) : Colors.grey.shade600,
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isSelected ? const Color(0xFF006064) : Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? const Color(0xFF006064) : Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  IconData _getShapeIcon(String shape) {
    switch (shape) {
      case 'rectangle':
        return Icons.crop_landscape;
      case 'square':
        return Icons.crop_square;
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
        return 'Rectangle Tank';
      case 'square':
        return 'Square Tank';
      case 'bowl':
        return 'Bowl Tank';
      case 'cylinder':
        return 'Cylinder Tank';
      default:
        return 'Rectangle Tank';
    }
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
      final List<Map<String, dynamic>> temporaryCompatibleFish = [];

      // Check each selected fish against tank shape
      for (var fishName in _fishSelections.keys) {
        final fishData = fishList.firstWhere(
          (fish) => fish['common_name']?.toString().toLowerCase() == fishName.toLowerCase(),
          orElse: () => null,
        );

        if (fishData != null) {
          final maxSize = fishData['max_size'];
          final minTankSize = fishData['minimum_tank_size_l'] ?? fishData['min_tank_size'] ?? fishData['tank_size_required'];
          
          // Check if fish will be incompatible when fully grown
          if (_isFishIncompatibleWithTankShape(fishName, maxSize, minTankSize, _selectedTankShape)) {
            // Check if this could be temporary housing for juvenile fish
            if (_canBeTemporaryHousing(fishName, maxSize, minTankSize, _selectedTankShape)) {
              temporaryCompatibleFish.add({
                'fish_name': fishName,
                'max_size': maxSize,
                'min_tank_size': minTankSize,
                'current_tank_suitable_months': _getTemporaryHousingDuration(maxSize, _selectedTankShape),
                'growth_warning': _getGrowthWarning(fishName, maxSize, minTankSize, _selectedTankShape),
                'ai_warning_available': true,
                'ai_enhanced': true, // Flag to trigger AI enhancement later
              });
            } else {
              incompatibleFish.add({
                'fish_name': fishName,
                'max_size': maxSize,
                'min_tank_size': minTankSize,
                'reason': _getTankShapeIncompatibilityReason(fishName, maxSize, minTankSize, _selectedTankShape),
              });
            }
          }
        }
      }

      // If there are fish that need warnings about growth, show that (unless bypassed)
      if (temporaryCompatibleFish.isNotEmpty && !_bypassTemporaryHousingWarning) {
        return {
          'warning': 'Growth Planning Required',
          'temporary_housing_issues': temporaryCompatibleFish,
          'selected_tank_shape': _selectedTankShape,
        };
      }

      // If there are completely incompatible fish, return error result
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
               
      case 'square':
        // HOBBYIST: Square tanks (50-500L) - Moderate space limitations
        return (fishMaxSize != null && fishMaxSize > 30) || 
               (fishMinTankSize != null && fishMinTankSize > 500);
               
      case 'rectangle':
      default:
        // MONSTER KEEPERS: Rectangle tanks (20L-2000L+) - Most versatile for all sizes
        return false;
    }
  }

  String _getTankShapeIncompatibilityReason(String fishName, dynamic maxSize, dynamic minTankSize, String tankShape) {
    final size = maxSize?.toString() ?? 'N/A';
    final tankVol = minTankSize?.toString() ?? 'N/A';
    
    switch (tankShape) {
      case 'bowl':
        return '$fishName (max size: ${size}cm, min tank: ${tankVol}L) is too large for a bowl tank. Bowl tanks (2-20L) are BEGINNER-friendly and designed for nano fish under 8cm like bettas, small tetras, or shrimp.';
        
      case 'cylinder':
        return '$fishName (max size: ${size}cm, min tank: ${tankVol}L) needs more horizontal swimming space than a cylinder tank provides. Cylinder tanks (20-200L) are HOBBYIST-level and suitable for fish under 20cm.';
        
      case 'square':
        return '$fishName (max size: ${size}cm, min tank: ${tankVol}L) requires more swimming length than a square tank offers. Square tanks (50-500L) are HOBBYIST-level and work best for fish under 30cm.';
        
      default:
        return '$fishName is not suitable for the selected tank shape.';
    }
  }

  bool _canBeTemporaryHousing(String fishName, dynamic maxSize, dynamic minTankSize, String tankShape) {
    // Convert sizes to numbers for comparison
    double? fishMaxSize;
    
    try {
      if (maxSize != null) fishMaxSize = double.tryParse(maxSize.toString());
    } catch (e) {
      return false;
    }

    // Only allow temporary housing if the fish isn't extremely oversized for the tank
    switch (tankShape) {
      case 'bowl':
        // Allow temporary housing for fish up to 15cm (juveniles) but not massive fish
        return (fishMaxSize != null && fishMaxSize <= 15);
        
      case 'cylinder':
        // Allow temporary housing for fish up to 35cm
        return (fishMaxSize != null && fishMaxSize <= 35);
        
      case 'square':
        // Allow temporary housing for fish up to 50cm
        return (fishMaxSize != null && fishMaxSize <= 50);
        
      case 'rectangle':
      default:
        return true; // Rectangles can temporarily house anything
    }
  }

  int _getTemporaryHousingDuration(dynamic maxSize, String tankShape) {
    double? fishMaxSize;
    try {
      if (maxSize != null) fishMaxSize = double.tryParse(maxSize.toString());
    } catch (e) {
      return 0;
    }

    if (fishMaxSize == null) return 0;

    // Estimate months based on fish size and tank limitations
    switch (tankShape) {
      case 'bowl':
        if (fishMaxSize <= 10) return 6; // Small fish - 6 months
        if (fishMaxSize <= 15) return 3; // Medium fish - 3 months
        return 0;
        
      case 'cylinder':
        if (fishMaxSize <= 15) return 12; // Small fish - 1 year
        if (fishMaxSize <= 25) return 8;  // Medium fish - 8 months
        if (fishMaxSize <= 35) return 4;  // Large fish - 4 months
        return 0;
        
      case 'square':
        if (fishMaxSize <= 20) return 18; // Small fish - 1.5 years
        if (fishMaxSize <= 35) return 12; // Medium fish - 1 year
        if (fishMaxSize <= 50) return 6;  // Large fish - 6 months
        return 0;
        
      default:
        return 0; // Rectangle tanks don't need temporary housing
    }
  }

  /// Calculate smart tank size requirements considering shoaling behavior
  Map<String, dynamic> _calculateSmartTankSize(String fishName, int quantity, Map<String, dynamic> fishData) {
    final minTankSize = fishData['minimum_tank_size_l'] ?? fishData['min_tank_size'] ?? fishData['tank_size_required'];
    final socialBehavior = fishData['social_behavior']?.toString().toLowerCase() ?? '';
    
    double baseTankSize = 0;
    try {
      baseTankSize = double.tryParse(minTankSize.toString()) ?? 0;
    } catch (e) {
      baseTankSize = 0;
    }
    
    if (baseTankSize == 0) {
      return {
        'total_size': 'Unknown',
        'explanation': 'Tank size data unavailable',
        'is_accurate': false,
      };
    }
    
    // Smart calculation based on social behavior
    double totalTankSize;
    String explanation;
    
    if (socialBehavior.contains('shoaling') || socialBehavior.contains('schooling')) {
      // Shoaling fish: base size + small increment per additional fish
      if (quantity == 1) {
        totalTankSize = baseTankSize;
        explanation = 'Single fish needs ${baseTankSize.toInt()}L';
      } else {
        // For shoaling fish, add 2-3L per additional fish (not full base size)
        final additionalSpace = (quantity - 1) * 2.5; // 2.5L per additional fish
        totalTankSize = baseTankSize + additionalSpace;
        explanation = 'Shoaling fish: ${baseTankSize.toInt()}L base + ${additionalSpace.toInt()}L for ${quantity - 1} additional fish';
      }
    } else if (socialBehavior.contains('territorial') || socialBehavior.contains('solitary')) {
      // Territorial fish: each needs full space
      totalTankSize = baseTankSize * quantity;
      explanation = 'Territorial fish: each needs ${baseTankSize.toInt()}L × $quantity = ${totalTankSize.toInt()}L';
    } else {
      // Default: moderate sharing
      if (quantity == 1) {
        totalTankSize = baseTankSize;
        explanation = 'Single fish needs ${baseTankSize.toInt()}L';
      } else {
        final additionalSpace = (quantity - 1) * (baseTankSize * 0.3); // 30% of base size per additional
        totalTankSize = baseTankSize + additionalSpace;
        explanation = 'Community fish: ${baseTankSize.toInt()}L base + ${additionalSpace.toInt()}L for ${quantity - 1} additional fish';
      }
    }
    
    return {
      'total_size': '${totalTankSize.toInt()}L',
      'explanation': explanation,
      'is_accurate': true,
      'base_size': baseTankSize.toInt(),
      'quantity': quantity,
    };
  }

  /// Get smart tank size information for display
  Future<Map<String, dynamic>> _getSmartTankSizeInfo() async {
    try {
      // Get fish data to calculate smart tank size
      final response = await http.get(
        Uri.parse(ApiConfig.fishListEndpoint),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return {'is_accurate': false};
      }

      final List<dynamic> fishList = json.decode(response.body);
      
      // Calculate smart tank size for the first fish (assuming similar behavior for same species)
      for (var fishName in _fishSelections.keys) {
        final fishData = fishList.firstWhere(
          (fish) => fish['common_name']?.toString().toLowerCase() == fishName.toLowerCase(),
          orElse: () => null,
        );

        if (fishData != null) {
          final quantity = _fishSelections[fishName] ?? 1;
          return _calculateSmartTankSize(fishName, quantity, fishData);
        }
      }
      
      return {'is_accurate': false};
    } catch (e) {
      print('Error getting smart tank size info: $e');
      return {'is_accurate': false};
    }
  }



  String _getGrowthWarning(String fishName, dynamic maxSize, dynamic minTankSize, String tankShape) {
    final size = maxSize?.toString() ?? 'Unknown';
    String tankVol = 'Unknown';
    
    // Try to get tank volume from multiple sources
    if (minTankSize != null) {
      final parsed = double.tryParse(minTankSize.toString());
      tankVol = parsed != null ? '${parsed.toInt()}L' : minTankSize.toString();
    }
    
    // If still unknown, try to estimate based on fish size
    if (tankVol == 'Unknown' && maxSize != null) {
      final maxSizeNum = double.tryParse(maxSize.toString());
      if (maxSizeNum != null) {
        // Rough estimation: 1cm of fish needs about 1-2L of water
        final estimatedVolume = (maxSizeNum * 1.5).round();
        tankVol = '~${estimatedVolume}L (estimated)';
      }
    }
    
    final months = _getTemporaryHousingDuration(maxSize, tankShape);
    final upgradeTimeline = months > 1 ? months - 1 : months;
    
    // Use the same logic as quick planning guide
    switch (tankShape) {
      case 'bowl':
        return '⚠️ TEMPORARY ONLY: $fishName will grow to ${size}cm and need ${tankVol}. Plan upgrade in $upgradeTimeline months to Rectangle tank!';
        
      case 'cylinder':
        return '📅 GROWTH PLANNING: $fishName will reach ${size}cm and need ${tankVol}. Plan upgrade in $upgradeTimeline months to Rectangle tank.';
        
      case 'square':
        return '📅 FUTURE UPGRADE: $fishName will grow to ${size}cm and need ${tankVol}. Plan upgrade in $upgradeTimeline months to Rectangle tank.';
        
      default:
        return 'No growth concerns for this tank shape.';
    }
  }

  Future<String> _generateAIPlanningOptions(List<Map<String, dynamic>> temporaryFish) async {
    if (temporaryFish.isEmpty) return 'No specific planning needed.';
    
    try {
      print('🧠 Generating AI planning options for ${temporaryFish.length} fish...');
      
      // Create a simplified prompt for AI planning
      final fishDetails = temporaryFish.map((fish) {
        final maxSize = fish['max_size']?.toString() ?? 'Unknown';
        final months = fish['current_tank_suitable_months']?.toString() ?? 'Unknown';
        return '${fish['fish_name']} (${maxSize}cm, ${months} months)';
      }).join(', ');
      
      final aiPrompt = """
      Create a simple 3-step action plan for aquarium fish growth planning:
      Fish: $fishDetails
      Current tank: ${_getShapeLabel(_selectedTankShape)}
      
      Provide only 3 numbered steps:
      1. What to monitor now
      2. When to upgrade (timeline)
      3. What to upgrade to
      
      Keep each step under 15 words. Be direct and practical.
      """;
      
      final aiResponse = await OpenAIService.getChatResponse(aiPrompt).timeout(
        const Duration(seconds: 15),
      );
      
      if (aiResponse.isNotEmpty && (aiResponse.contains('1.') || aiResponse.contains('1)'))) {
          return aiResponse;
      }
    } catch (e) {
      print('🧠 AI planning generation failed: $e');
    }
    
    // Use actual calculated months from fish data
    final maxMonths = temporaryFish.map((f) => f['current_tank_suitable_months'] as int).reduce((a, b) => a < b ? a : b);
    final tankShape = _getShapeLabel(_selectedTankShape);
    final upgradeTimeline = maxMonths > 1 ? maxMonths - 1 : maxMonths;
    
    return '''
1. Monitor fish size monthly
2. Plan upgrade in $upgradeTimeline months
3. Research ${tankShape} tanks
''';
  }



  Future<List<String>> _getTankmateRecommendations() async {
    try {
      final fishNames = _fishSelections.keys.toList();
      if (fishNames.isEmpty) return [];

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/tankmate-recommendations'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'fish_names': fishNames}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final recommendations = List<String>.from(data['recommendations'] ?? []);
        final result = recommendations.take(5).toList(); // Limit to 5 recommendations
        _tankmateRecommendations = result; // Store the result
        return result;
      }
    } catch (e) {
      print('🐠 Tankmate recommendations failed: $e');
    }
    
    final fallback = ['Consider peaceful community fish like tetras, rasboras, or corydoras.'];
    _tankmateRecommendations = fallback; // Store fallback result
    return fallback;
  }

  Future<String> _generateTankEnvironmentAnalysis() async {
    try {
      final fishNames = _fishSelections.keys.toList();
      final tankVolume = _calculationResult!['requirements']['minimum_tank_volume'];
      final tankShape = _getShapeLabel(_selectedTankShape);
      
      final aiPrompt = """
      Explain why this tank setup is optimal for these fish in EXACTLY 50 words:
      Fish: ${fishNames.join(', ')}
      Tank Volume: $tankVolume
      Tank Shape: $tankShape
      
      Provide a detailed, educational explanation covering:
      - Why this volume is sufficient for the fish species
      - Benefits of this tank shape for swimming patterns and gas exchange
      - Key environmental factors and considerations
      - Any special requirements or recommendations
      
      Be comprehensive, educational, and practical. Count your words carefully - maximum 50 words total.
      """;
      
      final aiResponse = await OpenAIService.getChatResponse(aiPrompt).timeout(
        const Duration(seconds: 25),
      );
      
      if (aiResponse.isNotEmpty) {
        return aiResponse;
      }
    } catch (e) {
      print('🧠 AI tank environment analysis failed: $e');
    }
    
    return 'This ${_getShapeLabel(_selectedTankShape).toLowerCase()} tank provides adequate swimming space and surface area for gas exchange. Consider the fish species requirements for optimal health.';
  }

  Future<String> _generateFiltrationRecommendations() async {
    try {
      final fishNames = _fishSelections.keys.toList();
      final tankVolume = _calculationResult!['requirements']['minimum_tank_volume'];
      
      final aiPrompt = """
      Recommend filtration for this aquarium setup in EXACTLY 50 words:
      Fish: ${fishNames.join(', ')}
      Tank Volume: $tankVolume
      
      Provide detailed, educational filter recommendations covering:
      - Recommended filter type and capacity for this setup
      - Filtration rate (turnover) requirements and why they matter
      - Maintenance schedule and procedures for optimal performance
      - Special considerations for these specific fish species
      - Additional equipment recommendations if needed
      
      Be comprehensive, educational, and practical. Count your words carefully - maximum 50 words total.
      """;
      
      final aiResponse = await OpenAIService.getChatResponse(aiPrompt).timeout(
        const Duration(seconds: 25),
      );
      
      if (aiResponse.isNotEmpty) {
        return aiResponse;
      }
    } catch (e) {
      print('🧠 AI filtration recommendations failed: $e');
    }
    
    final volume = _calculationResult!['requirements']['minimum_tank_volume'] ?? 'your tank size';
    return 'Use a filter rated for $volume or larger with 4-6x tank volume turnover per hour. Clean filter media monthly and monitor water quality weekly for optimal fish health.';
  }

  Future<String> _generateDietAndCareTips() async {
    try {
      final fishNames = _fishSelections.keys.toList();
      
      final aiPrompt = """
      Provide diet and care tips for these fish in EXACTLY 50 words:
      Fish: ${fishNames.join(', ')}
      
      Provide detailed, educational recommendations covering:
      - Feeding frequency, amounts, and timing for optimal health
      - Food types (flakes, pellets, live food) and nutritional requirements
      - Water change schedule, procedures, and why they're important
      - Special care requirements and behavioral monitoring
      - Health monitoring tips and common issues to watch for
      - Environmental factors that affect fish well-being
      
      Be comprehensive, educational, and practical. Count your words carefully - maximum 50 words total.
      """;
      
      final aiResponse = await OpenAIService.getChatResponse(aiPrompt).timeout(
        const Duration(seconds: 25),
      );
      
      if (aiResponse.isNotEmpty) {
          return aiResponse;
      }
    } catch (e) {
      print('🧠 AI diet and care tips failed: $e');
    }
    
    return 'Feed 1-2 times daily, only what fish eat in 2-3 minutes. Use high-quality flakes or pellets as staple diet. Perform 25% water changes weekly and monitor fish behavior daily for signs of stress or illness.';
  }

  Future<String> _generateWaterParameters() async {
    try {
      final fishNames = _fishSelections.keys.toList();
      
      final aiPrompt = """
      Provide comprehensive water parameters for these fish in bullet point format (EXACTLY 50 words):
      Fish: ${fishNames.join(', ')}
      
      Provide detailed water parameter recommendations in bullet points covering:
      - Temperature range (in Celsius) and why it's optimal
      - pH range and water hardness requirements
      - Ammonia, nitrite, and nitrate levels to maintain
      - Water change frequency and procedures
      - Testing schedule and monitoring tips
      - Any special water quality considerations
      
      Format as bullet points with • symbol. Be comprehensive, educational, and practical. Count your words carefully - maximum 50 words total.
      """;
      
      final aiResponse = await OpenAIService.getChatResponse(aiPrompt).timeout(
        const Duration(seconds: 25),
      );
      
      if (aiResponse.isNotEmpty) {
        return aiResponse;
      }
    } catch (e) {
      print('🧠 AI water parameters failed: $e');
    }
    
    return 'Maintain temperature 24-26°C, pH 6.5-7.5, ammonia/nitrite 0ppm, nitrate <20ppm. Test weekly, change 25% water bi-weekly. Monitor fish behavior for stress indicators.';
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
                    borderRadius: BorderRadius.circular(12),
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
      ),
    );
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
            'Calculating Water Requirements...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF006064),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Analyzing fish compatibility and tank requirements',
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

  Widget _buildTemporaryHousingWarning(Map<String, dynamic> results) {
    final temporaryFish = results['temporary_housing_issues'] as List<Map<String, dynamic>>? ?? [];
    final selectedShape = results['selected_tank_shape'] as String? ?? 'Unknown';
    
    return FutureBuilder<String>(
      future: _generateAIPlanningOptions(temporaryFish),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Show loading animation while generating planning guide
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
                  'Generating Growth Planning Guide...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF006064),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Analyzing fish growth patterns and creating personalized timeline',
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
        
        // Show the full interface once planning guide is ready
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      child: SingleChildScrollView(
      child: Column(
        children: [
          // Warning Card
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
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
                      Icons.schedule,
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
                          'Growth Planning Required',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Your fish will outgrow this ${_getShapeLabel(selectedShape).toLowerCase()}',
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
          // Planning Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                    color: Colors.white,
              borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                          Icon(Icons.psychology, color: const Color(0xFF006064), size: 20),
                    const SizedBox(width: 8),
                          const Text(
                            'Quick Planning Guide',
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
                        snapshot.data ?? '1. Monitor fish size monthly\n2. Plan upgrade in 3-6 months\n3. Research larger tank options',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                          height: 1.4,
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
                  child: OutlinedButton(
                    onPressed: () {
                      // Choose different setup - go back to tank shape selection
                      setState(() {
                        _calculationResult = null;
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color.fromARGB(255, 82, 82, 82),
                      side: const BorderSide(color: Colors.white, width: 2),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Choose Different Setup',
                      style: TextStyle(
                            fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _bypassTemporaryHousingWarning = true;
                        _calculationResult = null; // Clear warning and continue
                      });
                      _calculateRequirements();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                            horizontal: 12,
                      ),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                          alignment: Alignment.center,
                    ),
                    child: const Text(
                      'Continue with Temporary',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                            fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    ),
        );
      },
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
                              borderRadius: BorderRadius.circular(12),
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
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lightbulb_outline, color: Colors.blue.shade700, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Recommendation',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Consider switching to a Rectangle tank for the best compatibility with large fish, or choose smaller fish species that are suitable for ${_getShapeLabel(selectedShape).toLowerCase()}.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.blue.shade800,
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
              onPressed: _resetCalculator,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00BCD4),
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
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
              onPressed: _resetCalculator,  // Use the new reset function
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00BCD4),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Water Calculator',
          style: TextStyle(color: Color(0xFF006064), fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: Color(0xFF006064)),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const BeginnerGuideDialog(calculatorType: 'water'),
              );
            },
          ),
        ],
      ),
      body: Container(
        color: Colors.white,
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    return Stack(
      children: [
        if (_isCalculating)
          _buildBowlLoadingAnimation()
        else if (_isLoading)
          const Center(child: CircularProgressIndicator(color: Color(0xFF00BCD4)))
        else
          Container(
            color: Colors.white,
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        if (_calculationResult == null) ...[
                          _buildTankShapeSelector(),
                          ..._fishCards.map((card) => _buildFishInput(card)),
                        ] else if (_calculationResult!['temporary_housing_issues'] != null)
                          _buildTemporaryHousingWarning(_calculationResult!)
                        else if (_calculationResult!['tank_shape_issues'] != null)
                          _buildTankShapeIncompatibilityResults(_calculationResult!)
                        else if (_calculationResult!['incompatible_pairs'] != null || _calculationResult!['conditional_pairs'] != null)
                          _buildCompatibilityResults(_calculationResult!)
                        else
                          _buildWaterRequirements(),

                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      if (_calculationResult == null) ...[
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _addNewTextField,
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
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _calculateRequirements,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00BCD4),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
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
                      ],
                      if (_calculationResult != null && !_calculationResult!.containsKey('incompatible_pairs') && !_calculationResult!.containsKey('conditional_pairs') && !_calculationResult!.containsKey('tank_shape_issues') && !_calculationResult!.containsKey('temporary_housing_issues')) ...[
                        Expanded(
                          child: TextButton(
                            onPressed: _resetCalculator,
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.grey[200],
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Try Again',
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
                            onPressed: () async {
                              // Check authentication first
                              final user = Supabase.instance.client.auth.currentUser;
                              if (user == null) {
                                // Show auth required dialog
                                showDialog(
                                  context: context,
                                  builder: (BuildContext context) => const AuthRequiredDialog(
                                    title: 'Sign In Required',
                                    message: 'You need to sign in to save water calculations to your collection.',
                                  ),
                                );
                                return;
                              }
                              
                              // Prepare oxygen and filtration needs maps
                              Map<String, String> oxygenNeeds = {};
                              Map<String, String> filtrationNeeds = {};
                              _careRecommendationsMap?.forEach((fish, rec) {
                                for (var line in rec.split('\n')) {
                                  if (line.toLowerCase().contains('oxygen needs:')) {
                                    final idx = line.indexOf(':');
                                    if (idx != -1 && idx + 1 < line.length) {
                                      oxygenNeeds[fish] = line.substring(idx + 1).trim();
                                    }
                                  } else if (line.toLowerCase().contains('filtration needs:')) {
                                    final idx = line.indexOf(':');
                                    if (idx != -1 && idx + 1 < line.length) {
                                      filtrationNeeds[fish] = line.substring(idx + 1).trim();
                                    }
                                  }
                                }
                              });
                              final calculation = WaterCalculation(
                                fishSelections: Map<String, int>.from(_fishSelections),
                                minimumTankVolume: _calculationResult!['requirements']['minimum_tank_volume'],
                                phRange: _calculationResult!['requirements']['pH_range'],
                                temperatureRange: _calculationResult!['requirements']['temperature_range'],
                                recommendedQuantities: Map<String, int>.from(_fishSelections),
                                dateCalculated: DateTime.now(),
                                tankStatus: 'N/A',
                                oxygenNeeds: oxygenNeeds.isNotEmpty ? oxygenNeeds : null,
                                filtrationNeeds: filtrationNeeds.isNotEmpty ? filtrationNeeds : null,
                                waterParametersResponse: _waterParametersResponse,
                                tankAnalysisResponse: _tankAnalysisResponse,
                                filtrationResponse: _filtrationResponse,
                                dietCareResponse: _dietCareResponse,
                                tankmateRecommendations: _tankmateRecommendations,
                              );
                              
                              Provider.of<LogBookProvider>(context, listen: false)
                                .addWaterCalculation(calculation);
                                
                              showCustomNotification(context, 'Water calculation saved to history');
                              
                              // Wait for notification to be visible
                              await Future.delayed(const Duration(milliseconds: 1500));
                              
                              if (!mounted) return;
                              
                              // Reset calculator state instead of navigating
                              _resetCalculator();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00BCD4),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
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
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
} 