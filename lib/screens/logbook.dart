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
import '../widgets/custom_notification.dart';
import '../widgets/description_widget.dart';
import '../widgets/fish_images_grid.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_config.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'dart:typed_data';


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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex,
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
                          'Diet Information',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF006064),
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildDetailRow('Diet Type', prediction.diet),
                        _buildDetailRow('Preferred Food', prediction.preferredFood),
                        _buildDetailRow('Feeding Frequency', prediction.feedingFrequency),
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
              calculation is WaterCalculation ? 'Water Requirements' : 'Fish Requirements',
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
                : _buildFishCalculationDetails(calculation as FishCalculation),
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
          final encodedName = Uri.encodeComponent(fishName.trim().replaceAll(' ', '_'));
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
              
              print('Building water calculator fish card for: $fishName, qty: $quantity');
              
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Fish image
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      child: CachedNetworkImage(
                        imageUrl: ApiConfig.getFishImageUrl(fishName),
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          height: 200,
                          color: Colors.grey[200],
                          child: const Center(child: CircularProgressIndicator()),
                        ),
                        errorWidget: (context, url, error) {
                          print('Error loading water calculation image for $fishName: $error');
                          return Container(
                            height: 200,
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
                      ),
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
                      child: CachedNetworkImage(
                        imageUrl: ApiConfig.getFishImageUrl(fishName),
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          height: 200,
                          color: Colors.grey[200],
                          child: const Center(child: CircularProgressIndicator()),
                        ),
                        errorWidget: (context, url, error) {
                          print('Error loading water calculation image for $fishName: $error');
                          return Container(
                            height: 200,
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
                      ),
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

  Widget _buildCalculatorTab() {
    return Consumer<LogBookProvider>(
      builder: (context, provider, child) {
        final allCalculations = [
          ...provider.savedCalculations,
          ...provider.savedFishCalculations,
        ]..sort((a, b) {
            DateTime dateA = (a is WaterCalculation) ? a.dateCalculated : (a as FishCalculation).dateCalculated;
            DateTime dateB = (b is WaterCalculation) ? b.dateCalculated : (b as FishCalculation).dateCalculated;
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
                  : (calculation as FishCalculation).dateCalculated.toString()),
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
              onDismissed: (direction) {
                if (calculation is WaterCalculation) {
                  provider.removeWaterCalculation(calculation);
                  showCustomNotification(context, 'Water calculation removed');
                } else if (calculation is FishCalculation) {
                  provider.removeFishCalculation(calculation);
                  showCustomNotification(context, 'Fish calculation removed');
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
                            calculation is WaterCalculation ? Icons.water_drop : Icons.water,
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
                                calculation is WaterCalculation ? 'Water Calculator' : 'Fish Calculator',
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
                                    : 'Tank Volume: ${(calculation as FishCalculation).tankVolume}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                DateFormat('MMM d, y').format(
                                  (calculation is WaterCalculation)
                                      ? calculation.dateCalculated
                                      : (calculation as FishCalculation).dateCalculated,
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
                    builder: (context) => const HomePage(initialTabIndex: 3),
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
          key: Key(result.dateChecked.toString()),
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
          onDismissed: (direction) {
            logBookProvider.removeCompatibilityResult(result);
            showCustomNotification(context, 'Compatibility result removed');
          },
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                          child: FutureBuilder<http.Response>(
                            future: http.get(Uri.parse(ApiConfig.getFishImageUrl(result.fish1Name))),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return Container(
                                  width: 60,
                                  height: 60,
                                  color: Colors.grey[200],
                                  child: const Center(child: CircularProgressIndicator()),
                                );
                              }
                              if (snapshot.hasError || !snapshot.hasData || snapshot.data!.statusCode != 200) {
                                return Container(
                                  width: 60,
                                  height: 60,
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.error),
                                );
                              }
                              final Map<String, dynamic> jsonData = json.decode(snapshot.data!.body);
                              final String? base64Image = jsonData['image_data'];
                              if (base64Image == null || base64Image.isEmpty) {
                                return Container(
                                  width: 60,
                                  height: 60,
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.error),
                                );
                              }
                              final String base64Str = base64Image.contains(',') ? base64Image.split(',')[1] : base64Image;
                              return Image.memory(
                                base64Decode(base64Str),
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: FutureBuilder<http.Response>(
                            future: http.get(Uri.parse(ApiConfig.getFishImageUrl(result.fish2Name))),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return Container(
                                  width: 60,
                                  height: 60,
                                  color: Colors.grey[200],
                                  child: const Center(child: CircularProgressIndicator()),
                                );
                              }
                              if (snapshot.hasError || !snapshot.hasData || snapshot.data!.statusCode != 200) {
                                return Container(
                                  width: 60,
                                  height: 60,
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.error),
                                );
                              }
                              final Map<String, dynamic> jsonData = json.decode(snapshot.data!.body);
                              final String? base64Image = jsonData['image_data'];
                              if (base64Image == null || base64Image.isEmpty) {
                                return Container(
                                  width: 60,
                                  height: 60,
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.error),
                                );
                              }
                              final String base64Str = base64Image.contains(',') ? base64Image.split(',')[1] : base64Image;
                              return Image.memory(
                                base64Decode(base64Str),
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                              );
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

  void _showCompatibilityDetails(BuildContext context, CompatibilityResult result) {
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

              final fish1Details = snapshot.data?[0];
              final fish2Details = snapshot.data?[1];

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    // Fish 1 Details Card
                    _buildDetailedFishCard(
                      fishName: result.fish1Name,
                      fishDetails: fish1Details,
                      imagePath: ApiConfig.getFishImageUrl(result.fish1Name),
                    ),
                    const SizedBox(height: 24),
                    // Fish 2 Details Card
                    _buildDetailedFishCard(
                      fishName: result.fish2Name,
                      fishDetails: fish2Details,
                      imagePath: ApiConfig.getFishImageUrl(result.fish2Name),
                    ),
                    const SizedBox(height: 24),
                    // Compatibility Result Card
                    Card(
                      elevation: 2,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Compatibility Result',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF006064),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Icon(
                                  result.isCompatible ? Icons.check_circle : Icons.error,
                                  color: result.isCompatible ? Colors.green : Colors.red,
                                  size: 24,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  result.isCompatible ? 'Compatible' : 'Not Compatible',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: result.isCompatible ? Colors.green : Colors.red,
                                  ),
                                ),
                              ],
                            ),
                            if (!result.isCompatible && result.reasons.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              const Text(
                                'Incompatibility Reasons:',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF006064),
                                ),
                              ),
                              const SizedBox(height: 8),
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
                                      ),
                                    ),
                                  ],
                                ),
                              )),
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

  Widget _buildDetailedFishCard({
    required String fishName,
    required String imagePath,
    Map<String, dynamic>? fishDetails,
  }) {
    return Card(
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fish Image
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            child: FutureBuilder<http.Response>(
              future: http.get(Uri.parse(ApiConfig.getFishImageUrl(fishName))),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Container(
                    height: 200,
                    color: Colors.grey[300],
                    child: const Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError || !snapshot.hasData || snapshot.data!.statusCode != 200) {
                  return Container(
                    height: 200,
                    color: Colors.grey[300],
                    child: const Icon(Icons.error, size: 40, color: Colors.grey),
                  );
                }
                final Map<String, dynamic> jsonData = json.decode(snapshot.data!.body);
                final String? base64Image = jsonData['image_data'];
                if (base64Image == null || base64Image.isEmpty) {
                  return Container(
                    height: 200,
                    color: Colors.grey[300],
                    child: const Icon(Icons.error, size: 40, color: Colors.grey),
                  );
                }
                final String base64Str = base64Image.contains(',') ? base64Image.split(',')[1] : base64Image;
                return Image.memory(
                  base64Decode(base64Str),
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                );
              },
            ),
          ),
          // Fish Name and Details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    fishName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF006064),
                    ),
                  ),
                ),
                if (fishDetails != null && fishDetails['recommended_quantity'] != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'Recommended: ${fishDetails['recommended_quantity']}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF006064),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (fishDetails != null) ...[
            const SizedBox(height: 8),
            // Scientific Name
            if (fishDetails['Scientific Name'] != null)
              Text(
                'Scientific Name: ${fishDetails['Scientific Name']}',
                style: const TextStyle(
                  fontSize: 16,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

