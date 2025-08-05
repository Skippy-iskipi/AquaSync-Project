import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import '../screens/logbook_provider.dart';
import '../models/water_calculation.dart';
import '../config/api_config.dart';
import '../widgets/custom_notification.dart';
import 'dart:async';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../services/openai_service.dart';

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
      showCustomNotification(
        context,
        'Error loading fish list: ${e.toString()}',
        isError: true,
      );
    } finally {
      setState(() => _isLoading = false);
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

    setState(() => _isLoading = true);
    try {
      // Check compatibility for 2 or more fish
      if (_fishSelections.length >= 2) {
        final compatibilityResponse = await http.post(
          Uri.parse(ApiConfig.checkGroupEndpoint),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json'
          },
          body: json.encode({'fish_names': _fishSelections.keys.toList()}),
        ).timeout(ApiConfig.timeout);

        if (compatibilityResponse.statusCode != 200) {
          throw Exception('Failed to check compatibility: ${compatibilityResponse.statusCode}');
        }

        final compatibilityData = json.decode(compatibilityResponse.body);
        bool hasIncompatiblePairs = false;
        List<Map<String, dynamic>> incompatiblePairs = [];
        
        for (var result in compatibilityData['results']) {
          if (result['compatibility'] == 'Not Compatible') {
            hasIncompatiblePairs = true;
            incompatiblePairs.add({
              'pair': result['pair'],
              'reasons': result['reasons'],
            });
          }
        }

        if (hasIncompatiblePairs) {
          setState(() {
            _calculationResult = {
              'error': 'Incompatible Fish Combinations',
              'incompatible_pairs': incompatiblePairs,
            };
            _isLoading = false;
          });
          return;
        }
      }

      // Calculate water requirements
      final waterResponse = await http.post(
        Uri.parse(ApiConfig.calculateRequirementsEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        },
        body: json.encode({'fish_selections': _fishSelections}),
      ).timeout(ApiConfig.timeout);

      if (waterResponse.statusCode != 200) {
        throw Exception('Failed to calculate water requirements: ${waterResponse.statusCode}');
      }

      final responseData = json.decode(waterResponse.body);
      setState(() {
        _calculationResult = responseData;
      });

      // After calculation, generate care recommendations for all fish
      await _generateAllRecommendations();

    } catch (e) {
      print('Error calculating requirements: $e');
      showCustomNotification(
        context,
        'Error calculating requirements. Please try again.',
        isError: true,
      );
      setState(() {
        _calculationResult = null;
      });
    } finally {
      setState(() => _isLoading = false);
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
                                title: Text(
                                  fishName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.black87,
                                    fontWeight: FontWeight.bold,
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
                      const SizedBox(height: 24),
                      // pH Range
                      _buildParameterRow(
                        icon: Icons.science,
                        label: 'pH Range',
                        value: _calculationResult!['requirements']['pH_range'],
                      ),
                      const SizedBox(height: 16),
                      // Temperature
                      _buildParameterRow(
                        icon: Icons.thermostat,
                        label: 'Temperature',
                        value: _calculationResult!['requirements']['temperature_range'].replaceAll('Â', ''),
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
    });
  }

  Widget _buildIncompatibilityResults(List<Map<String, dynamic>> incompatiblePairs) {
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
              children: incompatiblePairs.map((pair) {
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
                            const Icon(
                              FontAwesomeIcons.fish,
                              color: Color(0xFF006064),
                              size: 18,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '${pair['pair'][0]} + ${pair['pair'][1]}',
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
                          padding: const EdgeInsets.only(left: 30, bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                margin: const EdgeInsets.only(top: 6),
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFF6B6B),
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
              }).toList(),
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
      body: Container(
        color: Colors.white,
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    return Stack(
      children: [
        if (_isLoading)
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
                        if (_calculationResult == null)
                          ..._fishCards.map((card) => _buildFishInput(card))
                        else if (_calculationResult!['incompatible_pairs'] != null)
                          _buildIncompatibilityResults(_calculationResult!['incompatible_pairs'])
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
                          child: ElevatedButton(
                            onPressed: _addNewTextField,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00BCD4),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Add',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
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
                      if (_calculationResult != null && !_calculationResult!.containsKey('incompatible_pairs')) ...[
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
                            onPressed: () async {
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
                              );
                              
                              Provider.of<LogBookProvider>(context, listen: false)
                                .addWaterCalculation(calculation);
                                
                              showCustomNotification(context, 'Water calculation saved to logbook');
                              
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