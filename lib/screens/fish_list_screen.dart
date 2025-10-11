import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/api_config.dart';
import '../widgets/smart_search_widget.dart';
import '../widgets/fish_details_screen.dart';
import '../models/fish_species.dart';
import 'package:lottie/lottie.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../services/favorites_service.dart';

class FishListScreen extends StatefulWidget {
  final String title;
  final bool? isSaltWater;

  const FishListScreen({
    super.key,
    required this.title,
    this.isSaltWater,
  });

  @override
  State<FishListScreen> createState() => _FishListScreenState();
}

// Widget for displaying grouped recommendation fields in an ExpansionTile
class _RecommendationExpansionGroup extends StatefulWidget {
  final List<Map<String, dynamic>> fields;
  final Map<String, dynamic> data;

  const _RecommendationExpansionGroup({
    Key? key,
    required this.fields,
    required this.data,
  }) : super(key: key);

  @override
  State<_RecommendationExpansionGroup> createState() => _RecommendationExpansionGroupState();
}

class _RecommendationExpansionGroupState extends State<_RecommendationExpansionGroup> {

  @override
  Widget build(BuildContext context) {
    final firstField = widget.fields.first;
    final remainingCount = widget.fields.length - 1;
    return ExpansionTile(
      initiallyExpanded: false,
      title: Row(
        children: [
          Icon(firstField['icon'] as IconData, size: 22, color: Color(0xFF006064)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              firstField['label'],
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF006064),
                overflow: TextOverflow.ellipsis,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (remainingCount > 0)
            Flexible(
              child: Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: Text(
                  '+$remainingCount more',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
        ],
      ),
      children: widget.fields.map((field) {
        final value = widget.data[field['key']] ?? 'N/A';
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(field['icon'] as IconData, color: Color(0xFF006064), size: 22),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          field['label'],
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Color(0xFF006064)),
                        ),
                        const SizedBox(height: 4),
                        value is List
                            ? LayoutBuilder(
                                builder: (context, constraints) {
                                  final maxChipWidth = constraints.maxWidth * 0.7;
                                  return Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: value.map<Widget>((v) {
                                      final text = v.toString();
                                      return ConstrainedBox(
                                        constraints: BoxConstraints(maxWidth: maxChipWidth),
                                        child: Chip(
                                          label: Text(
                                            text,
                                            overflow: TextOverflow.ellipsis,
                                            softWrap: false,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  );
                                },
                              )
                            : Text(
                                value.toString(),
                                style: const TextStyle(fontSize: 15),
                                softWrap: true,
                                maxLines: 6,
                                overflow: TextOverflow.ellipsis,
                              ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
      onExpansionChanged: (expanded) {
        if (mounted) {
          setState(() {});
        }
      },
    );
  }
}

class _FishListScreenState extends State<FishListScreen> {
  // Persistent cache for fish details (description, image, care recommendations)
  final Map<String, Map<String, dynamic>> _fishDetailsCache = {};
  List<FishSpecies> fishList = [];
  List<FishSpecies> filteredFishList = [];
  List<Map<String, dynamic>> smartSearchResults = [];
  List<Map<String, dynamic>> topSearchResults = [];
  bool isLoading = true;
  String? error;
  final TextEditingController _searchController = TextEditingController();
  final GlobalKey<SmartSearchWidgetState> _searchWidgetKey = GlobalKey<SmartSearchWidgetState>();
  bool _cacheLoaded = false;
  bool _isUsingSmartSearch = false;
  String _currentSearchQuery = '';
  static const String _fishListCacheKey = 'fish_list_cache_v3'; // Updated version for temperature fix
  static const String _fishListCacheTimeKey = 'fish_list_cache_time_v3';
  final FavoritesService _favoritesService = FavoritesService();
  Set<String> _favoriteFish = {};
  late StreamSubscription _favoritesSubscription;

  // In-memory cache for list thumbnail image URLs
  static final Map<String, String> _thumbUrlCache = <String, String>{};
  static final Map<String, DateTime> _thumbCacheTime = <String, DateTime>{};
  static const Duration _thumbTtl = Duration(minutes: 10);
  // Memoized pending fetches to avoid duplicate requests during rebuilds
  static final Map<String, Future<http.Response>> _thumbFutureCache = {};

  // Add filter state
  Map<String, bool> waterTypeFilters = {'Freshwater': false, 'Saltwater': false};
  Map<String, bool> temperamentFilters = {'Peaceful': false, 'Semi-aggressive': false, 'Aggressive': false};
  Map<String, bool> socialBehaviorFilters = {'Schooling': false, 'Solitary': false, 'Community': false};
  Map<String, bool> dietFilters = {'Omnivore': false, 'Carnivore': false, 'Herbivore': false};



  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    await _favoritesService.loadFavorites();
    if (mounted) {
      setState(() {
        _favoriteFish = _favoritesService.getFavorites();
      });
    }
    _favoritesSubscription = _favoritesService.favoritesStream.listen((favorites) {
      if (mounted) {
        setState(() {
          _favoriteFish = favorites;
        });
      }
    });
    await _loadFishDetailsCache();
    await _loadFishListWithCache();
  }

  Future<void> _loadFishDetailsCache() async {
    if (_cacheLoaded) return;
    final prefs = await SharedPreferences.getInstance();
    final cachedData = prefs.getString('fish_details_cache');
    if (cachedData != null) {
      try {
        final Map<String, dynamic> decoded = json.decode(cachedData);
        decoded.forEach((key, value) {
          if (value is Map<String, dynamic>) {
            _fishDetailsCache[key] = value;
          } else if (value is Map) {
            _fishDetailsCache[key] = Map<String, dynamic>.from(value);
          }
        });
      } catch (e) {
        // Ignore cache load errors
      }
    }
    _cacheLoaded = true;
  }

  Future<void> _saveFishDetailsCache() async {
    final prefs = await SharedPreferences.getInstance();
    final cacheString = json.encode(_fishDetailsCache);
    await prefs.setString('fish_details_cache', cacheString);
  }

  Future<void> _loadFishListWithCache() async {
    try {
      if (!mounted) return;
      setState(() {
        isLoading = true;
        error = null;
      });
      
      // Force fresh fetch for now to ensure temperature parsing works
      print('DEBUG: Forcing fresh fetch to ensure temperature parsing works');
      await fetchFishList(saveToCache: true);
      return;
    } catch (e) {
      // Fallback to network fetch on any cache issue
      await fetchFishList(saveToCache: true);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _favoritesSubscription.cancel();
    // Optionally save cache on dispose (for safety)
    _saveFishDetailsCache();
    super.dispose();
  }

  void _onSmartSearchChanged(String query) {
    print('DEBUG SEARCH: Search query changed to: "$query"');
    setState(() {
      _currentSearchQuery = query;
      _isUsingSmartSearch = query.isNotEmpty;
      
      // If query is empty, clear all search results
      if (query.isEmpty) {
        print('DEBUG SEARCH: Clearing search results');
        smartSearchResults = [];
        topSearchResults = [];
        filteredFishList = fishList;
      }
    });
  }

  void _clearSearch() {
    // Clear the search widget first
    _searchWidgetKey.currentState?.clearSearch();
    
    setState(() {
      _currentSearchQuery = '';
      _isUsingSmartSearch = false;
      smartSearchResults = [];
      topSearchResults = [];
      filteredFishList = fishList;
    });
  }

  void _onSmartSearchResults(List<Map<String, dynamic>> results) {
    if (!mounted) return;
    
    print('DEBUG SEARCH: Received ${results.length} search results');
    if (results.isNotEmpty) {
      print('DEBUG SEARCH: First result keys: ${results.first.keys.toList()}');
      print('DEBUG SEARCH: First result search_score: ${results.first['search_score']}');
    }
    
    setState(() {
      smartSearchResults = results;
      
      if (_isUsingSmartSearch) {
        // Extract top 10 results based on search score
        topSearchResults = results
            .where((fish) => fish['search_score'] != null)
            .toList()
          ..sort((a, b) => (b['search_score'] as double).compareTo(a['search_score'] as double));
        
        // Take top 10 results
        topSearchResults = topSearchResults.take(10).toList();
        
        print('DEBUG SEARCH: Top results count: ${topSearchResults.length}');
        
        // Convert smart search results to FishSpecies objects with better error handling
        filteredFishList = results.map((fishData) {
          try {
            // Ensure all required fields are present with fallbacks
            final processedFishData = Map<String, dynamic>.from(fishData);
            
            // Add fallbacks for missing fields
            processedFishData['common_name'] ??= 'Unknown Fish';
            processedFishData['scientific_name'] ??= 'Unknown';
            processedFishData['max_size'] ??= processedFishData['max_size_(cm)'] ?? 'Unknown';
            processedFishData['temperament'] ??= 'Unknown';
            processedFishData['water_type'] ??= 'Unknown';
            processedFishData['temperature_range'] ??= 'Unknown';
            processedFishData['ph_range'] ??= 'Unknown';
            processedFishData['habitat_type'] ??= 'Unknown';
            processedFishData['social_behavior'] ??= 'Unknown';
            processedFishData['tank_level'] ??= 'Unknown';
            processedFishData['minimum_tank_size'] ??= processedFishData['minimum_tank_size_(l)'] ?? 'Unknown';
            processedFishData['compatibility_notes'] ??= 'Unknown';
            processedFishData['diet'] ??= 'Unknown';
            processedFishData['lifespan'] ??= 'Unknown';
            processedFishData['care_level'] ??= 'Unknown';
            processedFishData['preferred_food'] ??= 'Unknown';
            processedFishData['feeding_frequency'] ??= 'Unknown';
            processedFishData['description'] ??= 'No description available.';
            
        print('DEBUG SEARCH: Converting fish: ${processedFishData['common_name']}');
        print('DEBUG SEARCH: Fish data keys: ${processedFishData.keys.toList()}');
        print('DEBUG SEARCH: Search score: ${processedFishData['search_score']}');
        final fish = FishSpecies.fromJson(processedFishData);
        print('DEBUG SEARCH: Converted fish - Name: ${fish.commonName}, Temp: ${fish.temperatureRange}, Tank: ${fish.minimumTankSize}');
        return fish;
          } catch (e) {
            print('ERROR converting fish data: $e');
            print('Problematic fish data: $fishData');
            // Return a default fish to prevent crash
            return FishSpecies(
              commonName: fishData['common_name']?.toString() ?? 'Unknown Fish',
              scientificName: fishData['scientific_name']?.toString() ?? 'Unknown',
              maxSize: fishData['max_size']?.toString() ?? fishData['max_size_(cm)']?.toString() ?? 'Unknown',
              temperament: fishData['temperament']?.toString() ?? 'Unknown',
              waterType: fishData['water_type']?.toString() ?? 'Unknown',
              temperatureRange: fishData['temperature_range']?.toString() ?? 'Unknown',
              phRange: fishData['ph_range']?.toString() ?? 'Unknown',
              habitatType: fishData['habitat_type']?.toString() ?? 'Unknown',
              socialBehavior: fishData['social_behavior']?.toString() ?? 'Unknown',
              tankLevel: fishData['tank_level']?.toString() ?? 'Unknown',
              minimumTankSize: fishData['minimum_tank_size']?.toString() ?? fishData['minimum_tank_size_(l)']?.toString() ?? 'Unknown',
              compatibilityNotes: fishData['compatibility_notes']?.toString() ?? 'Unknown',
              diet: fishData['diet']?.toString() ?? 'Unknown',
              lifespan: fishData['lifespan']?.toString() ?? 'Unknown',
              careLevel: fishData['care_level']?.toString() ?? 'Unknown',
              preferredFood: fishData['preferred_food']?.toString() ?? 'Unknown',
              feedingFrequency: fishData['feeding_frequency']?.toString() ?? 'Unknown',
            );
          }
        }).toList();
        
        print('DEBUG SEARCH: Filtered fish list count: ${filteredFishList.length}');
      } else {
        // Clear top results when not searching
        topSearchResults = [];
        // Use regular fish list when not searching
        filteredFishList = fishList;
      }
    });
  }


  Future<void> fetchFishList({bool saveToCache = false}) async {
    try {
      // Check if widget is still mounted before setState
      if (!mounted) return;
      
      setState(() {
        isLoading = true;
        error = null;
      });

      // Check server connection first
      final isConnected = await ApiConfig.checkServerConnection();
      if (!isConnected) {
        if (!mounted) return;
        setState(() {
          error = 'Cannot connect to server at ${ApiConfig.baseUrl}\nPlease make sure the server is running and accessible.';
          isLoading = false;
        });
        return;
      }

      print('Fetching fish list from: ${ApiConfig.baseUrl}/fish-list');
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/fish-list'),
        headers: {'Connection': 'keep-alive'},
      ).timeout(ApiConfig.timeout);
      
      print('Response status code: ${response.statusCode}');
      // Print first fish item to see available fields
      final List<dynamic> data = json.decode(response.body);
      if (data.isNotEmpty) {
        print('First fish item fields: ${(data.first as Map<String, dynamic>).keys.toList()}');
        print('First fish temperature_range: ${(data.first as Map<String, dynamic>)['temperature_range']}');
      }

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        
        // Debug: Check what temperature data we're getting from API
        if (data.isNotEmpty) {
          final firstFish = data.first as Map<String, dynamic>;
          print('DEBUG API: First fish name: ${firstFish['common_name']}');
          print('DEBUG API: temperature_range from API: ${firstFish['temperature_range']}');
          print('DEBUG API: minimum_tank_size_(l) from API: ${firstFish['minimum_tank_size_(l)']}');
          print('DEBUG API: All available keys: ${firstFish.keys.toList()}');
          
          // Create FishSpecies and check temperature
          final fishSpecies = FishSpecies.fromJson(firstFish);
          print('DEBUG API: FishSpecies temperatureRange after parsing: ${fishSpecies.temperatureRange}');
          print('DEBUG API: FishSpecies minimumTankSize after parsing: ${fishSpecies.minimumTankSize}');
        }
        
        if (!mounted) return;
        setState(() {
          final fishListTemp = data
              .asMap()
              .entries
              .map<FishSpecies>((entry) {
                final index = entry.key;
                final item = entry.value;
                try {
                  final fish = FishSpecies.fromJson(Map<String, dynamic>.from(item as Map));
                  // Debug first few fish temperature parsing
                  if (index < 10) {
                    print('DEBUG FRESH: ${fish.commonName} - Raw temp: ${item['temperature_range']} -> Parsed: ${fish.temperatureRange}');
                    print('DEBUG FRESH: ${fish.commonName} - Raw tank: ${item['minimum_tank_size_(l)']} -> Parsed: ${fish.minimumTankSize}');
                  }
                  return fish;
                } catch (e) {
                  print('ERROR parsing fish at index $index: $e');
                  print('Item data: $item');
                  // Return a default fish to prevent crash
                  return FishSpecies(
                    commonName: 'Unknown Fish',
                    scientificName: 'Unknown',
                    maxSize: 'Unknown',
                    temperament: 'Unknown',
                    waterType: 'Unknown',
                    temperatureRange: 'Unknown',
                    phRange: 'Unknown',
                    habitatType: 'Unknown',
                    socialBehavior: 'Unknown',
                    tankLevel: 'Unknown',
                    minimumTankSize: 'Unknown',
                    compatibilityNotes: 'Unknown',
                    diet: 'Unknown',
                    lifespan: 'Unknown',
                    careLevel: 'Unknown',
                    preferredFood: 'Unknown',
                    feedingFrequency: 'Unknown',
                  );
                }
              })
              .where((fish) => 
                widget.isSaltWater == null ||
                (widget.isSaltWater == true && fish.waterType == 'Saltwater') ||
                (widget.isSaltWater == false && fish.waterType == 'Freshwater'))
              .toList();
          
          // Sort alphabetically by common name
          fishListTemp.sort((a, b) => a.commonName.toLowerCase().compareTo(b.commonName.toLowerCase()));
          fishList = fishListTemp;
          filteredFishList = fishList;
          isLoading = false;
          error = null;
        });
        if (saveToCache) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_fishListCacheKey, json.encode(data));
          await prefs.setInt(_fishListCacheTimeKey, DateTime.now().millisecondsSinceEpoch);
        }
      } else {
        print('Error response: ${response.body}');
        if (!mounted) return;
        setState(() {
          error = 'Failed to load fish data: ${response.statusCode}\nResponse: ${response.body}';
          isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      print('Error fetching fish list: $e');
      print('Stack trace: $stackTrace');
      if (!mounted) return;
      setState(() {
        error = 'Error connecting to server: $e\nPlease make sure the server is running at ${ApiConfig.baseUrl}';
        isLoading = false;
      });
    }
  }
  
  void _showFishDetails(FishSpecies fish) async {
    final commonName = fish.commonName;
    final scientificName = fish.scientificName;
    final cacheKey = '$commonName|$scientificName';

    Map<String, dynamic> fishData;

    if (_fishDetailsCache.containsKey(cacheKey)) {
      fishData = _fishDetailsCache[cacheKey]!;
    } else {
      fishData = fish.toJson();
    // Ensure all parsed data is properly formatted with correct field names
      fishData['temperature_range'] = fish.temperatureRange;
      fishData['max_size'] = fish.maxSize;
      fishData['minimum_tank_size'] = fish.minimumTankSize;
      fishData['water_type'] = fish.waterType;
      fishData['temperament'] = fish.temperament;
      fishData['care_level'] = fish.careLevel;
      fishData['lifespan'] = fish.lifespan;
      fishData['ph_range'] = fish.phRange;
      fishData['social_behavior'] = fish.socialBehavior;
      fishData['diet'] = fish.diet;
      fishData['preferred_food'] = fish.preferredFood;
      fishData['feeding_frequency'] = fish.feedingFrequency;
      fishData['description'] = fish.description;
      
      // Fetch additional details if not cached
      try {
        await _fetchFishDescriptionFromDatabase(fishData, commonName, scientificName);
        await _fetchCareRecommendationsFromDatabase(fishData, commonName, scientificName, fishData);
        
        // Save to cache
        _fishDetailsCache[cacheKey] = fishData;
      await _saveFishDetailsCache();
    } catch (e) {
        print('Error loading additional details: $e');
      }
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (BuildContext context) {
          return FishDetailsScreen(
            commonName: commonName,
            scientificName: scientificName,
            fishData: fishData,
            useCapturedImage: false,
          );
        },
      ),
    );
    }

  /// Fetch fish description from Supabase database
  Future<void> _fetchFishDescriptionFromDatabase(Map<String, dynamic> fishCopy, String commonName, String scientificName) async {
    try {
      final response = await Supabase.instance.client
          .from('fish_species')
          .select('description')
          .or('common_name.ilike.%$commonName%,scientific_name.ilike.%$scientificName%')
          .limit(1);

      if (response.isNotEmpty && response.first['description'] != null) {
        fishCopy['description'] = response.first['description'];
      } else {
        // Fallback to local description generation if no database description found
        _generateLocalDescription(fishCopy, commonName, scientificName, fishCopy);
      }
    } catch (e) {
      print('Error fetching description from database: $e');
      // Fallback to local description generation on error
      _generateLocalDescription(fishCopy, commonName, scientificName, fishCopy);
    }
  }

  /// Generate local description when database description is not available
  void _generateLocalDescription(Map<String, dynamic> fishCopy, String commonName, String scientificName, Map<String, dynamic> fish) {
    final waterType = fish['water_type'] ?? 'Unknown';
    final maxSize = fish['max_size'] ?? 'Unknown';
    final temperament = fish['temperament'] ?? 'Unknown';
    final careLevel = fish['care_level'] ?? 'Unknown';
    
    fishCopy['description'] = 'The $commonName is a $waterType fish that can grow up to $maxSize cm. '
        'It has a $temperament temperament and requires $careLevel care level. '
        'This species is known for its unique characteristics and makes an interesting addition to aquariums.';
  }

  /// Fetch care recommendations from Supabase database
  Future<void> _fetchCareRecommendationsFromDatabase(Map<String, dynamic> fishCopy, String commonName, String scientificName, Map<String, dynamic> fish) async {
    try {
      final response = await Supabase.instance.client
          .from('fish_species')
          // Fetch only diet-related fields, as temperature and other data are already in the fish object
          .select('diet, preferred_food, feeding_frequency, portion_grams, overfeeding_risks, feeding_notes')
          .or('common_name.ilike.%$commonName%,scientific_name.ilike.%$scientificName%')
          .limit(1);

      if (response.isNotEmpty) {
        final dbData = response.first;
        final minTankSize = fish['minimum_tank_size_(l)'] ?? fish['minimum_tank_size_l'] ?? fish['minimum_tank_size'] ?? 'Unknown';
        final waterType = fish['water_type'] ?? 'Unknown';
        final temperament = fish['temperament'] ?? 'Unknown';
        final careLevel = fish['care_level'] ?? 'Unknown';
        
        fishCopy['care_recommendations'] = {
          'diet_type': dbData['diet'] ?? fish['diet'] ?? 'Omnivore',
          'preferred_foods': dbData['preferred_food'] ?? 'Flake food, Pellets',
          'feeding_frequency': dbData['feeding_frequency'] ?? '2-3 times daily',
          'portion_size': dbData['portion_grams'] != null ? '${dbData['portion_grams']}g per feeding' : 'Small amounts that can be consumed in 2-3 minutes',
          'overfeeding_risks': (dbData['overfeeding_risks'] != null && dbData['overfeeding_risks'].toString().isNotEmpty) 
              ? dbData['overfeeding_risks'] 
              : 'Can lead to water quality issues and health problems',
          'feeding_notes': (dbData['feeding_notes'] != null && dbData['feeding_notes'].toString().isNotEmpty) 
              ? dbData['feeding_notes'] 
              : 'Follow standard feeding guidelines for this species',
          'minimum_tank_size': '$minTankSize L',
          'water_type': waterType,
          'temperament': temperament,
          'care_level': careLevel,
        };
      } else {
        // Fallback to local care recommendations if no database data found
        _generateLocalCareRecommendations(fishCopy, commonName, scientificName, fish);
      }
    } catch (e) {
      print('Error fetching care recommendations from database: $e');
      // Fallback to local care recommendations on error
      _generateLocalCareRecommendations(fishCopy, commonName, scientificName, fish);
    }
  }

  /// Generate care recommendations locally when database data is not available (fallback)
  void _generateLocalCareRecommendations(Map<String, dynamic> fishCopy, String commonName, String scientificName, Map<String, dynamic> fish) {
    final diet = fish['diet'] ?? 'Omnivore';
    final minTankSize = fish['minimum_tank_size_(l)'] ?? fish['minimum_tank_size_l'] ?? fish['minimum_tank_size'] ?? 'Unknown';
    final waterType = fish['water_type'] ?? 'Unknown';
    final temperament = fish['temperament'] ?? 'Unknown';
    final careLevel = fish['care_level'] ?? 'Unknown';
    
    fishCopy['care_recommendations'] = {
      'diet_type': diet,
      'preferred_foods': 'Flake food, Pellets',
      'feeding_frequency': '2-3 times daily',
      'portion_size': 'Small amounts that can be consumed in 2-3 minutes',
      'overfeeding_risks': 'Can lead to water quality issues and health problems',
      'feeding_notes': 'Follow standard feeding guidelines for this species',
      'minimum_tank_size': '$minTankSize L',
      'water_type': waterType,
      'temperament': temperament,
      'care_level': careLevel,
    };
  }





Widget buildFishListImage(String? fishName) {
  final name = (fishName ?? '').trim();
  if (name.isEmpty) {
    return Container(
      width: 120,
      height: 80,
      color: Colors.grey[200],
      child: const Icon(Icons.image_not_supported_outlined, color: Colors.grey, size: 24),
    );
  }

  // Serve from cache if fresh
  final cachedUrl = _thumbUrlCache[name];
  final fetchedAt = _thumbCacheTime[name];
  final fresh = fetchedAt != null && DateTime.now().difference(fetchedAt) < _thumbTtl;
  if (cachedUrl != null && cachedUrl.isNotEmpty && fresh) {
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final cacheWidth = (120 * dpr).round();
    final cacheHeight = (80 * dpr).round();
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.network(
        cachedUrl,
        width: 120,
        height: 80,
        fit: BoxFit.cover,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
        filterQuality: FilterQuality.low,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(color: Colors.grey[200]);
        },
        errorBuilder: (c, e, s) => Container(
          color: Colors.grey[200],
          child: const Icon(Icons.image_not_supported_outlined, color: Colors.grey, size: 24),
        ),
      ),
    );
  }

  // Use memoized future to curb duplicate round-trips during rebuilds
  final future = _thumbFutureCache[name] ??= http.get(Uri.parse(ApiConfig.getFishImageUrl(name)));
  return FutureBuilder<http.Response>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return Container(
          width: 120,
          height: 80,
          color: Colors.grey[200],
          child: const SizedBox.shrink(),
        );
      }
      
      if (snapshot.hasError) {
        // Debug: Print error details
        print('Image fetch error for "$name": ${snapshot.error}');
        return Container(
          width: 120,
          height: 80,
          color: Colors.grey[200],
          child: const Icon(Icons.image_not_supported_outlined, color: Colors.grey, size: 24),
        );
      }
      
      if (!snapshot.hasData || snapshot.data!.statusCode != 200) {
        // Debug: Print response details
        if (snapshot.hasData) {
          print('API returned ${snapshot.data!.statusCode} for "$name": ${snapshot.data!.body}');
        }
        return Container(
          width: 120,
          height: 80,
          color: Colors.grey[200],
          child: const Icon(Icons.image_not_supported_outlined, color: Colors.grey, size: 24),
        );
      }
      
      try {
        // For local images, the response is the actual image file, not JSON
        // We need to construct the URL for the image
        final String imageUrl = '${ApiConfig.baseUrl}/fish-image/${Uri.encodeComponent(name)}';
        
        // Debug: Print response data
        print('Local image URL for "$name": $imageUrl');
        
        if (imageUrl.isNotEmpty) {
          // Update cache (no need to setState for list item image)
          _thumbUrlCache[name] = imageUrl;
          _thumbCacheTime[name] = DateTime.now();
          // Drop memoized future after success to prevent memory growth and allow TTL to work
          _thumbFutureCache.remove(name);
        } else {
          print('Empty image URL returned for "$name"');
        }
        
        if (imageUrl.isEmpty) {
          return Container(
            width: 120,
            height: 80,
            color: Colors.grey[200],
            child: const Icon(Icons.image_not_supported_outlined, color: Colors.grey, size: 24),
          );
        }
        
        return ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            width: 120,
            height: 80,
            child: Image.network(
              imageUrl,
              width: 120,
              height: 80,
              fit: BoxFit.cover,
              cacheWidth: (120 * MediaQuery.of(context).devicePixelRatio).round(),
              cacheHeight: (80 * MediaQuery.of(context).devicePixelRatio).round(),
              filterQuality: FilterQuality.low,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(color: Colors.grey[200]);
              },
              errorBuilder: (c, e, s) {
                // Debug: Print image loading error
                print('Image loading failed for "$name" from URL: $imageUrl - Error: $e');
                return Container(
                  color: Colors.grey[200],
                  child: const Icon(Icons.image_not_supported_outlined, color: Colors.grey, size: 24),
                );
              },
            ),
          ),
        );
      } catch (e) {
        // Debug: Print error
        print('Error processing image for "$name": $e');
        return Container(
          width: 120,
          height: 80,
          color: Colors.grey[200],
          child: const Icon(Icons.image_not_supported_outlined, color: Colors.grey, size: 24),
        );
      }
    },
  );
}


  
  void _openFilterModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: MediaQuery.of(context).viewInsets,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Filter Fish', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Active Filters', style: TextStyle(fontWeight: FontWeight.w600)),
                          TextButton(
                            onPressed: () {
                              setModalState(() {
                                waterTypeFilters.updateAll((key, value) => false);
                                temperamentFilters.updateAll((key, value) => false);
                                socialBehaviorFilters.updateAll((key, value) => false);
                                dietFilters.updateAll((key, value) => false);
                              });
                            },
                            child: const Text('Clear All'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text('Water Type', style: TextStyle(fontWeight: FontWeight.w600)),
                      ...waterTypeFilters.keys.map((type) => CheckboxListTile(
                        title: Text(type),
                        value: waterTypeFilters[type],
                        onChanged: (val) {
                          setModalState(() => waterTypeFilters[type] = val ?? false);
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                        dense: true,
                      )),
                      const Divider(),
                      const Text('Temperament', style: TextStyle(fontWeight: FontWeight.w600)),
                      ...temperamentFilters.keys.map((type) => CheckboxListTile(
                        title: Text(type),
                        value: temperamentFilters[type],
                        onChanged: (val) {
                          setModalState(() => temperamentFilters[type] = val ?? false);
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                        dense: true,
                      )),
                      const Divider(),
                      const Text('Social Behavior', style: TextStyle(fontWeight: FontWeight.w600)),
                      ...socialBehaviorFilters.keys.map((type) => CheckboxListTile(
                        title: Text(type),
                        value: socialBehaviorFilters[type],
                        onChanged: (val) {
                          setModalState(() => socialBehaviorFilters[type] = val ?? false);
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                        dense: true,
                      )),
                      const Divider(),
                      const Text('Diet', style: TextStyle(fontWeight: FontWeight.w600)),
                      ...dietFilters.keys.map((type) => CheckboxListTile(
                        title: Text(type),
                        value: dietFilters[type],
                        onChanged: (val) {
                          setModalState(() => dietFilters[type] = val ?? false);
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                        dense: true,
                      )),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            if (mounted) {
                              setState(() {}); // To trigger filter in main list
                            }
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF006064),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          child: const Text('Apply Filters'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  List<FishSpecies> get _filteredFishListWithFilters {
    List<FishSpecies> list = filteredFishList;
    
    // Don't apply additional filters when using smart search
    // Smart search already provides relevant results
    if (_isUsingSmartSearch) {
      print('DEBUG SEARCH: Using smart search results directly (${list.length} fish)');
    } else {
      // Apply manual filters only when not using smart search
      print('DEBUG SEARCH: Applying manual filters to ${list.length} fish');
      
      // Water type
      if (waterTypeFilters.containsValue(true)) {
        list = list.where((fish) => waterTypeFilters[fish.waterType] == true).toList();
      }
      // Temperament
      if (temperamentFilters.containsValue(true)) {
        list = list.where((fish) => temperamentFilters[fish.temperament] == true).toList();
      }
      // Social Behavior
      if (socialBehaviorFilters.containsValue(true)) {
        list = list.where((fish) => socialBehaviorFilters[fish.socialBehavior] == true).toList();
      }
      // Diet
      if (dietFilters.containsValue(true)) {
        list = list.where((fish) => dietFilters[fish.diet] == true).toList();
      }
    }
    
    final favorites = list.where((fish) => _favoriteFish.contains(fish.commonName)).toList();
    final nonFavorites = list.where((fish) => !_favoriteFish.contains(fish.commonName)).toList();
    list = [...favorites, ...nonFavorites];
    
    print('DEBUG SEARCH: After manual filtering and sorting: ${list.length} fish');
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF006064)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.title,
          style: const TextStyle(
            color: Color(0xFF006064),
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_alt_outlined, color: Color(0xFF006064)),
            onPressed: _openFilterModal,
            tooltip: 'Filter',
          ),
        ],
      ),
      body: Column(
        children: [
          // Smart Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SmartSearchWidget(
              key: _searchWidgetKey,
              onSearchChanged: _onSmartSearchChanged,
              onSearchResults: _onSmartSearchResults,
              hintText: 'Search fish...',
              showAutocomplete: true,
            ),
          ),
          
          // Search Results Indicator
          if (_isUsingSmartSearch && _filteredFishListWithFilters.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFF006064).withOpacity(0.1),
              child: Row(
                children: [
                  Icon(
                    Icons.search,
                    size: 16,
                    color: const Color(0xFF006064),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Found ${_filteredFishListWithFilters.length} fish for "$_currentSearchQuery"',
                      style: const TextStyle(
                        color: Color(0xFF006064),
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => _onSmartSearchChanged(''),
                    child: const Text(
                      'Clear',
                      style: TextStyle(
                        color: Color(0xFF006064),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
          // Top Results Section
          if (_isUsingSmartSearch && topSearchResults.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: const Color(0xFF006064).withOpacity(0.05),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.star,
                        size: 18,
                        color: const Color(0xFF006064),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Top ${topSearchResults.length} Results',
                        style: const TextStyle(
                          color: Color(0xFF006064),
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF006064).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Best Matches',
                          style: TextStyle(
                            color: const Color(0xFF006064),
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 110,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: topSearchResults.length,
                      itemBuilder: (context, index) {
                        final fishData = topSearchResults[index];
                        final fish = FishSpecies.fromJson(fishData);
                        final score = fishData['search_score'] as double? ?? 0.0;
                        
                        return Container(
                          width: 120,
                          margin: const EdgeInsets.only(right: 8),
                          child: _TopResultCard(
                            fish: fish,
                            score: score,
                            onTap: () => _showFishDetails(fish),
                            buildFishListImage: buildFishListImage,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          
          // Fish List
          Expanded(
            child: isLoading
                ? Center(
                    child: SizedBox(
                      width: 200,
                      height: 200,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(seconds: 3),
                        builder: (context, value, child) {
                          return Lottie.asset(
                            'lib/lottie/BowlAnimation.json',
                            width: 200,
                            height: 200,
                            fit: BoxFit.contain,
                            repeat: false,
                            frameRate: FrameRate(60),
                          );
                        },
                      ),
                    ),
                  )
                : error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              error!,
                              style: const TextStyle(color: Colors.red),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: fetchFishList,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF006064),
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _filteredFishListWithFilters.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _isUsingSmartSearch ? Icons.search_off : FontAwesomeIcons.fish,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _isUsingSmartSearch 
                                      ? 'No fish found for "$_currentSearchQuery"'
                                      : 'No fish found',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                if (_isUsingSmartSearch) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'Try different keywords or check spelling',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      _clearSearch();
                                    },
                                    icon: const Icon(Icons.clear),
                                    label: const Text('Clear Search'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF006064),
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            itemCount: _filteredFishListWithFilters.length,
                            itemBuilder: (context, index) {
                              final fish = _filteredFishListWithFilters[index];
                              return _DetailedFishCard(
                                fish: fish,
                                onTap: () => _showFishDetails(fish),
                                buildFishListImage: buildFishListImage,
                                isFavorite: _favoriteFish.contains(fish.commonName),
                                onFavoriteTap: () => _favoritesService.toggleFavorite(fish.commonName),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

// Detailed Fish Card Widget - 1 column with comprehensive information
class _DetailedFishCard extends StatefulWidget {
  final FishSpecies fish;
  final VoidCallback onTap;
  final Widget Function(String?) buildFishListImage;
  final bool isFavorite;
  final VoidCallback onFavoriteTap;

  const _DetailedFishCard({
    required this.fish,
    required this.onTap,
    required this.buildFishListImage,
    required this.isFavorite,
    required this.onFavoriteTap,
  });

  @override
  State<_DetailedFishCard> createState() => _DetailedFishCardState();
}

class _DetailedFishCardState extends State<_DetailedFishCard> {
  bool _isDescriptionExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(
          color: Colors.grey.shade300,
          width: 1,
        ),
      ),
      elevation: 2,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fish Image and Basic Info Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Fish Image
                  Container(
                    width: 120,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: widget.buildFishListImage(widget.fish.commonName),
                    ),
                  ),
                  
                  const SizedBox(width: 16),
                  
                  // Fish Names and Water Type
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Fish Common Name
                        Text(
                          widget.fish.commonName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF006064),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        
                        const SizedBox(height: 4),
                        
                        // Scientific Name
                        Text(
                          widget.fish.scientificName,
                          style: TextStyle(
                            fontSize: 16,
                            fontStyle: FontStyle.italic,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        
                        const SizedBox(height: 8),
                        
                        // Water Type Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: widget.fish.waterType == 'Freshwater' 
                                ? Colors.teal.withOpacity(0.1)
                                : Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: widget.fish.waterType == 'Freshwater' 
                                  ? Colors.teal
                                  : Colors.blue,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            widget.fish.waterType,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: widget.fish.waterType == 'Freshwater' 
                                  ? Colors.teal[700]
                                  : Colors.blue[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      widget.isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: widget.isFavorite ? Colors.redAccent : Colors.grey,
                    ),
                    onPressed: widget.onFavoriteTap,
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Description with See More/See Less
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Description',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF006064),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    (widget.fish.description?.isNotEmpty == true) 
                        ? widget.fish.description! 
                        : 'No description available.',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      height: 1.4,
                    ),
                    maxLines: _isDescriptionExpanded ? null : 3,
                    overflow: _isDescriptionExpanded ? null : TextOverflow.ellipsis,
                  ),
                  
                  // See More/See Less Button
                  if ((widget.fish.description?.length ?? 0) > 150) ...[
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isDescriptionExpanded = !_isDescriptionExpanded;
                        });
                      },
                      child: Text(
                        _isDescriptionExpanded ? 'See less' : 'See more',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF00BCD4),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              
              const SizedBox(height: 16),
              
              // View Details Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: widget.onTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00BCD4),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    elevation: 2,
                  ),
                  child: const Text(
                    'View Details',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _ExpandableInfoItem extends StatefulWidget {
  final String label;
  final String value;
  final IconData icon;

  const _ExpandableInfoItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  State<_ExpandableInfoItem> createState() => _ExpandableInfoItemState();
}

class _ExpandableInfoItemState extends State<_ExpandableInfoItem> {
  bool isExpanded = false;

  String _truncateText(String text, int wordLimit) {
    final words = text.split(' ');
    if (words.length <= wordLimit) {
      return text;
    }
    return '${words.take(wordLimit).join(' ')}...';
  }

  @override
  Widget build(BuildContext context) {
    final wordCount = widget.value.split(' ').length;
    final shouldTruncate = wordCount > 10;
    final displayText = shouldTruncate && !isExpanded 
        ? _truncateText(widget.value, 10)
        : widget.value;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            widget.icon,
            size: 22,
            color: const Color(0xFF00BCD4),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: Text(
              widget.label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF006064),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  displayText,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.right,
                ),
                if (shouldTruncate) ...[
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        isExpanded = !isExpanded;
                      });
                    },
                    child: Text(
                      isExpanded ? 'See less' : 'See more',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF00BCD4),
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                      ),
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
}


class _TopResultCard extends StatelessWidget {
  final FishSpecies fish;
  final double score;
  final VoidCallback onTap;
  final Widget Function(String?) buildFishListImage;

  const _TopResultCard({
    required this.fish,
    required this.score,
    required this.onTap,
    required this.buildFishListImage,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(
          color: const Color(0xFF006064).withOpacity(0.2),
          width: 1,
        ),
      ),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Column(
          children: [
            // Fish image - 50% of card height
            Expanded(
              flex: 1,
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
                child: buildFishListImage(fish.commonName),
              ),
            ),
            // Fish names - 50% of card height
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Fish common name
                    Text(
                      fish.commonName,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Fish scientific name
                    Text(
                      fish.scientificName,
                      style: TextStyle(
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
