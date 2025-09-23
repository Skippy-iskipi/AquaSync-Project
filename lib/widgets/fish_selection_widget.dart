import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../config/api_config.dart';
import 'fish_info_dialog.dart';
import 'smart_search_widget.dart';
import '../screens/capture.dart';
import '../widgets/custom_notification.dart';
import 'dart:io';

class FishSelectionWidget extends StatefulWidget {
  final Map<String, int> selectedFish;
  final Function(Map<String, int>) onFishSelectionChanged;
  final List<Map<String, dynamic>> availableFish;
  final VoidCallback? onBack;
  final VoidCallback? onNext;
  final bool canProceed;
  final bool isLastStep;
  final Map<String, dynamic> compatibilityResults;
  final Map<String, String> tankShapeWarnings;
  final Function(Map<String, String>)? onTankShapeWarningsChanged;
  final String? nextButtonText;
  final bool hideButtonsWhenKeyboardVisible;

  const FishSelectionWidget({
    super.key,
    required this.selectedFish,
    required this.onFishSelectionChanged,
    required this.availableFish,
    this.onBack,
    this.onNext,
    this.canProceed = true,
    this.isLastStep = false,
    this.compatibilityResults = const {},
    this.tankShapeWarnings = const {},
    this.onTankShapeWarningsChanged,
    this.nextButtonText,
    this.hideButtonsWhenKeyboardVisible = false,
  });

  @override
  State<FishSelectionWidget> createState() => _FishSelectionWidgetState();
}

class _FishSelectionWidgetState extends State<FishSelectionWidget> {
  List<Map<String, dynamic>> _filteredFish = [];
  File? _capturedImage;
  bool _isCapturing = false;
  
  // Filter state
  Map<String, bool> waterTypeFilters = {'Freshwater': false, 'Saltwater': false};
  Map<String, bool> temperamentFilters = {'Peaceful': false, 'Semi-aggressive': false, 'Aggressive': false};
  Map<String, bool> socialBehaviorFilters = {'Schooling': false, 'Solitary': false, 'Community': false};
  Map<String, bool> dietFilters = {'Omnivore': false, 'Carnivore': false, 'Herbivore': false};
  
  // Draggable container state
  double _containerHeight = 0.08; // Initially only show header (8% of screen height)
  bool _isDragging = false;
  bool _isExpanded = false; // Track if container is expanded

  @override
  void initState() {
    super.initState();
    _filteredFish = widget.availableFish;
  }

  void _onSearchChanged(String query) {
    // This method is called by SmartSearchWidget but we don't need to do anything here
    // because the actual filtering is handled by _onSearchResults
    print('DEBUG FISH SELECTION: Search changed to: "$query"');
    
    // If query is empty, clear the search and show all fish
    if (query.isEmpty) {
      _clearSearch();
    }
  }

  void _onSearchResults(List<Map<String, dynamic>> results) {
    print('DEBUG FISH SELECTION: Received ${results.length} search results');
    setState(() {
      _filteredFish = results;
    });
  }

  void _clearSearch() {
    setState(() {
      _filteredFish = widget.availableFish;
    });
  }

  void _addFish(String fishName) {
    final currentCount = widget.selectedFish[fishName] ?? 0;
    widget.onFishSelectionChanged({
      ...widget.selectedFish,
      fishName: currentCount + 1,
    });
  }

  void _removeFish(String fishName) {
    final currentCount = widget.selectedFish[fishName] ?? 0;
    if (currentCount > 1) {
      widget.onFishSelectionChanged({
        ...widget.selectedFish,
        fishName: currentCount - 1,
      });
    } else {
      final newSelection = Map<String, int>.from(widget.selectedFish);
      newSelection.remove(fishName);
      widget.onFishSelectionChanged(newSelection);
    }
  }

  void _deleteFish(String fishName) {
    final newSelection = Map<String, int>.from(widget.selectedFish);
    newSelection.remove(fishName);
    widget.onFishSelectionChanged(newSelection);
  }

  void _showFishInfoDialog(String fishName) {
    showDialog(
      context: context,
      builder: (context) => FishInfoDialog(fishName: fishName),
    );
  }

