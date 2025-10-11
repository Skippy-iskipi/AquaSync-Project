import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import '../config/api_config.dart';
import '../widgets/fish_images_grid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/favorites_service.dart';
import 'dart:async';

class FishDetailsScreen extends StatefulWidget {
  final String commonName;
  final String scientificName;
  final String? capturedImagePath; // For captured fish images
  final Map<String, dynamic>? fishData; // For fish list data
  final bool useCapturedImage;

  const FishDetailsScreen({
    super.key,
    required this.commonName,
    required this.scientificName,
    this.capturedImagePath,
    this.fishData,
    this.useCapturedImage = false,
  });

  @override
  State<FishDetailsScreen> createState() => _FishDetailsScreenState();
}

class _FishDetailsScreenState extends State<FishDetailsScreen> {
  Map<String, dynamic>? _fishDetails;
  bool _isLoading = true;
  String? _error;
  final FavoritesService _favoritesService = FavoritesService();
  bool _isFavorite = false;
  late StreamSubscription _favoritesSubscription;

  @override
  void initState() {
    super.initState();
    _loadFishDetails();
    _loadInitialFavorites();
    _favoritesSubscription = _favoritesService.favoritesStream.listen((favorites) {
      if (mounted) {
        setState(() {
          _isFavorite = favorites.contains(widget.commonName);
        });
      }
    });
  }

  Future<void> _loadInitialFavorites() async {
    await _favoritesService.loadFavorites();
    if (mounted) {
      setState(() {
        _isFavorite = _favoritesService.getFavorites().contains(widget.commonName);
      });
    }
  }

  @override
  void dispose() {
    _favoritesSubscription.cancel();
    super.dispose();
  }

