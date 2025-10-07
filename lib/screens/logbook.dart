import 'package:flutter/material.dart';
import '../screens/capture.dart'; 
import '../screens/homepage.dart';
import 'package:provider/provider.dart';
import 'logbook_provider.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/fish_prediction.dart';

import 'package:intl/intl.dart';
import '../models/compatibility_result.dart';
import '../models/fish_calculation.dart';
import '../models/water_calculation.dart';
import '../models/diet_calculation.dart';
import '../models/fish_volume_calculation.dart';
import '../widgets/custom_notification.dart';
import '../widgets/fish_details_screen.dart';
import '../config/api_config.dart';

import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../widgets/calculation_result_widget.dart';




class LogBook extends StatefulWidget {
  final int initialTabIndex;
  
  const LogBook({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  _LogBookState createState() => _LogBookState();
}

class _LogBookState extends State<LogBook> {
  String _selectedSection = 'Captured';
  bool _showArchived = false; // Track if showing archived items
  
  final List<String> _sections = [
    'Captured',
    'Calculation',
    'Compatibility',
  ];


  @override
  void initState() {
    super.initState();
    // Set initial section based on the initialTabIndex
    if (widget.initialTabIndex < _sections.length) {
      _selectedSection = _sections[widget.initialTabIndex];
    }
  }


  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[50],
      child: Column(
        children: [
          // Tab selector
          _buildSectionSelector(),
          
          // Content area
          Expanded(
            child: Container(
              color: Colors.white,
              child: _buildSelectedSection(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: const Color(0xFFE0E0E0),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: _sections.map((section) {
              final isSelected = _selectedSection == section;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedSection = section;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF00BFB3) : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(
                          section,
                          style: TextStyle(
                          color: isSelected ? Colors.white : const Color(0xFF666666),
                            fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          // Archived toggle button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _showArchived = !_showArchived;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      decoration: BoxDecoration(
                        color: _showArchived ? Colors.orange[100] : Colors.grey[100],
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _showArchived ? Colors.orange : Colors.grey[300]!,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _showArchived ? Icons.archive : Icons.archive_outlined,
                            size: 16,
                            color: _showArchived ? Colors.orange[700] : Colors.grey[600],
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _showArchived ? 'Show Active' : 'Show Archived',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: _showArchived ? Colors.orange[700] : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }





  Widget _buildSelectedSection() {
    switch (_selectedSection) {
      case 'Captured':
        return _buildFishCollectionTab();
      case 'Calculation':
        return _buildCalculatorTab();
      case 'Compatibility':
        return _buildFishCompatibilityTab();
      default:
        return _buildFishCollectionTab();
    }
  }

  void _showFishDetails(FishPrediction prediction) {
    // Convert FishPrediction to fish data format
    final fishData = {
      'common_name': prediction.commonName,
      'scientific_name': prediction.scientificName,
      'water_type': prediction.waterType,
      'max_size': prediction.maxSize,
      'temperament': prediction.temperament,
      'care_level': prediction.careLevel,
      'lifespan': prediction.lifespan,
      'temperature_range': prediction.temperatureRange,
      'ph_range': prediction.phRange,
      'minimum_tank_size': prediction.minimumTankSize,
      'social_behavior': prediction.socialBehavior,
      'diet': prediction.diet,
      'preferred_food': prediction.preferredFood,
      'feeding_frequency': prediction.feedingFrequency,
      'description': prediction.description,
    };

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (BuildContext context) {
          return FishDetailsScreen(
            commonName: prediction.commonName,
            scientificName: prediction.scientificName,
            capturedImagePath: prediction.imagePath,
            fishData: fishData,
            useCapturedImage: true,
          );
        },
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
              calculation is WaterCalculation 
                  ? 'Water Requirements' 
                  : calculation is FishCalculation
                    ? 'Fish Requirements'
                    : calculation is FishVolumeCalculation
                      ? 'Fish Volume Calculation'
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
                  ? _buildFishCalculationDetails(calculation)
                  : calculation is FishVolumeCalculation
                    ? _buildFishVolumeCalculationDetails(calculation)
                    : _buildDietCalculationDetails(calculation),
          ),
        ),
      ),
    );
  }


  Widget _buildWaterCalculationDetails(WaterCalculation calculation) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          
          // Tank Shape Card
          if (calculation.tankShape != null) ...[
            CalculationResultWidget(
              title: 'Tank Shape',
              subtitle: 'Selected aquarium configuration',
              icon: Icons.rectangle_rounded,
              infoRows: [
                CalculationInfoRow(
                  icon: Icons.rectangle_rounded,
                  label: 'Shape',
                  value: calculation.tankShape!,
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
          
          // Selected Fish Card
          FishSelectionCard(
            fishSelections: calculation.fishSelections,
            cardTitle: 'Selected Fish',
            cardSubtitle: 'Fish species for water calculation',
          ),
          const SizedBox(height: 20),
          
          // Tank Dimensions Card
          CalculationResultWidget(
            title: 'Tank Dimensions',
            subtitle: 'Aquarium size and volume information',
            icon: Icons.rectangle_rounded,
            infoRows: [
              CalculationInfoRow(
                icon: Icons.water,
                label: 'Minimum Tank Volume',
                value: calculation.minimumTankVolume,
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Water Requirements Card
          CalculationResultWidget(
            title: 'Water Requirements',
            subtitle: 'Optimal water parameters for your fish',
            icon: Icons.water_drop_rounded,
            infoRows: calculation.waterRequirements != null ? [
              CalculationInfoRow(
                icon: Icons.thermostat,
                label: 'Temperature Range',
                value: (calculation.waterRequirements!['temperature_range'] as String?) ?? calculation.temperatureRange,
              ),
              CalculationInfoRow(
                icon: Icons.science,
                label: 'pH Range',
                value: (calculation.waterRequirements!['pH_range'] as String?) ?? 
                          (calculation.waterRequirements!['ph_range'] as String?) ?? 
                          (calculation.waterRequirements!['pH'] as String?) ?? 
                          calculation.phRange,
                        ),
              CalculationInfoRow(
                icon: Icons.water,
                label: 'Minimum Tank Volume',
                value: '${(calculation.waterRequirements!['minimum_tank_volume'] as String?) ?? calculation.minimumTankVolume}',
              ),
            ] : [
              CalculationInfoRow(
                icon: Icons.thermostat,
                label: 'Temperature Range',
                value: calculation.temperatureRange.replaceAll('Â', ''),
              ),
              CalculationInfoRow(
                icon: Icons.science,
                label: 'pH Range',
                value: calculation.phRange,
              ),
              CalculationInfoRow(
                icon: Icons.water,
                label: 'Minimum Tank Volume',
                value: '${calculation.minimumTankVolume} L',
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Tankmate Recommendations Card
          if (calculation.tankmateRecommendations != null && calculation.tankmateRecommendations!.isNotEmpty) ...[
            TankmateRecommendationsCard(
              tankmates: calculation.tankmateRecommendations!,
              compatibleWithConditions: null, // Add this data if available
            ),
          const SizedBox(height: 20),
          ],
          
          // Feeding Information Card
          if (calculation.feedingInformation != null && calculation.feedingInformation!.isNotEmpty) ...[
            FeedingInformationCard(feedingInformation: calculation.feedingInformation!),
            const SizedBox(height: 20),
          ],
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
          const SizedBox(height: 24),
          
          // Selected Fish Card
          FishSelectionCard(
            fishSelections: calculation.fishSelections,
            cardTitle: 'Selected Fish',
            cardSubtitle: 'Fish species for dimension calculation',
          ),
          const SizedBox(height: 20),
          
          // Tank Dimensions Card
          CalculationResultWidget(
            title: 'Tank Dimensions',
            subtitle: 'Aquarium size and volume information',
            icon: Icons.rectangle_rounded,
            infoRows: [
              CalculationInfoRow(
                icon: Icons.water,
                label: 'Tank Volume',
                value: calculation.tankVolume,
                                ),
                            ],
                          ),
          const SizedBox(height: 20),
          
          // Water Parameters Card
          CalculationResultWidget(
            title: 'Water Parameters',
            subtitle: 'Optimal water conditions for your fish',
            icon: Icons.thermostat_rounded,
            infoRows: [
              CalculationInfoRow(
                icon: Icons.thermostat_rounded,
                label: 'Temperature Range',
                value: calculation.temperatureRange.replaceAll('Â', ''),
              ),
              CalculationInfoRow(
                icon: Icons.science_rounded,
                label: 'pH Range',
                value: calculation.phRange,
                    ),
                  ],
                ),
          const SizedBox(height: 20),
          
          // AI-generated content cards
          if (calculation.waterParametersResponse != null) ...[
            _buildAIContentCard(
              'Water Parameters',
              Icons.water_drop,
              calculation.waterParametersResponse!,
            ),
            const SizedBox(height: 20),
          ],
          if (calculation.tankAnalysisResponse != null) ...[
            _buildAIContentCard(
              'Tank & Environment',
              null,
              calculation.tankAnalysisResponse!,
            ),
            const SizedBox(height: 20),
          ],
          if (calculation.filtrationResponse != null) ...[
            _buildAIContentCard(
              'Filtration & Equipment',
              Icons.filter_alt,
              calculation.filtrationResponse!,
            ),
            const SizedBox(height: 20),
          ],
          if (calculation.dietCareResponse != null) ...[
            _buildAIContentCard(
              'Diet & Care Tips',
              Icons.restaurant,
              calculation.dietCareResponse!,
            ),
            const SizedBox(height: 20),
          ],
          if (calculation.tankmateRecommendations != null && calculation.tankmateRecommendations!.isNotEmpty) ...[
            TankmateRecommendationsCard(
              tankmates: calculation.tankmateRecommendations!,
              compatibleWithConditions: null, // Add this data if available
            ),
            const SizedBox(height: 20),
          ],
          
          // Feeding Information Card
          if (calculation.feedingInformation != null && calculation.feedingInformation!.isNotEmpty) ...[
            FeedingInformationCard(feedingInformation: calculation.feedingInformation!),
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }

  Widget _buildAIContentCard(String title, IconData? icon, String content) {
    return SizedBox(
      width: double.infinity,
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F7FA),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: icon != null 
                      ? (icon == Icons.water_drop 
                          ? Image.asset(
                              'lib/icons/Create_Aquarium.png',
                              width: 20,
                              height: 20,
                              color: const Color(0xFF006064),
                            )
                          : Icon(
                              icon,
                              color: const Color(0xFF006064),
                            ))
                      : Image.asset(
                          'lib/icons/Create_Aquarium.png',
                          width: 20,
                          height: 20,
                          color: const Color(0xFF006064),
                        ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF006064),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                content,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildFishVolumeCalculationDetails(FishVolumeCalculation calculation) {
    return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          const SizedBox(height: 24),
          
          // Tank Shape Card
          CalculationResultWidget(
            title: 'Tank Shape',
            subtitle: 'Selected aquarium configuration',
            icon: Icons.rectangle_rounded,
            infoRows: [
              CalculationInfoRow(
                icon: Icons.rectangle_rounded,
                label: 'Shape',
                value: calculation.tankShape,
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Tank Dimensions Card
          CalculationResultWidget(
            title: 'Tank Dimensions',
            subtitle: 'Aquarium size and volume information',
            icon: Icons.rectangle_rounded,
            infoRows: [
              CalculationInfoRow(
                icon: Icons.water,
                label: 'Tank Volume',
                value: calculation.tankVolume,
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Selected Fish Card
          FishSelectionCard(
            fishSelections: calculation.fishSelections,
            cardTitle: 'Selected Fish',
            cardSubtitle: 'Fish species for volume calculation',
          ),
          const SizedBox(height: 20),
          
          // Recommended Quantities Card
          CalculationResultWidget(
            title: 'Recommended Quantities',
            subtitle: 'Optimal fish quantities for your tank',
            icon: Icons.recommend_rounded,
            infoRows: calculation.recommendedQuantities.entries.map((entry) => 
              CalculationInfoRow(
                icon: Icons.recommend_rounded,
                label: entry.key,
                value: '${entry.value} recommended',
              ),
            ).toList(),
          ),
          const SizedBox(height: 20),
          
          // Tankmate Recommendations Card
          if (calculation.tankmateRecommendations != null && calculation.tankmateRecommendations!.isNotEmpty) ...[
            TankmateRecommendationsCard(
              tankmates: calculation.tankmateRecommendations!,
              compatibleWithConditions: null, // Add this data if available
            ),
            const SizedBox(height: 20),
          ],
          
          // Water Requirements Card
          CalculationResultWidget(
            title: 'Water Requirements',
            subtitle: 'Optimal water parameters for your fish',
            icon: Icons.water_drop_rounded,
            infoRows: [
              if (calculation.waterRequirements['temperature_range'] != null)
                CalculationInfoRow(
                  icon: Icons.thermostat_rounded,
                  label: 'Temperature Range',
                  value: calculation.waterRequirements['temperature_range'].toString(),
                ),
              if (calculation.waterRequirements['ph_range'] != null)
                CalculationInfoRow(
                  icon: Icons.science_rounded,
                  label: 'pH Range',
                  value: calculation.waterRequirements['ph_range'].toString(),
                ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Feeding Information Card
          FeedingInformationCard(feedingInformation: calculation.feedingInformation),
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
          
          // Selected Fish Card
          FishSelectionCard(
            fishSelections: calculation.fishSelections,
            cardTitle: 'Selected Fish',
            cardSubtitle: 'Fish species for diet calculation',
          ),
          const SizedBox(height: 20),
          
          // Feeding Schedule Card
          if (calculation.feedingSchedule != null) ...[
            CalculationResultWidget(
              title: 'Feeding Schedule',
              subtitle: 'Recommended feeding times and frequency',
              icon: Icons.schedule_rounded,
              infoRows: [
                CalculationInfoRow(
                  label: '',
                  value: calculation.feedingSchedule!,
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
          
          // Total Food Per Feeding Card
          if (calculation.totalFoodPerFeeding != null) ...[
            CalculationResultWidget(
              title: 'Total Food Per Feeding',
              subtitle: 'Recommended food amount per feeding',
              icon: Icons.scale_rounded,
              infoRows: [
                CalculationInfoRow(
                  label: 'Food Amount',
                  value: calculation.totalFoodPerFeeding!,
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
          
          // Per Fish Breakdown Card
          if (calculation.perFishBreakdown != null && calculation.perFishBreakdown!.isNotEmpty) ...[
            CalculationResultWidget(
              title: 'Per Fish Breakdown',
              subtitle: 'Individual feeding portions for each fish',
              icon: FontAwesomeIcons.fish,
              infoRows: calculation.perFishBreakdown!.entries.map((entry) => 
                CalculationInfoRow(
                  label: entry.key,
                  value: '${entry.value['quantity'] ?? 1}x: ${entry.value['total_portion'] ?? 'Standard portion'}',
                ),
              ).toList(),
            ),
            const SizedBox(height: 20),
          ],
          
          // Recommended Food Types Card
          if (calculation.recommendedFoodTypes != null && calculation.recommendedFoodTypes!.isNotEmpty) ...[
            CalculationResultWidget(
              title: 'Recommended Food Types',
              subtitle: 'Best food options for your fish',
              icon: Icons.restaurant_menu_rounded,
              infoRows: calculation.recommendedFoodTypes!.map((foodType) => 
                CalculationInfoRow(
                  label: '',
                  value: foodType,
                ),
              ).toList(),
            ),
            const SizedBox(height: 20),
          ],
          
          // Feeding Tips Card
          if (calculation.feedingTips != null && calculation.feedingTips!.isNotEmpty) ...[
            CalculationResultWidget(
              title: 'Feeding Tips',
              subtitle: 'Helpful feeding recommendations',
              icon: Icons.lightbulb_rounded,
              infoRows: [
                CalculationInfoRow(
                  label: '',
                  value: calculation.feedingTips!,
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
          
        ],
      ),
    );
  }







  Widget _buildFishCollectionTab() {
    return Consumer<LogBookProvider>(
      builder: (context, logBookProvider, child) {
        // Load archived data if showing archived and data is empty
        if (_showArchived && logBookProvider.archivedPredictions.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            logBookProvider.loadArchivedData();
          });
        }

        final predictions = _showArchived ? logBookProvider.archivedPredictions : logBookProvider.savedPredictions;
        
        if (predictions.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _showArchived ? 'No archived fish predictions' : 'No fish predictions saved yet',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF00BFB3),
                        const Color(0xFF4DD0E1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00BFB3).withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CaptureScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                        color: Colors.white,
                            size: 20,
                      ),
                        ),
                        const SizedBox(width: 12),
                      const Text(
                          'Capture New Fish',
                        style: TextStyle(
                          fontSize: 16,
                            fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: predictions.length + (_showArchived ? 0 : 1), // +1 for capture button only if not archived
          itemBuilder: (context, index) {
            if (!_showArchived && index == predictions.length) {
              // Show capture button at the end (only for active items)
              return _buildCaptureButton();
            }
            
            final prediction = predictions[index];
            return _showArchived 
              ? _buildArchivedFishCard(prediction, logBookProvider)
              : Dismissible(
                  key: Key(prediction.commonName),
                  background: Container(
                    color: const Color.fromARGB(255, 255, 17, 0),
                    alignment: Alignment.center,
                    child: const Text(
                      'Archive',
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
                    logBookProvider.archivePrediction(prediction);
                    showCustomNotification(context, '${prediction.commonName} archived from collection');
                  },
                  child: _buildFishCard(prediction),
                );
          },
        );
      },
    );
  }

  Widget _buildFishCard(FishPrediction prediction) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        elevation: 2,
                child: InkWell(
                  onTap: () => _showFishDetails(prediction),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            height: 200,
            child: Column(
                      children: [
                // Fish Image - takes up most of the card
                Expanded(
                  flex: 3,
                  child: Container(
                    width: double.infinity,
                          decoration: BoxDecoration(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(6),
                        topRight: Radius.circular(6),
                      ),
                    ),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(6),
                            topRight: Radius.circular(6),
                          ),
                            child: prediction.imagePath.isNotEmpty
                                ? kIsWeb
                                    ? Image.network(
                                        prediction.imagePath,
                                        fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity,
                                        errorBuilder: (context, error, stackTrace) {
                                        return _buildSimpleImagePlaceholder();
                                        },
                                      )
                                    : Image.file(
                                        File(prediction.imagePath),
                                        fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity,
                                        errorBuilder: (context, error, stackTrace) {
                                        return _buildSimpleImagePlaceholder();
                                      },
                                    )
                              : _buildSimpleImagePlaceholder(),
                        ),
                        // Delete button overlay
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: IconButton(
                              onPressed: () async {
                                final shouldDelete = await _showDeleteConfirmationDialogFishPrediction(prediction);
                                if (shouldDelete) {
                                  Provider.of<LogBookProvider>(context, listen: false).archivePrediction(prediction);
                                  showCustomNotification(context, '${prediction.commonName} archived from collection');
                                }
                              },
                              icon: const Icon(
                                Icons.archive,
                                color: Colors.orange,
                                size: 20,
                              ),
                              padding: const EdgeInsets.all(8),
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Fish Names - more space for text
                        Expanded(
                  flex: 2,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: const BoxDecoration(
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(6),
                        bottomRight: Radius.circular(6),
                      ),
                    ),
                          child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                        // Common Name
                              Text(
                                prediction.commonName,
                                style: const TextStyle(
                            fontSize: 14,
                                  fontWeight: FontWeight.bold,
                            color: Colors.black87,
                                ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                              ),
                        const SizedBox(height: 2),
                        // Scientific Name
                              Text(
                                prediction.scientificName,
                                style: TextStyle(
                            fontSize: 11,
                                  fontStyle: FontStyle.italic,
                                  color: Colors.grey[600],
                                ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
  }

  Widget _buildArchivedFishCard(FishPrediction prediction, LogBookProvider logBookProvider) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        elevation: 2,
        child: InkWell(
          onTap: () => _showFishDetails(prediction),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            height: 200,
            child: Column(
              children: [
                // Fish Image - takes up most of the card
                Expanded(
                  flex: 3,
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(6),
                        topRight: Radius.circular(6),
                      ),
                    ),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(6),
                            topRight: Radius.circular(6),
                          ),
                          child: prediction.imagePath.isNotEmpty
                              ? kIsWeb
                                  ? Image.network(
                                      prediction.imagePath,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity,
                                      errorBuilder: (context, error, stackTrace) {
                                        return _buildSimpleImagePlaceholder();
                                      },
                                    )
                                  : Image.file(
                                      File(prediction.imagePath),
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity,
                                      errorBuilder: (context, error, stackTrace) {
                                        return _buildSimpleImagePlaceholder();
                                      },
                                    )
                            : _buildSimpleImagePlaceholder(),
                        ),
                        // Restore button overlay
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: IconButton(
                              onPressed: () async {
                                final shouldRestore = await _showRestoreConfirmationDialogFishPrediction(prediction);
                                if (shouldRestore) {
                                  await logBookProvider.restorePrediction(prediction);
                                  showCustomNotification(context, '${prediction.commonName} restored to collection');
                                }
                              },
                              icon: const Icon(
                                Icons.restore,
                                color: Colors.green,
                                size: 20,
                              ),
                              padding: const EdgeInsets.all(8),
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                            ),
                          ),
                        ),
                        // Archived overlay
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.archive,
                                  color: Colors.white,
                                  size: 12,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Archived',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Fish Names - more space for text
                Expanded(
                  flex: 2,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: const BoxDecoration(
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(6),
                        bottomRight: Radius.circular(6),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Common Name
                        Text(
                          prediction.commonName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        // Scientific Name
                        Text(
                          prediction.scientificName,
                          style: TextStyle(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            color: Colors.grey[600],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCaptureButton() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF00BFB3),
              const Color(0xFF4DD0E1),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00BFB3).withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const CaptureScreen(),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Capture New Fish',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStartCalculatingButton() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF00BFB3),
              const Color(0xFF4DD0E1),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00BFB3).withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const HomePage(initialTabIndex: 2),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.calculate,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Start Calculating',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCheckCompatibilityButton() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF00BFB3),
              const Color(0xFF4DD0E1),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00BFB3).withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const HomePage(initialTabIndex: 1),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.compare_arrows,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Check Compatibility',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSimpleImagePlaceholder() {
    return Container(
      color: Colors.grey[200],
      child: const Center(
        child: Icon(
          FontAwesomeIcons.fish,
          color: Colors.grey,
          size: 40,
        ),
      ),
    );
  }


  Future<bool> _showDeleteConfirmationDialogFishPrediction(FishPrediction prediction) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.red.withOpacity(0.1),
                      Colors.red.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.archive_outlined,
                  color: Colors.orange,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Archive Fish',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'This action cannot be undone',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Are you sure you want to archive this fish from your collection?',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF374151),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          color: const Color(0xFF00BFB3).withOpacity(0.1),
                        ),
                        child: const Icon(
                          FontAwesomeIcons.fish,
                          color: Color(0xFF00BFB3),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              prediction.commonName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              prediction.scientificName,
                              style: TextStyle(
                                fontSize: 14,
                                fontStyle: FontStyle.italic,
                                color: Colors.grey[600],
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
          actions: <Widget>[
            Row(
              children: [
                Expanded(
                  child: TextButton(
              onPressed: () => Navigator.of(context).pop(false),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: Colors.grey.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      backgroundColor: Colors.grey.withOpacity(0.05),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Archive',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    ) ?? false;
  }

  Future<bool> _showRestoreConfirmationDialogFishPrediction(FishPrediction prediction) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.green.withOpacity(0.1),
                      Colors.green.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.restore,
                  color: Colors.green,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Restore Fish',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'This will restore the fish to your active collection',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Are you sure you want to restore this fish to your collection?',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF374151),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          color: const Color(0xFF00BFB3).withOpacity(0.1),
                        ),
                        child: const Icon(
                          FontAwesomeIcons.fish,
                          color: Color(0xFF00BFB3),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              prediction.commonName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              prediction.scientificName,
                              style: TextStyle(
                                fontSize: 14,
                                fontStyle: FontStyle.italic,
                                color: Colors.grey[600],
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
          actions: <Widget>[
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: Colors.grey.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      backgroundColor: Colors.grey.withOpacity(0.05),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Restore',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    ) ?? false;
  }

  Widget _buildCalculatorTab() {
    return Consumer<LogBookProvider>(
      builder: (context, provider, child) {
        // Load archived data if showing archived and data is empty
        if (_showArchived && provider.archivedCalculations.isEmpty && 
            provider.archivedFishCalculations.isEmpty && 
            provider.archivedDietCalculations.isEmpty && 
            provider.archivedFishVolumeCalculations.isEmpty) {
          print('No archived calculations found, loading from database...');
          WidgetsBinding.instance.addPostFrameCallback((_) {
            provider.loadArchivedData();
          });
        } else {
          print('Build calculator tab - Show archived: $_showArchived');
          print('Water calculations: ${provider.archivedCalculations.length} archived, ${provider.savedCalculations.length} active');
          print('Fish calculations: ${provider.archivedFishCalculations.length} archived, ${provider.savedFishCalculations.length} active');
          print('Diet calculations: ${provider.archivedDietCalculations.length} archived, ${provider.savedDietCalculations.length} active');
          print('Fish volume calculations: ${provider.archivedFishVolumeCalculations.length} archived, ${provider.savedFishVolumeCalculations.length} active');
        }

        final allCalculations = _showArchived ? [
          ...provider.archivedCalculations,
          ...provider.archivedFishCalculations,
          ...provider.archivedDietCalculations,
          ...provider.archivedFishVolumeCalculations,
        ] : [
          ...provider.savedCalculations,
          ...provider.savedFishCalculations,
          ...provider.savedDietCalculations,
          ...provider.savedFishVolumeCalculations,
        ]..sort((a, b) {
            DateTime dateA;
            DateTime dateB;
            
            if (a is WaterCalculation) {
              dateA = a.dateCalculated;
            } else if (a is FishCalculation) {
              dateA = a.dateCalculated;
            } else if (a is DietCalculation) {
              dateA = a.dateCalculated;
            } else if (a is FishVolumeCalculation) {
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
            } else if (b is FishVolumeCalculation) {
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
                Text(
                  _showArchived ? 'No archived calculations' : 'No calculations saved yet',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF00BFB3),
                        const Color(0xFF4DD0E1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00BFB3).withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HomePage(initialTabIndex: 2),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.calculate,
                        color: Colors.white,
                            size: 20,
                      ),
                        ),
                        const SizedBox(width: 12),
                      const Text(
                          'Start Calculating',
                        style: TextStyle(
                          fontSize: 16,
                            fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: allCalculations.length + (_showArchived ? 0 : 1), // +1 for calculate button only if not archived
          itemBuilder: (context, index) {
            if (!_showArchived && index == allCalculations.length) {
              // Show calculate button at the end (only for active items)
              return _buildStartCalculatingButton();
            }
            
            final calculation = allCalculations[index];
            return _showArchived 
              ? _buildArchivedCalculationCard(calculation, provider)
              : Dismissible(
              key: Key((calculation is WaterCalculation) 
                  ? calculation.dateCalculated.toString() 
                  : (calculation is FishCalculation) 
                    ? calculation.dateCalculated.toString()
                    : (calculation is DietCalculation)
                      ? calculation.dateCalculated.toString()
                      : (calculation as FishVolumeCalculation).dateCalculated.toString()),
              background: Container(
                color: const Color.fromARGB(255, 255, 17, 0),
                alignment: Alignment.center,
                child: const Text(
                  'Archive',
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
                  provider.archiveWaterCalculation(calculation);
                  showCustomNotification(context, 'Water calculation archived');
                } else if (calculation is FishCalculation) {
                  provider.archiveFishCalculation(calculation);
                  showCustomNotification(context, 'Fish calculation archived');
                } else if (calculation is DietCalculation) {
                  provider.archiveDietCalculation(calculation);
                  showCustomNotification(context, 'Diet calculation archived');
                } else if (calculation is FishVolumeCalculation) {
                  provider.archiveFishVolumeCalculation(calculation);
                  showCustomNotification(context, 'Fish volume calculation archived');
                }
              },
              child: Card(
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
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
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: calculation is WaterCalculation 
                              ? Image.asset(
                                  'lib/icons/Create_Aquarium.png',
                                  width: 30,
                                  height: 30,
                                  color: const Color(0xFF006064),
                                )
                              : Icon(
                                  calculation is FishCalculation 
                                    ? Icons.water
                                    : calculation is FishVolumeCalculation
                                      ? Icons.calculate
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
                                      : calculation is FishVolumeCalculation
                                        ? 'Fish Volume Calculator'
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
                                      ? 'Tank Volume: ${calculation.tankVolume}'
                                      : calculation is FishVolumeCalculation
                                        ? 'Tank: ${calculation.tankShape} - ${calculation.tankVolume}'
                                        : 'Fish: ${(calculation as DietCalculation).fishSelections.keys.join(', ')}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              if (calculation is DietCalculation) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Daily Portion: ${calculation.totalPortion} pieces',
                                  style: const TextStyle(
                                    color: Color(0xFF006064),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                              Text(
                                DateFormat('MMM d, y').format(
                                  calculation is WaterCalculation
                                      ? calculation.dateCalculated
                                      : calculation is FishCalculation
                                        ? calculation.dateCalculated
                                        : calculation is FishVolumeCalculation
                                          ? calculation.dateCalculated
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
    String title = 'Archive Calculation';
    String content = 'Are you sure you want to archive this calculation?';
    IconData icon = Icons.calculate;
    String typeName = 'Calculation';
    
    if (calculation is WaterCalculation) {
      content = 'Are you sure you want to archive this water calculation?';
      icon = Icons.water_drop;
      typeName = 'Water Calculator';
    } else if (calculation is FishCalculation) {
      content = 'Are you sure you want to archive this fish calculation?';
      icon = FontAwesomeIcons.fish;
      typeName = 'Fish Calculator';
      icon = FontAwesomeIcons.fish;
    } else if (calculation is FishVolumeCalculation) {
      content = 'Are you sure you want to archive this fish volume calculation?';
      icon = Icons.calculate;
      typeName = 'Fish Volume Calculator';
    } else if (calculation is DietCalculation) {
      content = 'Are you sure you want to archive this diet calculation?';
      icon = Icons.restaurant;
      typeName = 'Diet Calculator';
    }
    
    return await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.red.withOpacity(0.1),
                      Colors.red.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.archive_outlined,
                  color: Colors.orange,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'This action cannot be undone',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  content,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF374151),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          color: const Color(0xFF00BFB3).withOpacity(0.1),
                        ),
                        child: Icon(
                          icon,
                          color: const Color(0xFF00BFB3),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              typeName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Saved calculation',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
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
          actions: <Widget>[
            Row(
              children: [
                Expanded(
                  child: TextButton(
              onPressed: () => Navigator.of(context).pop(false),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: Colors.grey.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      backgroundColor: Colors.grey.withOpacity(0.05),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Archive',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    ) ?? false;
  }

  Future<bool> _showRestoreConfirmationDialogCalculation(dynamic calculation) async {
    String title = 'Restore Calculation';
    String content = 'Are you sure you want to restore this calculation?';
    IconData icon = Icons.calculate;
    String typeName = 'Calculation';
    
    if (calculation is WaterCalculation) {
      content = 'Are you sure you want to restore this water calculation?';
      icon = Icons.water_drop;
      typeName = 'Water Calculator';
    } else if (calculation is FishCalculation) {
      content = 'Are you sure you want to restore this fish calculation?';
      icon = FontAwesomeIcons.fish;
      typeName = 'Fish Calculator';
    } else if (calculation is FishVolumeCalculation) {
      content = 'Are you sure you want to restore this fish volume calculation?';
      icon = Icons.calculate;
      typeName = 'Fish Volume Calculator';
    } else if (calculation is DietCalculation) {
      content = 'Are you sure you want to restore this diet calculation?';
      icon = Icons.restaurant;
      typeName = 'Diet Calculator';
    }
    
    return await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.green.withOpacity(0.1),
                      Colors.green.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.restore,
                  color: Colors.green,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'This will restore the calculation to your active calculations',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  content,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF374151),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          color: const Color(0xFF00BFB3).withOpacity(0.1),
                        ),
                        child: Icon(
                          icon,
                          color: const Color(0xFF00BFB3),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              typeName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Saved calculation',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
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
          actions: <Widget>[
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: Colors.grey.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      backgroundColor: Colors.grey.withOpacity(0.05),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Restore',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    ) ?? false;
  }

  Widget _buildArchivedCalculationCard(dynamic calculation, LogBookProvider provider) {
    // Debug information
    final type = calculation is WaterCalculation 
        ? 'Water Calculation' 
        : calculation is FishCalculation 
          ? 'Fish Calculation'
          : calculation is FishVolumeCalculation
            ? 'Fish Volume Calculation'
            : 'Diet Calculation';
    
    print('Rendering archived calculation card - Type: $type');
    print('Calculation data: $calculation');
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
      ),
      child: InkWell(
        onTap: () {
          print('Tapped on archived $type: $calculation');
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
                  borderRadius: BorderRadius.circular(6),
                ),
                child: calculation is WaterCalculation 
                    ? Image.asset(
                        'lib/icons/Create_Aquarium.png',
                        width: 30,
                        height: 30,
                        color: const Color(0xFF006064),
                      )
                    : Icon(
                        calculation is FishCalculation 
                          ? Icons.water
                          : calculation is FishVolumeCalculation
                            ? Icons.calculate
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            type,
                            style: const TextStyle(
                              color: Color(0xFF006064),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.archive,
                                color: Colors.white,
                                size: 10,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Archived',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getCalculationTitle(calculation),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (calculation is DietCalculation) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Daily Portion: ${calculation.totalPortion} pieces',
                        style: const TextStyle(
                          color: Color(0xFF006064),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    Text(
                      _getFormattedDate(calculation),
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              // Restore button
              IconButton(
                onPressed: () async {
                  print('Restoring $type: $calculation');
                  final shouldRestore = await _showRestoreConfirmationDialogCalculation(calculation);
                  if (shouldRestore) {
                    try {
                      if (calculation is WaterCalculation) {
                        await provider.restoreWaterCalculation(calculation);
                      } else if (calculation is FishCalculation) {
                        await provider.restoreFishCalculation(calculation);
                      } else if (calculation is DietCalculation) {
                        await provider.restoreDietCalculation(calculation);
                      } else if (calculation is FishVolumeCalculation) {
                        await provider.restoreFishVolumeCalculation(calculation);
                      }
                      showCustomNotification(context, 'Calculation restored');
                    } catch (e) {
                      print('Error restoring calculation: $e');
                      showCustomNotification(context, 'Error restoring calculation: $e', isError: true);
                    }
                  }
                },
                icon: const Icon(
                  Icons.restore,
                  color: Colors.green,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  String _getCalculationTitle(dynamic calculation) {
    if (calculation is WaterCalculation) {
      return 'Tank Volume: ${calculation.minimumTankVolume ?? 'N/A'}';
    } else if (calculation is FishCalculation) {
      return 'Tank Volume: ${calculation.tankVolume ?? 'N/A'}';
    } else if (calculation is FishVolumeCalculation) {
      return 'Tank: ${calculation.tankShape ?? 'N/A'} - ${calculation.tankVolume ?? 'N/A'}';
    } else if (calculation is DietCalculation) {
      return 'Fish: ${calculation.fishSelections?.keys.join(', ') ?? 'N/A'}';
    }
    return 'Unknown Calculation';
  }
  
  String _getFormattedDate(dynamic calculation) {
    try {
      final date = calculation is WaterCalculation
          ? calculation.dateCalculated
          : calculation is FishCalculation
              ? calculation.dateCalculated
              : calculation is FishVolumeCalculation
                  ? calculation.dateCalculated
                  : (calculation as DietCalculation).dateCalculated;
                  
      return DateFormat('MMM d, y').format(date ?? DateTime.now());
    } catch (e) {
      print('Error formatting date: $e');
      return 'Date unknown';
    }
  }

  Widget _buildFishCompatibilityTab() {
    final logBookProvider = Provider.of<LogBookProvider>(context);
    
    // Load archived data if showing archived and data is empty
    if (_showArchived && logBookProvider.archivedCompatibilityResults.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        logBookProvider.loadArchivedData();
      });
    }

    final compatibilityResults = _showArchived 
      ? List<CompatibilityResult>.from(logBookProvider.archivedCompatibilityResults)
      : List<CompatibilityResult>.from(logBookProvider.savedCompatibilityResults);
    
    compatibilityResults.sort((a, b) => b.dateChecked.compareTo(a.dateChecked));

    if (compatibilityResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _showArchived ? 'No archived compatibility checks' : 'No compatibility results saved yet',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            if (!_showArchived) Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF00BFB3),
                    const Color(0xFF4DD0E1),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00BFB3).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const HomePage(initialTabIndex: 1),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.compare_arrows,
                    color: Colors.white,
                        size: 20,
                  ),
                    ),
                    const SizedBox(width: 12),
                  const Text(
                    'Check Compatibility',
                    style: TextStyle(
                      fontSize: 16,
                        fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
       padding: const EdgeInsets.all(16),
       itemCount: compatibilityResults.length + (_showArchived ? 0 : 1), // +1 for check compatibility button only if not archived
      itemBuilder: (context, index) {
         if (!_showArchived && index == compatibilityResults.length) {
           // Show check compatibility button at the end (only for active items)
           return _buildCheckCompatibilityButton();
         }
         
        final result = compatibilityResults[index];
        return _showArchived 
          ? _buildArchivedCompatibilityCard(result, logBookProvider)
          : Dismissible(
              key: Key(result.id.toString()),
              background: Container(
                color: const Color.fromARGB(255, 255, 17, 0),
                alignment: Alignment.center,
                child: const Text(
                  'Archive',
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
                logBookProvider.archiveCompatibilityResult(result);
            showCustomNotification(context, 'Compatibility result archived');
          },
           child: Container(
             margin: const EdgeInsets.only(bottom: 16),
             child: Material(
               color: Colors.white,
               borderRadius: BorderRadius.circular(6),
            elevation: 2,
            child: InkWell(
              onTap: () {
                _showCompatibilityDetails(context, result);
              },
                 borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                       // Display selected fish images (limit to first 2 for display)
                       Row(
                         children: result.selectedFish.keys.take(2).map((fishName) {
                           return Padding(
                             padding: const EdgeInsets.only(right: 8),
                             child: ClipRRect(
                               borderRadius: BorderRadius.circular(6),
                          child: Image.network(
                                 ApiConfig.getFishImageUrl(fishName),
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            cacheWidth: (60 * MediaQuery.of(context).devicePixelRatio).round(),
                            cacheHeight: (60 * MediaQuery.of(context).devicePixelRatio).round(),
                            filterQuality: FilterQuality.low,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                width: 60,
                                height: 60,
                                color: Colors.grey[200],
                                child: const Center(child: CircularProgressIndicator()),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) => Container(
                              width: 60,
                              height: 60,
                              color: Colors.grey[200],
                              child: const Icon(Icons.image_not_supported_outlined, color: Colors.grey, size: 24),
                            ),
                          ),
                        ),
                           );
                         }).toList(),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                               result.selectedFish.keys.length > 2 
                                 ? '${result.selectedFish.keys.take(2).join(' & ')} +${result.selectedFish.keys.length - 2} more'
                                 : result.selectedFish.keys.join(' & '),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                                 color: result.compatibilityLevel == 'compatible' ? Colors.green[50] : 
                                        result.compatibilityLevel == 'conditional' ? Colors.orange[50] : Colors.red[50],
                                 borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                                 result.compatibilityLevel == 'compatible' ? 'Compatible' : 
                                 result.compatibilityLevel == 'conditional' ? 'Conditional' : 'Not Compatible',
                              style: TextStyle(
                                   color: result.compatibilityLevel == 'compatible' ? Colors.green[700] : 
                                          result.compatibilityLevel == 'conditional' ? Colors.orange[700] : Colors.red[700],
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
          ),
        );
      },
    );
  }

  Widget _buildArchivedCompatibilityCard(CompatibilityResult result, LogBookProvider logBookProvider) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        elevation: 2,
        child: InkWell(
          onTap: () {
            _showCompatibilityDetails(context, result);
          },
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Display selected fish images (limit to first 2 for display)
                Row(
                  children: result.selectedFish.keys.take(2).map((fishName) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.network(
                          ApiConfig.getFishImageUrl(fishName),
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          cacheWidth: (60 * MediaQuery.of(context).devicePixelRatio).round(),
                          cacheHeight: (60 * MediaQuery.of(context).devicePixelRatio).round(),
                          filterQuality: FilterQuality.low,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              width: 60,
                              height: 60,
                              color: Colors.grey[200],
                              child: const Center(child: CircularProgressIndicator()),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) => Container(
                            width: 60,
                            height: 60,
                            color: Colors.grey[200],
                            child: const Icon(Icons.image_not_supported_outlined, color: Colors.grey, size: 24),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              result.selectedFish.keys.join(', '),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.archive,
                                  color: Colors.white,
                                  size: 10,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Archived',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Checked: ${DateFormat('MMM d, y').format(result.dateChecked)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: result.compatibilityLevel == 'compatible' ? Colors.green.withOpacity(0.1) : 
                                       result.compatibilityLevel == 'conditional' ? Colors.orange.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                result.compatibilityLevel.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: result.compatibilityLevel == 'compatible' ? Colors.green[700] : 
                                         result.compatibilityLevel == 'conditional' ? Colors.orange[700] : Colors.red[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                          // Restore button
                          IconButton(
                            onPressed: () async {
                              final shouldRestore = await _showRestoreConfirmationDialogCompatibility(result);
                              if (shouldRestore) {
                                await logBookProvider.restoreCompatibilityResult(result);
                                showCustomNotification(context, 'Compatibility result restored');
                              }
                            },
                            icon: const Icon(
                              Icons.restore,
                              color: Colors.green,
                              size: 20,
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
        ),
      ),
    );
  }

  Future<bool> _showRestoreConfirmationDialogCompatibility(CompatibilityResult result) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.green.withOpacity(0.1),
                      Colors.green.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.restore,
                  color: Colors.green,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  'Restore Compatibility Result',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF006064),
                  ),
                ),
              ),
            ],
          ),
          content: const Text(
            'Are you sure you want to restore this compatibility result?',
            style: TextStyle(
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[600],
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF00BFB3),
                    Color(0xFF4DD0E1),
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Restore',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ) ?? false;
  }

  Future<bool> _showDeleteConfirmationDialogCompatibility(CompatibilityResult result) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.red.withOpacity(0.1),
                      Colors.red.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.archive_outlined,
                  color: Colors.orange,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Archive Compatibility',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 4),
                                Text(
                      'This action cannot be undone',
                                  style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
              ),
            ],
          ),
          content: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                              const Text(
                  'Are you sure you want to archive this compatibility result?',
                                style: TextStyle(
                                  fontSize: 16,
                    color: Color(0xFF374151),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                  ),
                                    child: Row(
                                      children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          color: const Color(0xFF00BFB3).withOpacity(0.1),
                        ),
                        child: const Icon(
                          Icons.compare_arrows,
                          color: Color(0xFF00BFB3),
                                          size: 20,
                                        ),
                      ),
                      const SizedBox(width: 12),
                                                                                 Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              result.selectedFish.keys.length > 2 
                                ? '${result.selectedFish.keys.take(2).join(' & ')} +${result.selectedFish.keys.length - 2} more'
                                : result.selectedFish.keys.join(' & '),
                                             style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              result.compatibilityLevel == 'compatible' ? 'Compatible' : 
                              result.compatibilityLevel == 'conditional' ? 'Conditional' : 'Not Compatible',
                              style: TextStyle(
                                               fontSize: 14,
                                color: result.compatibilityLevel == 'compatible' ? Colors.green[600] : 
                                       result.compatibilityLevel == 'conditional' ? Colors.orange[600] : Colors.red[600],
                                fontWeight: FontWeight.w500,
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
          actions: <Widget>[
            Row(
              children: [
                                      Expanded(
                  child: TextButton(
              onPressed: () => Navigator.of(context).pop(false),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: Colors.grey.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      backgroundColor: Colors.grey.withOpacity(0.05),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6B7280),
                      ),
                        ),
                      ),
                    ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Archive',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    ) ?? false;
  }

  void _showPairAnalysisDetails(BuildContext context, Map<String, dynamic> pair) {
    final fish1 = pair['fish1'] ?? '';
    final fish2 = pair['fish2'] ?? '';
    final compatibility = pair['compatibility'] ?? '';
    final conditions = List<String>.from(pair['conditions'] ?? []);
    
    // Capitalize fish names properly
    final capitalizedFish1 = fish1.isNotEmpty 
        ? '${fish1[0].toUpperCase()}${fish1.substring(1).toLowerCase()}'
        : fish1;
    final capitalizedFish2 = fish2.isNotEmpty 
        ? '${fish2[0].toUpperCase()}${fish2.substring(1).toLowerCase()}'
        : fish2;
    
    showDialog(
      context: context,
      builder: (context) => Dialog.fullscreen(
        backgroundColor: Colors.white,
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.grey.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Color(0xFF006064)),
                    ),
                    Expanded(
                      child: Text(
                        'Pair Analysis: $capitalizedFish1 & $capitalizedFish2',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF006064),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 48), // Balance the close button
                  ],
                ),
              ),
              
              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      
                      // Fish Images Section
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    ApiConfig.getFishImageUrl(fish1),
                                    width: double.infinity,
                                    height: 120,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Container(
                                      width: double.infinity,
                                      height: 120,
                                      color: Colors.grey[200],
                                      child: const Icon(Icons.image_not_supported_outlined, color: Colors.grey, size: 40),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  capitalizedFish1,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: compatibility == 'compatible' ? Colors.green[100] :
                                         compatibility == 'conditional' ? Colors.orange[100] : Colors.red[100],
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Icon(
                                  compatibility == 'compatible' ? Icons.check :
                                  compatibility == 'conditional' ? Icons.warning : Icons.close,
                                  color: compatibility == 'compatible' ? Colors.green[700] :
                                         compatibility == 'conditional' ? Colors.orange[700] : Colors.red[700],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                compatibility.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: compatibility == 'compatible' ? Colors.green[700] :
                                         compatibility == 'conditional' ? Colors.orange[700] : Colors.red[700],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    ApiConfig.getFishImageUrl(fish2),
                                    width: double.infinity,
                                    height: 120,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Container(
                                      width: double.infinity,
                                      height: 120,
                                      color: Colors.grey[200],
                                      child: const Icon(Icons.image_not_supported_outlined, color: Colors.grey, size: 40),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  capitalizedFish2,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Analysis Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.black.withOpacity(0.1)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  compatibility == 'compatible' ? Icons.check_circle :
                                  compatibility == 'conditional' ? Icons.warning : Icons.cancel,
                                  color: compatibility == 'compatible' ? Colors.green :
                                         compatibility == 'conditional' ? Colors.orange : Colors.red,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Analysis',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              compatibility == 'compatible' 
                                  ? 'These fish should get along well based on their water needs, temperament, size, and behavior'
                                  : compatibility == 'conditional'
                                      ? 'These fish can live together, but you\'ll need to create the right environment'
                                      : 'These fish are not compatible and should not be kept together',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black,
                                height: 1.4,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      
                      // Conditions Section (for conditional compatibility)
                      if (compatibility == 'conditional' && conditions.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.black.withOpacity(0.1)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.checklist, color: Colors.black, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Required Conditions',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ...conditions.map((condition) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      margin: const EdgeInsets.only(top: 6),
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: Colors.orange,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        condition,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.black,
                                          height: 1.4,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                
                 // Selected Fish Card
                 CalculationResultWidget(
                   title: 'Selected Fish',
                   subtitle: 'Fish species for compatibility check',
                   icon: Icons.compare_arrows,
                   infoRows: result.selectedFish.entries.map((entry) => 
                     CalculationInfoRow(
                       icon: Icons.compare_arrows,
                       label: '${entry.value}x ${entry.key}',
                       value: '',
                       showEyeIcon: true,
                     ),
                   ).toList(),
                 ),
                const SizedBox(height: 20),
                
                // Compatibility Result Card
                CalculationResultWidget(
                  title: 'Compatibility Result',
                  subtitle: 'Overall compatibility assessment',
                  icon: result.compatibilityLevel == 'compatible' ? Icons.check_circle : 
                        result.compatibilityLevel == 'conditional' ? Icons.warning : Icons.cancel,
                  infoRows: [
                    CalculationInfoRow(
                      icon: result.compatibilityLevel == 'compatible' ? Icons.check_circle : 
                            result.compatibilityLevel == 'conditional' ? Icons.warning : Icons.cancel,
                      label: 'Status',
                      value: result.compatibilityLevel == 'compatible' ? 'Compatible' : 
                             result.compatibilityLevel == 'conditional' ? 'Conditional' : 'Not Compatible',
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                // Analysis Details Card
                if (result.reasons.isNotEmpty) ...[
                  CalculationResultWidget(
                    title: 'Analysis Details',
                    subtitle: 'Compatibility analysis breakdown',
                    icon: Icons.analytics,
                    infoRows: result.reasons.map((reason) => 
                      CalculationInfoRow(
                        icon: result.compatibilityLevel == 'compatible' ? Icons.check_circle_outline :
                              result.compatibilityLevel == 'conditional' ? Icons.warning_amber_outlined : Icons.error_outline,
                        label: reason,
                        value: '',
                      ),
                    ).toList(),
                  ),
                  const SizedBox(height: 20),
                ],
                
                 // Pair Analysis Card
                 if (result.pairAnalysis.isNotEmpty && result.pairAnalysis['pairs'] != null) ...[
                   CalculationResultWidget(
                     title: 'Pair-by-Pair Analysis',
                     subtitle: 'Individual fish pair compatibility',
                     icon: Icons.compare_arrows,
                     infoRows: (result.pairAnalysis['pairs'] as List).map((pair) {
                       final fish1 = pair['fish1'] ?? '';
                       final fish2 = pair['fish2'] ?? '';
                       final compatibility = pair['compatibility'] ?? '';
                       
                       // Capitalize fish names properly
                       final capitalizedFish1 = fish1.isNotEmpty 
                           ? '${fish1[0].toUpperCase()}${fish1.substring(1).toLowerCase()}'
                           : fish1;
                       final capitalizedFish2 = fish2.isNotEmpty 
                           ? '${fish2[0].toUpperCase()}${fish2.substring(1).toLowerCase()}'
                           : fish2;
                       
                       return CalculationInfoRow(
                         icon: compatibility == 'compatible' ? Icons.check_circle :
                               compatibility == 'conditional' ? Icons.warning : Icons.cancel,
                         label: '$capitalizedFish1 & $capitalizedFish2',
                         value: compatibility.toUpperCase(),
                         onTap: () => _showPairAnalysisDetails(context, pair),
                         showArrowIcon: true,
                       );
                     }).toList(),
                   ),
                   const SizedBox(height: 20),
                 ],
              ],
            ),
          ),
        ),
      ),
    );
  }

}
