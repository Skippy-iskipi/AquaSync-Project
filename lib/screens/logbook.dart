import 'package:flutter/material.dart';
import '../screens/capture.dart'; 
import '../screens/homepage.dart';
import 'package:provider/provider.dart';
import 'logbook_provider.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/fish_prediction.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../models/compatibility_result.dart';
import '../models/fish_calculation.dart';
import '../models/water_calculation.dart';
import '../models/diet_calculation.dart';
import '../widgets/custom_notification.dart';
import '../widgets/description_widget.dart';
import '../widgets/fish_images_grid.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_config.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'dart:typed_data';
import '../services/openai_service.dart';
import 'capture.dart';



class LogBook extends StatefulWidget {
  final int initialTabIndex;
  
  const LogBook({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  _LogBookState createState() => _LogBookState();
}

class _LogBookState extends State<LogBook> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<int, bool> _showOxygenNeeds = {};
  Map<int, bool> _showFiltrationNeeds = {};
  // Cache resolved direct image URLs per fish name to avoid refetching
  final Map<String, String> _fishImageUrlCache = {};


  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
  }

  // Resolve a fish image from a fish name (or API URL) and render with cache
  Widget _buildResolvedFishImage(String fishName, {double height = 200}) {
    final encoded = Uri.encodeComponent(fishName);

    // If we have a cached direct URL, render immediately with CachedNetworkImage
    if (_fishImageUrlCache.containsKey(fishName)) {
      final directUrl = _fishImageUrlCache[fishName]!;
      return CachedNetworkImage(
        imageUrl: directUrl,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          height: height,
          color: Colors.grey[200],
          child: const Center(child: CircularProgressIndicator()),
        ),
        errorWidget: (context, url, error) => Container(
          height: height,
          color: Colors.grey[200],
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 40, color: Colors.grey),
              const SizedBox(height: 8),
              Text(
                fishName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Otherwise, fetch via backend JSON and then render the direct URL
    return FutureBuilder<http.Response?>(
      future: ApiConfig.makeRequestWithFailover(
        endpoint: '/fish-image/${encoded.replaceAll(' ', '')}',
        method: 'GET',
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: height,
            width: double.infinity,
            color: Colors.grey[200],
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        final resp = snapshot.data;
        if (resp != null && resp.statusCode == 200) {
          try {
            final Map<String, dynamic> jsonData = json.decode(resp.body);
            final String directUrl = (jsonData['url'] ?? '').toString();
            if (directUrl.isNotEmpty) {
              // Save to in-memory cache
              _fishImageUrlCache[fishName] = directUrl;
              return CachedNetworkImage(
                imageUrl: directUrl,
                height: height,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  height: height,
                  color: Colors.grey[200],
                  child: const Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (context, url, error) => Container(
                  height: height,
                  color: Colors.grey[200],
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, size: 40, color: Colors.grey),
                      const SizedBox(height: 8),
                      Text(
                        fishName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }
          } catch (e) {
            // fallthrough to error widget below
          }
        }
        return Container(
          height: height,
          color: Colors.grey[200],
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 40, color: Colors.grey),
              const SizedBox(height: 8),
              Text(
                fishName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Material(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: const Color(0xFF006064),
              unselectedLabelColor: Colors.grey,
              indicatorColor: const Color(0xFF4DD0E1),
              labelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.normal,
                fontSize: 14,
              ),
              tabs: const [
                Tab(text: 'Fish Collection'),
                Tab(text: 'Fish Calculator'),
                Tab(text: 'Fish Compatibility'),
              ],
            ),
          ),
          Expanded(
            child: Container(
              color: Colors.white,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildFishCollectionTab(),
                  _buildCalculatorTab(),
                  _buildFishCompatibilityTab(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showFishDetails(FishPrediction prediction) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (BuildContext context) {
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
                  fontSize: 20,
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
                    child: prediction.imagePath.isNotEmpty
                      ? kIsWeb
                          ? Image.network(
                              prediction.imagePath,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey.shade200,
                                  child: const Icon(
                                    Icons.image_not_supported,
                                    size: 50,
                                    color: Colors.grey,
                                  ),
                                );
                              },
                            )
                          : Image.file(
                              File(prediction.imagePath),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey.shade200,
                                  child: const Icon(
                                    Icons.image_not_supported,
                                    size: 50,
                                    color: Colors.grey,
                                  ),
                                );
                              },
                            )
                      : Container(
                          color: Colors.grey.shade200,
                          child: const Icon(
                            Icons.photo,
                            size: 50,
                            color: Colors.grey,
                          ),
                        ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          prediction.commonName,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF006064),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          prediction.scientificName,
                          style: TextStyle(
                            fontSize: 20,
                            fontStyle: FontStyle.italic,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        // Add description widget
                        if (prediction.description.isNotEmpty)
                          DescriptionWidget(
                            description: prediction.description,
                            maxLines: 3,
                          ),
                        
                        // Add fish images grid right after description
                        const SizedBox(height: 20),
                        FishImagesGrid(fishName: prediction.commonName),
                        
                        const SizedBox(height: 20),
                        
                        const Text(
                          'Basic Information',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF006064),
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildDetailRow('Water Type', prediction.waterType),
                        _buildDetailRow('Maximum Size', prediction.maxSize),
                        _buildDetailRow('Temperament', prediction.temperament),
                        _buildDetailRow('Care Level', prediction.careLevel),
                        _buildDetailRow('Lifespan', prediction.lifespan),
                        const SizedBox(height: 40),
                        
                        // Add Habitat Information section
                        const Text(
                          'Habitat Information',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF006064),
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildDetailRow('Temperature Range', prediction.temperatureRange.isNotEmpty ? prediction.temperatureRange : 'Unknown'),
                        _buildDetailRow('pH Range', prediction.phRange.isNotEmpty ? prediction.phRange : 'Unknown'),
                        _buildDetailRow('Minimum Tank Size', prediction.minimumTankSize.isNotEmpty ? prediction.minimumTankSize : 'Unknown'),
                        _buildDetailRow('Social Behavior', prediction.socialBehavior.isNotEmpty ? prediction.socialBehavior : 'Unknown'),
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
                        // Diet recommendation with expandable groups like capture.dart
                        _buildDietRecommendationSection(prediction),
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
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Color(0xFF006064),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? 'Not specified' : value,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black87,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDietRecommendationSection(FishPrediction prediction) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getCareRecommendations(prediction.commonName, prediction.scientificName),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF006064)),
            ),
          );
        }

        final careData = snapshot.hasData && !snapshot.data!.containsKey('error') 
            ? snapshot.data! 
            : {
                'diet_type': prediction.diet,
                'preferred_foods': prediction.preferredFood,
                'feeding_frequency': prediction.feedingFrequency,
                'portion_size': 'N/A',
                'fasting_schedule': 'N/A',
                'overfeeding_risks': 'N/A',
                'behavioral_notes': 'N/A',
                'tankmate_feeding_conflict': 'N/A',
              };

        if (snapshot.hasError || (snapshot.hasData && snapshot.data!.containsKey('error'))) {
          // Show error but still display basic diet info
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (snapshot.data!.containsKey('error'))
                Text(snapshot.data!['error'], style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 10),
              _buildDietRecommendationGroups(careData),
            ],
          );
        }