  Future<void> _captureImage() async {
    setState(() {
      _isCapturing = true;
    });

    try {
      // Directly navigate to capture screen for fish identification
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const CaptureScreen(isForSelection: true),
        ),
      );

      print('DEBUG: Capture result received: $result');
      if (result != null && result is Map<String, dynamic>) {
        final fishName = result['fishName'] as String?;
        print('DEBUG: Fish name from result: $fishName');
        if (fishName != null && fishName.isNotEmpty) {
          setState(() {
            _capturedImage = result['imageFile'] as File?;
          });
          
          print('DEBUG: Showing captured fish dialog for: $fishName');
          // Show dialog to select the fish
          _showCapturedFishDialog(fishName);
        } else {
          print('DEBUG: Fish name is null or empty');
        }
      } else {
        print('DEBUG: Result is null or not a Map');
      }
    } catch (e) {
      showCustomNotification(
        context,
        'Failed to process image: $e',
        isError: true,
      );
    } finally {
      setState(() {
        _isCapturing = false;
      });
    }
  }


  void _showCapturedFishDialog(String fishName) {
    // Find the fish data from available fish list
    final fishData = widget.availableFish.firstWhere(
      (fish) => fish['common_name'] == fishName,
      orElse: () => <String, dynamic>{},
    );
    
    final scientificName = fishData['scientific_name']?.toString() ?? 'Unknown';
    final maxSize = fishData['max_size']?.toString() ?? 'Unknown';
    final lifespan = fishData['lifespan']?.toString() ?? 'Unknown';
    final waterType = fishData['water_type']?.toString() ?? 'Unknown';
    final temperament = fishData['temperament']?.toString() ?? 'Unknown';
    final socialBehavior = fishData['social_behavior']?.toString() ?? 'Unknown';
    final diet = fishData['diet']?.toString() ?? 'Unknown';
    final phRange = fishData['ph_range']?.toString() ?? 'Unknown';
    final temperatureRange = fishData['temperature_range']?.toString() ?? 'Unknown';
    final minimumTankSize = fishData['minimum_tank_size_(l)'] != null 
        ? '${fishData['minimum_tank_size_(l)'].toString()} L' 
        : (fishData['minimum_tank_size']?.toString() ?? 'Unknown');
    final tankLevel = fishData['tank_level']?.toString() ?? 'Unknown';
    final description = fishData['description']?.toString() ?? 'No description available.';
    final compatibilityNotes = fishData['compatibility_notes']?.toString() ?? 'No compatibility notes available.';

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFF00BCD4)),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              'Fish Identified',
              style: TextStyle(
                color: Color(0xFF00BCD4),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image container with fish name overlay
                Stack(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 350,
                      child: _capturedImage != null
                          ? Image.file(
                              _capturedImage!,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              color: Colors.grey.shade200,
                              child: const Center(
                                child: Icon(
                                  FontAwesomeIcons.fish,
                                  size: 64,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                    ),
                    // Fish name overlay
                    Positioned(
                      bottom: 15,
                      left: 0,
                      right: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.8),
                              Colors.black.withOpacity(0.95),
                            ],
                          ),
                        ),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fishName,
                              style: const TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    offset: Offset(1, 1),
                                    blurRadius: 3,
                                    color: Colors.black54,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              scientificName,
                              style: const TextStyle(
                                fontSize: 22,
                                fontStyle: FontStyle.italic,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    offset: Offset(1, 1),
                                    blurRadius: 3,
                                    color: Colors.black54,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                
                // Floating info card
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  child: Transform.translate(
                    offset: const Offset(0, -30),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildInfoCard('Max Size', maxSize, Icons.straighten),
                          _buildInfoCard('Lifespan', lifespan, Icons.timer),
                          _buildInfoCard('Water Type', waterType, Icons.water),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // About this fish section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Description section
                      const Text(
                        'Description',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00BCD4),
                        ),
                      ),
                      Text(
                        description,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.5,
                          color: Colors.black87,
                        ),
                      ),
                      // Basic Information section
                      ExpansionTile(
                        initiallyExpanded: false,
                        title: const Text(
                          'Basic Information',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF00BCD4),
                          ),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Column(
                              children: [
                                _buildDetailCard('Temperament', temperament, Icons.psychology),
                                _buildDetailCard('Social Behavior', socialBehavior, Icons.group),
                                _buildDetailCard('Compatibility Notes', compatibilityNotes, Icons.info),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      // Habitat Information section
                      ExpansionTile(
                        initiallyExpanded: false,
                        title: const Text(
                          'Habitat Information',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF00BCD4),
                          ),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Column(
                              children: [
                                _buildDetailCard('pH Range', phRange, Icons.science),
                                _buildDetailCard('Minimum Tank Size', minimumTankSize, Icons.water_drop),
                                _buildDetailCard(
                                  'Temperature Range',
                                  temperatureRange.toLowerCase() != 'unknown'
                                      ? '$temperatureRange °C'
                                      : 'Unknown',
                                  Icons.thermostat,
                                ),
                                _buildDetailCard('Tank Level', tankLevel, Icons.layers),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      // Diet Information section
                      ExpansionTile(
                        initiallyExpanded: false,
                        title: const Text(
                          'Diet Information',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF00BCD4),
                          ),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Column(
                              children: [
                                _buildDetailCard('Diet Type', diet, Icons.restaurant),
                                _buildDetailCard('Preferred Foods', fishData['preferred_food']?.toString() ?? 'Unknown', Icons.set_meal),
                                _buildDetailCard('Feeding Frequency', fishData['feeding_frequency']?.toString() ?? 'Unknown', Icons.schedule),
                                _buildDetailCard('Portion Size', fishData['portion_grams'] != null 
                                    ? '${fishData['portion_grams'].toString()}g per feeding' 
                                    : 'Small amounts that can be consumed in 2-3 minutes', Icons.line_weight),
                                _buildDetailCard('Overfeeding Risks', fishData['overfeeding_risks']?.toString() ?? 'Can lead to water quality issues and health problems', Icons.error),
                                _buildDetailCard('Feeding Notes', fishData['feeding_notes']?.toString() ?? 'Follow standard feeding guidelines for this species', Icons.psychology),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      
                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey[400],
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                              ),
                              onPressed: () => Navigator.pop(context),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00BCD4),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                              ),
                              onPressed: () {
                                Navigator.pop(context);
                                _addFish(fishName);
                              },
                              child: const Text(
                                'Select This Fish',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
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

  Widget _buildInfoCard(String label, String value, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: const Color(0xFF00BCD4),
          size: 28,
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF00BCD4),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildDetailCard(String label, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF00BCD4).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
            child: Icon(
              icon,
              color: const Color(0xFF00BCD4),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF00BCD4),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterOptions() {
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
                            backgroundColor: const Color(0xFF00BCD4),
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
    // Start with either search results or all available fish
    List<Map<String, dynamic>> list = _filteredFish.isNotEmpty ? _filteredFish : widget.availableFish;
    
    // Water type
    if (waterTypeFilters.containsValue(true)) {
      list = list.where((fish) {
        final waterType = (fish['water_type'] ?? '').toString();
        return waterTypeFilters[waterType] == true;
      }).toList();
    }
    
    // Temperament
    if (temperamentFilters.containsValue(true)) {
      list = list.where((fish) {
        final temperament = (fish['temperament'] ?? '').toString();
        return temperamentFilters[temperament] == true;
      }).toList();
    }
    
    // Social Behavior
    if (socialBehaviorFilters.containsValue(true)) {
      list = list.where((fish) {
        final socialBehavior = (fish['social_behavior'] ?? '').toString();
        return socialBehaviorFilters[socialBehavior] == true;
      }).toList();
    }
    
    // Diet
    if (dietFilters.containsValue(true)) {
      list = list.where((fish) {
        final diet = (fish['diet'] ?? '').toString();
        return dietFilters[diet] == true;
      }).toList();
    }
    
    return list;
  }

  Widget _buildFishImage(String fishName) {
    if (fishName.isEmpty) {
      return Icon(
        FontAwesomeIcons.fish,
        color: Colors.grey.shade400,
        size: 32,
      );
    }

    final imageUrl = '${ApiConfig.baseUrl}/fish-image/${Uri.encodeComponent(fishName)}';
    
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      cacheWidth: 150,
      cacheHeight: 150,
      filterQuality: FilterQuality.low,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          color: Colors.grey.shade200,
          child: Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFF00BCD4)),
              ),
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: Colors.grey.shade200,
          child: Icon(
            FontAwesomeIcons.fish,
            color: Colors.grey.shade400,
            size: 28,
          ),
        );
      },
    );
  }

  // Dynamic font size calculation based on text length
  double _getDynamicFontSize(String text, double maxSize, double minSize) {
    if (text.length <= 10) {
      return maxSize; // Short text - use maximum size
    } else if (text.length <= 15) {
      return maxSize * 0.9; // Medium text - slightly smaller
    } else if (text.length <= 20) {
      return maxSize * 0.8; // Long text - smaller
    } else if (text.length <= 25) {
      return maxSize * 0.7; // Very long text - much smaller
    } else {
      return minSize; // Extremely long text - minimum size
    }
  }

  Widget _buildFishCard(Map<String, dynamic> fish) {
    final fishName = fish['common_name'] as String? ?? 'Unknown';
    final scientificName = fish['scientific_name'] as String? ?? 'Unknown';
    final isSelected = widget.selectedFish.containsKey(fishName);

    return Card(
      elevation: isSelected ? 3 : 2,
      color: Colors.white,
      margin: EdgeInsets.zero, // Remove card margin
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide(
          color: isSelected ? const Color(0xFF00BCD4) : Colors.grey.shade300,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () => _showFishInfoDialog(fishName),
        borderRadius: BorderRadius.zero,
        child: Container(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Fish Image - Takes up most of the space
              Expanded(
                flex: 3,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.zero,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.zero,
                    child: _buildFishImage(fishName),
                  ),
                ),
              ),

              // Fish Name and Scientific Name - Combined section
              Expanded(
                flex: 1,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Fish Name with dynamic font size
                    Text(
                      fishName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: _getDynamicFontSize(fishName, 14, 10),
                        color: isSelected ? const Color(0xFF00BCD4) : Colors.grey.shade800,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.clip,
                    ),
                    
                    const SizedBox(height: 2),
                    
                    // Scientific Name with dynamic font size
                    Text(
                      scientificName,
                      style: TextStyle(
                        fontSize: _getDynamicFontSize(scientificName, 12, 8),
                        fontStyle: FontStyle.italic,
                        color: Colors.grey.shade600,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 4),
              
              // Select/Unselect Button
              Expanded(
                flex: 1,
                child: ElevatedButton(
                  onPressed: () => isSelected ? _removeFish(fishName) : _addFish(fishName),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isSelected ? Colors.red : const Color(0xFF00BCD4),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    elevation: isSelected ? 2 : 1,
                  ),
                  child: Text(
                    isSelected ? 'Unselect' : 'Select',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedFishMiniTab(bool isKeyboardVisible) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      constraints: isKeyboardVisible 
          ? BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.2) // Limit height when keyboard is visible
          : null,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Selected Fish Section (only show if there are selected fish)
          if (widget.selectedFish.isNotEmpty) ...[
            // Header with drag handle - This is the draggable area
            GestureDetector(
              onTap: () {
                setState(() {
                  if (_isExpanded) {
                    _containerHeight = 0.08; // Collapse to header only
                    _isExpanded = false;
                  } else {
                    _containerHeight = 0.2; // Expand to show content (reduced from 0.25)
                    _isExpanded = true;
                  }
                });
              },
              onPanStart: (details) {
                setState(() {
                  _isDragging = true;
                });
              },
              onPanUpdate: (details) {
                if (_isDragging) {
                  final screenHeight = MediaQuery.of(context).size.height;
                  final deltaY = details.delta.dy;
                  final newHeight = _containerHeight - (deltaY / screenHeight);
                  
                  setState(() {
                    _containerHeight = newHeight.clamp(0.08, 0.4); // Min 8% (header only), Max 40% of screen height
                    _isExpanded = _containerHeight > 0.12; // Consider expanded if more than header
                  });
                }
              },
              onPanEnd: (details) {
                setState(() {
                  _isDragging = false;
                });
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _isDragging ? const Color(0xFF0097A7) : const Color(0xFF00BCD4),
                  borderRadius: _isExpanded 
                      ? const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        )
                      : BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    // Drag handle
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: _isDragging ? Colors.white : Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(FontAwesomeIcons.fish, color: Colors.white, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Selected Fish',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${widget.selectedFish.values.fold<int>(0, (sum, v) => sum + v)} total',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 8),
                        AnimatedRotation(
                          turns: _isExpanded ? 0.5 : 0.0,
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            Icons.keyboard_arrow_down,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            // Selected Fish List - Only show if expanded
            if (_isExpanded) ...[
              AnimatedContainer(
                duration: _isDragging ? Duration.zero : const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                height: (MediaQuery.of(context).size.height * _containerHeight - 60).clamp(100.0, 300.0), // Reduced max height to prevent overflow
                decoration: BoxDecoration(
                  color: _isDragging ? Colors.grey.shade50 : Colors.white,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Selected Fish Items
                      ...widget.selectedFish.entries.map((entry) {
                        final fishName = entry.key;
                        final quantity = entry.value;
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            children: [
                            // Fish Image (small) - Clickable
                            GestureDetector(
                              onTap: () => _showFishInfoDialog(fishName),
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 2,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: _buildFishImage(fishName),
                                ),
                              ),
                            ),
                              
                              const SizedBox(width: 12),
                              
                              // Fish Name
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      fishName,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        color: Colors.grey.shade800,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      'qty',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              
                            // Quantity Controls
                            Row(
                              children: [
                                // Minus Button
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: IconButton(
                                    onPressed: () => _removeFish(fishName),
                                    icon: Icon(
                                      Icons.remove,
                                      color: Colors.grey.shade700,
                                      size: 14,
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ),
                                
                                const SizedBox(width: 8),
                                
                                // Quantity Display
                                Container(
                                  width: 32,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: Center(
                                    child: Text(
                                      quantity.toString(),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                        color: Colors.grey.shade800,
                                      ),
                                    ),
                                  ),
                                ),
                                
                                const SizedBox(width: 8),
                                
                                // Plus Button
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: IconButton(
                                    onPressed: () => _addFish(fishName),
                                    icon: Icon(
                                      Icons.add,
                                      color: Colors.grey.shade700,
                                      size: 14,
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ),
                                
                                const SizedBox(width: 8),
                                
                                // Delete Button
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: IconButton(
                                    onPressed: () => _deleteFish(fishName),
                                    icon: Icon(
                                      Icons.delete_outline,
                                      color: Colors.grey.shade600,
                                      size: 14,
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ),
                              ],
                            ),
                            ],
                          ),
                        );
                      }).toList(),
                      
                      // Compatibility Results inside the selected fish container
                      if (widget.compatibilityResults.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _buildCompatibilityResults(),
                      ],
                      
                      // Tank Shape Warnings - Below compatibility results
                      if (widget.tankShapeWarnings.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _buildTankShapeWarningsWidget(),
                      ],
                      
                      // Navigation Buttons - Inside the expanded content (hide when keyboard is visible if specified)
                      if (!(widget.hideButtonsWhenKeyboardVisible && isKeyboardVisible)) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            // Back Button
                            if (widget.onBack != null) ...[
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: widget.onBack,
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
                              const SizedBox(width: 16),
                            ],
                            
                            // Next/Save Button
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: widget.canProceed ? widget.onNext : null,
                                icon: Icon(widget.isLastStep ? Icons.save : Icons.arrow_forward),
                                label: Text(widget.nextButtonText ?? (widget.isLastStep ? 'Save Tank' : 'Next')),
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
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ],
          
          // Navigation Buttons Section - Only show when no fish selected or collapsed (and not hiding buttons when keyboard is visible)
          if ((widget.selectedFish.isEmpty || !_isExpanded) && !(widget.hideButtonsWhenKeyboardVisible && isKeyboardVisible)) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  // Back Button
                  if (widget.onBack != null) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: widget.onBack,
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
                    const SizedBox(width: 16),
                  ],
                  
                  // Next/Save Button
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: widget.canProceed ? widget.onNext : null,
                      icon: Icon(widget.isLastStep ? Icons.save : Icons.arrow_forward),
                      label: Text(widget.nextButtonText ?? (widget.isLastStep ? 'Save Tank' : 'Next')),
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
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompatibilityResults() {
    if (widget.compatibilityResults.isEmpty) return const SizedBox.shrink();

    // Handle loading state
    if (widget.compatibilityResults['loading'] == true) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.shade300),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade700),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Checking compatibility...',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade700,
              ),
            ),
          ],
        ),
      );
    }

    final hasIncompatible = widget.compatibilityResults['has_incompatible_pairs'] == true;
    final hasConditional = widget.compatibilityResults['has_conditional_pairs'] == true;
    
    // Safe type casting with proper null checking
    List<Map<String, dynamic>> incompatiblePairs = [];
    List<Map<String, dynamic>> conditionalPairs = [];
    
    try {
      final incompatibleData = widget.compatibilityResults['incompatible_pairs'];
      if (incompatibleData is List) {
        incompatiblePairs = incompatibleData.cast<Map<String, dynamic>>();
      }
      
      final conditionalData = widget.compatibilityResults['conditional_pairs'];
      if (conditionalData is List) {
        conditionalPairs = conditionalData.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      print('Error parsing compatibility results: $e');
    }

    if (!hasIncompatible && !hasConditional) {
      // All fish are compatible
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green.shade300),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade700, size: 18),
            const SizedBox(width: 8),
            Text(
              'All selected fish are compatible!',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade700,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasIncompatible ? Colors.red.shade300 : Colors.orange.shade300,
        ),
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
              Icon(
                hasIncompatible ? Icons.warning : Icons.info_outline,
                color: hasIncompatible ? Colors.red : Colors.orange,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                hasIncompatible ? 'Compatibility Issues Found' : 'Compatibility Conditions',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: hasIncompatible ? Colors.red : Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Incompatible pairs
          if (incompatiblePairs.isNotEmpty) ...[
            Text(
              'Incompatible Fish:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.red.shade700,
              ),
            ),
            const SizedBox(height: 6),
            ...incompatiblePairs.map((pair) => Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${pair['pair'][0]} + ${pair['pair'][1]}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.red.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...(pair['reasons'] as List).map((reason) => Text(
                    '• $reason',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.red.shade600,
                    ),
                  )).toList(),
                ],
              ),
            )).toList(),
          ],
          
          // Conditional pairs
          if (conditionalPairs.isNotEmpty) ...[
            if (incompatiblePairs.isNotEmpty) const SizedBox(height: 12),
            Text(
              'Compatible with Conditions:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.orange.shade700,
              ),
            ),
            const SizedBox(height: 6),
            ...conditionalPairs.map((pair) => Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${pair['pair'][0]} + ${pair['pair'][1]}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...(pair['reasons'] as List).map((reason) => Text(
                    '• $reason',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.orange.shade600,
                    ),
                  )).toList(),
                ],
              ),
            )).toList(),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Check if keyboard is visible
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardVisible = keyboardHeight > 0;
    
    return isKeyboardVisible 
        ? SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(),
                const SizedBox(height: 16),
                _buildSearchResults(),
                const SizedBox(height: 16),
                _buildSelectedFishMiniTab(isKeyboardVisible),
              ],
            ),
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              _buildFishGrid(),
              _buildSelectedFishMiniTab(isKeyboardVisible),
      ],
    );
  }

  // Build header section
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Smart search widget (without capture button inside)
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey.shade300),
                color: Colors.transparent,
              ),
              child: SmartSearchWidget(
                onSearchChanged: _onSearchChanged,
                onSearchResults: _onSearchResults,
                hintText: 'Search Fish...',
                showAutocomplete: true,
                availableFish: widget.availableFish,
                selectedFish: widget.selectedFish,
                onFishSelected: _addFish,
              ),
            ),
          ),
          
          // Capture button (outside search container)
          const SizedBox(width: 6),
          GestureDetector(
            onTap: _captureImage,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF00BCD4),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: _isCapturing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 20,
                    ),
            ),
          ),
          
          // Filter button
          GestureDetector(
            onTap: _showFilterOptions,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.filter_alt_outlined,
                color: Color(0xFF00BCD4),
                size: 26,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Build fish grid section
  Widget _buildFishGrid() {
    return Expanded(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final filteredList = _filteredFishListWithFilters;
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: filteredList.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          FontAwesomeIcons.fish,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Loading Fish Data...',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: constraints.maxWidth > 600 ? 3 : 2, // Responsive columns
                      childAspectRatio: constraints.maxWidth > 600 ? 0.6 : 0.7, // Fixed height of ~200px
                      crossAxisSpacing: 4,
                      mainAxisSpacing: 4,
                    ),
                    itemCount: filteredList.length,
                    itemBuilder: (context, index) {
                      return _buildFishCard(filteredList[index]);
                    },
                  ),
          );
        },
      ),
    );
  }

  // Build search results section
  Widget _buildSearchResults() {
    if (_filteredFish.isEmpty) return const SizedBox.shrink();
    
    return Container(
      height: 120, // Fixed height to prevent overflow
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ListView.builder(
        itemCount: _filteredFish.length,
        itemBuilder: (context, index) {
          final fish = _filteredFish[index];
          final fishName = fish['common_name'] as String? ?? 'Unknown';
          final scientificName = fish['scientific_name'] as String? ?? 'Unknown';
          final isSelected = widget.selectedFish.containsKey(fishName);
          
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _buildFishImage(fishName),
                ),
              ),
              title: Text(
                fishName,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isSelected ? const Color(0xFF00BCD4) : Colors.black87,
                ),
              ),
              subtitle: Text(
                scientificName,
                style: const TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
              ),
              trailing: ElevatedButton(
                onPressed: () => isSelected ? _removeFish(fishName) : _addFish(fishName),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSelected ? Colors.red : const Color(0xFF00BCD4),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: Text(
                  isSelected ? 'Unselect' : 'Select',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              onTap: () => _showFishInfoDialog(fishName),
            ),
          );
        },
      ),
    );
  }

  // Build tank shape warnings widget
  Widget _buildTankShapeWarningsWidget() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          childrenPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          collapsedIconColor: const Color(0xFF00BCD4),
          iconColor: const Color(0xFF00BCD4),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFE0F7FA),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.info_outline,
              color: Color(0xFF00BCD4),
              size: 20,
            ),
          ),
          title: const Text(
            'Tank Size Notice',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Color(0xFF006064),
            ),
          ),
          subtitle: const Text(
            'Some fish may need a bigger tank',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: widget.tankShapeWarnings.entries.map((entry) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: Colors.grey.shade200,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.warning,
                          color: Colors.orange,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.key,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _getSimpleWarningMessage(entry.key, entry.value),
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade700,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // Convert technical warning messages to simple, user-friendly language
  String _getSimpleWarningMessage(String fishName, String technicalMessage) {
    if (technicalMessage.contains('too large for a bowl tank')) {
      return 'This fish grows too big for a small bowl tank. Try a rectangle tank instead.';
    } else if (technicalMessage.contains('needs more horizontal swimming space')) {
      return 'This fish needs more swimming space. A rectangle tank would be better.';
    } else if (technicalMessage.contains('Requires larger tank')) {
      return 'This fish needs a bigger tank. Consider a rectangle tank.';
    } else if (technicalMessage.contains('not suitable for')) {
      return 'This fish needs a different tank shape. Try a rectangle tank.';
    } else {
      return 'This fish may not be suitable for your selected tank. Consider a rectangle tank.';
    }
  }
}
