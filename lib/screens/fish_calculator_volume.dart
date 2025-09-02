import 'package:flutter/material.dart';
import '../models/fish_calculation.dart';
import 'package:provider/provider.dart';
import 'logbook_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
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
import '../services/openai_service.dart';

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
  List<String> _suggestions = [];
  bool _showAllShapes = false;

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

  

  @override
  void initState() {
    super.initState();
    _loadFishSpecies();
  }

  @override
  void dispose() {
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
        Uri.parse(ApiConfig.fishSpeciesEndpoint),
        headers: {'Accept': 'application/json'}
      ).timeout(ApiConfig.timeout);
      
      if (response.statusCode == 200) {
        final List<dynamic> species = jsonDecode(response.body);
        setState(() {
          _fishSpecies = species.map((s) => s.toString()).toList();
        });
      } else {
        print('Error loading fish species: ${response.statusCode}');
      }
    } catch (e) {
      print('Error loading fish species: $e');
    }
  }

  void _updateSuggestions(String query) {
    if (query.isEmpty) {
      setState(() {
        _suggestions = [];
      });
      return;
    }

    setState(() {
      _suggestions = _fishSpecies
          .where((species) =>
              species.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  void _selectFish(String fish) {
    setState(() {
      _fishController1.text = fish;
      _suggestions = [];
    });
  }

  void _addFish() {
    final fishName = _fishController1.text.trim();
    if (fishName.isEmpty) {
      showCustomNotification(
        context,
        'Please enter a fish species',
        isError: true,
      );
      return;
    }

    // Check if the fish exists in the available species
    if (!_fishSpecies.contains(fishName)) {
      showCustomNotification(
        context,
        'Please select a valid fish from the suggestions',
        isError: true,
      );
      return;
    }

    setState(() {
      // If the fish is already in selections, increment its count
      if (_fishSelections.containsKey(fishName)) {
        _fishSelections[fishName] = _fishSelections[fishName]! + 1;
      } else {
        // Otherwise add it with count 1
        _fishSelections[fishName] = 1;
      }
      _fishController1.clear();
      _suggestions = [];
    });
  }

  void _addFishByName(String fishName) {
    if (!_fishSpecies.contains(fishName)) return;
    
    setState(() {
      if (_fishSelections.containsKey(fishName)) {
        _fishSelections[fishName] = _fishSelections[fishName]! + 1;
      } else {
        _fishSelections[fishName] = 1;
      }
    });
  }

  void _clearFishInputs() {
    setState(() {
      _fishSelections = {};
      _fishController1.clear();
      _volumeController.clear();
      _suggestions = [];
      _calculationData = null;
      _selectedTankShape = 'bowl';
      _showAllShapes = false;
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

    final calculation = FishCalculation(
      tankVolume: _calculationData!['tank_details']['volume'],
      fishSelections: _fishSelections,
      recommendedQuantities: recommendedQuantities,
      dateCalculated: DateTime.now(),
      phRange: _calculationData!['water_conditions']['pH_range'],
      temperatureRange: _calculationData!['water_conditions']['temperature_range'],
      tankStatus: _calculationData!['tank_details']['status'],
      currentBioload: _calculationData!['tank_details']['current_bioload'],
      waterParametersResponse: _waterParametersResponse,
      tankAnalysisResponse: _tankAnalysisResponse,
      filtrationResponse: _filtrationResponse,
      dietCareResponse: _dietCareResponse,
      tankmateRecommendations: _tankmateRecommendations,
    );

    final logBookProvider = Provider.of<LogBookProvider>(context, listen: false);
    logBookProvider.addFishCalculation(calculation);

    showCustomNotification(context, 'Fish calculation saved to history');
    
    // Clear all inputs and reset state
    setState(() {
      _clearFishInputs();
      _volumeController.clear();
      _calculationData = null;
    });
  }

  Future<void> _calculateRequirements() async {
    if (_volumeController.text.isEmpty) {
      showCustomNotification(
        context,
        'Please enter tank volume or use the Dimensions Calculator if you don\'t know it',
        isError: true,
      );
      return;
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
      double volume = double.parse(_volumeController.text);
      if (_selectedUnit == 'gal') {
        volume = volume * 3.78541; // Convert gallons to liters
      }

      print('Request URL: ${ApiConfig.calculateCapacityEndpoint}');
      print('Request body: ${jsonEncode({
        'tank_volume': volume,
        'fish_selections': _fishSelections,
      })}');
      
      final response = await http.post(
        Uri.parse(ApiConfig.calculateCapacityEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        },
        body: jsonEncode({
          'tank_volume': volume,
          'fish_selections': _fishSelections,
          'tank_shape': _selectedTankShape,
        }),
      );

      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        if (response.body.isEmpty) {
          throw Exception('Server returned an empty response');
        }

        try {
          final data = jsonDecode(response.body);
          setState(() {
            _calculationData = {
              ...data,
              'fish_selections': _fishSelections,
            };
            _isCalculating = false;
          });
        } catch (e) {
          print('Error parsing response: $e');
          throw Exception('Failed to parse response');
        }
      } else {
        print('Error response body: ${response.body}');
        String errorMessage;
        try {
          final errorBody = jsonDecode(response.body);
          errorMessage = errorBody['error'] ?? 'Unknown error occurred';
        } catch (e) {
          errorMessage = response.body.isNotEmpty 
              ? 'Server error: ${response.body}'
              : 'Server returned status code ${response.statusCode}';
        }
        throw Exception('Failed to calculate requirements: $errorMessage');
      }
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

  Widget _buildFishInput() {
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
          // Display selected fish
          if (_fishSelections.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFE0F7FA),
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        FontAwesomeIcons.fish,
                        color: Color(0xFF006064),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Selected Fish',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF006064),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  for (var entry in _fishSelections.entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${entry.value}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF006064),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => FishInfoDialog(fishName: entry.key),
                                );
                              },
                              child: Text(
                                entry.key,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF006064),
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Color(0xFF006064)),
                            onPressed: () {
                              setState(() {
                                _fishSelections.remove(entry.key);
                              });
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
          ],
          // Input section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _fishSelections.isEmpty ? const Color(0xFFE0F7FA) : Colors.white,
              borderRadius: _fishSelections.isEmpty
                ? const BorderRadius.vertical(top: Radius.circular(12))
                : BorderRadius.zero,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_fishSelections.isEmpty) ...[
                  Row(
                    children: [
                      const Icon(
                        FontAwesomeIcons.fish,
                        color: Color(0xFF006064),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Fish Species',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF006064),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _fishController1,
                    decoration: InputDecoration(
                      hintText: 'Enter fish species',
                      filled: true,
                      fillColor: const Color(0xFFF5F5F5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    onChanged: (value) => _updateSuggestions(value),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _addFish,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00ACC1),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Add',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          if (_suggestions.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _suggestions.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    leading: const Icon(FontAwesomeIcons.fish, color: Color(0xFF006064)),
                    title: Text(_suggestions[index]),
                    onTap: () => _selectFish(_suggestions[index]),
                  );
                },
              ),
            ),
          // Show tankmate recommendations for each selected fish
          ..._fishSelections.keys.map((fishName) => 
            FishCardTankmates(
              fishName: fishName,
              onFishSelected: (selectedFish) {
                _addFishByName(selectedFish);
              },
            ),
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
                        _calculationData!['tank_details']['volume'],
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
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
                          borderRadius: BorderRadius.circular(12),
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
                                  borderRadius: BorderRadius.circular(8),
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
                                              borderRadius: BorderRadius.circular(4),
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
                                            borderRadius: BorderRadius.circular(8),
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
                      // AI-generated water parameters
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
                                  ),
                                ),
                              ],
                            );
                          } else if (snapshot.hasError) {
                            return Text(
                              'Unable to generate water parameters. Please try again.',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            );
                          } else {
                            final response = snapshot.data ?? 'No water parameters available.';
                            final words = response.split(' ');
                            final displayText = _showFullWaterParameters 
                                ? response 
                                : words.take(25).join(' ');
                            
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayText,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF006064),
                                    height: 1.5,
                                  ),
                                ),
                                if (words.length > 25) ...[
                                  const SizedBox(height: 8),
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _showFullWaterParameters = !_showFullWaterParameters;
                                      });
                                    },
                                    child: Text(
                                      _showFullWaterParameters ? 'See less' : 'See more',
                                      style: const TextStyle(
                                        color: Color(0xFF00BCD4),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
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
                            return Text(
                              'This ${_getShapeLabel(_selectedTankShape).toLowerCase()} tank provides adequate swimming space and surface area for gas exchange. Consider the fish species requirements for optimal health.',
                              style: const TextStyle(
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
          // Filtration & Equipment Card
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
        onTimeout: () => 'Unable to generate water parameters at this time. Please try again later.',
      );
      
      return aiResponse;
    } catch (e) {
      return 'Unable to generate water parameters. Please check your connection and try again.';
    }
  }

  Future<String> _generateTankEnvironmentAnalysis() async {
    try {
      final fishNames = _fishSelections.keys.toList();
      final tankVolume = _calculationData!['tank_details']['volume'];
      final tankShape = _getShapeLabel(_selectedTankShape);
      
      // Extract recommended quantities from fish_details
      final fishDetails = _calculationData!['fish_details'] as List<dynamic>;
      final quantityText = fishDetails
          .map((fish) => '${fish['recommended_quantity']} ${fish['name']}')
          .join(', ');
      
      final aiPrompt = """
      Explain why this tank setup is optimal for these fish in EXACTLY 50 words:
      Fish: ${fishNames.join(', ')}
      Recommended Quantities: $quantityText
      Tank Volume: $tankVolume
      Tank Shape: $tankShape
      
      Provide a detailed, educational explanation covering:
      - Why these specific quantities are ideal for this tank volume
      - How the tank volume supports the recommended fish quantities
      - Benefits of this tank shape for swimming patterns and gas exchange
      - Key environmental factors and considerations
      - Any special requirements or recommendations
      
      Be comprehensive, educational, and practical. Count your words carefully - maximum 50 words total.
      """;
      
      print('🧠 Generating tank environment analysis for: ${fishNames.join(', ')}');
      final aiResponse = await OpenAIService.getChatResponse(aiPrompt).timeout(
        const Duration(seconds: 25),
      );
      
      print('🧠 AI Response: $aiResponse');
      
      if (aiResponse.isNotEmpty && aiResponse.trim().isNotEmpty) {
        return aiResponse.trim();
      }
    } catch (e) {
      print('🧠 AI tank environment analysis failed: $e');
    }
    
    // Return a more detailed fallback
    final fishNames = _fishSelections.keys.toList();
    final tankVolume = _calculationData!['tank_details']['volume'];
    final tankShape = _getShapeLabel(_selectedTankShape);
    
    return 'This ${tankShape.toLowerCase()} tank ($tankVolume) provides adequate swimming space and surface area for gas exchange. The recommended quantities of ${fishNames.join(', ')} are suitable for this tank size and shape.';
  }

  Future<String> _generateFiltrationRecommendations() async {
    try {
      final fishNames = _fishSelections.keys.toList();
      final tankVolume = _calculationData!['tank_details']['volume'];
      
      // Extract recommended quantities from fish_details
      final fishDetails = _calculationData!['fish_details'] as List<dynamic>;
      final quantityText = fishDetails
          .map((fish) => '${fish['recommended_quantity']} ${fish['name']}')
          .join(', ');
      
      final aiPrompt = """
      Recommend filtration for this aquarium setup in EXACTLY 50 words:
      Fish: ${fishNames.join(', ')}
      Recommended Quantities: $quantityText
      Tank Volume: $tankVolume
      
      Provide detailed, educational filter recommendations covering:
      - Recommended filter type and capacity for this setup
      - Filtration rate (turnover) requirements and why they matter
      - How the recommended fish quantities affect filtration needs
      - Maintenance schedule and procedures for optimal performance
      - Special considerations for these specific fish species
      - Additional equipment recommendations if needed
      
      Be comprehensive, educational, and practical. Count your words carefully - maximum 50 words total.
      """;
      
      print('🧠 Generating filtration recommendations for: ${fishNames.join(', ')}');
      final aiResponse = await OpenAIService.getChatResponse(aiPrompt).timeout(
        const Duration(seconds: 25),
      );
      
      print('🧠 AI Response: $aiResponse');
      
      if (aiResponse.isNotEmpty && aiResponse.trim().isNotEmpty) {
        return aiResponse.trim();
      }
    } catch (e) {
      print('🧠 AI filtration recommendations failed: $e');
    }
    
    // Return a more detailed fallback
    final tankVolume = _calculationData!['tank_details']['volume'];
    final fishNames = _fishSelections.keys.toList();
    
    return 'Use a filter rated for $tankVolume or larger with 4-6x tank volume turnover per hour. For ${fishNames.join(', ')}, consider canister or hang-on-back filters. Clean filter media monthly and monitor water quality weekly for optimal fish health.';
  }

  Future<String> _generateDietAndCareTips() async {
    try {
      final fishNames = _fishSelections.keys.toList();
      
      // Extract recommended quantities from fish_details
      final fishDetails = _calculationData!['fish_details'] as List<dynamic>;
      final quantityText = fishDetails
          .map((fish) => '${fish['recommended_quantity']} ${fish['name']}')
          .join(', ');
      
      final aiPrompt = """
      Provide diet and care tips for these fish in EXACTLY 50 words:
      Fish: ${fishNames.join(', ')}
      Recommended Quantities: $quantityText
      
      Provide detailed, educational recommendations covering:
      - Feeding frequency, amounts, and timing for optimal health
      - How the recommended quantities affect feeding requirements
      - Food types (flakes, pellets, live food) and nutritional requirements
      - Water change schedule, procedures, and why they're important
      - Special care requirements and behavioral monitoring
      - Health monitoring tips and common issues to watch for
      - Environmental factors that affect fish well-being
      
      Be comprehensive, educational, and practical. Count your words carefully - maximum 50 words total.
      """;
      
      print('🧠 Generating diet and care tips for: ${fishNames.join(', ')}');
      final aiResponse = await OpenAIService.getChatResponse(aiPrompt).timeout(
        const Duration(seconds: 25),
      );
      
      print('🧠 AI Response: $aiResponse');
      
      if (aiResponse.isNotEmpty && aiResponse.trim().isNotEmpty) {
        return aiResponse.trim();
      }
    } catch (e) {
      print('🧠 AI diet and care tips failed: $e');
    }
    
    // Return a more detailed fallback
    final fishNames = _fishSelections.keys.toList();
    
    return 'Feed ${fishNames.join(', ')} 1-2 times daily, only what they eat in 2-3 minutes. Use high-quality flakes or pellets as staple diet. Perform 25% water changes weekly and monitor fish behavior daily for signs of stress or illness.';
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
              color: const Color(0xFFE0F7FA),
              borderRadius: BorderRadius.circular(12),
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
                      for (var entry in _fishSelections.entries)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE0F7FA),
                                  borderRadius: BorderRadius.circular(8),
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
                      borderRadius: BorderRadius.circular(8),
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

  Widget _buildVolumeInput() {
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
                      FontAwesomeIcons.water,
                      color: Color(0xFF006064),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Tank Volume',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF006064),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
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
                      }
                    },
                    style: const TextStyle(
                      color: Color(0xFF006064),
                      fontSize: 16,
                    ),
                    underline: Container(),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _volumeController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Enter tank volume',
                    filled: true,
                    fillColor: const Color(0xFFF5F5F5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),

              ],
            ),
          ),
        ],
      ),
    );
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
              'reason': _getTankShapeIncompatibilityReason(fishName, maxSize, minTankSize, _selectedTankShape),
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

  /// Calculate smart tank size requirements considering shoaling behavior
  Map<String, dynamic> _calculateSmartTankSize(String fishName, int quantity, Map<String, dynamic> fishData) {
    final minTankSize = fishData['minimum_tank_size_l'] ?? fishData['min_tank_size'] ?? fishData['tank_size_required'];
    final socialBehavior = fishData['social_behavior']?.toString().toLowerCase() ?? '';
    final maxSize = fishData['max_size'];
    
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Volume Calculator',
          style: TextStyle(color: Color(0xFF006064), fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: Color(0xFF006064)),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const BeginnerGuideDialog(calculatorType: 'volume'),
              );
            },
          ),
        ],
      ),
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
                                ],
                              )
                            else if (_calculationData!['tank_shape_issues'] != null)
                              _buildTankShapeIncompatibilityResults(_calculationData!)
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
                                onPressed: _saveCalculation,
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
                            const Icon(FontAwesomeIcons.fish, color: Color(0xFF006064), size: 16),
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
} 