        return _buildDietRecommendationGroups(careData);
      },
    );
  }

  Widget _buildDietRecommendationGroups(Map<String, dynamic> dietData) {
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
        ...fieldGroups.map((group) => _buildRecommendationExpansionGroup(group, dietData)).toList(),
      ],
    );
  }

  Widget _buildRecommendationExpansionGroup(List<Map<String, dynamic>> fields, Map<String, dynamic> data) {
    final firstField = fields.first;
    final remainingCount = fields.length - 1;
    
    return ExpansionTile(
      initiallyExpanded: false,
      title: Row(
        children: [
          Icon(firstField['icon'] as IconData, size: 22, color: const Color(0xFF006064)),
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
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      ),
      children: fields.map((field) {
        final value = data[field['key']] ?? 'N/A';
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Card(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(field['icon'] as IconData, color: const Color(0xFF006064), size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          field['label'],
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF006064),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        value is List
                            ? Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: value.map<Widget>((v) => Chip(
                                  label: Text(
                                    v.toString(),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  backgroundColor: const Color(0xFF006064).withOpacity(0.1),
                                  labelStyle: const TextStyle(color: Color(0xFF006064)),
                                )).toList(),
                              )
                            : Text(
                                value.toString(),
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black87,
                                ),
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
    );
  }

  Future<Map<String, dynamic>> _getCareRecommendations(String commonName, String scientificName) async {
    final logBookProvider = Provider.of<LogBookProvider>(context, listen: false);
    return await logBookProvider.generateCareRecommendations(commonName, scientificName);
  }

  void _showCalculationDetails(dynamic calculation) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFF006064)),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              calculation is WaterCalculation 
                  ? 'Water Requirements' 
                  : calculation is FishCalculation
                    ? 'Fish Requirements'
                    : 'Diet Calculation',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF006064),
              ),
            ),
          ),
          body: SingleChildScrollView(
            child: calculation is WaterCalculation
                ? _buildWaterCalculationDetails(calculation)
                : calculation is FishCalculation
                  ? _buildFishCalculationDetails(calculation as FishCalculation)
                  : _buildDietCalculationDetails(calculation as DietCalculation),
          ),
        ),
      ),
    );
  }

  Future<Map<String, dynamic>?> _fetchFishDetails(String fishName) async {
    try {
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/fish-list'));
      
      if (response.statusCode == 200) {
        final List<dynamic> fishList = json.decode(response.body);
        final fishDetails = fishList.firstWhere(
          (fish) => fish['Common Name'] == fishName,
          orElse: () => null,
        );
        
        if (fishDetails != null) {
          // Add image URL to fish details
          final encodedName = Uri.encodeComponent(fishName.trim().replaceAll(' ', ''));
          fishDetails['ImageURL'] = '${ApiConfig.baseUrl}/fish-image/$encodedName';
          
          // Ensure all required fields are present with default values if missing or empty
          final fieldsToCheck = [
            'Water Type',
            'Max Size (cm)',
            'Temperament',
            'Care Level',
            'Lifespan',
            'Diet',
            'Preferred Food',
            'Feeding Frequency',
          ];

          for (final field in fieldsToCheck) {
            if (fishDetails[field] == null || fishDetails[field].toString().trim().isEmpty) {
              fishDetails[field] = 'Not specified';
            }
          }
          
          // Cache the fish details
          final jsonString = json.encode(fishDetails);
          DefaultCacheManager().putFile(
            '${ApiConfig.baseUrl}/fish-details/$encodedName',
            Uint8List.fromList(utf8.encode(jsonString)),
            maxAge: const Duration(days: 7), // Cache for 7 days
          );
          
          return fishDetails;
        }
        
        print('Fish details not found for: $fishName');
        return null;
      } else {
        print('Error fetching fish details: ${response.statusCode}');
        print('Response body: ${response.body}');
        
        // Try to get cached data if API call fails
        try {
          final fileInfo = await DefaultCacheManager().getFileFromCache(
            '${ApiConfig.baseUrl}/fish-details/${Uri.encodeComponent(fishName.trim().replaceAll(' ', '_'))}'
          );
          if (fileInfo != null) {
            final cachedData = await fileInfo.file.readAsString();
            final decodedData = json.decode(cachedData);
            
            // Ensure cached data also has default values
            final fieldsToCheck = [
              'Water Type',
              'Max Size (cm)',
              'Temperament',
              'Care Level',
              'Lifespan',
              'Diet',
              'Preferred Food',
              'Feeding Frequency',
            ];

            for (final field in fieldsToCheck) {
              if (decodedData[field] == null || decodedData[field].toString().trim().isEmpty) {
                decodedData[field] = 'Not specified';
              }
            }
            
            return decodedData;
          }
        } catch (cacheError) {
          print('Error reading from cache: $cacheError');
        }
        
        return null;
      }
    } catch (e) {
      print('Error fetching fish details: $e');
      return null;
    }
  }

  Widget _buildWaterCalculationDetails(WaterCalculation calculation) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          // Fish Details Cards
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: calculation.fishSelections.length,
            itemBuilder: (context, index) {
              final fishName = calculation.fishSelections.keys.elementAt(index);
              final quantity = calculation.fishSelections[fishName];
              final oxygen = calculation.oxygenNeeds != null ? calculation.oxygenNeeds![fishName] : null;
              final filtration = calculation.filtrationNeeds != null ? calculation.filtrationNeeds![fishName] : null;
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Fish image
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      child: _buildResolvedFishImage(fishName, height: 200),
                    ),
                    // Fish details
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                fishName,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF006064),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  'Recommended: ${quantity ?? 1}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF006064),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          StatefulBuilder(
                            builder: (context, setLocalState) {
                              bool showOxygen = _showOxygenNeeds[index] ?? false;
                              bool showFiltration = _showFiltrationNeeds[index] ?? false;

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text('Oxygen Needs', style: TextStyle(fontWeight: FontWeight.w500)),
                                    trailing: Icon(showOxygen ? Icons.expand_less : Icons.expand_more),
                                    onTap: () {
                                      setLocalState(() {
                                        showOxygen = !showOxygen;
                                        _showOxygenNeeds[index] = showOxygen;
                                      });
                                    },
                                  ),
                                  if (showOxygen && oxygen != null && oxygen.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 12.0, bottom: 8),
                                      child: Text(
                                        _cleanNeedsDescription(oxygen).isNotEmpty
                                            ? _cleanNeedsDescription(oxygen)
                                            : 'No additional description.',
                                        style: TextStyle(fontSize: 14, color: Colors.black87),
                                      ),
                                    ),

                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text('Filtration Needs', style: TextStyle(fontWeight: FontWeight.w500)),
                                    trailing: Icon(showFiltration ? Icons.expand_less : Icons.expand_more),
                                    onTap: () {
                                      setLocalState(() {
                                        showFiltration = !showFiltration;
                                        _showFiltrationNeeds[index] = showFiltration;
                                      });
                                    },
                                  ),
                                  if (showFiltration && filtration != null && filtration.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 12.0, bottom: 8),
                                      child: Text(
                                        _cleanNeedsDescription(filtration).isNotEmpty
                                            ? _cleanNeedsDescription(filtration)
                                            : 'No additional description.',
                                        style: TextStyle(fontSize: 14, color: Colors.black87),
                                      ),
                                    ),
                                ],
                              );
                            },
                          )


                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          // Tank Volume Card
          SizedBox(
            width: double.infinity,
            child: Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tank Volume',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF006064),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Minimum Tank Volume: ${calculation.minimumTankVolume}',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Water Parameters Card
          SizedBox(
            width: double.infinity,
            child: Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Water Parameters',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF006064),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Temperature Range: ${calculation.temperatureRange.replaceAll('Â', '')}',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'pH Range: ${calculation.phRange}',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFishCalculationDetails(FishCalculation calculation) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: calculation.fishSelections.length,
            itemBuilder: (context, index) {
              final fishName = calculation.fishSelections.keys.elementAt(index);
              final recommendedQuantity = calculation.recommendedQuantities[fishName];
              
              return Card(
                margin: const EdgeInsets.only(top: 8, bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Fish image
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      child: _buildResolvedFishImage(fishName, height: 200),
                    ),
                    // Fish details
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                fishName,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF006064),
                                ),
                              ),
                              if (recommendedQuantity != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    'Recommended: $recommendedQuantity',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF006064),
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
              );
            },
          ),
          // Tank Requirements Card
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tank Requirements',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF006064),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Tank Volume: ${calculation.tankVolume}',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Water Parameters Card
          SizedBox(
            width: double.infinity,
            child: Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Water Parameters',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF006064),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Temperature Range: ${calculation.temperatureRange.replaceAll('Â', '')}',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'pH Range: ${calculation.phRange}',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDietCalculationDetails(DietCalculation calculation) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          // Fish Details Cards
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: calculation.fishSelections.length,
            itemBuilder: (context, index) {
              final fishName = calculation.fishSelections.keys.elementAt(index);
              final quantity = calculation.fishSelections[fishName];
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Fish image
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      child: _buildResolvedFishImage(fishName, height: 200),
                    ),
                    // Fish details
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                fishName,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF006064),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  'Quantity: ${quantity ?? 1}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF006064),
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
              );
            },
          ),
          // Diet Summary Card
          SizedBox(
            width: double.infinity,
            child: Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Diet Summary',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF006064),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const SizedBox.shrink(),
                    const SizedBox(height: 8),
                    const Text(
                      'Tank total per feeding:',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF006064),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      ' • ${calculation.totalPortionRange ?? '${calculation.totalPortion} pcs of ${_inferFoodLabelFromPortionDetails(calculation.portionDetails ?? const {})}'}',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (calculation.portionDetails?.isNotEmpty == true) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'Per Fish Portions:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF006064),
                        ),
                      ),
                      const SizedBox(height: 6),
                      ...(calculation.portionDetails ?? const {}).entries.map((e) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('• ', style: TextStyle(fontSize: 16, color: Colors.black87)),
                                Expanded(
                                  child: Text(
                                    '${e.key}: ${e.value}',
                                    style: const TextStyle(fontSize: 16, color: Colors.black87),
                                  ),
                                ),
                              ],
                            ),
                          )),
                    ],
                    if (calculation.feedingNotes?.isNotEmpty == true) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Feeding Notes:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF006064),
                        ),
                      ),
                      const SizedBox(height: 6),
                      ...calculation.feedingNotes!
                          .split(RegExp(r'\r?\n'))
                          .where((line) => line.trim().isNotEmpty)
                          .map((line) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('• ', style: TextStyle(fontSize: 16, color: Colors.black87)),
                                    Expanded(
                                      child: Text(
                                        line.replaceFirst(RegExp(r'^[-•]\s*'), '').trim(),
                                        style: const TextStyle(fontSize: 16, color: Colors.black87),
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                    ],
                    if (calculation.feedingsPerDay != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Feeding Frequency:',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF006064),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        ' • ${calculation.feedingsPerDay} times per day',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

String _cleanNeedsDescription(String input) {
  final unwantedWords = ['low', 'medium', 'moderate', 'high'];
  final pattern = RegExp(r'\b(' + unwantedWords.join('|') + r')\b', caseSensitive: false);
  final cleaned = input.replaceAll(pattern, '').replaceAll(RegExp(r'\s+'), ' ').trim();
  return cleaned;
}


  // Infer a concise food label (e.g., 'pellets', 'flakes') from portionDetails values
  String _inferFoodLabelFromPortionDetails(Map<String, dynamic> details) {
    if (details.isEmpty) return 'food';
    final foods = <String>{};
    final known = <String>{
      'flakes','flake','pellet','pellets','sinking pellets','micro pellets','granules',
      'algae wafer','algae wafers','wafer','wafers','bloodworms','brine shrimp','daphnia','tubifex',
      'vegetable','veggies','spirulina','frozen','live food'
    };
    for (final v in details.values) {
      final s = (v ?? '').toString().toLowerCase();
      // Try to capture pattern like '... (2-3 small pellets each)' or '... of flakes'
      final ofMatch = RegExp(r'\bof\s+([a-zA-Z ]+?)(?=\s*(?:each|per\s*day|/day|daily|\.|,|$))')
          .firstMatch(s);
      if (ofMatch != null) {
        var label = ofMatch.group(1)!.trim();
        label = label.replaceAll(RegExp(r'\b(food|feeds?)\b'), '').trim();
        if (label.isNotEmpty) foods.add(label);
        continue;
      }
      // Otherwise search for known keywords
      for (final k in known) {
        if (s.contains(k)) {
          foods.add(k);
        }
      }
    }
    if (foods.isEmpty) return 'food';
    if (foods.length == 1) return foods.first;
    return 'mixed food';
  }


  Widget _buildFishCollectionTab() {
    return Consumer<LogBookProvider>(
      builder: (context, logBookProvider, child) {
        if (logBookProvider.savedPredictions.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'No fish predictions saved yet',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CaptureScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 0, 96, 100),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Add Fish',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: logBookProvider.savedPredictions.length,
          itemBuilder: (context, index) {
            final prediction = logBookProvider.savedPredictions[index];
            return Dismissible(
              key: Key(prediction.commonName),
              background: Container(
                color: const Color.fromARGB(255, 255, 17, 0),
                alignment: Alignment.center,
                child: const Text(
                  'Delete',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              confirmDismiss: (direction) async {
                return await _showDeleteConfirmationDialogFishPrediction(prediction);
              },
              onDismissed: (direction) {
                logBookProvider.removePrediction(prediction);
                showCustomNotification(context, '${prediction.commonName} removed from collection');
              },
              child: Card(
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: InkWell(
                  onTap: () => _showFishDetails(prediction),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        Container(
                          width: 170,
                          height: 100,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: prediction.imagePath.isNotEmpty
                                ? kIsWeb
                                    ? Image.network(
                                        prediction.imagePath,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return const Center(
                                            child: Icon(
                                              Icons.image_not_supported,
                                              color: Colors.grey,
                                              size: 40,
                                            ),
                                          );
                                        },
                                      )
                                    : Image.file(
                                        File(prediction.imagePath),
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return const Center(
                                            child: Icon(
                                              Icons.image_not_supported,
                                              color: Colors.grey,
                                              size: 40,
                                            ),
                                          );
                                        },
                                      )
                                : const Center(
                                    child: Icon(
                                      Icons.photo,
                                      color: Colors.grey,
                                      size: 40,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                prediction.commonName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                prediction.scientificName,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontStyle: FontStyle.italic,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 4),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<bool> _showDeleteConfirmationDialogFishPrediction(FishPrediction prediction) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: Text('Are you sure you want to remove ${prediction.commonName} from your collection?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Confirm'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    ) ?? false;
  }

  Widget _buildCalculatorTab() {
    return Consumer<LogBookProvider>(
      builder: (context, provider, child) {
        final allCalculations = [
          ...provider.savedCalculations,
          ...provider.savedFishCalculations,
          ...provider.savedDietCalculations,
        ]..sort((a, b) {
            DateTime dateA;
            DateTime dateB;
            
            if (a is WaterCalculation) {
              dateA = a.dateCalculated;
            } else if (a is FishCalculation) {
              dateA = a.dateCalculated;
            } else if (a is DietCalculation) {
              dateA = a.dateCalculated;
            } else {
              dateA = DateTime(0);
            }
            
            if (b is WaterCalculation) {
              dateB = b.dateCalculated;
            } else if (b is FishCalculation) {
              dateB = b.dateCalculated;
            } else if (b is DietCalculation) {
              dateB = b.dateCalculated;
            } else {
              dateB = DateTime(0);
            }
            
            return dateB.compareTo(dateA);
          });

        if (allCalculations.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'No calculations saved yet',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HomePage(initialTabIndex: 2),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 0, 96, 100),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'lib/icons/calculator_icon.png',
                        width: 24,
                        height: 24,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Calculate',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: allCalculations.length,
          itemBuilder: (context, index) {
            final calculation = allCalculations[index];
            return Dismissible(
              key: Key((calculation is WaterCalculation) 
                  ? calculation.dateCalculated.toString() 
                  : (calculation is FishCalculation) 
                    ? (calculation as FishCalculation).dateCalculated.toString()
                    : (calculation as DietCalculation).dateCalculated.toString()),
              background: Container(
                color: const Color.fromARGB(255, 255, 17, 0),
                alignment: Alignment.center,
                child: const Text(
                  'Delete',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              confirmDismiss: (direction) async {
                return await _showDeleteConfirmationDialogCalculation(calculation);
              },
              onDismissed: (direction) {
                if (calculation is WaterCalculation) {
                  provider.removeWaterCalculation(calculation);
                  showCustomNotification(context, 'Water calculation removed');
                } else if (calculation is FishCalculation) {
                  provider.removeFishCalculation(calculation);
                  showCustomNotification(context, 'Fish calculation removed');
                } else if (calculation is DietCalculation) {
                  provider.removeDietCalculation(calculation);
                  showCustomNotification(context, 'Diet calculation removed');
                }
              },
              child: Card(
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: InkWell(
                  onTap: () {
                    _showCalculationDetails(calculation);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.teal.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            calculation is WaterCalculation 
                                ? Icons.water_drop 
                                : calculation is FishCalculation 
                                  ? Icons.water
                                  : Icons.restaurant,
                            color: const Color(0xFF006064),
                            size: 30,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                calculation is WaterCalculation 
                                    ? 'Water Calculator' 
                                    : calculation is FishCalculation 
                                      ? 'Fish Calculator'
                                      : 'Diet Calculator',
                                style: const TextStyle(
                                  color: Color(0xFF006064),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                calculation is WaterCalculation
                                    ? 'Tank Volume: ${calculation.minimumTankVolume}'
                                    : calculation is FishCalculation
                                      ? 'Tank Volume: ${(calculation as FishCalculation).tankVolume}'
                                      : 'Fish name: ${(calculation as DietCalculation).fishSelections.keys.join(', ')}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                DateFormat('MMM d, y').format(
                                  calculation is WaterCalculation
                                      ? calculation.dateCalculated
                                      : calculation is FishCalculation
                                        ? (calculation as FishCalculation).dateCalculated
                                        : (calculation as DietCalculation).dateCalculated,
                                ),
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<bool> _showDeleteConfirmationDialogCalculation(dynamic calculation) async {
    String title = 'Confirm Deletion';
    String content = 'Are you sure you want to remove this calculation?';
    if (calculation is WaterCalculation) {
      content = 'Are you sure you want to remove this water calculation?';
    } else if (calculation is FishCalculation) {
      content = 'Are you sure you want to remove this fish calculation?';
    } else if (calculation is DietCalculation) {
      final String rangeOrTotal = (calculation as DietCalculation).totalPortionRange
          ?? (calculation as DietCalculation).totalPortion.toString();
      content = 'Are you sure you want to remove this diet calculation?';
    }
    return await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Confirm'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    ) ?? false;
  }

  Widget _buildFishCompatibilityTab() {
    final logBookProvider = Provider.of<LogBookProvider>(context);
    final compatibilityResults = List<CompatibilityResult>.from(logBookProvider.savedCompatibilityResults)
      ..sort((a, b) => b.dateChecked.compareTo(a.dateChecked));

    if (compatibilityResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'No compatibility results saved yet',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const HomePage(initialTabIndex: 1),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 0, 96, 100),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'lib/icons/sync_icon.png',
                    width: 24,
                    height: 24,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Check Compatibility',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: compatibilityResults.length,
      itemBuilder: (context, index) {
        final result = compatibilityResults[index];
        return Dismissible(
          key: Key(result.id.toString()),
          background: Container(
            color: const Color.fromARGB(255, 255, 17, 0),
            alignment: Alignment.center,
            child: const Text(
              'Delete',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          direction: DismissDirection.endToStart,
          confirmDismiss: (direction) async {
            return await _showDeleteConfirmationDialogCompatibility(result);
          },
          onDismissed: (direction) {
            logBookProvider.removeCompatibilityResult(result);
            showCustomNotification(context, 'Compatibility result removed');
          },
          child: Card(
            elevation: 2,
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: InkWell(
              onTap: () {
                _showCompatibilityDetails(context, result);
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: FutureBuilder<http.Response?>(
                            future: ApiConfig.makeRequestWithFailover(
                              endpoint: '/fish-image/${Uri.encodeComponent(result.fish1Name.replaceAll(' ', ''))}',
                              method: 'GET',
                            ),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return Container(
                                  width: 60,
                                  height: 60,
                                  color: Colors.grey[200],
                                  child: const Center(child: CircularProgressIndicator()),
                                );
                              }
                              if (snapshot.hasError || snapshot.data == null || snapshot.data!.statusCode != 200) {
                                return Container(
                                  width: 60,
                                  height: 60,
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.error),
                                );
                              }
                              try {
                                final Map<String, dynamic> jsonData = json.decode(snapshot.data!.body);
                                final String? imageUrl = (jsonData['url'] ?? '').toString();
                                if (imageUrl == null || imageUrl.isEmpty) {
                                  return Container(
                                    width: 60,
                                    height: 60,
                                    color: Colors.grey[200],
                                    child: const Icon(Icons.error),
                                  );
                                }
                                return Image.network(
                                  imageUrl,
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stack) => Container(
                                    width: 60,
                                    height: 60,
                                    color: Colors.grey[200],
                                    child: const Icon(Icons.image_not_supported),
                                  ),
                                );
                              } catch (_) {
                                return Container(
                                  width: 60,
                                  height: 60,
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.error),
                                );
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: FutureBuilder<http.Response?>(
                            future: ApiConfig.makeRequestWithFailover(
                              endpoint: '/fish-image/${Uri.encodeComponent(result.fish2Name.replaceAll(' ', ''))}',
                              method: 'GET',
                            ),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return Container(
                                  width: 60,
                                  height: 60,
                                  color: Colors.grey[200],
                                  child: const Center(child: CircularProgressIndicator()),
                                );
                              }
                              if (snapshot.hasError || snapshot.data == null || snapshot.data!.statusCode != 200) {
                                return Container(
                                  width: 60,
                                  height: 60,
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.error),
                                );
                              }
                              try {
                                final Map<String, dynamic> jsonData = json.decode(snapshot.data!.body);
                                final String? imageUrl = (jsonData['url'] ?? '').toString();
                                if (imageUrl == null || imageUrl.isEmpty) {
                                  return Container(
                                    width: 60,
                                    height: 60,
                                    color: Colors.grey[200],
                                    child: const Icon(Icons.error),
                                  );
                                }
                                return Image.network(
                                  imageUrl,
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stack) => Container(
                                    width: 60,
                                    height: 60,
                                    color: Colors.grey[200],
                                    child: const Icon(Icons.image_not_supported),
                                  ),
                                );
                              } catch (_) {
                                return Container(
                                  width: 60,
                                  height: 60,
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.error),
                                );
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${result.fish1Name} & ${result.fish2Name}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: result.isCompatible ? Colors.green[50] : Colors.red[50],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              result.isCompatible ? 'Compatible' : 'Not Compatible',
                              style: TextStyle(
                                color: result.isCompatible ? Colors.green[700] : Colors.red[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<bool> _showDeleteConfirmationDialogCompatibility(CompatibilityResult result) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: const Text('Are you sure you want to remove this compatibility result?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Confirm'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    ) ?? false;
  }

  void _showCompatibilityDetails(BuildContext context, CompatibilityResult result) {
    // Normalize plan string for robust comparison
    String normalizedPlan = result.savedPlan.trim().toLowerCase().replaceAll(' ', '_');
    bool showDetailed = normalizedPlan == 'pro';

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFF006064)),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              'Compatibility Details',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF006064),
              ),
            ),
          ),
          body: FutureBuilder<List<Map<String, dynamic>?>>(
            future: Future.wait([
              _fetchFishDetails(result.fish1Name),
              _fetchFishDetails(result.fish2Name),
            ]),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Fish 1
                    _FishImageAndName(
                      fishName: result.fish1Name,
                    ),
                    const SizedBox(height: 16),
                    const Icon(Icons.compare_arrows, size: 32, color: Color(0xFF006064)),
                    const SizedBox(height: 16),
                    // Fish 2
                    _FishImageAndName(
                      fishName: result.fish2Name,
                    ),
                    const SizedBox(height: 32),
                    // Compatibility Result Card
                    Card(
                      elevation: 2,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  result.isCompatible ? Icons.check_circle : Icons.cancel,
                                  color: result.isCompatible ? Colors.green : Colors.red,
                                  size: 28,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  result.isCompatible ? 'Compatible' : 'Not Compatible',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: result.isCompatible ? Colors.green : Colors.red,
                                  ),
                                ),
                              ],
                            ),
                            if (!result.isCompatible && result.reasons.isNotEmpty) ...[
                              const SizedBox(height: 18),
                              const Text(
                                'Incompatibility Reasons:',
                                textAlign: TextAlign.left,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF006064),
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (showDetailed) ...[
                                // Use the saved detailed reasons from the sync result instead of regenerating
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: result.reasons.map((reason) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Icon(
                                          Icons.error_outline,
                                          color: Colors.red,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                                                                 Expanded(
                                           child: Text(
                                             reason,
                                             style: const TextStyle(
                                               fontSize: 14,
                                               color: Colors.black87,
                                             ),
                                             textAlign: TextAlign.justify,
                                           ),
                                         ),
                                      ],
                                    ),
                                  )).toList(),
                                ),
                              ] else ...[
                                ...result.reasons.map((reason) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(
                                        Icons.error_outline,
                                        color: Colors.red,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          reason,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Colors.black87,
                                          ),
                                          textAlign: TextAlign.justify,
                                        ),
                                      ),
                                    ],
                                  ),
                                )),
                              ],
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _FishImageAndName({
    required String fishName,
  }) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 320,
            height: 200,
            child: _buildResolvedFishImage(fishName, height: 200),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          fishName,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF006064),
          ),
        ),
      ],
    );
  }
}
