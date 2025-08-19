import 'package:flutter/material.dart';
import '../models/fish_calculation.dart';
import 'package:provider/provider.dart';
import 'logbook_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_config.dart';
import '../widgets/custom_notification.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class FishCalculatorVolume extends StatefulWidget {
  const FishCalculatorVolume({super.key});

  @override
  _FishCalculatorVolumeState createState() => _FishCalculatorVolumeState();
}

class _FishCalculatorVolumeState extends State<FishCalculatorVolume> {
  String _selectedUnit = 'L';
  final TextEditingController _volumeController = TextEditingController();
  final TextEditingController _fishController1 = TextEditingController();
  List<String> _fishSpecies = [];
  bool _isCalculating = false;
  Map<String, int> _fishSelections = {};
  Map<String, dynamic>? _calculationData;
  List<String> _suggestions = [];

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

  void _clearFishInputs() {
    setState(() {
      _fishSelections = {};
      _fishController1.clear();
      _volumeController.clear();
      _suggestions = [];
      _calculationData = null;
    });
  }

  Future<void> _saveCalculation() async {
    if (_calculationData == null) return;

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
        'Please enter tank volume',
        isError: true,
      );
      return;
    }

    setState(() {
      _isCalculating = true;
      _calculationData = null;
    });

    try {
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
          _calculationData = {
            ...data,
            'fish_selections': _fishSelections,
          };
          
          final tankDetails = data['tank_details'];
          final waterConditions = data['water_conditions'];
          final fishDetails = data['fish_details'];
          final compatibilityIssues = data['compatibility_issues'] as List;

          // Build compatibility issues text
          String compatibilityText = '';
          if (compatibilityIssues.isNotEmpty) {
            compatibilityText = '\nCompatibility Issues:\n';
            for (var issue in compatibilityIssues) {
              final pair = issue['pair'] as List;
              final reasons = issue['reasons'] as List;
              compatibilityText += '• ${pair[0]} and ${pair[1]}:\n  ${reasons.join("\n  ")}\n';
            }
          }

          // Build fish details text
          String fishDetailsText = fishDetails.map((f) {
            final recommendedQty = f['recommended_quantity'] ?? "N/A";
            return '• ${f['name']}:\n'
                '  Recommended: $recommendedQty\n'
                '  Min Tank Size: ${f['individual_requirements']['minimum_tank_size']}';
          }).join('\n\n');

          setState(() {
                'Current Volume: ${tankDetails['volume']}\n\n'
                'Water Conditions:\n'
                '• Temperature: ${waterConditions['temperature_range'].replaceAll('Â', '')}\n'
                '• pH Range: ${waterConditions['pH_range']}\n\n'
                'Fish Details:\n$fishDetailsText\n'
                '$compatibilityText';
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
                            child: Text(
                              entry.key,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
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
                        child: ExpansionTile(
                          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: Container(
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
                          title: Text(
                            fish['name'],
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Row(
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
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (fish['individual_requirements'] != null && 
                                      fish['individual_requirements']['minimum_tank_size'] != null) ...[
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.straighten,
                                          size: 16,
                                          color: Color(0xFF006064),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Min tank size: ${fish['individual_requirements']['minimum_tank_size']}',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                  if (fish['school_size'] != null) ...[
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.groups,
                                          size: 16,
                                          color: Color(0xFF006064),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'School size: ${fish['school_size']}',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.info_outline,
                                        size: 16,
                                        color: Color(0xFF006064),
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          'Our recommendation is based on tank volume, fish bioload, and optimal living conditions.',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey[700],
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
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
                      // pH Range
                      _buildParameterRow(
                        icon: Icons.science,
                        label: 'pH Range',
                        value: _calculationData!['water_conditions']['pH_range'],
                      ),
                      const SizedBox(height: 16),
                      // Temperature
                      _buildParameterRow(
                        icon: Icons.thermostat,
                        label: 'Temperature',
                        value: _calculationData!['water_conditions']['temperature_range'].replaceAll('Â', ''),
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
                                      child: Text(
                                        '${pair[0]} + ${pair[1]}',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFFE53935),
                                        ),
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
            child: TextField(
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
        child: Stack(
          children: [
            if (_isCalculating)
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
                            if (_calculationData == null)
                              Column(
                                children: [
                                  _buildVolumeInput(),
                                  _buildFishInput(),
                                ],
                              )
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
                    else if (_calculationData!['compatibility_issues'] == null || 
                           (_calculationData!['compatibility_issues'] as List).isEmpty)
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
} 