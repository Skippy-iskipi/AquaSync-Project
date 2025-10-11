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
// Removed OpenAI service import
import '../widgets/expandable_reason.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/auth_required_dialog.dart';
import '../widgets/fish_info_dialog.dart';
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
  // Track real-time compatibility state
  bool _hasIncompatiblePairs = false;
  String _compatibilityMessage = '';
  List<FishCard> _fishCards = [];
  final Map<String, int> _fishSelections = {};
  final Map<int, String> _cardToFish = {}; // Track which fish belongs to which card
  List<String> _availableFish = [];
  bool _isLoading = false;
  Map<String, dynamic>? _calculationResult;
  bool _isCalculating = false;
  String _selectedTankShape = 'bowl'; // Tank shape selection
  bool _bypassTemporaryHousingWarning = false; // Skip temporary housing validation once
  Map<String, String> _fishTankShapeWarnings = {}; // Track tank shape warnings for each fish

  // Fish data from Supabase
  Map<String, dynamic>? _fishData;
  List<String>? _tankmateRecommendations;
  
  // Store conditional compatibility pairs for display
  List<Map<String, dynamic>> _conditionalCompatibilityPairs = [];
  
  // Dropdown state
  Map<String, bool> _showDropdown = {};
  Map<String, String> _searchQueries = {};

  // Suggestions state
  bool _isSuggestionsExpanded = false;

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

  // Build suggestion section widget
  Widget _buildSuggestionSection() {
    return Consumer<LogBookProvider>(
      builder: (context, logBookProvider, child) {
        final suggestedFish = _getSuggestedFishNames();
        
        // Always show the row with help button, even if no suggestions
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Suggestion card (if there are suggestions)
                if (suggestedFish.isNotEmpty)
                  Expanded(
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
                                                // Add fish to first empty card or create new card
                                                bool added = false;
                                                for (var card in _fishCards) {
                                                  if (card.controller.text.isEmpty) {
                                                    setState(() {
                                                      card.controller.text = fishName;
                                                      _addFish(fishName, card.id);
                                                    });
                                                    added = true;
                                                    break;
                                                  }
                                                }
                                                
                                                // If no empty card, add new one
                                                if (!added) {
                                                  _addNewTextField();
                                                  final newCard = _fishCards.last;
                                                  setState(() {
                                                    newCard.controller.text = fishName;
                                                    _addFish(fishName, newCard.id);
                                                  });
                                                }
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
                ),
              
              // Help button
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => const BeginnerGuideDialog(calculatorType: 'water'),
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF00BFB3).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: const Color(0xFF00BFB3).withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: const Center(
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Icon(
                        Icons.help_outline,
                        color: Color(0xFF00BFB3),
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ],
            ),
          ),
        );
      },
    );
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
                  borderRadius: BorderRadius.circular(6),
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
                        borderRadius: BorderRadius.circular(6),
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
                                borderRadius: BorderRadius.circular(6),
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
          _fishSelections[fishName] = (_fishSelections[fishName] ?? 1) - 1;
          if (_fishSelections[fishName]! <= 0) {
            _fishSelections.remove(fishName);
          }
          // Clear warning for this fish
          _fishTankShapeWarnings.remove(fishName);
        }

        // Clean up card-to-fish mapping
        _cardToFish.remove(id);

        // Clean up dropdown state
        _showDropdown.remove(id.toString());
        _searchQueries.remove(id.toString());

        // Dispose and remove the card
        _fishCards[index].dispose();
        _fishCards.removeAt(index);
      }
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
    if (!_isCalculateButtonEnabled()) {
      showCustomNotification(
        context,
        _getCalculateButtonDisabledReason(),
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
            _calculationResult = {
              'error': 'Incompatible Fish Combinations',
              'incompatible_pairs': incompatiblePairs,
              'conditional_pairs': [], // Clear conditional pairs for incompatible case
              'all_pairs': incompatiblePairs,
            };
            _isLoading = false;
          });
          return;
        }
        
        // Store conditional pairs for warning display but continue calculation
        if (hasConditionalPairs) {
          print('Found conditional compatibility issues, proceeding with warnings...');
          _conditionalCompatibilityPairs = conditionalPairs;
        }
      }

      print('No compatibility issues found, proceeding with water calculation...');
      
      // Load fish data from Supabase
      await _loadFishData();
      
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
      ).timeout(const Duration(seconds: 30));

      print('Water calculation API call completed with status: ${waterResponse.statusCode}');

      if (waterResponse.statusCode != 200) {
        throw Exception('Failed to calculate water requirements: ${waterResponse.statusCode}');
      }

      final responseData = json.decode(waterResponse.body);
      print('Water calculation successful, setting results...');
      
      // Load tankmate recommendations
      await _loadTankmateRecommendations();
      
      setState(() {
        _calculationResult = responseData;
        // Add conditional compatibility warnings to results if they exist
        if (_conditionalCompatibilityPairs.isNotEmpty) {
          _calculationResult!['conditional_compatibility_warnings'] = _conditionalCompatibilityPairs;
        }
        _isCalculating = false;
        _isLoading = false;
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

  Future<void> _loadFishData() async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.fishListEndpoint),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List<dynamic> fishList = json.decode(response.body);
        _fishData = {};
        for (var fish in fishList) {
          _fishData![fish['common_name']] = fish;
        }
        print('Loaded fish data for ${_fishData!.length} species');
      } else {
        print('Failed to load fish data: ${response.statusCode}');
      }
    } catch (e) {
      print('Error loading fish data: $e');
    }
  }

  Future<void> _loadTankmateRecommendations() async {
    try {
      final fishNames = _fishSelections.keys.toList();
      if (fishNames.isEmpty) return;

      // Use the unified compatibility system
      final recommendations = await _getTankmateRecommendations();
      _tankmateRecommendations = recommendations;
      print('Loaded ${_tankmateRecommendations!.length} tankmate recommendations using unified system');
    } catch (e) {
      print('Error loading tankmate recommendations: $e');
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

  void _addFish(String fishName, int cardId) {
    if (fishName.isEmpty) return;
    setState(() {
      // Clear previous fish for this card if it exists
      final previousFish = _cardToFish[cardId];
      if (previousFish != null && previousFish != fishName) {
        _fishSelections[previousFish] = (_fishSelections[previousFish] ?? 1) - 1;
        if (_fishSelections[previousFish]! <= 0) {
          _fishSelections.remove(previousFish);
        }
        // Clear warning for previous fish
        _fishTankShapeWarnings.remove(previousFish);
      }
      
      // Add new fish
      _fishSelections[fishName] = (_fishSelections[fishName] ?? 0) + 1;
      _cardToFish[cardId] = fishName;
      print("Added fish: $fishName, count: ${_fishSelections[fishName]}");
    });
    
    // Check tank shape compatibility for the new fish
    _checkFishTankShapeCompatibility(fishName);
  }

  Widget _buildFishInput(FishCard card) {
    final cardIndex = _fishCards.indexOf(card);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          // Simple header
                Row(
                  children: [
                    Text(
                'Fish Species ${cardIndex + 1}',
                      style: const TextStyle(
                        fontSize: 16,
                  fontWeight: FontWeight.w600,
                        color: Color(0xFF006064),
                      ),
                    ),
                    // Eye icon for fish info
                    if (card.controller.text.isNotEmpty && _availableFish.contains(card.controller.text)) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) => FishInfoDialog(fishName: card.controller.text),
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
                    ],
              const Spacer(),
                if (_fishCards.length > 1)
                GestureDetector(
                  onTap: () => _removeFishCard(card.id),
                  child: const Icon(
                    Icons.close,
                    color: Colors.grey,
                    size: 18,
                  ),
                  ),
              ],
            ),
          const SizedBox(height: 12),
          
          // Fish input and quantity in one row
          Row(
              children: [
              // Fish name input field with autocomplete
                Expanded(
                  flex: 3,
                  child: Autocomplete<String>(
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                      return _availableFish.take(10); // Show first 10 fish when empty
                      }
                      return _availableFish.where((String fish) =>
                        fish.toLowerCase().contains(textEditingValue.text.toLowerCase())).take(10);
                    },
                    onSelected: (String selection) {
                      setState(() {
                        card.controller.text = selection;
                        _addFish(selection, card.id);
                      });
                    },
                    fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                      textEditingController.text = card.controller.text;
                      
                      return TextFormField(
                        controller: textEditingController,
                        focusNode: focusNode,
                        onChanged: (value) {
                          card.controller.text = value;
                          setState(() {
                            _searchQueries[card.id.toString()] = value;
                            
                            // Clear old fish data for this card when input changes
                            final previousFish = _cardToFish[card.id];
                            if (previousFish != null && previousFish != value) {
                              _fishSelections[previousFish] = (_fishSelections[previousFish] ?? 1) - 1;
                              if (_fishSelections[previousFish]! <= 0) {
                                _fishSelections.remove(previousFish);
                              }
                              _cardToFish.remove(card.id);
                              // Clear warning for previous fish
                              _fishTankShapeWarnings.remove(previousFish);
                            }
                          });
                          
                          // Check tank shape compatibility for the new input
                          if (value.isNotEmpty) {
                            _checkFishTankShapeCompatibility(value);
                          }
                        },
                        decoration: InputDecoration(
                        hintText: 'Search or type fish name...',
                          filled: true,
                        fillColor: Colors.transparent,
                          border: OutlineInputBorder(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(8),
                            bottomLeft: Radius.circular(8),
                            topRight: Radius.zero,
                            bottomRight: Radius.zero,
                          ),
                            borderSide: BorderSide.none,
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
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _showDropdown[card.id.toString()] = !(_showDropdown[card.id.toString()] ?? false);
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
                    turns: (_showDropdown[card.id.toString()] ?? false) ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.arrow_drop_down,
                      color: Color(0xFF00BCD4),
                      size: 36,
                    ),
                  ),
                ),
              ),
              
              // Quantity controls
              if (card.controller.text.isNotEmpty && _availableFish.contains(card.controller.text)) ...[
                const SizedBox(width: 12),
                Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                    _buildMinimalQuantityButton(
                      icon: Icons.remove,
                      onTap: () {
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
                      width: 30,
                      height: 32,
                        alignment: Alignment.center,
                        child: Text(
                          _fishSelections[card.controller.text]?.toString() ?? '0',
                          style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                            color: Color(0xFF006064),
                          ),
                        ),
                      ),
                    _buildMinimalQuantityButton(
                      icon: Icons.add,
                      onTap: () => _addFish(card.controller.text, card.id),
                      ),
                    ],
                  ),
              ],
            ],
          ),
          
          // Dropdown list
          if (_showDropdown[card.id.toString()] == true) ...[
            const SizedBox(height: 8),
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey.shade300),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                ),
              ],
            ),
              child: ListView.builder(
                itemCount: _getFilteredFish(card.id.toString()).length,
                itemBuilder: (context, index) {
                  final fish = _getFilteredFish(card.id.toString())[index];
                  return ListTile(
                    title: Text(fish),
                    onTap: () {
                      setState(() {
                        card.controller.text = fish;
                        _addFish(fish, card.id);
                        _showDropdown[card.id.toString()] = false;
                      });
                    },
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<String> _getFilteredFish(String cardId) {
    final query = _searchQueries[cardId] ?? '';
    if (query.isEmpty) {
      return _availableFish;
    }
    return _availableFish.where((fish) =>
        fish.toLowerCase().contains(query.toLowerCase())).toList();
  }

  Widget _buildMinimalQuantityButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Icon(
          icon,
          color: const Color(0xFF00BCD4),
          size: 16,
        ),
      ),
    );
  }


  Widget _buildWaterRequirements() {
    final bool isEnabled = _isCalculateButtonEnabled();
    final String disabledReason = _getCalculateButtonDisabledReason();
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
                      // Fish List with Supabase data
                      ..._fishSelections.entries.map((entry) {
                        final fishName = entry.key;
                        final count = entry.value;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Card(
                            elevation: 0,
                            margin: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE0F7FA),
                                    borderRadius: BorderRadius.circular(6),
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
                                  const SizedBox(width: 12),
                                  Expanded(
                                  child: Text(
                                  fishName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                      color: Color(0xFF006064),
                                    fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                  GestureDetector(
                                    onTap: () {
                                      showDialog(
                                        context: context,
                                        builder: (context) => FishInfoDialog(fishName: fishName),
                                      );
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF00BCD4).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
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
          // Tankmate Recommendations Card
          if (_tankmateRecommendations != null && _tankmateRecommendations!.isNotEmpty)
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
                                borderRadius: BorderRadius.circular(6),
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
          // Conditional Compatibility Warnings (if any)
          if (_calculationResult != null && _calculationResult!['conditional_compatibility_warnings'] != null)
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
                      if (_calculationResult != null && _calculationResult!['requirements'] != null) ...[
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
                      ] else ...[
                                const Text(
                          'Water requirements will be calculated based on selected fish.',
                                  style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                                    fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                          ],
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
                                      title: 'Compatible with Conditions',
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


  List<String> _getUniqueFishSpecies() {
    return _fishSelections.keys.toSet().toList();
  }

  Map<String, dynamic> _getFeedingInformation() {
    if (_fishData == null || _fishSelections.isEmpty) return {};
    
    Map<String, dynamic> feedingInfo = {};
    
    for (String fishName in _getUniqueFishSpecies()) {
      final fishData = _fishData![fishName];
      if (fishData == null) continue;
      
      Map<String, dynamic> fishFeedingInfo = {};
      
      // Portion per fish
      if (fishData['portion_grams'] != null && fishData['portion_grams'].toString().isNotEmpty) {
        fishFeedingInfo['portion_grams'] = fishData['portion_grams'];
      }
      
      // Preferred food
      if (fishData['preferred_food'] != null && fishData['preferred_food'].toString().isNotEmpty) {
        fishFeedingInfo['preferred_food'] = fishData['preferred_food'];
      }
      
      // Feeding notes
      if (fishData['feeding_notes'] != null && fishData['feeding_notes'].toString().isNotEmpty) {
        fishFeedingInfo['feeding_notes'] = fishData['feeding_notes'];
      }
      
      // Overfeeding risks
      if (fishData['overfeeding_risks'] != null && fishData['overfeeding_risks'].toString().isNotEmpty) {
        fishFeedingInfo['overfeeding_risks'] = fishData['overfeeding_risks'];
      }
      
      // Only add if there's at least one feeding info field
      if (fishFeedingInfo.isNotEmpty) {
        feedingInfo[fishName] = fishFeedingInfo;
      }
    }
    
    return feedingInfo;
  }

  String _getPhRangeFromFishData() {
    if (_fishData == null || _fishSelections.isEmpty) {
      print('DEBUG: No fish data or selections available for pH range');
      return 'Unknown';
    }
    
    List<String> phRanges = [];
    
    for (String fishName in _getUniqueFishSpecies()) {
      final fishData = _fishData![fishName];
      if (fishData == null) {
        print('DEBUG: No fish data for $fishName');
        continue;
      }
      
      // Debug: Print available fields for this fish
      print('DEBUG: Available fields for $fishName: ${fishData.keys.toList()}');
      
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
    
    for (String fishName in _getUniqueFishSpecies()) {
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
    
    // If all fish have the same temperature range, return it with °C
    if (tempRanges.toSet().length == 1) {
      final range = tempRanges.first;
      return range.contains('°C') ? range : '$range°C';
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

  // Check compatibility for all selected fish when tank shape changes
  Future<void> _checkAllFishTankShapeCompatibility() async {
    for (String fishName in _fishSelections.keys) {
      await _checkFishTankShapeCompatibility(fishName);
    }
  }

  // Check if calculate button should be enabled
  bool _isCalculateButtonEnabled() {
    // If no fish selected or tank shape warnings exist, disable button
    if (_fishSelections.isEmpty || _fishTankShapeWarnings.isNotEmpty) {
      return false;
    }

    // If only one fish, enable button
    if (_fishSelections.length == 1) {
      return true;
    }

    // Use tracked compatibility state
    return !_hasIncompatiblePairs;
  }

  // Get the reason why calculate button is disabled
  String _getCalculateButtonDisabledReason() {
    if (_fishSelections.isEmpty) {
      return 'Please add at least one fish to calculate requirements';
    } 
    
    if (_fishTankShapeWarnings.isNotEmpty) {
      return 'Some fish are not suitable for the selected tank shape. Please change tank shape or remove incompatible fish.';
    }

    if (_hasIncompatiblePairs && _fishSelections.length > 1) {
      return _compatibilityMessage.isNotEmpty 
          ? _compatibilityMessage 
          : 'Some fish are not compatible with each other. Please remove incompatible fish.';
    }
    
    return '';
  }

  // Build tank shape warnings widget
  Widget _buildTankShapeWarningsWidget() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
            child: Icon(
              Icons.info_outline,
              color: const Color(0xFF00BCD4),
              size: 20,
            ),
          ),
          title: Text(
            'Tank Size Notice',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Color(0xFF006064),
            ),
          ),
          subtitle: Text(
            'Some fish may need a bigger tank',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
            ),
          ),
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _fishTankShapeWarnings.entries.map((entry) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: Colors.grey.shade200,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          FontAwesomeIcons.fish,
                          color: Colors.orange.shade600,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.key,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _getSimpleWarningMessage(entry.key, entry.value),
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade700,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // Convert technical warning messages to simple, user-friendly language
  String _getSimpleWarningMessage(String fishName, String technicalMessage) {
    if (technicalMessage.contains('too large for a bowl tank')) {
      return 'This fish grows too big for a small bowl tank. Try a rectangle tank instead.';
    } else if (technicalMessage.contains('needs more horizontal swimming space')) {
      return 'This fish needs more swimming space. A rectangle tank would be better.';
    } else if (technicalMessage.contains('Requires larger tank')) {
      return 'This fish needs a bigger tank. Consider a rectangle tank.';
    } else if (technicalMessage.contains('not suitable for')) {
      return 'This fish needs a different tank shape. Try a rectangle tank.';
    } else {
      return 'This fish may not be suitable for your selected tank. Consider a rectangle tank.';
    }
  }

  void _resetCalculator() {
    setState(() {
      _fishCards = [FishCard(id: 0)];  // Reset with one text controller
      _fishSelections.clear();
      _cardToFish.clear();
      _fishTankShapeWarnings.clear(); // Clear tank shape warnings
      _calculationResult = null;
      _isLoading = false;
      _isCalculating = false;
      _selectedTankShape = 'bowl';
      _bypassTemporaryHousingWarning = false;
      
      // Clear Supabase data
      _fishData = null;
      _tankmateRecommendations = null;
      _conditionalCompatibilityPairs.clear(); // Clear conditional compatibility pairs
    });
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
        });
        // Check compatibility for all selected fish when tank shape changes
        _checkAllFishTankShapeCompatibility();
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
        // BEGINNER: Bowl tanks (10-15L) - Only for nano fish
        return (fishMaxSize != null && fishMaxSize > 8) || 
               (fishMinTankSize != null && fishMinTankSize > 15);
               
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

  String _getTankShapeIncompatibilityReason(String fishName, dynamic maxSize, dynamic minTankSize, String tankShape) {
    switch (tankShape) {
      case 'bowl':
        return '$fishName is too large for a bowl tank. Bowl tanks are small and only suitable for tiny fish like bettas or small tetras.';
        
      case 'cylinder':
        return '$fishName needs more swimming space than a cylinder tank provides. Cylinder tanks are tall but narrow, limiting swimming space.';
        
      default:
        return '$fishName is not suitable for the selected tank shape.';
    }
  }


  // Check fish compatibility with tank shape and update warnings
  Future<void> _checkFishTankShapeCompatibility(String fishName) async {
    if (fishName.isEmpty) {
      setState(() {
        _fishTankShapeWarnings.remove(fishName);
      });
      return;
    }

    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('fish_species')
          .select('common_name, "max_size_(cm)", "minimum_tank_size_(l)"')
          .ilike('common_name', fishName)
          .maybeSingle();

      if (response != null) {
        final maxSize = response["max_size_(cm)"];
        final minTankSize = response["minimum_tank_size_(l)"];
        
        final isIncompatible = _isFishIncompatibleWithTankShape(fishName, maxSize, minTankSize, _selectedTankShape);
        
        setState(() {
          if (isIncompatible) {
            String warning = _getTankShapeIncompatibilityReason(fishName, maxSize, minTankSize, _selectedTankShape);
            _fishTankShapeWarnings[fishName] = warning;
          } else {
            _fishTankShapeWarnings.remove(fishName);
          }
        });
      } else {
        setState(() {
          _fishTankShapeWarnings.remove(fishName);
        });
      }
    } catch (e) {
      print('Error checking fish tank shape compatibility for $fishName: $e');
      setState(() {
        _fishTankShapeWarnings.remove(fishName);
      });
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
        // Allow temporary housing for fish up to 12cm (juveniles) but not massive fish
        return (fishMaxSize != null && fishMaxSize <= 12);
        
      case 'cylinder':
        // Allow temporary housing for fish up to 35cm
        return (fishMaxSize != null && fishMaxSize <= 35);
        
        
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
        if (fishMaxSize <= 8) return 4; // Small fish - 4 months
        if (fishMaxSize <= 12) return 2; // Medium fish - 2 months
        return 0;
        
      case 'cylinder':
        if (fishMaxSize <= 15) return 12; // Small fish - 1 year
        if (fishMaxSize <= 25) return 8;  // Medium fish - 8 months
        if (fishMaxSize <= 35) return 4;  // Large fish - 4 months
        return 0;
        
        
      default:
        return 0; // Rectangle tanks don't need temporary housing
    }
  }

  /// owlate smart tank size requirements considering shoaling behavior
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
        
        
      default:
        return 'No growth concerns for this tank shape.';
    }
  }

  Future<String> _generateAIPlanningOptions(List<Map<String, dynamic>> temporaryFish) async {
    if (temporaryFish.isEmpty) return 'No specific planning needed.';
    
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
            // Add fully compatible tankmates
            if (response['fully_compatible_tankmates'] != null) {
              final rawFullyCompatible = response['fully_compatible_tankmates'];
              if (rawFullyCompatible is List) {
                final fullyCompatible = rawFullyCompatible.map((e) {
                  if (e is Map<String, dynamic> && e.containsKey('name')) {
                    return e['name'].toString();
                  } else {
                    return e.toString();
                  }
                }).toList();
                fishFullyCompatible[fishName] = fullyCompatible.toSet();
                print('🐠 $fishName fully compatible: $fullyCompatible');
              } else {
                print('🐠 $fishName fully compatible data is not a list: $rawFullyCompatible');
              }
            }
            
            // Add conditional tankmates
            if (response['conditional_tankmates'] != null) {
              final rawConditional = response['conditional_tankmates'];
              if (rawConditional is List) {
                final conditional = rawConditional.map((e) {
                  if (e is Map<String, dynamic> && e.containsKey('name')) {
                    return e['name'].toString();
                  } else {
                    return e.toString();
                  }
                }).toList();
                fishConditional[fishName] = conditional.toSet();
                print('🐠 $fishName conditional: $conditional');
              } else {
                print('🐠 $fishName conditional data is not a list: $rawConditional');
              }
            }
          } else {
            print('🐠 No tankmate data found for $fishName');
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
      
      // Filter tankmates based on tank shape compatibility
      final tankShapeCompatibleFully = await _filterTankmatesByTankShape(commonFullyCompatible.toList());
      final tankShapeCompatibleConditional = await _filterTankmatesByTankShape(commonConditional.toList());
      
      print('🐠 After tank shape filtering:');
      print('🐠 Fully compatible: $tankShapeCompatibleFully');
      print('🐠 Conditional: $tankShapeCompatibleConditional');
      
      return {
        'fully_compatible': tankShapeCompatibleFully,
        'conditional': tankShapeCompatibleConditional,
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

  /// Filter tankmates based on tank shape compatibility
  Future<List<String>> _filterTankmatesByTankShape(List<String> tankmates) async {
    if (tankmates.isEmpty) return [];
    
    try {
      // Get fish data from Supabase to check tank shape compatibility
      final supabase = Supabase.instance.client;
      List<String> compatibleTankmates = [];
      
      for (String tankmate in tankmates) {
        try {
          final response = await supabase
              .from('fish_species')
              .select('common_name, "max_size_(cm)", "minimum_tank_size_(l)"')
              .ilike('common_name', tankmate)
              .maybeSingle();

          if (response != null) {
            final maxSize = response["max_size_(cm)"];
            final minTankSize = response["minimum_tank_size_(l)"];
            
            // Check if this tankmate is compatible with the selected tank shape
            if (!_isFishIncompatibleWithTankShape(tankmate, maxSize, minTankSize, _selectedTankShape)) {
              compatibleTankmates.add(tankmate);
              print('🐠 $tankmate is compatible with $_selectedTankShape tank (size: $maxSize, min tank: $minTankSize)');
            } else {
              print('🐠 $tankmate is NOT compatible with $_selectedTankShape tank (size: $maxSize, min tank: $minTankSize)');
            }
          } else {
            // If we can't find fish data in Supabase, include it to be safe
            compatibleTankmates.add(tankmate);
            print('🐠 $tankmate - no fish data found in Supabase, including to be safe');
          }
        } catch (e) {
          print('🐠 Error fetching fish data for $tankmate: $e');
          // Include to be safe if there's an error
          compatibleTankmates.add(tankmate);
        }
      }
      
      return compatibleTankmates;
    } catch (e) {
      print('🐠 Error filtering tankmates by tank shape: $e');
      return tankmates; // Return all if filtering fails
    }
  }


  Widget _buildRealTimeCompatibilityCheck() {
    // Don't call _updateCompatibilityState() here to avoid infinite API calls
    // The FutureBuilder below will call _getRealTimeCompatibilityResults() only once per build
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
              Icons.psychology,
              color: Color(0xFF006064),
            ),
          ),
          title: const Text(
            'Real-time Compatibility Check',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF006064),
            ),
          ),
          subtitle: FutureBuilder<Map<String, dynamic>>(
            future: _getRealTimeCompatibilityResults(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Text(
                  'Checking compatibility...',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                );
              } else if (snapshot.hasData) {
                final results = snapshot.data!;
                final incompatiblePairs = results['incompatible_pairs'] as List<Map<String, dynamic>>? ?? [];
                final conditionalPairs = results['conditional_pairs'] as List<Map<String, dynamic>>? ?? [];
                final total = incompatiblePairs.length + conditionalPairs.length;
                
                if (total > 0) {
                  return Text(
                    'Tap to view $total compatibility issues (${incompatiblePairs.length} incompatible, ${conditionalPairs.length} conditional)',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  );
                } else {
                  return const Text(
                    'All selected fish are compatible!',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green,
                    ),
                  );
                }
              } else {
                return const Text(
                  'Unable to check compatibility',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                );
              }
            },
          ),
          children: [
            FutureBuilder<Map<String, dynamic>>(
              future: _getRealTimeCompatibilityResults(),
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
                        'Checking compatibility...',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF006064),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  );
                } else if (snapshot.hasData) {
                  final results = snapshot.data!;
                  final incompatiblePairs = results['incompatible_pairs'] as List<Map<String, dynamic>>? ?? [];
                  final conditionalPairs = results['conditional_pairs'] as List<Map<String, dynamic>>? ?? [];
                  
                  if (incompatiblePairs.isEmpty && conditionalPairs.isEmpty) {
                    return Row(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'All selected fish are compatible!',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.green,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    );
                  } else {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Incompatible Pairs
                        if (incompatiblePairs.isNotEmpty) ...[
                          _buildCompatibilitySection(
                            'Incompatible Fish',
                            incompatiblePairs,
                            Icons.cancel,
                            Colors.red,
                          ),
                          const SizedBox(height: 16),
                        ],
                        // Conditional Pairs
                        if (conditionalPairs.isNotEmpty) ...[
                          _buildCompatibilitySection(
                            'Compatible with Conditions',
                            conditionalPairs,
                            Icons.warning,
                            Colors.orange,
                          ),
                        ],
                      ],
                    );
                  }
                } else {
                  return const Text(
                    'Unable to check compatibility',
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
    );
  }

  // Update real-time compatibility state
  Future<void> _updateCompatibilityState() async {
    // Calculate total fish count (including quantities)
    final totalFishCount = _fishSelections.values.fold<int>(0, (sum, qty) => sum + qty);
    
    if (totalFishCount <= 1) {
      setState(() {
        _hasIncompatiblePairs = false;
        _compatibilityMessage = '';
      });
      return;
    }

    try {
      final results = await _getRealTimeCompatibilityResults();
      final incompatiblePairs = results['incompatible_pairs'] as List? ?? [];
      
      setState(() {
        _hasIncompatiblePairs = incompatiblePairs.isNotEmpty;
        _compatibilityMessage = _hasIncompatiblePairs
            ? 'Some fish are not compatible with each other. Please remove incompatible fish.'
            : '';
      });
    } catch (e) {
      print('Error updating compatibility state: $e');
      setState(() {
        _hasIncompatiblePairs = false;
        _compatibilityMessage = 'Unable to verify fish compatibility';
      });
    }
  }

  Future<Map<String, dynamic>> _getRealTimeCompatibilityResults() async {
    try {
      final fishNames = _fishSelections.keys.toList();
      
      // Calculate total fish count (including quantities)
      final totalFishCount = _fishSelections.values.fold<int>(0, (sum, qty) => sum + qty);
      
      if (totalFishCount < 2) {
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
        'incompatible_pairs': incompatiblePairs,
        'conditional_pairs': conditionalPairs,
      };
    } catch (e) {
      print('Error getting real-time compatibility results: $e');
      return {'incompatible_pairs': [], 'conditional_pairs': []};
    }
  }

  Widget _buildConditionalCompatibilityWarning() {
    final conditionalPairs = _calculationResult!['conditional_compatibility_warnings'] as List<Map<String, dynamic>>? ?? [];
    
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

  Widget _buildTankmateRecommendationsWidget() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
              fontSize: 16,
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
                  'Unable to load tankmate recommendations',
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
                            color: Colors.green,
                            description: 'These fish are highly compatible with your selection',
                          ),
                          const SizedBox(height: 16),
                        ],
                        // Conditional Section
                        if (conditional.isNotEmpty) ...[
                          _buildTankmateSection(
                            title: 'Compatible with Conditions',
                            tankmates: conditional,
                            icon: Icons.warning,
                            color: Colors.orange,
                            description: 'These fish may work with proper setup and monitoring',
                          ),
                        ],
                        
                        // Tank Shape Warning
                        if (fullyCompatible.isEmpty && conditional.isEmpty) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.orange.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Colors.orange.shade700,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'No tankmates found for ${_getShapeLabel(_selectedTankShape)}. Consider switching to a Rectangle tank for more options.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.orange.shade800,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
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
                    'Unable to load tankmate recommendations',
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
    );
  }

  Widget _buildCompatibilitySection(String title, List<Map<String, dynamic>> pairs, IconData icon, Color color) {
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
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Text(
                '${pairs.length}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Compatibility pairs with reasons
        ...pairs.map((pair) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.05),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fish pair
              Row(
                children: [
                  Icon(icon, color: color, size: 14),
                  const SizedBox(width: 8),
                  Text(
                    '${pair['pair'][0]} + ${pair['pair'][1]}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: color,
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
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        reason.toString(),
                        style: TextStyle(
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
    );
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
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Text(
                '${tankmates.length}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Tankmate chips
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: tankmates.take(10).map((tankmate) => GestureDetector(
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => FishInfoDialog(fishName: tankmate),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: color.withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tankmate,
                    style: TextStyle(
                      fontSize: 12,
                      color: color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.remove_red_eye,
                    size: 14,
                    color: color,
                  ),
                ],
              ),
            ),
          )).toList(),
        ),
      ],
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
              borderRadius: BorderRadius.circular(6),
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
                        borderRadius: BorderRadius.circular(6),
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
                        borderRadius: BorderRadius.circular(6),
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
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(6),
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

  Widget _buildCompatibilityResults(Map<String, dynamic> results) {
    List<Map<String, dynamic>> incompatiblePairs = [];
    List<Map<String, dynamic>> conditionalPairs = [];
    
    if (results['incompatible_pairs'] != null) {
      incompatiblePairs = (results['incompatible_pairs'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    
    if (results['conditional_pairs'] != null) {
      conditionalPairs = (results['conditional_pairs'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    
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
              onPressed: _resetCalculator,  // Use the new reset function
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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
                          _buildSuggestionSection(),
                          _buildTankShapeSelector(),
                          ..._fishCards.map((card) => _buildFishInput(card)),
                          // Tank shape compatibility warnings
                          if (_fishTankShapeWarnings.isNotEmpty) _buildTankShapeWarningsWidget(),
                          // Real-time compatibility check (show if total fish count >= 2)
                          if (_fishSelections.values.fold<int>(0, (sum, qty) => sum + qty) >= 2) _buildRealTimeCompatibilityCheck(),
                          // Tankmate recommendations for selected fish
                          if (_fishSelections.isNotEmpty) _buildTankmateRecommendationsWidget(),
                        ] else ...[
                          // Show results - check for specific issues first, then show main results
                          if (_calculationResult!['temporary_housing_issues'] != null)
                            _buildTemporaryHousingWarning(_calculationResult!)
                          else if (_calculationResult!['tank_shape_issues'] != null)
                            _buildTankShapeIncompatibilityResults(_calculationResult!)
                          else if (_calculationResult!['incompatible_pairs'] != null)
                            _buildCompatibilityResults(_calculationResult!)
                          else
                            _buildWaterRequirements(),
                        ],

                      ],
                    ),
                  ),
                ),
                // Bottom action buttons - simplified
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Colors.grey.shade200)),
                  ),
                  child: SafeArea(
                  child: Row(
                    children: [
                      if (_calculationResult == null) ...[
                          // Add fish button - minimal
                        Expanded(
                            child: TextButton.icon(
                            onPressed: _addNewTextField,
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                              icon: const Icon(Icons.add, color: Color(0xFF00BCD4), size: 18),
                            label: const Text(
                              'Add Fish',
                                style: TextStyle(
                                  color: Color(0xFF00BCD4), 
                                  fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                          ),
                          const SizedBox(width: 12),
                          // Calculate button - minimal
                        Expanded(
                          child: Tooltip(
                            message: _isCalculateButtonEnabled() ? '' : _getCalculateButtonDisabledReason(),
                            child: ElevatedButton(
                              onPressed: _isCalculateButtonEnabled() ? () {
                                if (!_hasIncompatiblePairs) {
                                  _calculateRequirements();
                                }
                              } : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isCalculateButtonEnabled() && !_hasIncompatiblePairs
                                    ? const Color(0xFF00BCD4) 
                                    : Colors.grey.shade300,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              child: Text(
                                _fishSelections.isEmpty 
                                    ? 'Add Fish to Calculate' 
                                    : _fishTankShapeWarnings.isNotEmpty 
                                        ? 'Fix Tank Issues First' 
                                        : 'Calculate',
                                style: TextStyle(
                                  color: _isCalculateButtonEnabled() 
                                      ? Colors.white 
                                      : Colors.grey.shade500,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                      if (_calculationResult != null && !_calculationResult!.containsKey('incompatible_pairs') && !_calculationResult!.containsKey('tank_shape_issues') && !_calculationResult!.containsKey('temporary_housing_issues')) ...[
                        Expanded(
                          child: TextButton(
                            onPressed: _resetCalculator,
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.grey[200],
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            child: const Text(
                              'Try Again',
                              style: TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.w500,
                                  fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                          const SizedBox(width: 12),
                        Expanded(
                            child: ElevatedButton.icon(
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
                              
                              // Get minimum tank volume with fallback
                              final minTankVolume = _calculationResult!['requirements']?['minimum_tank_volume']?.toString() ?? 'Unknown';
                              
                              print('DEBUG: Creating WaterCalculation with:');
                              print('  - Fish selections: $_fishSelections');
                              print('  - Min tank volume: $minTankVolume');
                              print('  - pH range: ${_getPhRangeFromFishData()}');
                              print('  - Temperature range: ${_getTemperatureRangeFromFishData()}');
                              print('  - Tank shape: $_selectedTankShape');
                              print('  - Tankmate recommendations: $_tankmateRecommendations');
                              print('  - Feeding information: ${_getFeedingInformation()}');
                              
                              final calculation = WaterCalculation(
                                fishSelections: Map<String, int>.from(_fishSelections),
                                minimumTankVolume: minTankVolume,
                                phRange: _getPhRangeFromFishData(),
                                temperatureRange: _getTemperatureRangeFromFishData(),
                                recommendedQuantities: Map<String, int>.from(_fishSelections),
                                dateCalculated: DateTime.now(),
                                tankStatus: 'N/A',
                                waterParametersResponse: null,
                                tankAnalysisResponse: null,
                                filtrationResponse: null,
                                dietCareResponse: null,
                                tankmateRecommendations: _tankmateRecommendations?.isNotEmpty == true ? _tankmateRecommendations : null,
                                tankShape: _selectedTankShape,
                                waterRequirements: {
                                  'temperature_range': _getTemperatureRangeFromFishData(),
                                  'pH_range': _getPhRangeFromFishData(),
                                  'minimum_tank_volume': minTankVolume,
                                },
                                feedingInformation: _getFeedingInformation().isNotEmpty ? _getFeedingInformation() : null,
                              );
                              
                              try {
                                await Provider.of<LogBookProvider>(context, listen: false)
                                .addWaterCalculation(calculation);
                                
                              showCustomNotification(context, 'Water calculation saved to history');
                              } catch (e) {
                                print('ERROR: Failed to save water calculation: $e');
                                showCustomNotification(
                                  context, 
                                  'Failed to save calculation: ${e.toString()}',
                                  isError: true,
                                );
                                return;
                              }
                              
                              // Wait for notification to be visible
                              await Future.delayed(const Duration(milliseconds: 1500));
                              
                              if (!mounted) return;
                              
                              // Reset calculator state instead of navigating
                              _resetCalculator();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00BCD4),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                              label: const Text(
                                'Save to Collection',
                              style: TextStyle(
                                color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
} 