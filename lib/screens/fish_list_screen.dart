import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../widgets/description_widget.dart';
import '../services/openai_service.dart';
import 'package:lottie/lottie.dart';
import 'dart:math' as math;
import 'dart:collection';

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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
  List<Map<String, dynamic>> fishList = [];
  List<Map<String, dynamic>> filteredFishList = [];
  bool isLoading = true;
  String? error;
  final TextEditingController _searchController = TextEditingController();
  bool _cacheLoaded = false;
  static const String _fishListCacheKey = 'fish_list_cache_v2';
  static const String _fishListCacheTimeKey = 'fish_list_cache_time_v2';
  static const Duration _fishListTtl = Duration(minutes: 30);

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
    _loadFishDetailsCache().then((_) {
      _loadFishListWithCache();
    });
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

      final prefs = await SharedPreferences.getInstance();
      final cachedList = prefs.getString(_fishListCacheKey);
      final cachedAtMillis = prefs.getInt(_fishListCacheTimeKey);
      final now = DateTime.now();
      if (cachedList != null && cachedAtMillis != null) {
        final cachedAt = DateTime.fromMillisecondsSinceEpoch(cachedAtMillis);
        final fresh = now.difference(cachedAt) < _fishListTtl;
        final List<dynamic> data = json.decode(cachedList);
        final list = data
            .map<Map<String, dynamic>>((item) => item as Map<String, dynamic>)
            .where((fish) =>
                widget.isSaltWater == null ||
                (widget.isSaltWater == true && fish['water_type'] == 'Saltwater') ||
                (widget.isSaltWater == false && fish['water_type'] == 'Freshwater'))
            .toList();
        if (!mounted) return;
        setState(() {
          fishList = list;
          filteredFishList = fishList;
          isLoading = false;
        });
        // Background refresh if stale
        if (!fresh) {
          unawaited(fetchFishList(saveToCache: true));
        }
        return;
      }

      // No cache, fetch normally and save
      await fetchFishList(saveToCache: true);
    } catch (e) {
      // Fallback to network fetch on any cache issue
      await fetchFishList(saveToCache: true);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    // Optionally save cache on dispose (for safety)
    _saveFishDetailsCache();
    super.dispose();
  }

  void _filterFishList(String query) {
    if (!mounted) return;
    setState(() {
      if (query.isEmpty) {
        filteredFishList = fishList;
      } else {
        filteredFishList = fishList.where((fish) {
          final name = fish['common_name']?.toString().toLowerCase() ?? '';
          final scientificName = fish['scientific_name']?.toString().toLowerCase() ?? '';
          return name.contains(query.toLowerCase()) || 
                 scientificName.contains(query.toLowerCase());
        }).toList();
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
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (!mounted) return;
        setState(() {
          fishList = data
              .map<Map<String, dynamic>>((item) => item as Map<String, dynamic>)
              .where((fish) => 
                widget.isSaltWater == null ||
                (widget.isSaltWater == true && fish['water_type'] == 'Saltwater') ||
                (widget.isSaltWater == false && fish['water_type'] == 'Freshwater'))
              .toList();
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
  
  void _showFishDetails(Map<String, dynamic> fish) async {
    final commonName = fish['common_name'] ?? 'Unknown';
    final scientificName = fish['scientific_name'] ?? 'Unknown';
    final cacheKey = '$commonName|$scientificName';

    // Check persistent cache first
    if (_fishDetailsCache.containsKey(cacheKey)) {
      _showFishDetailsScreen(_fishDetailsCache[cacheKey]!);
      return;
    }

    Map<String, dynamic> fishCopy = Map<String, dynamic>.from(fish);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
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
              const SizedBox(height: 16),
              const Text(
                'Loading Fish Details',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      // Fetch all in parallel
      final results = await Future.wait([
        http.get(Uri.parse(ApiConfig.getFishImageUrl(commonName))),
        OpenAIService.generateFishDescription(commonName, scientificName),
        OpenAIService.generateCareRecommendations(commonName, scientificName),
      ]);

      // Image
      final http.Response imageResponse = results[0] as http.Response;
      String? imageUrl;
      if (imageResponse.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(imageResponse.body);
        // New API returns a direct URL string under 'url'
        imageUrl = (jsonData['url'] ?? '').toString();
      }
      // Store URL for display; keep base64Image if previously cached to maintain backward-compat
      fishCopy['imageUrl'] = imageUrl;

      // Description
      fishCopy['description'] = results[1] as String;

      // Diet/Care Recommendations
      fishCopy['care_recommendations'] = results[2] as Map<String, dynamic>;

      // Save to in-memory and persistent cache
      _fishDetailsCache[cacheKey] = fishCopy;
      await _saveFishDetailsCache();

      if (mounted) {
        Navigator.pop(context); // Close loading
        _showFishDetailsScreen(fishCopy);
      }
    } catch (e) {
      print('Error loading fish details: $e');
      if (mounted) {
        Navigator.pop(context);
        fishCopy['description'] = 'Failed to generate description. Try again later.';
        fishCopy['imageUrl'] = null;
        fishCopy['care_recommendations'] = {'error': 'Failed to load diet/care recommendations.'};
        _fishDetailsCache[cacheKey] = fishCopy;
        await _saveFishDetailsCache();
        _showFishDetailsScreen(fishCopy);
      }
    }
  }
  
  void _showFishDetailsScreen(Map<String, dynamic> fish) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (BuildContext context) {
          final String? imageUrl = fish['imageUrl'];
          final String? base64Image = fish['base64Image']; // legacy cached support
          final Map<String, dynamic> careData = fish['care_recommendations'] ?? {};
          return Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFF006064)),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: const Text(
                'Fish Details',
                style: TextStyle(
                  color: Color(0xFF006064),
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            body: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 300,
                    child: Builder(
                      builder: (_) {
                        final screenWidth = MediaQuery.of(context).size.width;
                        final imageWidth = screenWidth;
                        final imageHeight = 300.0;
                        final commonName = (fish['common_name'] ?? '').toString();

                        // 1) Use imageUrl from details if present
                        String? headerUrl = (imageUrl != null && imageUrl.isNotEmpty) ? imageUrl : null;

                        // 2) Fallback to list thumbnail cache if available and fresh
                        headerUrl ??= _thumbUrlCache[commonName];

                        Widget buildNet(String url) {
                          return Image.network(
                            url,
                            width: imageWidth,
                            height: imageHeight,
                            fit: BoxFit.cover,
                            cacheWidth: (imageWidth * MediaQuery.of(context).devicePixelRatio).round(),
                            cacheHeight: (imageHeight * MediaQuery.of(context).devicePixelRatio).round(),
                            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                              if (wasSynchronouslyLoaded) return child;
                              return AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                child: frame != null
                                    ? child
                                    : Container(
                                        color: Colors.grey[200],
                                        child: const Center(child: CircularProgressIndicator()),
                                      ),
                              );
                            },
                            errorBuilder: (c, e, s) => Container(
                              color: Colors.grey[200],
                              child: const Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
                            ),
                          );
                        }

                        if (headerUrl != null && headerUrl.isNotEmpty) {
                          return buildNet(headerUrl);
                        }

                        // 3) Try legacy base64 from cache if present
                        if (base64Image != null && base64Image.isNotEmpty) {
                          try {
                            final String base64Str = base64Image.contains(',')
                                ? base64Image.split(',')[1]
                                : base64Image;
                            return Image.memory(
                              base64Decode(base64Str),
                              width: imageWidth,
                              height: imageHeight,
                              fit: BoxFit.cover,
                            );
                          } catch (e) {
                            print('Error loading base64 image: $e');
                          }
                        }

                        // 4) Network fallback: try variations of the name
                        if (commonName.isNotEmpty) {
                          return FutureBuilder<String?>(
                            future: _fetchFishImageWithFallback(commonName),
                            builder: (context, snap) {
                              if (snap.connectionState == ConnectionState.waiting) {
                                return Container(color: Colors.grey[200]);
                              }
                              final url = snap.data;
                              if (url != null && url.isNotEmpty) {
                                // Update in-memory caches for consistency in this session
                                fish['imageUrl'] = url;
                                _thumbUrlCache[commonName] = url;
                                _thumbCacheTime[commonName] = DateTime.now();
                                return buildNet(url);
                              }
                              return Container(
                                color: Colors.grey[200],
                                height: imageHeight,
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.image_not_supported,
                                        size: 50,
                                        color: Colors.grey,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'No image available',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        }

                        // 5) Final placeholder
                        return Container(
                          color: Colors.grey[200],
                          height: imageHeight,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.image_not_supported,
                                  size: 50,
                                  color: Colors.grey,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'No image available',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fish['common_name'] ?? 'Unknown',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF006064),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          fish['scientific_name'] ?? 'Unknown',
                          style: TextStyle(
                            fontSize: 20,
                            fontStyle: FontStyle.italic,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 20),
                        DescriptionWidget(
                          description: fish['description'] ?? 'No description available.',
                          maxLines: 4,
                        ),
                        const SizedBox(height: 30),
                        // Gallery moved before Basic Information
                        if (fish['common_name'] != null) ...[
                          const Text(
                            'Gallery',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF006064),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _FishImagesGrid(
                            fishName: fish['common_name'],
                            initialDisplayCount: 4,
                            showTitle: true,
                          ),
                          const SizedBox(height: 40),
                        ],
                        const Text(
                          'Basic Information',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF006064),
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildDetailRow('Water Type', fish['water_type'] ?? 'Unknown'),
                        _buildDetailRow('Maximum Size', '${fish['max_size']} cm'),
                        _buildDetailRow('Temperament', fish['temperament'] ?? 'Unknown'),
                        _buildDetailRow('Care Level', fish['care_level'] ?? 'Unknown'),
                        _buildDetailRow('Lifespan', fish['lifespan'] ?? 'Unknown'),
                        
                        const SizedBox(height: 40),
                        const Text(
                          'Habitat Information',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF006064),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Builder(
                          builder: (context) {
                            final String tempRaw = (fish['temperature_range'] ??
                                    fish['temperature_range_(Â°c)'] ??
                                    fish['temperature_range_c'] ??
                                    'Unknown')
                                .toString()
                                .trim();
                            final String tempDisplay = (tempRaw.isEmpty || tempRaw == 'Unknown')
                                ? 'Unknown'
                                : (tempRaw.contains('°') || tempRaw.toLowerCase().contains('c')
                                    ? tempRaw
                                    : '$tempRaw °C');
                            return _buildDetailRow('Temperature Range', tempDisplay);
                          },
                        ),
                        _buildDetailRow('pH Range', fish['ph_range'] ?? 'Unknown'),
                        _buildDetailRow('Minimum Tank Size',
                          fish['minimum_tank_size_(l)'] != null
                              ? '${fish['minimum_tank_size_(l)']} L'
                              : (fish['minimum_tank_size_l'] != null
                                  ? '${fish['minimum_tank_size_l']} L'
                                  : (fish['minimum_tank_size'] != null
                                      ? '${fish['minimum_tank_size']} L'
                                      : 'Unknown'))),
                        _buildDetailRow('Social Behavior', fish['social_behavior'] ?? 'Unknown'),
                        const SizedBox(height: 40),
                        const Text(
                          'Diet Recommendation',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF006064),
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (careData.containsKey('error'))
                          Text(careData['error'], style: const TextStyle(color: Colors.red)),
                        if (!careData.containsKey('error')) ...[
                          // Use the same fields/groups as before
                          Builder(
                            builder: (context) {
                              final fields = [
                                {'label': 'Diet Type', 'key': 'diet_type', 'icon': Icons.restaurant},
                                {'label': 'Preferred Foods', 'key': 'preferred_foods', 'icon': Icons.set_meal},
                                {'label': 'Feeding Frequency', 'key': 'feeding_frequency', 'icon': Icons.schedule},
                                {'label': 'Portion Size', 'key': 'portion_size', 'icon': Icons.line_weight},
                                {'label': 'Fasting Schedule', 'key': 'fasting_schedule', 'icon': Icons.calendar_today},
                                {'label': 'Overfeeding Risks', 'key': 'overfeeding_risks', 'icon': Icons.error},
                                {'label': 'Behavioral Notes', 'key': 'behavioral_notes', 'icon': Icons.psychology},
                                {'label': 'Tankmate Feeding Conflict', 'key': 'tankmate_feeding_conflict', 'icon': Icons.warning},
                              ];
                              final List<List<Map<String, dynamic>>> fieldGroups = [
                                fields.sublist(0, 2),
                                fields.sublist(2, 5),
                                fields.sublist(5, 8),
                              ];
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ...fieldGroups.map((group) => _RecommendationExpansionGroup(fields: group, data: careData)).toList(),
                                ],
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

Widget _buildDetailRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Label on the far left - takes only the space it needs
        Text(
          label,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: Color(0xFF006064),
          ),
        ),
        // Value on the far right - takes only the space it needs
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            color: Colors.black87,
          ),
        ),
      ],
    ),
  );
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
      borderRadius: BorderRadius.circular(8),
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
        final Map<String, dynamic> jsonData = json.decode(snapshot.data!.body);
        final String imageUrl = (jsonData['url'] ?? '').toString();
        
        // Debug: Print response data
        print('API response for "$name": $jsonData');
        
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
          borderRadius: BorderRadius.circular(8),
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
        // Debug: Print JSON parsing error
        print('JSON parsing error for "$name": $e - Response: ${snapshot.data!.body}');
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

// Add this method to help debug and improve fish name matching
String _sanitizeFishName(String name) {
  return name
      .toLowerCase()
      .trim()
      .replaceAll(RegExp(r'[^\w\s]'), '') // Remove special characters
      .replaceAll(RegExp(r'\s+'), ' '); // Normalize whitespace
}

// Enhanced method that tries multiple name variations
Future<String?> _fetchFishImageWithFallback(String fishName) async {
  final variations = [
    fishName, // Original name
    _sanitizeFishName(fishName), // Sanitized name
    fishName.toLowerCase(), // Lowercase
    fishName.replaceAll(' ', '_'), // Underscore instead of spaces
    fishName.replaceAll(' ', '-'), // Dash instead of spaces
  ];

  for (final variation in variations) {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.getFishImageUrl(variation)),
        headers: {'Connection': 'keep-alive'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        final String imageUrl = (jsonData['url'] ?? '').toString();
        if (imageUrl.isNotEmpty) {
          print('Found image for "$fishName" using variation: "$variation"');
          return imageUrl;
        }
      }
    } catch (e) {
      print('Failed to fetch image for "$fishName" with variation "$variation": $e');
      continue;
    }
  }

  print('No image found for "$fishName" after trying all variations');
  return null;
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
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  List<Map<String, dynamic>> get _filteredFishListWithFilters {
    List<Map<String, dynamic>> list = filteredFishList;
    // Water type
    if (waterTypeFilters.containsValue(true)) {
      list = list.where((fish) => waterTypeFilters[fish['water_type']] == true).toList();
    }
    // Temperament
    if (temperamentFilters.containsValue(true)) {
      list = list.where((fish) => temperamentFilters[fish['temperament']] == true).toList();
    }
    // Social Behavior
    if (socialBehaviorFilters.containsValue(true)) {
      list = list.where((fish) => socialBehaviorFilters[fish['social_behavior']] == true).toList();
    }
    // Diet
    if (dietFilters.containsValue(true)) {
      list = list.where((fish) => dietFilters[fish['diet']] == true).toList();
    }
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
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(25),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _filterFishList,
                decoration: InputDecoration(
                  hintText: 'Search fish...',
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.grey),
                          onPressed: () {
                            _searchController.clear();
                            _filterFishList('');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                ),
              ),
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
                                  Icons.search_off,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No fish found',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey[600],
                                  ),
                                ),
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
                              return _ModernFishCard(
                                fish: fish,
                                onTap: () => _showFishDetails(fish),
                                buildFishListImage: buildFishListImage,
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

// Modern Fish Card Widget
class _ModernFishCard extends StatelessWidget {
  final Map<String, dynamic> fish;
  final VoidCallback onTap;
  final Widget Function(String?) buildFishListImage;
  const _ModernFishCard({required this.fish, required this.onTap, required this.buildFishListImage});

  @override
  Widget build(BuildContext context) {
    List<Widget> tags = [];
    if (fish['water_type'] != null) {
      tags.add(_FishTag(label: fish['water_type'], color: fish['water_type'] == 'Freshwater' ? Colors.teal : Colors.blueAccent));
    }
    if (fish['temperament'] != null) {
      tags.add(_FishTag(label: fish['temperament'], color: Colors.orangeAccent));
    }
    if (fish['social_behavior'] != null) {
      tags.add(_FishTag(label: fish['social_behavior'], color: Colors.green));
    }
    if (fish['diet'] != null) {
      tags.add(_FishTag(label: fish['diet'], color: Colors.brown));
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 18),
      color: const Color(0xFFF5F7FA),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.grey.withOpacity(0.13), width: 1.2),
      ),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildFishListImage(fish['common_name']),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fish['common_name'] ?? '',
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          fish['scientific_name'] ?? '',
                          style: TextStyle(
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 7,
                          runSpacing: 2,
                          children: tags,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FishImagesGrid extends StatefulWidget {
  final String fishName;
  final int initialDisplayCount;
  final int maxImages;
  final bool showTitle;

  const _FishImagesGrid({
    Key? key,
    required this.fishName,
    this.initialDisplayCount = 4,
    this.maxImages = 20,
    this.showTitle = false,
  }) : super(key: key);

  @override
  State<_FishImagesGrid> createState() => _FishImagesGridState();
}

class _FishImagesGridState extends State<_FishImagesGrid> {
  bool _isLoading = true;
  bool _hasError = false;
  final List<String> _imageUrls = [];
  bool _showAll = false;
  static final Map<String, List<String>> _cache = {};
  static final Map<String, DateTime> _cacheTime = {};
  static final Map<String, Future<List<String>>> _pendingFetches = {};
  static const Duration _cacheTtl = Duration(hours: 24);

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  Future<void> _loadImages() async {
    if (widget.fishName.isEmpty) {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
      return;
    }

    // Check cache first
    final cached = _cache[widget.fishName];
    final fetchedAt = _cacheTime[widget.fishName];
    final isCacheValid = fetchedAt != null && 
        DateTime.now().difference(fetchedAt) < _cacheTtl;

    if (cached != null && isCacheValid) {
      setState(() {
        _imageUrls.addAll(cached);
        _isLoading = false;
      });
      return;
    }

    // Use existing fetch if one is in progress
    if (_pendingFetches[widget.fishName] != null) {
      try {
        final urls = await _pendingFetches[widget.fishName]!;
        _updateWithUrls(urls);
      } catch (e) {
        _handleError(e);
      }
      return;
    }

    // Start new fetch
    try {
      final future = _fetchImages();
      _pendingFetches[widget.fishName] = future;
      final urls = await future;
      _updateWithUrls(urls);
    } catch (e) {
      _handleError(e);
    } finally {
      _pendingFetches.remove(widget.fishName);
    }
  }

  Future<List<String>> _fetchImages() async {
    final urls = <String>{};
    final batchSize = 4;
    final maxBatches = (widget.maxImages / batchSize).ceil();
    
    for (var i = 0; i < maxBatches && urls.length < widget.maxImages; i++) {
      try {
        final response = await http.get(
          Uri.parse('${ApiConfig.baseUrl}/fish-image/${Uri.encodeComponent(widget.fishName)}?batch=$i'),
          headers: {'Content-Type': 'application/json'},
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data is List) {
            for (var item in data) {
              if (item is Map && item['url'] != null) {
                urls.add(item['url'].toString());
                if (urls.length >= widget.maxImages) break;
              }
            }
          } else if (data is Map && data['url'] != null) {
            urls.add(data['url'].toString());
          }
        }
      } catch (e) {
        print('Error fetching image batch $i: $e');
        // Continue with next batch even if one fails
      }
    }

    return urls.toList();
  }

  void _updateWithUrls(List<String> urls) {
    if (!mounted) return;
    
    setState(() {
      _imageUrls.clear();
      _imageUrls.addAll(urls);
      _isLoading = false;
      _hasError = urls.isEmpty;
    });

    // Update cache
    if (urls.isNotEmpty) {
      _cache[widget.fishName] = List.from(urls);
      _cacheTime[widget.fishName] = DateTime.now();
    }
  }

  void _handleError(dynamic error) {
    if (!mounted) return;
    print('Error loading fish images: $error');
    setState(() {
      _isLoading = false;
      _hasError = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: SizedBox(
          width: 40,
          height: 40,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_hasError || _imageUrls.isEmpty) {
      return const SizedBox.shrink();
    }

    // Show 2 by default, and when expanded, cap at 4
  final int limit = _showAll ? 4 : widget.initialDisplayCount;
  final displayUrls = _imageUrls.take(limit).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1.2,
          ),
          itemCount: displayUrls.length,
          itemBuilder: (context, index) {
            final url = displayUrls[index];
            return GestureDetector(
              onTap: () => _showFullScreenImage(url),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final dpr = MediaQuery.of(context).devicePixelRatio;
                    final targetW = (constraints.maxWidth * dpr).round();
                    final targetH = (constraints.maxHeight * dpr).round();
                    return Image.network(
                      url,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      cacheWidth: targetW,
                      cacheHeight: targetH,
                      filterQuality: FilterQuality.low,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          color: Colors.grey[200],
                          child: const SizedBox.shrink(),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[200],
                          child: Center(
                            child: SizedBox(
                              width: 60,
                              height: 60,
                              child: Lottie.asset(
                                'lib/lottie/BowlAnimation.json',
                                fit: BoxFit.contain,
                                repeat: true,
                                frameRate: FrameRate(60),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  void _showFullScreenImage(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog.fullscreen(
        backgroundColor: Colors.black87,
        child: Stack(
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 3.0,
              child: Center(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                      ),
                    );
                  },
                ),
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FishTag extends StatelessWidget {
  final String label;
  final Color color;
  const _FishTag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final maxTagWidth = MediaQuery.of(context).size.width * 0.5;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxTagWidth),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        margin: const EdgeInsets.only(bottom: 2),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
        ),
      ),
    );
  }
}