  Future<void> _loadFishDetails() async {
    try {
      if (widget.fishData != null) {
        // Use provided fish data
        _fishDetails = Map<String, dynamic>.from(widget.fishData!);
        await _fetchAdditionalDetails();
      } else {
        // Fetch from database
        await _fetchFishDetailsFromDatabase();
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load fish details: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchFishDetailsFromDatabase() async {
    try {
      final response = await Supabase.instance.client
          .from('fish_species')
          .select('*')
          .or('common_name.ilike.%${widget.commonName}%,scientific_name.ilike.%${widget.scientificName}%')
          .limit(1);

      if (response.isNotEmpty) {
        _fishDetails = response.first;
        await _fetchAdditionalDetails();
      } else {
        setState(() {
          _error = 'Fish details not found';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error fetching fish details: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchAdditionalDetails() async {
    try {
      // Fetch description from database
      await _fetchFishDescriptionFromDatabase();
      
      // Fetch care recommendations from database
      await _fetchCareRecommendationsFromDatabase();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading additional details: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchFishDescriptionFromDatabase() async {
    try {
      final response = await Supabase.instance.client
          .from('fish_species')
          .select('description')
          .or('common_name.ilike.%${widget.commonName}%,scientific_name.ilike.%${widget.scientificName}%')
          .limit(1);

      if (response.isNotEmpty && response.first['description'] != null) {
        _fishDetails!['description'] = response.first['description'];
      } else {
        _generateLocalDescription();
      }
    } catch (e) {
      _generateLocalDescription();
    }
  }

  void _generateLocalDescription() {
    final waterType = _fishDetails!['water_type'] ?? 'Unknown';
    final maxSize = _fishDetails!['max_size'] ?? 'Unknown';
    final temperament = _fishDetails!['temperament'] ?? 'Unknown';
    final careLevel = _fishDetails!['care_level'] ?? 'Unknown';
    
    _fishDetails!['description'] = 'The ${widget.commonName} is a $waterType fish that can grow up to $maxSize cm. '
        'It has a $temperament temperament and requires $careLevel care level. '
        'This species is known for its unique characteristics and makes an interesting addition to aquariums.';
  }

  Future<void> _fetchCareRecommendationsFromDatabase() async {
    try {
      final response = await Supabase.instance.client
          .from('fish_species')
          .select('diet, preferred_food, feeding_frequency, portion_grams, overfeeding_risks, feeding_notes')
          .or('common_name.ilike.%${widget.commonName}%,scientific_name.ilike.%${widget.scientificName}%')
          .limit(1);

      if (response.isNotEmpty) {
        final dbData = response.first;
        final minTankSize = _fishDetails!['minimum_tank_size_(l)'] ?? _fishDetails!['minimum_tank_size_l'] ?? _fishDetails!['minimum_tank_size'] ?? 'Unknown';
        final waterType = _fishDetails!['water_type'] ?? 'Unknown';
        final temperament = _fishDetails!['temperament'] ?? 'Unknown';
        final careLevel = _fishDetails!['care_level'] ?? 'Unknown';
        
        _fishDetails!['care_recommendations'] = {
          'diet_type': dbData['diet'] ?? _fishDetails!['diet'] ?? 'Omnivore',
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
        _generateLocalCareRecommendations();
      }
    } catch (e) {
      _generateLocalCareRecommendations();
    }
  }

  void _generateLocalCareRecommendations() {
    final diet = _fishDetails!['diet'] ?? 'Omnivore';
    final minTankSize = _fishDetails!['minimum_tank_size_(l)'] ?? _fishDetails!['minimum_tank_size_l'] ?? _fishDetails!['minimum_tank_size'] ?? 'Unknown';
    final waterType = _fishDetails!['water_type'] ?? 'Unknown';
    final temperament = _fishDetails!['temperament'] ?? 'Unknown';
    final careLevel = _fishDetails!['care_level'] ?? 'Unknown';
    
    _fishDetails!['care_recommendations'] = {
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

  Widget _buildImagePlaceholder() {
    return Container(
      color: Colors.grey[200],
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_not_supported,
              size: 50,
              color: Colors.grey,
            ),
            SizedBox(height: 8),
            Text(
              'No image available',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Color(0xFF006064),
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return _ExpandableInfoItem(
      label: label,
      value: value,
      icon: icon,
    );
  }

  Widget _buildExpandableDietCard(Map<String, dynamic> fish, Map<String, dynamic> careData) {
    List<Map<String, dynamic>> dietItems = [
      {
        'label': 'Diet Type',
        'value': (fish['diet'] ?? 'Unknown').toString(),
        'icon': Icons.restaurant,
      },
      {
        'label': 'Preferred Food',
        'value': (fish['preferred_food'] ?? 'Unknown').toString(),
        'icon': Icons.set_meal,
      },
      {
        'label': 'Feeding Frequency',
        'value': (fish['feeding_frequency'] ?? 'Unknown').toString(),
        'icon': Icons.schedule,
      },
    ];
    
    if (careData['portion_size'] != null) {
      dietItems.add({
        'label': 'Portion Size',
        'value': careData['portion_size'].toString(),
        'icon': Icons.line_weight,
      });
    }
    
    if (careData['feeding_notes'] != null) {
      dietItems.add({
        'label': 'Feeding Notes',
        'value': careData['feeding_notes'].toString(),
        'icon': Icons.lightbulb_outline,
      });
    }
    
    return _buildInfoCard(dietItems.map((item) => 
      _buildInfoItem(item['label'], item['value'], item['icon'])
    ).toList());
  }

  String _getTemperatureRange(Map<String, dynamic> fish) {
    final tempRange = fish['temperature_range']?.toString() ?? 
                     fish['temperature']?.toString() ?? 
                     fish['temperature_c']?.toString() ?? 
                     fish['temperature_range_c']?.toString() ?? 
                     fish['temperature_range_(°C)']?.toString() ?? 
                     fish['temperature_range_(Â°C)']?.toString() ?? 
                     fish['temp_range']?.toString() ?? 
                     fish['tempRange']?.toString() ?? 
                     fish['temperatureRange']?.toString() ?? 
                     fish['temp']?.toString() ?? 
                     fish['temp_c']?.toString() ?? 
                     fish['temp_celsius']?.toString() ?? 
                     fish['temp_range_c']?.toString() ?? 
                     fish['temp_range_celsius']?.toString() ?? 
                     'Unknown';
    
    if (tempRange != 'Unknown' && tempRange.isNotEmpty && tempRange != 'null') {
      return tempRange;
    }
    
    for (final key in fish.keys) {
      final value = fish[key]?.toString();
      if (value != null && value.isNotEmpty && value != 'null' && value != 'Unknown') {
        if (value.contains('°') || value.contains('C') || value.contains('F') || 
            RegExp(r'\d+.*\d+').hasMatch(value) || RegExp(r'\d+-\d+').hasMatch(value)) {
          return value;
        }
      }
    }
    
    return 'Unknown';
  }

  String _getMinimumTankSize(Map<String, dynamic> fish) {
    final tankSize = fish['minimum_tank_size_(l)']?.toString() ?? 
                    fish['minimum_tank_size']?.toString() ?? 
                    fish['minimumTankSize']?.toString() ?? 
                    fish['minimum_tank_size_l']?.toString() ?? 
                    fish['minimum_tank_size_l_']?.toString() ?? 
                    fish['minimumTankSizeL']?.toString() ?? 
                    fish['tank_size']?.toString() ?? 
                    fish['tankSize']?.toString() ?? 
                    fish['min_tank_size']?.toString() ?? 
                    fish['minTankSize']?.toString() ?? 
                    fish['tank_size_l']?.toString() ?? 
                    fish['tankSizeL']?.toString() ?? 
                    fish['tank_size_liters']?.toString() ?? 
                    fish['tankSizeLiters']?.toString() ?? 
                    fish['minimum_tank']?.toString() ?? 
                    fish['minTank']?.toString() ?? 
                    'Unknown';
    
    if (tankSize != 'Unknown' && tankSize.isNotEmpty && tankSize != 'null') {
      return tankSize;
    }
    
    for (final key in fish.keys) {
      final value = fish[key]?.toString();
      if (value != null && value.isNotEmpty && value != 'null' && value != 'Unknown') {
        if (RegExp(r'\d+').hasMatch(value) && 
            (value.toLowerCase().contains('l') || value.toLowerCase().contains('gal') || 
             value.toLowerCase().contains('liter') || value.toLowerCase().contains('gallon'))) {
          return value;
        }
      }
    }
    
    return 'Unknown';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF006064)),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Fish Details',
            style: TextStyle(
              color: Color(0xFF006064),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: Icon(
                _isFavorite ? Icons.favorite : Icons.favorite_border,
                color: _isFavorite ? Colors.red : const Color(0xFF006064),
              ),
              onPressed: () {
                _favoritesService.toggleFavorite(widget.commonName);
              },
              tooltip: _isFavorite ? 'Remove from favorites' : 'Add to favorites',
            ),
          ],
        ),
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00BCD4)),
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF006064)),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Fish Details',
            style: TextStyle(
              color: Color(0xFF006064),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: Icon(
                _isFavorite ? Icons.favorite : Icons.favorite_border,
                color: _isFavorite ? Colors.red : const Color(0xFF006064),
              ),
              onPressed: () {
                _favoritesService.toggleFavorite(widget.commonName);
              },
              tooltip: _isFavorite ? 'Remove from favorites' : 'Add to favorites',
            ),
          ],
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _error = null;
                  });
                  _loadFishDetails();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00BCD4),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final fish = _fishDetails!;
    final careData = fish['care_recommendations'] ?? {};

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF006064)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Fish Details',
          style: TextStyle(
            color: Color(0xFF006064),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              _isFavorite ? Icons.favorite : Icons.favorite_border,
              color: _isFavorite ? Colors.red : const Color(0xFF006064),
            ),
            onPressed: () {
              _favoritesService.toggleFavorite(widget.commonName);
            },
            tooltip: _isFavorite ? 'Remove from favorites' : 'Add to favorites',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Image Section
            Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF00BCD4).withOpacity(0.1),
                    Colors.white,
                  ],
                ),
              ),
              child: _buildHeroImage(),
            ),
            // Content Section
            Transform.translate(
              offset: const Offset(0, -20),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 20,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Fish Names
                      Center(
                        child: Column(
                          children: [
                            Text(
                              widget.commonName,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF006064),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.scientificName,
                              style: TextStyle(
                                fontSize: 18,
                                fontStyle: FontStyle.italic,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Description Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00BCD4).withOpacity(0.05),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: const Color(0xFF00BCD4).withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Description',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF006064),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              (fish['description'] ?? 'No description available.').toString(),
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
                      
                      // Gallery Section
                      if (widget.commonName.isNotEmpty) ...[
                        FishImagesGrid(
                          fishName: widget.commonName,
                          initialDisplayCount: 4,
                          showTitle: true,
                        ),
                        const SizedBox(height: 30),
                      ],
                      
                      // Basic Information Cards
                      _buildSectionTitle('Basic Information'),
                      const SizedBox(height: 16),
                      _buildInfoCard([
                        _buildInfoItem('Water Type', (fish['water_type'] ?? 'Unknown').toString(), Icons.water_drop),
                        _buildInfoItem('Maximum Size', (fish['max_size'] ?? 'Unknown').toString(), Icons.straighten),
                        _buildInfoItem('Temperament', (fish['temperament'] ?? 'Unknown').toString(), Icons.psychology),
                        _buildInfoItem('Care Level', (fish['care_level'] ?? 'Unknown').toString(), Icons.star),
                        _buildInfoItem('Lifespan', (fish['lifespan'] ?? 'Unknown').toString(), Icons.schedule),
                      ]),
                      
                      const SizedBox(height: 24),
                      
                      // Habitat Information Cards
                      _buildSectionTitle('Habitat Information'),
                      const SizedBox(height: 16),
                      _buildInfoCard([
                        _buildInfoItem('Temperature Range', _getTemperatureRange(fish), Icons.thermostat),
                        _buildInfoItem('pH Range', (fish['ph_range'] ?? 'Unknown').toString(), Icons.science),
                        _buildInfoItem('Minimum Tank Size', _getMinimumTankSize(fish), Icons.crop_square),
                        _buildInfoItem('Social Behavior', (fish['social_behavior'] ?? 'Unknown').toString(), Icons.group),
                      ]),
                      const SizedBox(height: 24),
                      
                      // Diet & Feeding Section
                      _buildSectionTitle('Diet & Feeding'),
                      const SizedBox(height: 16),
                      _buildExpandableDietCard(fish, careData),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroImage() {
    if (widget.useCapturedImage && widget.capturedImagePath != null && widget.capturedImagePath!.isNotEmpty) {
      // Use captured image - now stored as URL from Supabase Storage
      // Check if it's a URL or a local file path
      final isUrl = widget.capturedImagePath!.startsWith('http://') || 
                    widget.capturedImagePath!.startsWith('https://');
      
      return ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
        child: isUrl
            ? Image.network(
                widget.capturedImagePath!,
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _buildImagePlaceholder(),
              )
            : (kIsWeb
                ? Image.network(
                    widget.capturedImagePath!,
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => _buildImagePlaceholder(),
                  )
                : Image.file(
                    File(widget.capturedImagePath!),
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => _buildImagePlaceholder(),
                  )),
      );
    } else {
      // Use fish list image
      return FutureBuilder<String?>(
        future: Future.value('${ApiConfig.baseUrl}/fish-image/${Uri.encodeComponent(widget.commonName)}'),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return Container(
              color: Colors.grey[200],
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00BCD4)),
                ),
              ),
            );
          }
          
          final url = snap.data;
          if (url != null && url.isNotEmpty) {
            return ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(30),
                topRight: Radius.circular(30),
              ),
              child: Image.network(
                url,
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => _buildImagePlaceholder(),
              ),
            );
          }
          
          return _buildImagePlaceholder();
        },
      );
    }
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
