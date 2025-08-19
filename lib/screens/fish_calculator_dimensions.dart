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
import '../services/openai_service.dart';
import '../widgets/expandable_reason.dart';

class FishCalculatorDimensions extends StatefulWidget {
  const FishCalculatorDimensions({super.key});

  @override
  _FishCalculatorDimensionsState createState() => _FishCalculatorDimensionsState();
}

class _FishCalculatorDimensionsState extends State<FishCalculatorDimensions> {
  String _selectedUnit = 'CM';
  final TextEditingController _depthController = TextEditingController();
  final TextEditingController _widthController = TextEditingController();
  final TextEditingController _lengthController = TextEditingController();
  final TextEditingController _fishController1 = TextEditingController();
  final TextEditingController _fishController2 = TextEditingController();
  String? _result;
  String? _selectedFish1;
  String? _selectedFish2;
  bool _isCalculating = false;
  Map<String, dynamic>? _calculationData;
  List<String> _availableFish = [];
  Map<String, int> _fishSelections = {};

  // Keep reasons concise: first 1–2 sentences with a soft character cap
  String _shortenReason(String text, {int maxSentences = 2, int maxChars = 220}) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return trimmed;
    final parts = trimmed.split(RegExp(r'(?<=[.!?])\s+'));
    final take = parts.take(maxSentences).join(' ').trim();
    if (take.length <= maxChars) return take;
    return take.substring(0, maxChars).trimRight() + '…';
  }


  @override
  void initState() {
    super.initState();
    _loadFishSpecies();
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
    setState(() => _isCalculating = true);
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
      setState(() => _isCalculating = false);
    }
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

    // Verify fish exists in available fish list
    if (!_availableFish.contains(fishName)) {
      showCustomNotification(
        context,
        'Please select a valid fish from the suggestions',
        isError: true,
      );
      return;
    }

    setState(() {
      // Update fish selections map
      _fishSelections[fishName] = (_fishSelections[fishName] ?? 0) + 1;

      // Update selected fish UI state
      if (_selectedFish1 == null) {
        _selectedFish1 = fishName;
      } else if (_selectedFish2 == null && _selectedFish1 != fishName) {
        _selectedFish2 = fishName;
      } else if (_selectedFish1 == fishName || _selectedFish2 == fishName) {
        // If fish already selected, just update the count
        _fishSelections[fishName] = (_fishSelections[fishName] ?? 0) + 1;
      }
      
      // Clear the input field
      _fishController1.clear();
    });
  }

  void _clearFishInputs() {
    setState(() {
      _selectedFish1 = null;
      _selectedFish2 = null;
      _fishController1.clear();
      _fishController2.clear();
      _depthController.clear();
      _widthController.clear();
      _lengthController.clear();
      _result = null;
      _calculationData = null;
      _fishSelections = {};
    });
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
    if (volume <= 0) {
      showCustomNotification(
        context,
        'Please enter valid tank dimensions',
        isError: true,
      );
      return;
    }

    setState(() => _isCalculating = true);
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.calculateCapacityEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        },
        body: json.encode({
          'tank_volume': volume,
          'fish_selections': _fishSelections,
        }),
      ).timeout(ApiConfig.timeout);

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode != 200) {
        throw Exception('Failed to calculate capacity: ${response.statusCode}');
      }

      final responseData = json.decode(response.body);
      
      setState(() {
        _calculationData = {
          ...responseData,
          'fish_selections': _fishSelections,
        };
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
        _result = null;
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
      
      // Check if there are compatibility issues
      final compatibilityIssues = _calculationData!['compatibility_issues'] as List?;
      if (compatibilityIssues != null && compatibilityIssues.isNotEmpty) {
        showCustomNotification(
          context,
          'Cannot save: Fish are not compatible with each other',
          isError: true,
        );
        return;
      }
      
      final calculation = FishCalculation(
        tankVolume: tankVolume,
        fishSelections: Map<String, int>.from(_fishSelections),
        recommendedQuantities: recommendedQuantities,
        dateCalculated: DateTime.now(),
        phRange: waterConditions['pH_range'] ?? "6.0 - 7.0",
        temperatureRange: waterConditions['temperature_range'] ?? "22°C - 26°C",
        tankStatus: tankDetails['status'] ?? "Unknown",
        currentBioload: tankDetails['current_bioload'] ?? "0%",
      );

      final logBookProvider = Provider.of<LogBookProvider>(context, listen: false);
      logBookProvider.addFishCalculation(calculation);

      showCustomNotification(context, 'Fish calculation saved to history');
      
      // Clear all inputs and reset state
      setState(() {
        _clearFishInputs();
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
                  ..._fishSelections.entries.map((entry) => Padding(
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
                              if (_selectedFish1 == entry.key) {
                                _selectedFish1 = null;
                              } else if (_selectedFish2 == entry.key) {
                                _selectedFish2 = null;
                              }
                              _fishSelections.remove(entry.key);
                            });
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          iconSize: 20,
                        ),
                      ],
                    ),
                  )).toList(),
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
                        _fishController1.text = selection;
                      });
                    },
                    fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                      // Keep the controller in sync
                      textEditingController.text = _fishController1.text;
                      
                      return TextFormField(
                        controller: textEditingController,
                        focusNode: focusNode,
                        onChanged: (value) {
                          _fishController1.text = value;
                        },
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
                      );
                    },
                    optionsViewBuilder: (context, onSelected, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 4,
                          child: Container(
                            constraints: const BoxConstraints(maxHeight: 200),
                            width: MediaQuery.of(context).size.width - 64,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              itemCount: options.length,
                              itemBuilder: (BuildContext context, int index) {
                                final option = options.elementAt(index);
                                return ListTile(
                                  title: Text(option),
                                  onTap: () {
                                    onSelected(option);
                                  },
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
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
                        '${_calculateVolume().toStringAsFixed(1)} L',
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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
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
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0F7FA),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.science,
                              color: Color(0xFF006064),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'pH Range',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                _calculationData!['water_conditions']['pH_range'],
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Temperature
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0F7FA),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.thermostat,
                              color: Color(0xFF006064),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Temperature',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                _calculationData!['water_conditions']['temperature_range'].replaceAll('Â', ''),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
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
                      ..._fishSelections.entries.map((entry) => Padding(
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
                                  _buildDimensionsInput(),
                                  _buildFishInput(),
                                ],
                              )
                            else if (_calculationData!['compatibility_issues'] != null && (_calculationData!['compatibility_issues'] as List).isNotEmpty)
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
                    else if (_calculationData != null && (_calculationData!['compatibility_issues'] == null || (_calculationData!['compatibility_issues'] as List).isEmpty))
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

  Widget _buildDimensionsInput() {
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
                      FontAwesomeIcons.ruler,
                      color: Color(0xFF006064),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Tank Dimensions',
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
                  controller: _lengthController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Enter length',
                    filled: true,
                    fillColor: const Color(0xFFF5F5F5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _widthController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Enter width',
                    filled: true,
                    fillColor: const Color(0xFFF5F5F5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _depthController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Enter depth',
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

  double _calculateVolume() {
    final depth = double.tryParse(_depthController.text) ?? 0;
    final width = double.tryParse(_widthController.text) ?? 0;
    final length = double.tryParse(_lengthController.text) ?? 0;

    double volumeInLiters;
    if (_selectedUnit == 'CM') {
      // Convert cubic centimeters to liters
      volumeInLiters = (depth * width * length) / 1000;
    } else {
      // Convert cubic inches to liters
      volumeInLiters = (depth * width * length) * 0.0163871;
    }

    return volumeInLiters;
  }
} 