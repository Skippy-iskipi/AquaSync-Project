import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async'; // Add Timer import
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../widgets/description_widget.dart';
import '../widgets/fish_images_grid.dart';
import '../services/openai_service.dart'; // Import OpenAI service
import 'package:lottie/lottie.dart';

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
            Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: Text(
                '+$remainingCount more',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
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
                  const SizedBox(width: 12),
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
                            ? Wrap(
                                spacing: 6,
                                children: value.map<Widget>((v) => Chip(label: Text(v.toString()))).toList(),
                              )
                            : Text(
                                value.toString(),
                                style: const TextStyle(fontSize: 15),
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

  // Add filter state
  Map<String, bool> waterTypeFilters = {'Freshwater': false, 'Saltwater': false};
  Map<String, bool> temperamentFilters = {'Peaceful': false, 'Semi-aggressive': false, 'Aggressive': false};
  Map<String, bool> socialBehaviorFilters = {'Schooling': false, 'Solitary': false, 'Community': false};
  Map<String, bool> dietFilters = {'Omnivore': false, 'Carnivore': false, 'Herbivore': false};

  @override
  void initState() {
    super.initState();
    _loadFishDetailsCache().then((_) {
      fetchFishList();
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

  Future<void> fetchFishList() async {
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
      String? base64Image;
      if (imageResponse.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(imageResponse.body);
        base64Image = jsonData['image_data'];
      }
      fishCopy['base64Image'] = base64Image;

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
        fishCopy['base64Image'] = null;
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
          final String? base64Image = fish['base64Image'];
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
                    child: (base64Image == null || base64Image.isEmpty)
                        ? Container(
                            color: Colors.grey[200],
                            child: const Icon(
                              Icons.image_not_supported,
                              size: 50,
                              color: Colors.grey,
                            ),
                          )
                        : Image.memory(
                            base64Decode(base64Image.contains(',') ? base64Image.split(',')[1] : base64Image),
                            width: double.infinity,
                            height: 300,
                            fit: BoxFit.cover,
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
                        FishImagesGrid(
                          fishName: fish['common_name'] ?? '',
                          initialDisplayCount: 2,
                        ),
                        const SizedBox(height: 30),
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
                        _buildDetailRow('Temperature Range', fish['temperature_range'] ?? 'Unknown'),
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
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Color(0xFF006064),
            ),
          ),
          const Spacer(),
          SizedBox(
            width: MediaQuery.of(context).size.width * 0.4,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                color: Colors.black87,
              ),
              textAlign: TextAlign.left,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildFishListImage(String? fishName) {
    return FutureBuilder<http.Response>(
      future: http.get(Uri.parse(ApiConfig.getFishImageUrl(fishName ?? ''))),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            width: 120,
            height: 80,
            color: Colors.grey[200],
            child: Center(
              child: SizedBox(
                width: 60,
                height: 60,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(seconds: 3),
                  builder: (context, value, child) {
                    return Lottie.asset(
                      'lib/lottie/BowlAnimation.json',
                      width: 60,
                      height: 60,
                      fit: BoxFit.contain,
                      repeat: false,
                      frameRate: FrameRate(60),
                    );
                  },
                ),
              ),
            ),
          );
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.statusCode != 200) {
          return Container(
            width: 120,
            height: 80,
            color: Colors.grey[200],
            child: const Icon(Icons.image_not_supported_outlined, color: Colors.grey, size: 24),
          );
        }
        final Map<String, dynamic> jsonData = json.decode(snapshot.data!.body);
        final String? base64Image = jsonData['image_data'];
        if (base64Image == null || base64Image.isEmpty) {
          return Container(
            width: 120,
            height: 80,
            color: Colors.grey[200],
            child: const Icon(Icons.image_not_supported_outlined, color: Colors.grey, size: 24),
          );
        }
        final String base64Str = base64Image.contains(',') ? base64Image.split(',')[1] : base64Image;
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            base64Decode(base64Str),
            width: 120,
            height: 80,
            fit: BoxFit.cover,
          ),
        );
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
                        ),
                        const SizedBox(height: 5),
                        Text(
                          fish['scientific_name'] ?? '',
                          style: TextStyle(
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            color: Colors.grey[600],
                          ),
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

class _FishTag extends StatelessWidget {
  final String label;
  final Color color;
  const _FishTag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
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
      ),
    );
  }
}