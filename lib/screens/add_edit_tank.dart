import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../models/tank.dart';
import '../providers/tank_provider.dart';
import '../config/api_config.dart';
import '../widgets/fish_selection_widget.dart';
import '../widgets/fish_info_dialog.dart';

class AddEditTank extends StatefulWidget {
  final Tank? tank;

  const AddEditTank({super.key, this.tank});

  @override
  State<AddEditTank> createState() => _AddEditTankState();
}

class _AddEditTankState extends State<AddEditTank> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _lengthController = TextEditingController();
  final _widthController = TextEditingController();
  final _heightController = TextEditingController();

  String _selectedShape = 'rectangle';
  String _selectedUnit = 'CM';
  double _calculatedVolume = 0.0;
  
  // Tab/Group management
  int _currentStep = 0;
  final List<String> _stepTitles = [
    'Tank Setup',
    'Fish Selection',
    'Feed Inventory',
    'Summary',
  ];

  // Fish selection
  Map<String, int> _fishSelections = {};
  final Map<String, TextEditingController> _fishQuantityControllers = {};
  List<Map<String, dynamic>> _availableFish = [];
  

  // Feed inventory
  final Map<String, double> _availableFeeds = {};
  final Map<String, TextEditingController> _feedQuantityControllers = {};
  String _selectedFeed = '';
  final List<String> _commonFeeds = [
    'Pellets',
    'Flakes',
    'Bloodworms',
    'Brine Shrimp',
    'Daphnia',
    'Tubifex',
    'Freeze-dried',
    'Spirulina',
    'Vegetable',
    'Live Food',
  ];

  // Feed duration calculations
  Map<String, Map<String, dynamic>> _feedDurationData = {};
  
  // Feed recommendations
  Map<String, List<String>> _incompatibleFeeds = {};
  
  // Fish details for summary
  Map<String, Map<String, dynamic>> _fishDetails = {};

  // Results
  Map<String, dynamic> _compatibilityResults = {};
  Map<String, dynamic> _feedingRecommendations = {};
  Map<String, int> _recommendedFishQuantities = {};
  Map<String, dynamic> _feedPortionData = {};
  
  // Tank shape compatibility warnings
  Map<String, String> _fishTankShapeWarnings = {};

  @override
  void initState() {
    super.initState();
    _initializeForm();
    _loadAvailableFish();
  }

  void _nextStep() {
    if (_currentStep < _stepTitles.length - 1) {
      setState(() {
        _currentStep++;
      });
      
      // Load fish details when going to summary step
      if (_currentStep == 3) {
        _loadFishDetails();
      }
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    }
  }

  bool _canProceedToNext() {
    switch (_currentStep) {
      case 0: // Tank Setup
        return _nameController.text.trim().isNotEmpty && 
               (_calculatedVolume > 0 || _selectedShape == 'bowl');
      case 1: // Fish Selection
        return _fishSelections.isNotEmpty;
      case 2: // Feed Inventory
        return true; // Feed inventory is optional
      default:
        return false;
    }
  }

  void _initializeForm() {
    if (widget.tank != null) {
    final tank = widget.tank!;
    _nameController.text = tank.name;
      _selectedShape = tank.tankShape;
    _selectedUnit = tank.unit;
    _lengthController.text = tank.length.toString();
    _widthController.text = tank.width.toString();
    _heightController.text = tank.height.toString();
      _calculatedVolume = tank.volume;
      _fishSelections = Map<String, int>.from(tank.fishSelections);
      _availableFeeds.addAll(tank.availableFeeds);
      _compatibilityResults = tank.compatibilityResults;
      _feedingRecommendations = tank.feedingRecommendations;
      _recommendedFishQuantities = tank.recommendedFishQuantities;
      _feedPortionData = tank.feedPortionData;

      // Initialize fish quantity controllers
      for (final entry in _fishSelections.entries) {
        _fishQuantityControllers[entry.key] = TextEditingController(text: entry.value.toString());
      }

      // Initialize feed quantity controllers
      for (final entry in _availableFeeds.entries) {
        _feedQuantityControllers[entry.key] = TextEditingController(text: entry.value.toString());
      }
      
      // Calculate feed durations for existing data
      _calculateFeedDurations();
    }
    // Always calculate volume on initialization
    _calculateVolume();
  }

  Future<void> _loadAvailableFish() async {
    try {
      // Use direct HTTP call like water_calculator.dart to get all fish
      final response = await http.get(
        Uri.parse(ApiConfig.fishListEndpoint),
        headers: {'Accept': 'application/json'}
      ).timeout(ApiConfig.timeout);
      
      if (response.statusCode == 200) {
        final List<dynamic> fishList = json.decode(response.body);
        final fishData = fishList.map((fish) => Map<String, dynamic>.from(fish)).toList();

        setState(() {
          _availableFish = fishData;
        });
      } else {
        throw Exception('Failed to load fish list: ${response.statusCode}');
      }
    } catch (e) {
      print('Error loading fish species: $e');
      setState(() {
        _availableFish = [];
      });
    }
  }


  void _calculateVolume() {
    try {
      if (_selectedShape == 'bowl') {
        _calculatedVolume = 10.0; // Fixed 10L for bowl
        setState(() {}); // Trigger UI update
      return;
    }

      final length = double.tryParse(_lengthController.text) ?? 0.0;
      final width = double.tryParse(_widthController.text) ?? 0.0;
      final height = double.tryParse(_heightController.text) ?? 0.0;

      _calculatedVolume = Tank.calculateVolume(
        _selectedShape,
        length,
        width,
        height,
        _selectedUnit,
      );
      setState(() {}); // Trigger UI update
    } catch (e) {
      print('Error calculating volume: $e');
      _calculatedVolume = 0.0;
      setState(() {}); // Trigger UI update
    }
  }

  void _showVolumeCalculation() {
    final length = double.tryParse(_lengthController.text) ?? 0.0;
    final width = double.tryParse(_widthController.text) ?? 0.0;
    final height = double.tryParse(_heightController.text) ?? 0.0;

    final steps = Tank.getVolumeCalculationSteps(
      _selectedShape,
      length,
      width,
      height,
      _selectedUnit,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.functions, color: Color(0xFF006064)),
            const SizedBox(width: 8),
            const Text('Volume Calculation'),
          ],
        ),
        content: SingleChildScrollView(
      child: Text(
            steps,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }


  void _addFeed() {
    if (_selectedFeed.isNotEmpty) {
    setState(() {
        _availableFeeds[_selectedFeed] = 0.0;
        _feedQuantityControllers[_selectedFeed] = TextEditingController(text: '0');
        _selectedFeed = '';
      });
    }
  }

  void _removeFeed(String feedName) {
    setState(() {
      _availableFeeds.remove(feedName);
      _feedQuantityControllers[feedName]?.dispose();
      _feedQuantityControllers.remove(feedName);
    });
  }

  void _updateFeedQuantity(String feedName, String quantity) {
    final qty = double.tryParse(quantity) ?? 0.0;
    setState(() {
      _availableFeeds[feedName] = qty;
    });
    // Recalculate feed durations when quantity changes
    _calculateFeedDurations();
  }

  // Calculate how long each feed will last based on fish consumption
  Future<void> _calculateFeedDurations() async {
    if (_fishSelections.isEmpty || _availableFeeds.isEmpty) {
      setState(() {
        _feedDurationData = {};
      });
      return;
    }

    final Map<String, Map<String, dynamic>> durationData = {};

    for (final feedEntry in _availableFeeds.entries) {
      final feedName = feedEntry.key;
      final availableGrams = feedEntry.value;

      if (availableGrams <= 0) continue;

      // Calculate daily consumption for this feed type
      double totalDailyConsumption = 0.0;
      final Map<String, double> fishConsumption = {};

      for (final fishEntry in _fishSelections.entries) {
        final fishName = fishEntry.key;
        final fishCount = fishEntry.value;

        // Get fish consumption data from database
        final dailyConsumptionPerFish = await _getFishDailyConsumptionFromDB(fishName, feedName);
        final totalFishConsumption = dailyConsumptionPerFish * fishCount;

        fishConsumption[fishName] = totalFishConsumption;
        totalDailyConsumption += totalFishConsumption;
      }

      if (totalDailyConsumption > 0) {
        final daysRemaining = (availableGrams / totalDailyConsumption).floor();
        final hoursRemaining = ((availableGrams / totalDailyConsumption) * 24).floor();

        durationData[feedName] = {
          'available_grams': availableGrams,
          'daily_consumption': totalDailyConsumption,
          'days_remaining': daysRemaining,
          'hours_remaining': hoursRemaining,
          'fish_consumption': fishConsumption,
          'is_low_stock': daysRemaining <= 7,
          'is_critical': daysRemaining <= 3,
        };
      }
    }

    setState(() {
      _feedDurationData = durationData;
    });
    
    // Also analyze feed compatibility for recommendations
    _analyzeFeedCompatibility();
  }

  // Get daily consumption for a specific fish and feed type from database
  Future<double> _getFishDailyConsumptionFromDB(String fishName, String feedType) async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('fish_species')
          .select('common_name, portion_grams, feeding_frequency, preferred_food')
          .ilike('common_name', fishName)
          .maybeSingle();

      if (response != null) {
        final portionGrams = double.tryParse(response['portion_grams']?.toString() ?? '0') ?? 0.0;
        final feedingFrequency = int.tryParse(response['feeding_frequency']?.toString() ?? '2') ?? 2;
        final preferredFood = response['preferred_food']?.toString().toLowerCase() ?? '';

        // Check if the feed type matches the fish's preferred food
        final feedTypeLower = feedType.toLowerCase();
        final isPreferredFeed = preferredFood.contains(feedTypeLower) || 
                               feedTypeLower.contains(preferredFood) ||
                               _isFeedTypeCompatible(feedTypeLower, preferredFood);

        if (isPreferredFeed && portionGrams > 0) {
          // Calculate daily consumption: portion_grams * feeding_frequency
          return portionGrams * feedingFrequency;
        }
      }
    } catch (e) {
      print('Error getting fish consumption data for $fishName: $e');
    }
    
    return 0.0; // Return 0 if fish doesn't eat this feed type or data not found
  }

  // Check if feed type is compatible with fish's preferred food
  bool _isFeedTypeCompatible(String feedType, String preferredFood) {
    if (preferredFood.isEmpty) return true; // If no preference, assume compatible
    
    final feedTypeLower = feedType.toLowerCase();
    final preferredFoodLower = preferredFood.toLowerCase();
    
    // Direct match
    if (preferredFoodLower.contains(feedTypeLower) || feedTypeLower.contains(preferredFoodLower)) {
      return true;
    }
    
    // Check feed type mappings with more comprehensive matching
    final Map<String, List<String>> feedMappings = {
      'pellets': ['pellet', 'dry food', 'commercial', 'omnivore', 'carnivore', 'herbivore'],
      'flakes': ['flake', 'dry food', 'commercial', 'omnivore', 'carnivore', 'herbivore'],
      'bloodworms': ['bloodworm', 'live food', 'protein', 'meat', 'carnivore', 'insect', 'frozen'],
      'brine shrimp': ['brine shrimp', 'live food', 'protein', 'meat', 'carnivore', 'crustacean', 'frozen'],
      'daphnia': ['daphnia', 'live food', 'protein', 'meat', 'carnivore', 'crustacean', 'frozen'],
      'tubifex': ['tubifex', 'live food', 'protein', 'meat', 'carnivore', 'worm', 'frozen'],
      'freeze-dried': ['freeze-dried', 'freeze dried', 'protein', 'meat', 'carnivore', 'frozen'],
      'spirulina': ['spirulina', 'algae', 'vegetable', 'plant', 'herbivore', 'omnivore'],
      'vegetable': ['vegetable', 'plant', 'algae', 'herbivore', 'omnivore'],
      'live food': ['live food', 'live', 'protein', 'meat', 'carnivore'],
      'frozen': ['frozen', 'live food', 'protein', 'meat', 'carnivore'],
    };

    final feedVariations = feedMappings[feedTypeLower] ?? [feedTypeLower];
    
    for (final variation in feedVariations) {
      if (preferredFoodLower.contains(variation)) {
        return true;
      }
    }
    
    // Additional compatibility checks for common aquarium scenarios
    // If fish is omnivore, most feeds should be compatible
    if (preferredFoodLower.contains('omnivore')) {
      return true;
    }
    
    // If fish is carnivore, protein-based feeds should be compatible
    if (preferredFoodLower.contains('carnivore') && 
        (feedTypeLower.contains('bloodworm') || 
         feedTypeLower.contains('brine') || 
         feedTypeLower.contains('live') || 
         feedTypeLower.contains('frozen') ||
         feedTypeLower.contains('protein'))) {
      return true;
    }
    
    // If fish is herbivore, plant-based feeds should be compatible
    if (preferredFoodLower.contains('herbivore') && 
        (feedTypeLower.contains('spirulina') || 
         feedTypeLower.contains('vegetable') || 
         feedTypeLower.contains('algae') ||
         feedTypeLower.contains('plant'))) {
      return true;
    }
    
    return false;
  }

  // Analyze feed compatibility and generate recommendations
  Future<void> _analyzeFeedCompatibility() async {
    if (_fishSelections.isEmpty || _availableFeeds.isEmpty) {
      setState(() {
        _incompatibleFeeds = {};
      });
      return;
    }

    final Map<String, List<String>> incompatibleFeeds = {};

    // Get all fish dietary preferences
    final Map<String, String> fishPreferences = {};
    for (final fishName in _fishSelections.keys) {
      try {
        final supabase = Supabase.instance.client;
        final response = await supabase
            .from('fish_species')
            .select('common_name, preferred_food')
            .ilike('common_name', fishName)
            .maybeSingle();

        if (response != null) {
          fishPreferences[fishName] = response['preferred_food']?.toString().toLowerCase() ?? '';
        }
      } catch (e) {
        print('Error getting fish preferences for $fishName: $e');
      }
    }

    // Analyze each feed
    for (final feedName in _availableFeeds.keys) {
      final List<String> incompatibleFish = [];

      for (final fishEntry in _fishSelections.entries) {
        final fishName = fishEntry.key;
        final fishPreference = fishPreferences[fishName] ?? '';
        
        if (!_isFeedCompatibleWithFish(feedName, fishPreference)) {
          incompatibleFish.add(fishName);
        }
      }
      
      if (incompatibleFish.isNotEmpty) {
        incompatibleFeeds[feedName] = incompatibleFish;
      }
    }

    setState(() {
      _incompatibleFeeds = incompatibleFeeds;
    });
  }

  // Check if a feed is compatible with a fish's dietary preference
  bool _isFeedCompatibleWithFish(String feedName, String fishPreference) {
    // If no preference is specified, assume compatible (don't be too restrictive)
    if (fishPreference.isEmpty) return true;
    
    final feedTypeLower = feedName.toLowerCase();
    final fishPreferenceLower = fishPreference.toLowerCase();
    
    // Direct match
    if (fishPreferenceLower.contains(feedTypeLower) || feedTypeLower.contains(fishPreferenceLower)) {
      return true;
    }
    
    // Check feed type mappings with more comprehensive matching
    final Map<String, List<String>> feedMappings = {
      'pellets': ['pellet', 'dry food', 'commercial', 'omnivore', 'carnivore', 'herbivore'],
      'flakes': ['flake', 'dry food', 'commercial', 'omnivore', 'carnivore', 'herbivore'],
      'bloodworms': ['bloodworm', 'live food', 'protein', 'meat', 'carnivore', 'insect', 'frozen'],
      'brine shrimp': ['brine shrimp', 'live food', 'protein', 'meat', 'carnivore', 'crustacean', 'frozen'],
      'daphnia': ['daphnia', 'live food', 'protein', 'meat', 'carnivore', 'crustacean', 'frozen'],
      'tubifex': ['tubifex', 'live food', 'protein', 'meat', 'carnivore', 'worm', 'frozen'],
      'freeze-dried': ['freeze-dried', 'freeze dried', 'protein', 'meat', 'carnivore', 'frozen'],
      'spirulina': ['spirulina', 'algae', 'vegetable', 'plant', 'herbivore', 'omnivore'],
      'vegetable': ['vegetable', 'plant', 'algae', 'herbivore', 'omnivore'],
      'live food': ['live food', 'live', 'protein', 'meat', 'carnivore'],
      'frozen': ['frozen', 'live food', 'protein', 'meat', 'carnivore'],
    };

    final feedVariations = feedMappings[feedTypeLower] ?? [feedTypeLower];
    
    for (final variation in feedVariations) {
      if (fishPreferenceLower.contains(variation)) {
        return true;
      }
    }
    
    // Additional compatibility checks for common aquarium scenarios
    // If fish is omnivore, most feeds should be compatible
    if (fishPreferenceLower.contains('omnivore')) {
      return true;
    }
    
    // If fish is carnivore, protein-based feeds should be compatible
    if (fishPreferenceLower.contains('carnivore') && 
        (feedTypeLower.contains('bloodworm') || 
         feedTypeLower.contains('brine') || 
         feedTypeLower.contains('live') || 
         feedTypeLower.contains('frozen') ||
         feedTypeLower.contains('protein'))) {
      return true;
    }
    
    // If fish is herbivore, plant-based feeds should be compatible
    if (fishPreferenceLower.contains('herbivore') && 
        (feedTypeLower.contains('spirulina') || 
         feedTypeLower.contains('vegetable') || 
         feedTypeLower.contains('algae') ||
         feedTypeLower.contains('plant'))) {
      return true;
    }
    
    return false;
  }

  // Generate recommended feeds based on fish preferences
  List<String> _getRecommendedFeedsForFish() {
    if (_fishSelections.isEmpty) return [];

    final Set<String> recommendedFeeds = {};
    
    for (final fishName in _fishSelections.keys) {
      try {
        // Get fish dietary preferences
        final fishPreference = _getFishDietaryPreference(fishName);
        if (fishPreference.isNotEmpty) {
          // Map preferences to feed types
          final feeds = _mapPreferenceToFeeds(fishPreference);
          recommendedFeeds.addAll(feeds);
        }
      } catch (e) {
        print('Error getting recommendations for $fishName: $e');
      }
    }

    // Filter out feeds already in inventory
    return recommendedFeeds.where((feed) => !_availableFeeds.containsKey(feed)).toList();
  }

  // Get fish dietary preference (simplified for demo)
  String _getFishDietaryPreference(String fishName) {
    final fishNameLower = fishName.toLowerCase();
    
    // Common fish dietary preferences
    if (fishNameLower.contains('koi') || fishNameLower.contains('goldfish')) {
      return 'omnivore, pellets, flakes, vegetable, spirulina';
    } else if (fishNameLower.contains('betta') || fishNameLower.contains('gourami')) {
      return 'carnivore, pellets, bloodworms, brine shrimp, live food';
    } else if (fishNameLower.contains('tetra') || fishNameLower.contains('guppy')) {
      return 'omnivore, flakes, pellets, bloodworms, daphnia';
    } else if (fishNameLower.contains('cichlid') || fishNameLower.contains('angelfish')) {
      return 'carnivore, pellets, bloodworms, brine shrimp, live food';
    } else if (fishNameLower.contains('pleco') || fishNameLower.contains('catfish')) {
      return 'herbivore, vegetable, spirulina, algae wafers';
    }
    
    return 'omnivore, pellets, flakes'; // Default
  }

  // Map dietary preference to specific feed types
  List<String> _mapPreferenceToFeeds(String preference) {
    final List<String> feeds = [];
    final prefLower = preference.toLowerCase();
    
    if (prefLower.contains('pellets')) feeds.add('Pellets');
    if (prefLower.contains('flakes')) feeds.add('Flakes');
    if (prefLower.contains('bloodworms')) feeds.add('Bloodworms');
    if (prefLower.contains('brine shrimp')) feeds.add('Brine Shrimp');
    if (prefLower.contains('daphnia')) feeds.add('Daphnia');
    if (prefLower.contains('tubifex')) feeds.add('Tubifex');
    if (prefLower.contains('freeze-dried')) feeds.add('Freeze-dried');
    if (prefLower.contains('spirulina')) feeds.add('Spirulina');
    if (prefLower.contains('vegetable')) feeds.add('Vegetable');
    if (prefLower.contains('live food')) feeds.add('Live Food');
    
    return feeds;
  }

  // Load fish details for summary
  Future<void> _loadFishDetails() async {
    final Map<String, Map<String, dynamic>> fishDetails = {};

    for (final fishName in _fishSelections.keys) {
      try {
        final supabase = Supabase.instance.client;
        final response = await supabase
            .from('fish_species')
            .select('common_name, portion_grams, feeding_frequency, preferred_food, "max_size_(cm)", temperament, water_type')
            .ilike('common_name', fishName)
            .maybeSingle();

        if (response != null) {
          final portionGrams = double.tryParse(response['portion_grams']?.toString() ?? '0') ?? 0.0;
          final feedingFreq = int.tryParse(response['feeding_frequency']?.toString() ?? '2') ?? 2;
          final maxSize = double.tryParse(response['max_size_(cm)']?.toString() ?? '0') ?? 0.0;
          
          fishDetails[fishName] = {
            'common_name': response['common_name']?.toString() ?? fishName,
            'portion_grams': portionGrams > 0 ? portionGrams : null,
            'feeding_frequency': feedingFreq > 0 ? feedingFreq : null,
            'preferred_food': _getStringValue(response['preferred_food']),
            'max_size_cm': maxSize > 0 ? maxSize : null,
            'temperament': _getStringValue(response['temperament']),
            'water_type': _getStringValue(response['water_type']),
          };
        } else {
          // Fallback data if not found in database
          fishDetails[fishName] = {
            'common_name': fishName,
            'portion_grams': null,
            'feeding_frequency': null,
            'preferred_food': null,
            'max_size_cm': null,
            'temperament': null,
            'water_type': null,
          };
        }
      } catch (e) {
        print('Error loading fish details for $fishName: $e');
        // Fallback data on error
        fishDetails[fishName] = {
          'common_name': fishName,
          'portion_grams': null,
          'feeding_frequency': null,
          'preferred_food': null,
          'max_size_cm': null,
          'temperament': null,
          'water_type': null,
        };
      }
    }

    setState(() {
      _fishDetails = fishDetails;
    });
  }

  // Helper method to safely get string values
  String? _getStringValue(dynamic value) {
    if (value == null) return null;
    final str = value.toString();
    return str.isNotEmpty ? str : null;
  }











  Future<void> _checkCompatibility() async {
    if (_fishSelections.isEmpty) {
      setState(() {
        _compatibilityResults = {};
      });
      return;
    }

    try {
      // Always check compatibility (including tank volume/shape for single fish)
      final totalCount = _fishSelections.values.fold<int>(0, (sum, v) => sum + v);
      print('Total fish count: $totalCount');
      
      // Always check compatibility, even for single fish (to check tank volume/shape)
      print('Checking compatibility for fish...');
        final expandedFishNames = _fishSelections.entries
            .expand((e) => List.filled(e.value, e.key))
            .toList();

        final compatibilityResponse = await http.post(
          Uri.parse(ApiConfig.checkGroupEndpoint),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json'
          },
        body: json.encode({
          'fish_names': expandedFishNames,
          'tank_volume': _calculatedVolume,
          'tank_shape': _selectedShape,
        }),
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
        
        setState(() {
          _compatibilityResults = {
            'has_incompatible_pairs': hasIncompatiblePairs,
            'has_conditional_pairs': hasConditionalPairs,
            'incompatible_pairs': incompatiblePairs,
            'conditional_pairs': conditionalPairs,
            'all_pairs': [...incompatiblePairs, ...conditionalPairs],
          };
        });
    } catch (e) {
      print('Error checking compatibility: $e');
      setState(() {
        _compatibilityResults = {};
      });
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
        
        final isIncompatible = _isFishIncompatibleWithTankShape(fishName, maxSize, minTankSize, _selectedShape);
        
        setState(() {
          if (isIncompatible) {
            String warning = _getTankShapeIncompatibilityReason(fishName, maxSize, minTankSize, _selectedShape);
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

  // Check all selected fish for tank shape compatibility
  Future<void> _checkAllFishTankShapeCompatibility() async {
    for (String fishName in _fishSelections.keys) {
      await _checkFishTankShapeCompatibility(fishName);
    }
  }

  bool _isFishIncompatibleWithTankShape(String fishName, dynamic maxSize, dynamic minTankSize, String tankShape) {
    // Get quantity for this fish species
    int quantity = _fishSelections[fishName] ?? 1;
    
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

    // Calculate total tank size requirement for all fish of this species
    double totalMinTankSize = (fishMinTankSize ?? 0) * quantity;

    switch (tankShape) {
      case 'bowl':
        // Bowl tanks (10L) - Only for nano fish
        // Check individual size AND total tank size requirement
        return (fishMaxSize != null && fishMaxSize > 8) || 
               (totalMinTankSize > 15) || // Total requirement exceeds bowl capacity
               (_calculatedVolume < totalMinTankSize); // Tank too small for total requirement
               
      case 'cylinder':
        // Cylinder tanks - Limited horizontal swimming space
        // Check individual size AND total tank size requirement
        return (fishMaxSize != null && fishMaxSize > 20) || 
               (totalMinTankSize > 200) || // Total requirement exceeds cylinder capacity
               (_calculatedVolume < totalMinTankSize); // Tank too small for total requirement
               
      case 'rectangle':
      default:
        // Rectangle tanks - Most versatile, but still check total requirements
        return (_calculatedVolume < totalMinTankSize); // Tank too small for total requirement
    }
  }

  String _getTankShapeIncompatibilityReason(String fishName, dynamic maxSize, dynamic minTankSize, String tankShape) {
    // Get quantity for this fish species
    int quantity = _fishSelections[fishName] ?? 1;
    
    // Convert sizes to numbers for detailed messaging
    double? fishMaxSize = double.tryParse(maxSize?.toString() ?? '0');
    double? fishMinTankSize = double.tryParse(minTankSize?.toString() ?? '0');
    double totalMinTankSize = (fishMinTankSize ?? 0) * quantity;
    
    switch (tankShape) {
      case 'bowl':
        if (fishMaxSize != null && fishMaxSize > 8) {
          return '$fishName (x$quantity) is too large for a bowl tank. Individual fish size (${fishMaxSize}cm) exceeds bowl tank limit (8cm).';
        } else if (totalMinTankSize > 15) {
          return '$fishName (x$quantity) needs ${totalMinTankSize}L total but bowl tanks are only 10L. Each fish needs ${fishMinTankSize}L.';
        } else if (_calculatedVolume < totalMinTankSize) {
          return '$fishName (x$quantity) needs ${totalMinTankSize}L total but your tank is only ${_calculatedVolume}L.';
        }
        return '$fishName (x$quantity) is not suitable for a bowl tank.';
        
      case 'cylinder':
        if (fishMaxSize != null && fishMaxSize > 20) {
          return '$fishName (x$quantity) is too large for a cylinder tank. Individual fish size (${fishMaxSize}cm) exceeds cylinder tank limit (20cm).';
        } else if (totalMinTankSize > 200) {
          return '$fishName (x$quantity) needs ${totalMinTankSize}L total but cylinder tanks are limited to 200L. Each fish needs ${fishMinTankSize}L.';
        } else if (_calculatedVolume < totalMinTankSize) {
          return '$fishName (x$quantity) needs ${totalMinTankSize}L total but your tank is only ${_calculatedVolume}L.';
        }
        return '$fishName (x$quantity) needs more swimming space than a cylinder tank provides.';
        
      default:
        if (_calculatedVolume < totalMinTankSize) {
          return '$fishName (x$quantity) needs ${totalMinTankSize}L total but your tank is only ${_calculatedVolume}L. Each fish needs ${fishMinTankSize}L.';
        }
        return '$fishName (x$quantity) is not suitable for the selected tank shape.';
    }
  }




  Future<void> _saveTank() async {
    if (!_formKey.currentState!.validate()) {
        return;
      }
      
    if (_calculatedVolume <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter valid tank dimensions.'),
          backgroundColor: Colors.red,
        ),
      );
        return;
      }

    try {
      // Generate feeding recommendations if not already done
      if (_feedingRecommendations.isEmpty && _fishSelections.isNotEmpty) {
        final tankProvider = Provider.of<TankProvider>(context, listen: false);
        _feedingRecommendations = await tankProvider.generateFeedingRecommendations(_fishSelections);
        _feedPortionData = tankProvider.generateFeedPortionData(_fishSelections, _feedingRecommendations);
      }

      // Generate compatibility results if not already done
      if (_compatibilityResults.isEmpty && _fishSelections.isNotEmpty) {
        await _checkCompatibility();
      }

      final tank = Tank(
        id: widget.tank?.id,
        name: _nameController.text.trim(),
        tankShape: _selectedShape,
        length: double.parse(_lengthController.text),
        width: double.parse(_widthController.text),
        height: double.parse(_heightController.text),
        unit: _selectedUnit,
        volume: _calculatedVolume,
        fishSelections: _fishSelections,
        compatibilityResults: _compatibilityResults,
        feedingRecommendations: _feedingRecommendations,
        recommendedFishQuantities: _recommendedFishQuantities,
        availableFeeds: _availableFeeds,
        feedInventory: _feedDurationData, // Use calculated feed duration data
        feedPortionData: _feedPortionData,
        dateCreated: widget.tank?.dateCreated ?? DateTime.now(),
        lastUpdated: DateTime.now(),
        createdAt: widget.tank?.createdAt,
      );

      print('Saving tank with data:');
      print('- Name: ${tank.name}');
      print('- Fish selections: ${tank.fishSelections}');
      print('- Available feeds: ${tank.availableFeeds}');
      print('- Compatibility results: ${tank.compatibilityResults.isNotEmpty ? 'Present' : 'Empty'}');
      print('- Feeding recommendations: ${tank.feedingRecommendations.isNotEmpty ? 'Present' : 'Empty'}');
      print('- Feed portion data: ${tank.feedPortionData.isNotEmpty ? 'Present' : 'Empty'}');

      final tankProvider = Provider.of<TankProvider>(context, listen: false);

      if (widget.tank != null) {
        await tankProvider.updateTank(tank);
      } else {
        await tankProvider.addTank(tank);
      }

      Navigator.pop(context);
    } catch (e) {
      print('Error saving tank: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving tank: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }


  @override
  void dispose() {
    _nameController.dispose();
    _lengthController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    _fishQuantityControllers.values.forEach((controller) => controller.dispose());
    _feedQuantityControllers.values.forEach((controller) => controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF006064)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
              widget.tank != null ? 'Edit Tank' : 'Create New Tank',
          style: const TextStyle(
                color: Colors.black87,
            fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
      ),
      body: Form(
        key: _formKey,
          child: Column(
            children: [
            // Current step content
            Expanded(
              child: _currentStep == 1 
                  ? _buildCurrentStepContent() // Fish selection step - no scroll view
                  : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: _buildCurrentStepContent(),
              ),
            ),
            
            // Navigation buttons (only show for non-fish selection steps)
            if (_currentStep != 1) _buildNavigationButtons(),
          ],
        ),
      ),
    );
  }


  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildTankSetupStep();
      case 1:
        return _buildFishSelectionStep();
      case 2:
        return _buildFeedInventoryStep();
      case 3:
        return _buildSummaryStep();
      default:
        return Container();
    }
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
          children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _previousStep,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back'),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF00BCD4),
                  side: const BorderSide(color: Color(0xFF00BCD4)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _currentStep == _stepTitles.length - 1 
                  ? _saveTank 
                  : _canProceedToNext() ? _nextStep : null,
              icon: Icon(_currentStep == _stepTitles.length - 1 ? Icons.save : Icons.arrow_forward),
              label: Text(_currentStep == _stepTitles.length - 1 ? 'Save Tank' : 'Next'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00BCD4),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTankSetupStep() {
    return _buildSection(
      title: 'Tank Setup',
      icon: Icons.water_drop,
      children: [
        // Tank Name
        TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Tank Name',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.label),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter a tank name';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Tank Shape and Unit Selection - Side by Side (75/25)
        Row(
          children: [
            Expanded(
              flex: 3, // 75% width (3/4)
              child: DropdownButtonFormField<String>(
                value: _selectedShape,
                decoration: const InputDecoration(
                  labelText: 'Tank Shape',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.shape_line_outlined),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                items: const [
                  DropdownMenuItem(value: 'rectangle', child: Text('Rectangle')),
                  DropdownMenuItem(value: 'bowl', child: Text('Bowl (10L)')),
                  DropdownMenuItem(value: 'cylinder', child: Text('Cylinder')),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedShape = value!;
                  });
                  _calculateVolume();
                  // Check tank shape compatibility for all selected fish when tank shape changes
                  _checkAllFishTankShapeCompatibility();
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 1, // 25% width (1/4)
              child: DropdownButtonFormField<String>(
              value: _selectedUnit,
                decoration: InputDecoration(
                  labelText: 'Unit (${_selectedUnit})',
                  border: const OutlineInputBorder(),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                ),
                items: const [
                  DropdownMenuItem(value: 'CM', child: Text('CM')),
                  DropdownMenuItem(value: 'IN', child: Text('IN')),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedUnit = value!;
                  });
                  _calculateVolume();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Tank Dimensions (conditional) - Responsive
        if (_selectedShape == 'rectangle') ...[
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 600) {
                // Wide screen: 3 columns
                return Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _lengthController,
                        decoration: const InputDecoration(
                          labelText: 'Length',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.straighten),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (_) => _calculateVolume(),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Required';
                    }
                    if (double.tryParse(value) == null || double.parse(value) <= 0) {
                      return 'Invalid';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _widthController,
                        decoration: const InputDecoration(
                          labelText: 'Width',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.straighten),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (_) => _calculateVolume(),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Required';
                    }
                    if (double.tryParse(value) == null || double.parse(value) <= 0) {
                      return 'Invalid';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _heightController,
                        decoration: const InputDecoration(
                          labelText: 'Height',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.height),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (_) => _calculateVolume(),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Required';
                    }
                    if (double.tryParse(value) == null || double.parse(value) <= 0) {
                      return 'Invalid';
                    }
                    return null;
                  },
                ),
              ),
            ],
                );
              } else if (constraints.maxWidth > 400) {
                // Medium screen: 2 columns with height below
                return Column(
                  children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _lengthController,
                            decoration: const InputDecoration(
                              labelText: 'Length',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.straighten),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (_) => _calculateVolume(),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Required';
                    }
                    if (double.tryParse(value) == null || double.parse(value) <= 0) {
                      return 'Invalid';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                            controller: _widthController,
                            decoration: const InputDecoration(
                              labelText: 'Width',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.straighten),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (_) => _calculateVolume(),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Required';
                              }
                              if (double.tryParse(value) == null || double.parse(value) <= 0) {
                                return 'Invalid';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                  controller: _heightController,
                      decoration: const InputDecoration(
                        labelText: 'Height',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.height),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                  keyboardType: TextInputType.number,
                      onChanged: (_) => _calculateVolume(),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        if (double.tryParse(value) == null || double.parse(value) <= 0) {
                          return 'Invalid';
                        }
                        return null;
                      },
                    ),
                  ],
                );
              } else {
                // Narrow screen: stacked
                return Column(
                  children: [
                    TextFormField(
                      controller: _lengthController,
                      decoration: const InputDecoration(
                        labelText: 'Length',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.straighten),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (_) => _calculateVolume(),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Required';
                    }
                    if (double.tryParse(value) == null || double.parse(value) <= 0) {
                      return 'Invalid';
                    }
                    return null;
                  },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _widthController,
                      decoration: const InputDecoration(
                        labelText: 'Width',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.straighten),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (_) => _calculateVolume(),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        if (double.tryParse(value) == null || double.parse(value) <= 0) {
                          return 'Invalid';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _heightController,
                      decoration: const InputDecoration(
                        labelText: 'Height',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.height),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (_) => _calculateVolume(),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        if (double.tryParse(value) == null || double.parse(value) <= 0) {
                          return 'Invalid';
                        }
                        return null;
                      },
                    ),
                  ],
                );
              }
            },
          ),
        ] else if (_selectedShape == 'cylinder') ...[
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 500) {
                // Wide screen: 2 columns
                return Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _lengthController,
                        decoration: const InputDecoration(
                          labelText: 'Diameter',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.circle_outlined),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (_) => _calculateVolume(),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Required';
                    }
                    if (double.tryParse(value) == null || double.parse(value) <= 0) {
                      return 'Invalid';
                    }
                    return null;
                  },
                ),
              ),
                    const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _heightController,
                        decoration: const InputDecoration(
                          labelText: 'Height',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.height),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (_) => _calculateVolume(),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Required';
                    }
                    if (double.tryParse(value) == null || double.parse(value) <= 0) {
                      return 'Invalid';
                    }
                    return null;
                  },
                      ),
                    ),
                  ],
                );
              } else {
                // Narrow screen: stacked
                return Column(
                  children: [
                    TextFormField(
                      controller: _lengthController,
                      decoration: const InputDecoration(
                        labelText: 'Diameter',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.circle_outlined),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (_) => _calculateVolume(),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        if (double.tryParse(value) == null || double.parse(value) <= 0) {
                          return 'Invalid';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _heightController,
                      decoration: const InputDecoration(
                        labelText: 'Height',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.height),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (_) => _calculateVolume(),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        if (double.tryParse(value) == null || double.parse(value) <= 0) {
                          return 'Invalid';
                        }
                        return null;
                      },
                    ),
                  ],
                );
              }
            },
          ),
        ] else if (_selectedShape == 'bowl') ...[
          Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
        ),
            child: const Row(
        children: [
                Icon(Icons.info, color: Colors.blue),
                SizedBox(width: 8),
          Expanded(
                  child: Text(
                    'Bowl tanks use a fixed volume of 10L for consistent calculations.',
                    style: TextStyle(color: Colors.blue),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),

        // Calculated Volume Display
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _calculatedVolume > 0 ? const Color(0xFFE0F7FA) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _calculatedVolume > 0 ? const Color(0xFF00BCD4) : Colors.grey.shade300,
            ),
          ),
          child: Row(
            children: [
              Icon(
                _calculatedVolume > 0 ? Icons.water_drop : Icons.water_drop_outlined,
                color: _calculatedVolume > 0 ? const Color(0xFF00BCD4) : Colors.grey,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(
                      'Calculated Volume',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                        color: _calculatedVolume > 0 ? const Color(0xFF00BCD4) : Colors.grey.shade600,
                  ),
                ),
                  Text(
                      _calculatedVolume > 0
                          ? '${_calculatedVolume.toStringAsFixed(2)} L (${(_calculatedVolume * 0.264172).toStringAsFixed(2)} US gallons)'
                          : 'Enter dimensions to calculate',
                      style: TextStyle(
                        color: _calculatedVolume > 0 ? const Color(0xFF00BCD4) : Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              if (_calculatedVolume > 0)
                IconButton(
                  icon: const Icon(Icons.functions, color: Color(0xFF00BCD4)),
                  onPressed: _showVolumeCalculation,
                  tooltip: 'Show calculation steps',
          ),
        ],
      ),
        ),
      ],
    );
  }

   Widget _buildFishSelectionStep() {
     return FishSelectionWidget(
       selectedFish: _fishSelections,
       onFishSelectionChanged: (newSelections) {
         setState(() {
           _fishSelections = newSelections;
         });
         // Check compatibility after fish selection changes
         _checkCompatibility();
         // Check tank shape compatibility for all fish
         _checkAllFishTankShapeCompatibility();
         // Recalculate feed durations when fish selection changes
         _calculateFeedDurations();
       },
       availableFish: _availableFish,
       onBack: _currentStep > 0 ? _previousStep : null,
       onNext: _canProceedToNext() ? _nextStep : null,
       canProceed: _canProceedToNext(),
       isLastStep: _currentStep == _stepTitles.length - 1,
       compatibilityResults: _compatibilityResults,
       tankShapeWarnings: _fishTankShapeWarnings,
       onTankShapeWarningsChanged: (warnings) {
         setState(() {
           _fishTankShapeWarnings = warnings;
         });
       },
     );
   }







  Widget _buildFeedInventoryStep() {
    return _buildSection(
      title: 'Feed Inventory',
      icon: Icons.restaurant,
        children: [
        // Add Feed Section
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF00BCD4).withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add Feed to Inventory',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF006064),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
                  if (constraints.maxWidth < 400) {
                    // Narrow screen: stack vertically
              return Column(
              children: [
                  DropdownButtonFormField<String>(
                    value: _selectedFeed.isEmpty ? null : _selectedFeed,
                    decoration: const InputDecoration(
                      labelText: 'Select Feed Type',
                      border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.food_bank, color: Color(0xFF00BCD4)),
                    ),
                    items: _commonFeeds.map((feed) => DropdownMenuItem(
                      value: feed,
                            child: Text(feed),
                    )).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedFeed = value ?? '';
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                            onPressed: _selectedFeed.isNotEmpty ? _addFeed : null,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Feed'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00BCD4),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
            ),
          ),
        ],
              );
            } else {
              // Wide screen: side by side
    return Row(
        children: [
        Expanded(
                          flex: 3,
                    child: DropdownButtonFormField<String>(
                      value: _selectedFeed.isEmpty ? null : _selectedFeed,
                      decoration: const InputDecoration(
                        labelText: 'Select Feed Type',
                        border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.food_bank, color: Color(0xFF00BCD4)),
                      ),
                      items: _commonFeeds.map((feed) => DropdownMenuItem(
                        value: feed,
                              child: Text(feed),
                      )).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedFeed = value ?? '';
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                        Expanded(
                          flex: 1,
                          child: ElevatedButton.icon(
                            onPressed: _selectedFeed.isNotEmpty ? _addFeed : null,
                    icon: const Icon(Icons.add),
                    label: const Text('Add'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00BCD4),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
          ),
        ),
      ],
    );
  }
          },
        ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Feed Recommendations Section
        if (_fishSelections.isNotEmpty) ...[
          _buildFeedRecommendationsSection(),
          const SizedBox(height: 20),
        ],

        // Feed Inventory List
        if (_availableFeeds.isNotEmpty) ...[
          Text(
            'Feed Inventory',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF006064),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          ..._availableFeeds.entries.map((entry) => _buildFeedItem(entry.key, entry.value)),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              children: [
                Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                Text(
                  'No feed inventory added yet',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Add feeds to track how long they will last with your fish',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFeedItem(String feedName, double quantity) {
    final durationData = _feedDurationData[feedName];
    final isLowStock = durationData?['is_low_stock'] ?? false;
    final isCritical = durationData?['is_critical'] ?? false;
    final daysRemaining = durationData?['days_remaining'] ?? 0;
    final dailyConsumption = durationData?['daily_consumption'] ?? 0.0;

    String statusText;
    if (isCritical) {
      statusText = 'Critical - $daysRemaining days left';
    } else if (isLowStock) {
      statusText = 'Low stock - $daysRemaining days left';
    } else {
      statusText = '$daysRemaining days remaining';
    }
            
      return Container(
      margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
        color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCritical ? Colors.red.shade300 : 
                 isLowStock ? Colors.orange.shade300 : const Color(0xFF00BCD4).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
          children: [
          // Header with status
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isCritical ? Colors.red.shade50 : 
                     isLowStock ? Colors.orange.shade50 : const Color(0xFF00BCD4).withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(7),
                topRight: Radius.circular(7),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.restaurant,
                  color: isCritical ? Colors.red.shade700 : 
                         isLowStock ? Colors.orange.shade700 : const Color(0xFF006064),
                  size: 20,
                ),
                const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                feedName,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isCritical ? Colors.red.shade700 : 
                             isLowStock ? Colors.orange.shade700 : const Color(0xFF006064),
                    ),
                  ),
                ),
                Text(
                  statusText,
                  style: TextStyle(
                    color: isCritical ? Colors.red.shade700 : 
                           isLowStock ? Colors.orange.shade700 : const Color(0xFF006064),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                            IconButton(
                  icon: const Icon(Icons.remove_circle, color: Colors.red, size: 20),
                              onPressed: () => _removeFeed(feedName),
                  tooltip: 'Remove feed',
                ),
              ],
            ),
          ),
          
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Quantity input
                TextFormField(
                            controller: _feedQuantityControllers[feedName],
                  decoration: const InputDecoration(
                    labelText: 'Available Quantity',
                    border: OutlineInputBorder(),
                    suffixText: 'grams',
                    prefixIcon: Icon(Icons.scale, color: Color(0xFF00BCD4)),
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (value) => _updateFeedQuantity(feedName, value),
                          ),
                
                if (durationData != null) ...[
                  const SizedBox(height: 16),
                  
                  // Duration analysis
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Daily consumption
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Flexible(
                              child: Text('Daily consumption:', style: TextStyle(color: Colors.black87)),
                            ),
                            Flexible(
                              child: Text(
                                '${dailyConsumption.toStringAsFixed(2)}g/day',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF006064)),
                                textAlign: TextAlign.right,
                                overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                        ),
                        
                        // Fish breakdown
                        if (durationData['fish_consumption'] != null && 
                            (durationData['fish_consumption'] as Map<String, double>).isNotEmpty) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'Per fish species:',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          ...(durationData['fish_consumption'] as Map<String, double>).entries.map((fishEntry) {
                            return Padding(
                              padding: const EdgeInsets.only(left: 8, top: 2),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Flexible(
                                    child: Text(
                                      '${fishEntry.key}:',
                                      style: const TextStyle(color: Color(0xFF006064), fontSize: 12),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Flexible(
                                    child: Text(
                                      '${fishEntry.value.toStringAsFixed(2)}g/day',
                                      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12, color: Color(0xFF006064)),
                                      textAlign: TextAlign.right,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                        
                        // Compatibility information
                        if (durationData['fish_consumption'] != null && 
                            (durationData['fish_consumption'] as Map<String, double>).isEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.orange.shade200),
                            ),
                            child: Row(
        children: [
                                const Icon(Icons.info_outline, color: Colors.orange, size: 16),
                                const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                                    'No fish eat this feed type. Check recommendations above.',
                                    style: const TextStyle(
                                      color: Colors.orange,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedRecommendationsSection() {
    final recommendedFeeds = _getRecommendedFeedsForFish();
    final hasIncompatibleFeeds = _incompatibleFeeds.isNotEmpty;
    
    return Center(
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 1,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF00BCD4).withOpacity(0.2)),
          ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Feed Recommendations',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF006064),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          
          // Recommended feeds
          if (recommendedFeeds.isNotEmpty) ...[
            Text(
              'Recommended feeds for your fish:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.black87,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: recommendedFeeds.map((feed) => _buildRecommendedFeedChip(feed)).toList(),
            ),
            const SizedBox(height: 12),
          ],
          
          // Incompatible feeds warning
          if (hasIncompatibleFeeds) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline, color: Color(0xFF006064), size: 16),
                      const SizedBox(width: 6),
                      const Text(
                        'Incompatible Feeds',
                style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ..._incompatibleFeeds.entries.map((entry) {
                    final feedName = entry.key;
                    final incompatibleFish = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '• $feedName: Not suitable for ${incompatibleFish.join(', ')}',
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 12,
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ],
          
          // No recommendations message
          if (recommendedFeeds.isEmpty && !hasIncompatibleFeeds) ...[
            Text(
              'All your current feeds are compatible with your fish selection.',
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
        ),
      ),
    );
  }

  Widget _buildRecommendedFeedChip(String feedName) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFeed = feedName;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF00BCD4).withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF00BCD4).withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_circle_outline, color: Color(0xFF00BCD4), size: 16),
            const SizedBox(width: 4),
            Text(
              feedName,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 12,
                              fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryStep() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tank Information Card
          _buildSummaryCard(
            title: 'Tank Information',
            icon: Icons.water_drop,
            children: [
              _buildSummaryRow('Tank Name', _nameController.text),
              _buildSummaryRow('Tank Shape', _selectedShape.toUpperCase()),
              if (_selectedShape == 'rectangle') ...[
                _buildSummaryRow('Length', '${_lengthController.text} ${_selectedUnit.toLowerCase()}'),
                _buildSummaryRow('Width', '${_widthController.text} ${_selectedUnit.toLowerCase()}'),
                _buildSummaryRow('Height', '${_heightController.text} ${_selectedUnit.toLowerCase()}'),
              ] else if (_selectedShape == 'cylinder') ...[
                _buildSummaryRow('Diameter', '${_lengthController.text} ${_selectedUnit.toLowerCase()}'),
                _buildSummaryRow('Height', '${_heightController.text} ${_selectedUnit.toLowerCase()}'),
              ],
              _buildSummaryRow('Volume', '${_calculatedVolume.toStringAsFixed(2)} L (${(_calculatedVolume * 0.264172).toStringAsFixed(2)} US gallons)'),
            ],
          ),

          const SizedBox(height: 16),

          // Fish Selection Card
          if (_fishSelections.isNotEmpty) ...[
            _buildSummaryCard(
              title: 'Fish Selection (${_fishSelections.length} species)',
              icon: FontAwesomeIcons.fish,
              children: [
                ..._fishSelections.entries.map((entry) {
                  final fishName = entry.key;
                  final quantity = entry.value;
                  final fishDetail = _fishDetails[fishName];
                  
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF006064).withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF006064).withOpacity(0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  '$fishName (x$quantity)',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                    fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () => _showFishInfo(fishName),
                                  child: const Icon(
                                    Icons.visibility,
                                    color: Color(0xFF00BCD4),
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                            if (fishDetail != null) ...[
                              const SizedBox(height: 8),
                              if (fishDetail['portion_grams'] != null)
                                _buildSummaryRow('Portion per feeding', '${fishDetail['portion_grams']}g'),
                              if (fishDetail['feeding_frequency'] != null)
                                _buildSummaryRow('Feeding frequency', '${fishDetail['feeding_frequency']} times/day'),
                              if (fishDetail['preferred_food'] != null)
                                _buildSummaryRow('Preferred food', fishDetail['preferred_food']),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  );
                }).toList(),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // Feed Inventory Card
          if (_availableFeeds.isNotEmpty) ...[
            _buildSummaryCard(
              title: 'Feed Inventory (${_availableFeeds.length} types)',
              icon: Icons.restaurant,
              children: [
                ..._availableFeeds.entries.map((entry) {
                  final feedName = entry.key;
                  final quantity = entry.value;
                  final durationData = _feedDurationData[feedName];
                  final isLowStock = durationData?['is_low_stock'] ?? false;
                  final isCritical = durationData?['is_critical'] ?? false;
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isCritical ? Colors.red.shade50 : 
                             isLowStock ? Colors.orange.shade50 : 
                             const Color(0xFF006064).withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isCritical ? Colors.red.shade300 : 
                               isLowStock ? Colors.orange.shade300 : 
                               const Color(0xFF006064).withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.restaurant,
                              color: isCritical ? Colors.red.shade700 : 
                                     isLowStock ? Colors.orange.shade700 : 
                                     const Color(0xFF006064),
                              size: 16,
                        ),
                        const SizedBox(width: 8),
                            Text(
                              feedName,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isCritical ? Colors.red.shade700 : 
                                       isLowStock ? Colors.orange.shade700 : 
                                       const Color(0xFF006064),
                                fontSize: 16,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${quantity.toStringAsFixed(0)}g',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isCritical ? Colors.red.shade700 : 
                                       isLowStock ? Colors.orange.shade700 : 
                                       const Color(0xFF006064),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        if (durationData != null) ...[
                          const SizedBox(height: 8),
                          _buildSummaryRow('Daily consumption', '${durationData['daily_consumption']?.toStringAsFixed(2) ?? '0.00'}g/day'),
                          _buildSummaryRow('Days remaining', '${durationData['days_remaining'] ?? 0} days'),
                          if (durationData['fish_consumption'] != null && 
                              (durationData['fish_consumption'] as Map<String, double>).isNotEmpty) ...[
                            const SizedBox(height: 4),
                            const Text(
                              'Consumption by fish:',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                                fontSize: 12,
                              ),
                            ),
                            ...(durationData['fish_consumption'] as Map<String, double>).entries.map((fishEntry) {
                              return Padding(
                                padding: const EdgeInsets.only(left: 8, top: 2),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        '${fishEntry.key}:',
                                        style: const TextStyle(color: Color(0xFF006064), fontSize: 12),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Flexible(
                                      child: Text(
                                        '${fishEntry.value.toStringAsFixed(2)}g/day',
                                        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12, color: Color(0xFF006064)),
                                        textAlign: TextAlign.right,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ],
                        ],
                      ],
                ),
              );
            }).toList(),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // Compatibility Analysis Card
          if (_fishSelections.length > 1) ...[
            _buildSummaryCard(
              title: 'Compatibility Analysis',
              icon: Icons.analytics,
              children: [
                _buildCompatibilityAnalysis(),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildCompatibilityAnalysis() {
    // Use the existing compatibility results from the API
    final incompatiblePairs = <Map<String, dynamic>>[];
    final conditionalPairs = <Map<String, dynamic>>[];
    final compatiblePairs = <List<String>>[];

    // Get incompatible pairs from API results
    if (_compatibilityResults['incompatible_pairs'] is List) {
      incompatiblePairs.addAll(
        (_compatibilityResults['incompatible_pairs'] as List).cast<Map<String, dynamic>>()
      );
    }

    // Get conditional pairs from API results
    if (_compatibilityResults['conditional_pairs'] is List) {
      conditionalPairs.addAll(
        (_compatibilityResults['conditional_pairs'] as List).cast<Map<String, dynamic>>()
      );
    }

    // Find compatible pairs (pairs not in incompatible or conditional lists)
    final fishList = _fishSelections.keys.toList();
    final allAnalyzedPairs = <String>{};
    
    // Add pairs from API results
    for (final pair in [...incompatiblePairs, ...conditionalPairs]) {
      if (pair['pair'] is List) {
        final pairList = (pair['pair'] as List).map((e) => e.toString()).toList();
        if (pairList.length == 2) {
          final sortedPair = [pairList[0], pairList[1]]..sort();
          allAnalyzedPairs.add(sortedPair.join('|'));
        }
      }
    }
    
    // Find remaining compatible pairs
    for (int i = 0; i < fishList.length; i++) {
      for (int j = i + 1; j < fishList.length; j++) {
        final fish1 = fishList[i];
        final fish2 = fishList[j];
        final sortedPair = [fish1, fish2]..sort();
        final pairKey = sortedPair.join('|');
        
        if (!allAnalyzedPairs.contains(pairKey)) {
          compatiblePairs.add([fish1, fish2]);
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary status
          Container(
          padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: incompatiblePairs.isNotEmpty ? Colors.red.shade50 :
                   conditionalPairs.isNotEmpty ? Colors.orange.shade50 :
                   Colors.green.shade50,
          borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: incompatiblePairs.isNotEmpty ? Colors.red.shade200 :
                     conditionalPairs.isNotEmpty ? Colors.orange.shade200 :
                     Colors.green.shade200,
        ),
          ),
          child: Row(
          children: [
              Icon(
                incompatiblePairs.isNotEmpty ? Icons.warning :
                conditionalPairs.isNotEmpty ? Icons.info :
                Icons.check_circle,
                color: incompatiblePairs.isNotEmpty ? Colors.red :
                       conditionalPairs.isNotEmpty ? Colors.orange :
                       Colors.green,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  incompatiblePairs.isNotEmpty
                      ? '${incompatiblePairs.length} incompatible pair(s) detected'
                      : conditionalPairs.isNotEmpty
                          ? '${conditionalPairs.length} conditional pair(s) need monitoring'
                          : 'All fish are compatible',
                  style: TextStyle(
                    color: incompatiblePairs.isNotEmpty ? Colors.red.shade700 :
                           conditionalPairs.isNotEmpty ? Colors.orange.shade700 :
                           Colors.green.shade700,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              ],
              ),
            ),
        
        const SizedBox(height: 16),
        
        // Incompatible pairs
        if (incompatiblePairs.isNotEmpty) ...[
          Text(
            'Incompatible Pairs:',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.red,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          ...incompatiblePairs.map((pair) {
            final pairList = (pair['pair'] as List).map((e) => e.toString()).toList();
            final reasons = pair['reasons'] as List? ?? [];
            final reasonText = reasons.isNotEmpty ? reasons.join(', ') : 'Incompatible due to different requirements';
            return _buildCompatibilityItem(
              pairList[0], pairList[1], 'incompatible', Colors.red, reasonText
            );
          }),
          const SizedBox(height: 16),
        ],
        
        // Conditional pairs
        if (conditionalPairs.isNotEmpty) ...[
          Text(
            'Conditional Pairs (Monitor Closely):',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.orange,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          ...conditionalPairs.map((pair) {
            final pairList = (pair['pair'] as List).map((e) => e.toString()).toList();
            final reasons = pair['reasons'] as List? ?? [];
            final reasonText = reasons.isNotEmpty ? reasons.join(', ') : 'Monitor fish behavior closely for any signs of stress or aggression';
            return _buildCompatibilityItem(
              pairList[0], pairList[1], 'conditional', Colors.orange, reasonText
            );
          }),
          const SizedBox(height: 16),
        ],
        
        // Compatible pairs
        if (compatiblePairs.isNotEmpty) ...[
          Text(
            'Compatible Pairs:',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.green,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          ...compatiblePairs.map((pair) => _buildCompatibilityItem(
            pair[0], pair[1], 'compatible', Colors.green,
            'These fish are compatible and should work well together'
          )),
          ],
      ],
      );
    }

  Widget _buildCompatibilityItem(String fish1, String fish2, String status, Color color, String reason) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FaIcon(FontAwesomeIcons.fish, color: color, size: 14),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$fish1 ↔ $fish2',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            reason,
            style: TextStyle(
              color: Colors.black87,
              fontSize: 12,
            ),
            overflow: TextOverflow.visible,
            maxLines: 3,
          ),
        ],
      ),
    );
  }


  void _showFishInfo(String fishName) {
    showDialog(
      context: context,
      builder: (BuildContext context) => FishInfoDialog(fishName: fishName),
    );
  }


  Widget _buildSummaryCard({required String title, required IconData icon, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF006064).withOpacity(0.2)),
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
                child: Icon(icon, color: const Color(0xFF006064), size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            flex: 2,
            child: Text(
              '$label:',
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
      );
    }
    
  Widget _buildSection({required String title, required IconData icon, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(20),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F7FA),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: const Color(0xFF006064), size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                  style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

