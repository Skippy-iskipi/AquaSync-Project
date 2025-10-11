import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
// Removed lottie import
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../models/fish_prediction.dart';
import '../models/compatibility_result.dart';
import '../config/api_config.dart';
import '../widgets/custom_notification.dart';
import '../widgets/snap_tips_dialog.dart';
// Removed expandable_reason import
// Removed OpenAI service import
import '../widgets/description_widget.dart';
import '../widgets/fish_images_grid.dart';
import '../widgets/fish_info_dialog.dart';
import '../screens/logbook_provider.dart';
import '../widgets/auth_required_dialog.dart';
import '../widgets/fish_selection_widget.dart';

// Removed enhanced_tankmate_service import

// Widget for displaying grouped recommendation fields in an ExpansionTile
class _RecommendationExpansionGroup extends StatefulWidget {
  final List<Map<String, dynamic>> fields;
  final Map<String, dynamic> data;

  const _RecommendationExpansionGroup({
    required this.fields,
    required this.data,
  });

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
                  Icon(field['icon'] as IconData, color: const Color(0xFF006064), size: 22),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          field['label'],
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF006064),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          value.toString(),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                            height: 1.4,
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
}



class SyncScreen extends StatefulWidget {
  final String? initialFish;
  final File? initialFishImage;

  const SyncScreen({
    super.key, 
    this.initialFish,
    this.initialFishImage,
  });

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  List<String> _fishSpecies = [];
  List<Map<String, dynamic>> _availableFish = []; // Add actual fish data
  Map<String, int> _selectedFish = {}; // Changed to support multiple fish
  bool _isLoading = false;
  Map<String, String> _pairCompatibilityResults = {}; // Store individual pair results
  List<Map<String, dynamic>> _storedCompatibilityResults = []; // Store detailed API compatibility results
  bool _showAllPairs = false; // Track if all pairs are shown
  bool _showAllTankmateFish = false; // Track if all tankmate fish cards are shown
  bool _isSuggestionsExpanded = false; // Track if suggestions section is expanded
  // Confidence threshold for accepting predictions (50%)
  static const double _confidenceThreshold = 0.7;
  // Removed image cache - no longer needed
  // Controllers and suggestions are no longer needed
  // final TextEditingController _controller1 = TextEditingController();
  // final TextEditingController _controller2 = TextEditingController();
  // List<String> _suggestions1 = [];
  // List<String> _suggestions2 = [];
  CameraController? _cameraController;
  Future<void>? _initializeControllerFuture;
  bool _isCameraInitialized = false;
  String _fish1Name = '';
  String _fish2Name = '';
  String _fish1ImagePath = '';
  String _fish2ImagePath = '';
  File? _capturedImage1;
  File? _capturedImage2;
  


  @override
  void initState() {
    super.initState();
    // Try to connect to server and load data
    _checkServerAndLoadData();
    
    if (widget.initialFish != null) {
      setState(() {
        _selectedFish[widget.initialFish!] = 1;
        _fish1Name = widget.initialFish!;
      });
    }

    if (widget.initialFishImage != null) {
      setState(() {
        _capturedImage1 = widget.initialFishImage;
        _fish1ImagePath = widget.initialFishImage!.path;
      });
    }
  }



  // Removed AI Requirements Section - no longer needed

  // Removed _buildLoadingState - no longer needed

  // _buildErrorState removed (no longer used)



  // Removed fallback analysis - no longer needed

  // Removed AI analysis content - no longer needed

  Future<Map<String, Map<String, dynamic>>> _loadTankmateRecommendationsForAllFish(List<String> fishNames) async {
    try {
      final supabase = Supabase.instance.client;
      Map<String, Map<String, dynamic>> recommendations = {};
      
      // Load recommendations for each fish
      for (String fishName in fishNames) {
        try {
          final response = await supabase
            .from('fish_tankmate_recommendations')
            .select('fully_compatible_tankmates, conditional_tankmates, special_requirements, care_level, confidence_score')
              .ilike('fish_name', fishName)
            .maybeSingle();
        
          if (response != null) {
          List<String> fullyCompatible = [];
          List<Map<String, dynamic>> conditional = [];
          
          // Add fully compatible tankmates
            if (response['fully_compatible_tankmates'] != null) {
              fullyCompatible.addAll(List<String>.from(response['fully_compatible_tankmates']));
          }
          
          // Add conditional tankmates (preserve full objects with conditions)
            if (response['conditional_tankmates'] != null) {
              List<dynamic> conditionalData = response['conditional_tankmates'];
            for (var item in conditionalData) {
              if (item is Map<String, dynamic> && item['name'] != null) {
                conditional.add(item);
              } else if (item is String) {
                // Convert string to object format for consistency
                conditional.add({
                  'name': item,
                  'conditions': ['Compatibility requires specific conditions'],
                });
              }
            }
          }
          
            // Remove other selected fish from recommendations
            fullyCompatible.removeWhere((tankmate) => fishNames.contains(tankmate));
            conditional.removeWhere((item) => fishNames.contains(item['name']));
          
          // Sort and limit
          fullyCompatible.sort();
          conditional.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
          
            recommendations[fishName] = {
            'fully_compatible': fullyCompatible.take(6).toList(),
            'conditional': conditional.take(6).toList(),
              'special_requirements': List<String>.from(response['special_requirements'] ?? []),
              'care_level': response['care_level'] ?? 'Intermediate',
              'confidence_score': (response['confidence_score'] ?? 0.0).toDouble(),
            };
          }
        } catch (e) {
          print('Warning: Could not get recommendations for $fishName: $e');
          // Add empty recommendations for this fish
          recommendations[fishName] = {
            'fully_compatible': <String>[],
            'conditional': <Map<String, dynamic>>[],
            'special_requirements': <String>[],
            'care_level': 'Unknown',
            'confidence_score': 0.0,
          };
        }
      }
      
      return recommendations;
      
    } catch (e) {
      print('Error loading tankmate recommendations from Supabase: $e');
      return {};
    }
  }


  @override
  void dispose() {
    // _controller1.dispose(); // No longer needed
    // _controller2.dispose(); // No longer needed
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _checkServerAndLoadData() async {
    if (!mounted) return;
    
    // Check server connection first
    final isConnected = await ApiConfig.checkServerConnection();
    
    if (isConnected && mounted) {
      // If connected, load fish species and fish data in parallel
      await Future.wait([
        _loadFishSpecies(),
        _loadFishData(),
      ]);
    } else if (mounted) {
      // If not connected, show error message
      showCustomNotification(
        context,
        'Unable to connect to server. Please check your network connection.',
        isError: true,
      );
    }
  }

  // Get unique fish names from saved predictions for suggestions
  List<String> _getSuggestedFishNames() {
    try {
      final logBookProvider = Provider.of<LogBookProvider>(context, listen: false);
      final savedPredictions = logBookProvider.savedPredictions;
      
      // Get unique fish names from saved predictions
      final uniqueFishNames = <String>{};
      for (final prediction in savedPredictions) {
        if (prediction.commonName.isNotEmpty) {
          uniqueFishNames.add(prediction.commonName);
        }
      }
      
      return uniqueFishNames.toList()..sort();
    } catch (e) {
      print('Error getting suggested fish names: $e');
      return [];
    }
  }

  // Build suggestion section widget
  Widget _buildSuggestionSection() {
    return Consumer<LogBookProvider>(
      builder: (context, logBookProvider, child) {
        final suggestedFish = _getSuggestedFishNames();
        
        if (suggestedFish.isEmpty) {
          return const SizedBox.shrink();
        }
    
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey[200]!),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Collapsible header
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isSuggestionsExpanded = !_isSuggestionsExpanded;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), // Reduced vertical padding
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6), // Reduced padding
                        decoration: BoxDecoration(
                          color: const Color(0xFF00BCD4).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6), // Reduced border radius
                        ),
                        child: const Icon(
                          Icons.history,
                          color: Color(0xFF00BCD4),
                          size: 16, // Reduced icon size
                        ),
                      ),
                      const SizedBox(width: 10), // Reduced spacing
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min, // Added to minimize height
                          children: [
                            const Text(
                              'Saved Fish Suggestions',
                              style: TextStyle(
                                fontSize: 14, // Reduced font size
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF006064),
                              ),
                            ),
                            Text(
                              '${suggestedFish.length} fish from your collection',
                              style: TextStyle(
                                fontSize: 11, // Reduced font size
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      AnimatedRotation(
                        turns: _isSuggestionsExpanded ? 0.5 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.keyboard_arrow_down,
                          color: Colors.grey[600],
                          size: 20, // Reduced icon size
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Collapsible content
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                height: _isSuggestionsExpanded ? null : 0,
                child: _isSuggestionsExpanded
                    ? Container(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Fish chips with better spacing - aligned to left
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Wrap(
                                alignment: WrapAlignment.start, // Align to start/left
                                spacing: 10,
                                runSpacing: 10,
                                children: suggestedFish.take(8).map((fishName) {
                                  final isSelected = _selectedFish.containsKey(fishName);
                                  return GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        if (isSelected) {
                                          _selectedFish.remove(fishName);
                                        } else {
                                          _selectedFish[fishName] = 1;
                                        }
                                      });
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: isSelected 
                                            ? const Color(0xFF00BCD4)
                                            : Colors.grey[50],
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: isSelected 
                                              ? const Color(0xFF00BCD4)
                                              : Colors.grey[300]!,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            fishName,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: isSelected 
                                                  ? Colors.white
                                                  : Colors.black87,
                                            ),
                                          ),
                                          if (isSelected) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.all(2),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.check,
                                                size: 12,
                                                color: Color(0xFF00BCD4),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            
                            // Show more indicator if needed
                            if (suggestedFish.length > 8) ...[
                              const SizedBox(height: 12),
                              Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: Text(
                                    '+${suggestedFish.length - 8} more available',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      )
                    : null,
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _loadFishSpecies() async {
    if (!mounted) return;

    try {
      // Use the new failover method for more reliable API access
      final response = await ApiConfig.makeRequestWithFailover(
        endpoint: '/fish-species',
        method: 'GET',
      );
      
      if (response != null && mounted) {
        final List<dynamic> species = jsonDecode(response.body);
        setState(() {
          _fishSpecies = species.map((s) => s.toString()).toList();
        });
      } else if (mounted) {
        print('Error loading fish species: No servers available');
        showCustomNotification(
          context,
          'Unable to connect to server. Please check your network connection.',
          isError: true,
        );
      }
    } catch (e) {
      print('Error loading fish species: $e');
      if (mounted) {
        showCustomNotification(
          context,
          'Error loading fish species: ${e.toString()}',
          isError: true,
        );
      }
    }
  }

  Future<void> _loadFishData() async {
    if (!mounted) return;

    try {
      // Use the new failover method for more reliable API access
      final response = await ApiConfig.makeRequestWithFailover(
        endpoint: '/fish-list',
        method: 'GET',
      );
      
      if (response != null && mounted) {
        final List<dynamic> fishList = jsonDecode(response.body);
        setState(() {
          _availableFish = fishList.cast<Map<String, dynamic>>();
          // Sort by common name
          _availableFish.sort((a, b) => (a['common_name'] as String).compareTo(b['common_name'] as String));
        });
      } else if (mounted) {
        print('Error loading fish data: No servers available');
        showCustomNotification(
          context,
          'Unable to connect to server. Please check your network connection.',
          isError: true,
        );
      }
    } catch (e) {
      print('Error loading fish data: $e');
      if (mounted) {
        showCustomNotification(
          context,
          'Error loading fish data: ${e.toString()}',
          isError: true,
        );
      }
    }
  }

  // _updateSuggestions is no longer needed as dropdown handles filtering
  /*
  void _updateSuggestions(String query, bool isFirstField) {
    if (query.isEmpty) {
      setState(() {
        if (isFirstField) {
          _suggestions1 = [];
        } else {
          _suggestions2 = [];
        }
      });
      return;
    }

    final suggestions = _fishSpecies
        .where((species) => species.toLowerCase().contains(query.toLowerCase()))
        .toList();

    setState(() {
      if (isFirstField) {
        _suggestions1 = suggestions;
      } else {
        _suggestions2 = suggestions;
      }
    });
  }
  */

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _isCameraInitialized = false;
        });
        return;
      }

      _cameraController?.dispose();

      _cameraController = CameraController(
        cameras.first,
        ResolutionPreset.high,
        enableAudio: false,
      );

      _initializeControllerFuture = _cameraController?.initialize();
      
      await _initializeControllerFuture;  // Wait for initialization

      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      print('Camera initialization error: $e');
      if (mounted) {
        setState(() {
          _isCameraInitialized = false;
        });
        showCustomNotification(
          context,
          'Camera not available: $e',
          isError: true,
        );
      }
    }
  }

  String get apiUrl => ApiConfig.predictEndpoint;

  Future<void> _showCameraPreview(bool isFirstFish) async {
    if (!_isCameraInitialized) {
      await _initializeCamera();
    }

    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (BuildContext context) {
          if (!_isCameraInitialized || _cameraController == null) {
            return const Center(
              child: Text(
                'Camera is not available.\nPlease use the gallery picker instead.',
                textAlign: TextAlign.center,
              ),
            );
          }

          return FutureBuilder<void>(
            future: _initializeControllerFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                final size = MediaQuery.of(context).size;
                final scale = 1 / (_cameraController!.value.aspectRatio * size.aspectRatio);

                return Scaffold(
                  backgroundColor: Colors.black,
                  appBar: AppBar(
                    backgroundColor: const Color.fromARGB(255, 221, 233, 235),
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back),
                      color: const Color(0xFF006064),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    title: const Text('Fish Identifier', style: TextStyle(color: Color(0xFF006064))),
                  ),
                  body: Stack(
                    fit: StackFit.expand,
                    children: [
                      Transform.scale(
                        scale: scale,
                        child: Center(
                          child: CameraPreview(_cameraController!),
                        ),
                      ),
                      Center(
                        child: Container(
                          width: size.width * 0.8,
                          height: size.width * 0.8,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.teal, width: 2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                      Positioned(
                        top: size.height * 0.3,
                        left: 0,
                        right: 0,
                        child: const Center(
                          child: Text(
                            "Ensure the fish is in focus",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      if (_isLoading)
                        Container(
                          color: Colors.black54,
                          child: const Center(
                            child: CircularProgressIndicator(color: Colors.teal),
                          ),
                        ),
                    ],
                  ),
                  bottomNavigationBar: BottomAppBar(
                    color: Colors.grey[200],
                    height: 100,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.photo_library, color: Colors.teal),
                              onPressed: () async {
                                final ImagePicker picker = ImagePicker();
                                try {
                                  final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                                  if (image != null) {
                                    final result = await _getPredictions(image, isFirstFish);
                                    if (result) {
                                      Navigator.of(context).pop();
                                    }
                                  }
                                } catch (e) {
                                  print('Gallery image error: $e');
                                  showCustomNotification(
                                    context,
                                    'Error processing image: $e',
                                    isError: true,
                                  );
                                }
                              },
                              tooltip: 'Photos',
                            ),
                            const Text(
                              'Gallery',
                              style: TextStyle(
                                color: Colors.teal,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        GestureDetector(
                          onTap: () async {
                            try {
                              final image = await _cameraController!.takePicture();
                              if (mounted) {
                                Navigator.of(context).pop(); // Close camera preview first
                                final result = await _getPredictions(image, isFirstFish);
                                if (!result) {
                                  if (mounted) {
                                    _showCameraPreview(isFirstFish);
                                  }
                                }
                              }
                            } catch (e) {
                              print('Error taking picture: $e');
                              showCustomNotification(
                                context,
                                'Error taking picture: $e',
                                isError: true,
                              );
                            }
                          },
                          child: const CircleAvatar(
                            radius: 30,
                            backgroundColor: Colors.teal,
                            child: Icon(
                              Icons.camera,
                              color: Colors.white,
                              size: 35,
                            ),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.help, color: Colors.teal),
                              onPressed: () {
                                _showSnapTips();
                              },
                              tooltip: 'Photo Tips',
                            ),
                            const Text(
                              'Tips',
                              style: TextStyle(
                                color: Colors.teal,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              } else {
                return const Center(child: CircularProgressIndicator());
              }
            },
          );
        },
      ),
    );
  }

  Future<bool> _getPredictions(XFile imageFile, bool isFirstFish) async {
    setState(() {
      _isLoading = true;
    });

    // Show full-screen loading dialog with enhanced scanning animation
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        useRootNavigator: true,
        builder: (context) => Dialog.fullscreen(
          backgroundColor: const Color(0xFF006064),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF006064),
                  Color(0xFF00ACC1),
                  Color(0xFF006064),
                ],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // Header with close button
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Fish Identification',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Main scanning area
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Image container with scanning overlay
                          Container(
                            width: MediaQuery.of(context).size.width * 0.8,
                            height: MediaQuery.of(context).size.width * 0.8,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Stack(
                              children: [
                                // Fish image
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.file(
                                    io.File(imageFile.path),
                                    width: double.infinity,
                                    height: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                
                                // Scanning overlay
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(6),
                                    color: Colors.black.withOpacity(0.4),
                                  ),
                                ),
                                
                                // Corner scanning indicators
                                Positioned(
                                  top: 20,
                                  left: 20,
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      border: Border(
                                        top: BorderSide(color: Colors.teal, width: 3),
                                        left: BorderSide(color: Colors.teal, width: 3),
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 20,
                                  right: 20,
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      border: Border(
                                        top: BorderSide(color: Colors.teal, width: 3),
                                        right: BorderSide(color: Colors.teal, width: 3),
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 20,
                                  left: 20,
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(color: Colors.teal, width: 3),
                                        left: BorderSide(color: Colors.teal, width: 3),
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 20,
                                  right: 20,
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(color: Colors.teal, width: 3),
                                        right: BorderSide(color: Colors.teal, width: 3),
                                      ),
                                    ),
                                  ),
                                ),
                                
                                // Simple horizontal scanning lines
                                ...List.generate(5, (i) => 
                                  TweenAnimationBuilder<double>(
                                    tween: Tween<double>(
                                      begin: -MediaQuery.of(context).size.width * 0.8 - (i * 40),
                                      end: MediaQuery.of(context).size.width * 0.8 + 50,
                                    ),
                                    duration: Duration(seconds: 2 + (i * 1)),
                                    curve: Curves.easeInOut,
                                    builder: (context, double value, child) {
                                      return Positioned(
                                        top: value,
                                        child: Container(
                                          width: MediaQuery.of(context).size.width * 0.8,
                                          height: 2,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                Colors.transparent,
                                                Colors.teal.withOpacity(0.3),
                                                Colors.teal.withOpacity(0.8),
                                                Colors.teal.withOpacity(1),
                                                Colors.teal.withOpacity(0.8),
                                                Colors.teal.withOpacity(0.3),
                                                Colors.transparent,
                                              ],
                                              stops: const [0.0, 0.2, 0.4, 0.5, 0.6, 0.8, 1.0],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                    onEnd: () {
                                      if (mounted) {
                                        setState(() {});
                                      }
                                    },
                                  ),
                                ),
                                
                                // Pulsing center dot
                                Center(
                                  child: TweenAnimationBuilder<double>(
                                    tween: Tween<double>(begin: 0.8, end: 1.2),
                                    duration: const Duration(seconds: 2),
                                    curve: Curves.easeInOut,
                                    builder: (context, double value, child) {
                                      return Transform.scale(
                                        scale: value,
                                        child: Container(
                                          width: 20,
                                          height: 20,
                                          decoration: BoxDecoration(
                                            color: Colors.teal,
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.teal.withOpacity(0.6),
                                                blurRadius: 20,
                                                spreadRadius: 5,
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                    onEnd: () {
                                      if (mounted) {
                                        setState(() {});
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 40),
                          
                          // Status text
                          const Text(
                            'Analyzing Fish Species',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          Text(
                            'Please wait while we identify your fish...',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 16,
                            ),
                          ),
                          
                          const SizedBox(height: 40),
                          
                          // Progress indicator
                          SizedBox(
                            width: 200,
                            child: LinearProgressIndicator(
                              backgroundColor: Colors.white.withOpacity(0.3),
                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.teal),
                              minHeight: 6,
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
        ),
      );
    }

    // Add a minimum delay of 3 seconds for the scanning animation
    await Future.delayed(const Duration(seconds: 3));

    try {
      var uri = Uri.parse(apiUrl);
      print('Sending request to: $uri');
      var request = http.MultipartRequest('POST', uri);
      
      print('Image path: ${imageFile.path}');
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          imageFile.path,
          filename: 'image.jpg',
        ),
      );

      print('Sending request...');
      var response = await request.send();
      print('Response status code: ${response.statusCode}');
      var responseData = await response.stream.bytesToString();
      print('Response data: $responseData');

      if (response.statusCode == 200) {
        var decodedResponse = json.decode(responseData);
        print('Decoded response: $decodedResponse');
        // Handle potential low-confidence even on 200 responses
        final numCc200 = (decodedResponse['classification_confidence'] ?? decodedResponse['detection_confidence'] ?? 0) as num;
        final double confidence200 = numCc200.toDouble();
        final bool lowConf200 = decodedResponse['low_confidence'] == true;
        final bool hasFish200 = decodedResponse['has_fish'] == null ? true : (decodedResponse['has_fish'] == true);
        if (!hasFish200 || lowConf200 || confidence200 < _confidenceThreshold) {
          if (mounted) {
            Navigator.pop(context); // Close the scanning dialog
            _showSnapTipsDialog(!hasFish200 ? 'No fish detected' : 'Low confidence: ${(confidence200 * 100).toStringAsFixed(1)}%');
            setState(() { _isLoading = false; });
          }
          return false;
        }
        
        // Create temp prediction to get the fish names
        final commonName = decodedResponse['common_name'] ?? 'Unknown';
        final scientificName = decodedResponse['scientific_name'] ?? 'Unknown';
        
        // Fetch description from database instead of AI
        String description = '';
        try {
          description = await _fetchFishDescriptionFromDatabase(commonName, scientificName);
        } catch (e) {
          print('Error fetching description: $e');
          description = 'No description available. Try again later.';
        }
        
        // Fetch fish species data from Supabase for additional information
        final fishSpeciesData = await _fetchFishSpeciesData(commonName, scientificName);

        // Create a FishPrediction object with the new format
        FishPrediction prediction = FishPrediction(
          commonName: commonName,
          scientificName: scientificName,
          waterType: decodedResponse['water_type'] ?? 'Unknown',
          probability: '${((decodedResponse['classification_confidence'] ?? 0) * 100).toStringAsFixed(2)}%',
          imagePath: imageFile.path,
          maxSize: '${decodedResponse['max_size'] ?? 'Unknown'}',
          temperament: decodedResponse['temperament'] ?? 'Unknown',
          careLevel: decodedResponse['care_level'] ?? 'Unknown',
          lifespan: '${decodedResponse['lifespan'] ?? 'Unknown'} years',
          diet: decodedResponse['diet'] ?? 'Unknown',
          preferredFood: decodedResponse['preferred_food'] ?? 'Unknown',
          feedingFrequency: decodedResponse['feeding_frequency'] ?? 'Unknown',
          description: description,
          temperatureRange: fishSpeciesData?['temperature_range'] ?? decodedResponse['temperature_range_c'] ?? '',
          phRange: fishSpeciesData?['ph_range'] ?? decodedResponse['ph_range'] ?? '',
          socialBehavior: fishSpeciesData?['social_behavior'] ?? decodedResponse['social_behavior'] ?? '',
          minimumTankSize: fishSpeciesData?['minimum_tank_size_(l)'] != null 
              ? '${fishSpeciesData!['minimum_tank_size_(l)']} L' 
              : (decodedResponse['minimum_tank_size_l'] != null ? '${decodedResponse['minimum_tank_size_l']} L' : ''),
          compatibilityNotes: fishSpeciesData?['compatibility_notes'] ?? 'No compatibility notes available',
          tankLevel: fishSpeciesData?['tank_level'] ?? 'Unknown',
        );

        if (mounted) {
          Navigator.pop(context); // Close the scanning dialog
          setState(() {
            if (isFirstFish) {
              _capturedImage1 = File(imageFile.path);
            } else {
              _capturedImage2 = File(imageFile.path);
            }
            _isLoading = false;
          });

          // Show prediction results dialog
          if (mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showPredictionResults(imageFile, [prediction], isFirstFish);
            });
          }
        }
        return true;
      } else if (response.statusCode == 400) {
        if (mounted) {
          Navigator.pop(context); // Close the scanning dialog
        }
        var decodedResponse = json.decode(responseData);
        
        // Check for confidence level and fish detection
        final numCc = (decodedResponse['classification_confidence'] ?? decodedResponse['detection_confidence'] ?? 0) as num;
        final double confidence = numCc.toDouble();
        final bool hasFish = decodedResponse['has_fish'] == null ? true : (decodedResponse['has_fish'] == true);
        final bool lowConf = decodedResponse['low_confidence'] == true;

        // Show dialog for no fish or low confidence
        if (!hasFish || lowConf || confidence < _confidenceThreshold) {
          if (mounted) {
            _showSnapTipsDialog(!hasFish ? 'No fish detected' : 'Low confidence: ${(confidence * 100).toStringAsFixed(1)}%');
          }
          setState(() {
            _isLoading = false;
          });
          return false;
        }

        if (decodedResponse.containsKey('has_fish') && decodedResponse['has_fish'] == false) {
          // Snap Tips already shown above; just stop here without additional notifications
          return false;
        } else {
          if (mounted) {
            showCustomNotification(
              context,
              'Error: ${decodedResponse['detail']}',
              isError: true,
            );
          }
          return true;
        }
      } else {
        if (mounted) {
          Navigator.pop(context); // Close the scanning dialog
          showCustomNotification(
            context,
            'Failed to get predictions. Please try again.',
            isError: true,
          );
        }
        return true;
      }
    } catch (e, stackTrace) {
      print('Error getting predictions: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        Navigator.pop(context); // Close the scanning dialog
        showCustomNotification(
          context,
          'Failed to get predictions: ${e.toString()}',
          isError: true,
        );
      }
      return true;
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Show snap tips dialog for no fish or low confidence
  void _showSnapTipsDialog(String reason) {
    showDialog(
      context: context,
      useRootNavigator: true,
      builder: (context) => SnapTipsDialog(message: reason),
    );
  }

  void _showPredictionResults(XFile imageFile, List<FishPrediction> predictions, bool isFirstFish) {
    final highestPrediction = predictions.reduce((curr, next) {
      double currProb = double.parse(curr.probability.replaceAll('%', ''));
      double nextProb = double.parse(next.probability.replaceAll('%', ''));
      return currProb > nextProb ? curr : next;
    });

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
                'Fish Identification Results',
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
                  // Image container with fish name overlay
                  Stack(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 350,
                        child: Image.file(
                          File(imageFile.path),
                          fit: BoxFit.cover,
                        ),
                      ),
                      // Fish name overlay positioned higher for better visibility
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
                                highestPrediction.commonName,
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
                                highestPrediction.scientificName,
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
                          borderRadius: BorderRadius.circular(6),
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
                            _buildInfoCard('Max Size', highestPrediction.maxSize, Icons.straighten),
                            _buildInfoCard('Lifespan', highestPrediction.lifespan, Icons.timer),
                            _buildInfoCard('Water Type', highestPrediction.waterType, Icons.water),
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
                        DescriptionWidget(
                          description: highestPrediction.description,
                          maxLines: 6,
                        ),
                        const SizedBox(height: 30),
                        
                        // Image gallery
                        FishImagesGrid(fishName: highestPrediction.commonName),
                        
                        const SizedBox(height: 30),
                        
                        // Basic Information section
                        const Text(
                          'Basic Information',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF006064),
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildDetailCard('Temperament', highestPrediction.temperament, Icons.psychology),
                        _buildDetailCard('Care Level', highestPrediction.careLevel, Icons.star),
                        _buildDetailCard('Social Behavior', highestPrediction.socialBehavior.isNotEmpty ? highestPrediction.socialBehavior : 'Unknown', Icons.group),
                        _buildDetailCard('Compatibility Notes', highestPrediction.compatibilityNotes, Icons.info),
                        const SizedBox(height: 30),
                        
                        // Habitat Information section
                        const Text(
                          'Habitat Information',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF006064),
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildDetailCard('pH Range', highestPrediction.phRange.isNotEmpty ? highestPrediction.phRange : 'Unknown', Icons.science),
                        _buildDetailCard('Minimum Tank Size', highestPrediction.minimumTankSize.isNotEmpty ? highestPrediction.minimumTankSize : 'Unknown', Icons.water_drop),
                        _buildDetailCard(
                          'Temperature Range',
                          (highestPrediction.temperatureRange.isNotEmpty &&
                                  highestPrediction.temperatureRange.toLowerCase() != 'unknown')
                              ? '${highestPrediction.temperatureRange} °C'
                              : 'Unknown',
                          Icons.thermostat,
                        ),
                        _buildDetailCard('Tank Level', highestPrediction.tankLevel.isNotEmpty ? highestPrediction.tankLevel : 'Unknown', Icons.layers),
                        const SizedBox(height: 30),
                        
                        // Diet Information section
                        const Text(
                          'Diet Information',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF006064),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Basic diet information from prediction data
                        _buildDetailCard('Diet Type', highestPrediction.diet, Icons.restaurant),
                        _buildDetailCard('Preferred Foods', highestPrediction.preferredFood, Icons.set_meal),
                        _buildDetailCard('Feeding Frequency', highestPrediction.feedingFrequency, Icons.schedule),
                        const SizedBox(height: 40),
                        
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  _showCameraPreview(isFirstFish);
                                },
                                style: TextButton.styleFrom(
                                  backgroundColor: Colors.grey[100],
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                child: const Text(
                                  'Retry',
                                  style: TextStyle(
                                    color: Colors.black87,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _selectedFish[highestPrediction.commonName] = 1;
                                  });
                                  Navigator.of(context).pop();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00BCD4),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                child: const Text(
                                  'Select Fish',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
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
          );
        },
      ),
    );
  }



  Widget _buildInfoCard(String label, String value, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: const Color(0xFF00ACC1),
          size: 28,
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF006064),
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
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF00ACC1).withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF00ACC1),
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
                    color: Color(0xFF006064),
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

  // Method to fetch fish description from Supabase database
  Future<String> _fetchFishDescriptionFromDatabase(String commonName, String scientificName) async {
    try {
      final response = await Supabase.instance.client
          .from('fish_species')
          .select('description')
          .eq('active', true)
          .or('common_name.ilike.%$commonName%,scientific_name.ilike.%$scientificName%')
          .limit(1);

      if (response.isNotEmpty && response.first['description'] != null) {
        return response.first['description'];
      } else {
        // Fallback to local description generation if no database description found
        return 'The $commonName${scientificName.isNotEmpty ? ' ($scientificName)' : ''} is an aquarium fish species. '
            'This fish is known for its unique characteristics and makes an interesting addition to aquariums. '
            'For detailed care information, please consult aquarium care guides or speak with aquarium professionals.';
      }
    } catch (e) {
      print('Error fetching description from database: $e');
      // Fallback to local description generation on error
      return 'The $commonName${scientificName.isNotEmpty ? ' ($scientificName)' : ''} is an aquarium fish species. '
          'This fish is known for its unique characteristics and makes an interesting addition to aquariums. '
          'For detailed care information, please consult aquarium care guides or speak with aquarium professionals.';
    }
  }

  // Method to fetch fish species data from Supabase
  Future<Map<String, dynamic>?> _fetchFishSpeciesData(String commonName, String scientificName) async {
    try {
      final response = await Supabase.instance.client
          .from('fish_species')
          .select('*')
          .eq('active', true)
          .or('common_name.ilike.%$commonName%,scientific_name.ilike.%$scientificName%')
          .limit(1)
          .single();
      
      return response;
    } catch (e) {
      print('Error fetching fish species data: $e');
      return null;
    }
  }

  void _showSnapTips() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const SnapTipsDialog(),
    );
  }




  bool _canCheckCompatibility() {
    // Users can check compatibility without being logged in
    // Authentication is only required when saving results
    
    if (_selectedFish.isEmpty) {
      return false;
    }
    
    // Case 1: Multiple fish species (2 or more different fish)
    if (_selectedFish.length >= 2) {
      return true;
    }
    
    // Case 2: Single fish species with 2+ quantity
    if (_selectedFish.length == 1) {
      final quantity = _selectedFish.values.first;
      return quantity >= 2;
    }
    
    return false;
  }


  Future<void> _checkCompatibility() async {
    if (!_canCheckCompatibility()) {
      return;
    }
    
    if (_selectedFish.isEmpty) {
      showCustomNotification(
        context,
        'Please select at least 2 fish to check compatibility.',
        isError: true,
      );
      return;
    }
    
    if (_selectedFish.isEmpty) {
      showCustomNotification(
        context,
        'Please select at least 1 fish to check compatibility.',
        isError: true,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Create expanded fish list considering quantities
      List<String> expandedFishNames = [];
      
      // Add each fish according to its quantity for proper self-compatibility checking
      _selectedFish.forEach((fishName, quantity) {
        // Add the fish multiple times based on quantity
        for (int i = 0; i < quantity; i++) {
          expandedFishNames.add(fishName);
        }
      });

      final response = await http.post(
        Uri.parse(ApiConfig.checkGroupEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        },
        body: jsonEncode({'fish_names': expandedFishNames}),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw Exception('Failed to check compatibility: ${response.statusCode}');
      }

      final compatibilityData = jsonDecode(response.body);
      final results = compatibilityData['results'] as List? ?? [];
      
      // Store the detailed compatibility results for pair analysis
      _storedCompatibilityResults = results.cast<Map<String, dynamic>>();
      
      // Parse compatibility results and store individual pair results
      bool hasIncompatiblePairs = false;
      bool hasConditionalPairs = false;
      final List<Map<String, dynamic>> incompatiblePairs = [];
      final List<Map<String, dynamic>> conditionalPairs = [];
      final Set<String> seenPairs = {};
      
      // Clear previous pair results
      _pairCompatibilityResults.clear();
      
      for (var result in results) {
        final compatibility = result['compatibility'];
        
        if (compatibility == 'Not Compatible' || compatibility == 'Conditional' || compatibility == 'Conditionally Compatible') {
          final pair = List<String>.from(result['pair'].map((e) => e.toString()));
          if (pair.length == 2) {
            final a = pair[0].toLowerCase();
            final b = pair[1].toLowerCase();
            final key = ([a, b]..sort()).join('|');
            if (!seenPairs.contains(key)) {
              seenPairs.add(key);
              
              // Store individual pair result
              if (compatibility == 'Not Compatible') {
                _pairCompatibilityResults[key] = 'incompatible';
                hasIncompatiblePairs = true;
                incompatiblePairs.add({
                  'pair': result['pair'],
                  'reasons': result['reasons'],
                  'type': 'incompatible',
                });
              } else if (compatibility == 'Conditional' || compatibility == 'Conditionally Compatible') {
                _pairCompatibilityResults[key] = 'conditional';
                hasConditionalPairs = true;
                conditionalPairs.add({
                  'pair': result['pair'],
                  'reasons': result['reasons'],
                  'type': 'conditional',
                });
              }
            }
          }
        } else if (compatibility == 'Compatible') {
          // Store compatible pairs too
          final pair = List<String>.from(result['pair'].map((e) => e.toString()));
          if (pair.length == 2) {
            final a = pair[0].toLowerCase();
            final b = pair[1].toLowerCase();
            final key = ([a, b]..sort()).join('|');
            _pairCompatibilityResults[key] = 'compatible';
          }
        }
      }

      // Determine compatibility level and extract reasons/conditions
      String compatibilityLevel;
      List<String> baseReasons = [];
      Set<String> uniqueConditions = {};
      
      if (hasIncompatiblePairs) {
        compatibilityLevel = 'incompatible';
        // Get reasons from incompatible pairs
        Set<String> uniqueReasons = {};
        for (var pair in incompatiblePairs) {
          if (pair['reasons'] != null) {
            List<String> pairReasons = List<String>.from(pair['reasons']);
            for (String reason in pairReasons) {
              uniqueReasons.add(reason);
            }
          }
        }
        baseReasons = uniqueReasons.toList();
        if (baseReasons.isEmpty) {
          baseReasons = ['These fish are not compatible'];
        }
      } else if (hasConditionalPairs) {
        compatibilityLevel = 'conditional';
        // Get reasons and conditions from conditional pairs
        Set<String> uniqueReasons = {};
        for (var pair in conditionalPairs) {
          if (pair['reasons'] != null) {
            List<String> pairReasons = List<String>.from(pair['reasons']);
            for (String reason in pairReasons) {
              uniqueReasons.add(reason);
            }
          }
          // Also collect unique conditions
          if (pair['conditions'] != null) {
            List<String> pairConditions = List<String>.from(pair['conditions']);
            for (String condition in pairConditions) {
              uniqueConditions.add(condition);
            }
          }
        }
        baseReasons = uniqueReasons.toList();
        if (baseReasons.isEmpty) {
          baseReasons = ['These fish are compatible with conditions'];
        }
      } else {
        compatibilityLevel = 'compatible';
        baseReasons = ['These fish are compatible'];
      }

      // Set fish names and image paths for display
      setState(() {
        final fishNames = _selectedFish.keys.toList();
        if (fishNames.isNotEmpty) {
          _fish1Name = fishNames[0];
          if (fishNames.length > 1) {
            _fish2Name = fishNames[1];
          }
        }
        
        if (_capturedImage1 != null) {
          _fish1ImagePath = _capturedImage1!.path;
        } else if (_fish1ImagePath.isEmpty && _fish1Name.isNotEmpty) {
          // Store the fish name so the renderer can resolve via /fish-image/{name}
          _fish1ImagePath = _fish1Name;
        }
        if (_capturedImage2 != null) {
          _fish2ImagePath = _capturedImage2!.path;
        } else if (_fish2ImagePath.isEmpty && _fish2Name.isNotEmpty) {
          // Store the fish name so the renderer can resolve via /fish-image/{name}
          _fish2ImagePath = _fish2Name;
        }
      });
      
      
      if (mounted) {
        _showCompatibilityDialog(
          compatibilityLevel == 'compatible', 
          baseReasons, 
          compatibilityLevel, 
          uniqueConditions.toList()
        );
      }
    } catch (e) {
      print('Error checking compatibility: $e');
      showCustomNotification(
        context,
        'Error checking compatibility: ${e.toString()}',
        isError: true,
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showCompatibilityDialog(bool isCompatible, List<String> baseReasons, String compatibilityLevel, List<String> conditions) {
    // Enhanced compatibility dialog with full support for conditional compatibility
    Map<String, Map<String, dynamic>> tankmates = {}; // Store tankmate recommendations for each fish
    bool isLoadingTankmates = false;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Load tankmate recommendations for all selected fish
            if (tankmates.isEmpty && !isLoadingTankmates) {
              isLoadingTankmates = true;
              final fishNames = _selectedFish.keys.toList();
              if (fishNames.isNotEmpty) {
                _loadTankmateRecommendationsForAllFish(fishNames).then((recommendations) {
                if (mounted) {
                  setDialogState(() {
                    tankmates = recommendations;
                    isLoadingTankmates = false;
                  });
                }
              }).catchError((e) {
                print('Error loading tankmate recommendations: $e');
                if (mounted) {
                  setDialogState(() {
                    isLoadingTankmates = false;
                  });
                }
              });
              }
            }

            return Dialog(
              insetPadding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
              ),
              child: Container(
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height,
                decoration: const BoxDecoration(
                  color: Colors.white,
                ),
                child: SafeArea(
                  child: Column(
                    children: [
                    // Header with close button
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Compatibility Result',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            icon: const Icon(Icons.close, color: Colors.black),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.8),
                              shape: const CircleBorder(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Main content
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            // Fish images and names
                            _buildSimplifiedFishDisplay(),
                            
                            const SizedBox(height: 24),
                            
                            // Compatibility status
                            _buildCompatibilityStatus(compatibilityLevel),
                            
                            const SizedBox(height: 20),
                            
                            // Main reason
                            _buildMainReason(baseReasons, compatibilityLevel),
                            
                            const SizedBox(height: 20),
                            
                            // Detailed compatibility breakdown
                            _buildCompatibilityBreakdown(compatibilityLevel, baseReasons, setDialogState: setDialogState),
                            
                            const SizedBox(height: 20),
                            
                            // Tankmate recommendations (simplified)
                            if (tankmates.isNotEmpty || isLoadingTankmates)
                              _buildSimplifiedTankmateSection(tankmates, isLoadingTankmates, setDialogState: setDialogState),
                            
                          ],
                        ),
                      ),
                    ),
                    
                    // Action buttons
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(dialogContext).pop(),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                side: const BorderSide(color: Colors.black),
                              ),
                              child: const Text(
                                'Close',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async => await _saveCompatibilityResult(compatibilityLevel, baseReasons, dialogContext),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00BCD4),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                'Save Result',
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

  // Helper method to save compatibility result
  Future<void> _saveCompatibilityResult(String compatibilityLevel, List<String> baseReasons, BuildContext dialogContext) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      showDialog(
        context: context,
        builder: (BuildContext context) => const AuthRequiredDialog(
          title: 'Sign In Required',
          message: 'You need to sign in to save compatibility results to your collection.',
        ),
      );
      return;
    }
    
    final logbookProvider = Provider.of<LogBookProvider>(context, listen: false);
    
    // Prepare pair analysis data with detailed reasons and conditions
    final pairAnalysis = {
      'pairs': _pairCompatibilityResults.entries.map((entry) {
        final pair = entry.key.split('|');
        final fish1 = pair[0];
        final fish2 = pair[1];
        final compatibility = entry.value;
        
        // Find detailed reasons and conditions from stored API results
        List<String> reasons = [];
        List<String> conditions = [];
        
        for (var result in _storedCompatibilityResults) {
          if (result.containsKey('pair')) {
            final apiPair = List<String>.from(result['pair']);
            if (apiPair.length == 2) {
              final apiFish1 = apiPair[0].toLowerCase();
              final apiFish2 = apiPair[1].toLowerCase();
              
              // Check if this is the same pair (order doesn't matter)
              if ((apiFish1 == fish1 && apiFish2 == fish2) || 
                  (apiFish1 == fish2 && apiFish2 == fish1)) {
                // Extract reasons and conditions from the API result
                if (result['reasons'] != null) {
                  reasons = List<String>.from(result['reasons']);
                }
                if (result['conditions'] != null) {
                  conditions = List<String>.from(result['conditions']);
                }
                break;
              }
            }
          }
        }
        
        return {
          'fish1': fish1,
          'fish2': fish2,
          'compatibility': compatibility,
          'reasons': reasons,
          'conditions': conditions,
        };
      }).toList(),
    };
    
    // Get tankmate recommendations for all selected fish
    final tankmateRecommendations = await _loadTankmateRecommendationsForAllFish(_selectedFish.keys.toList());
    
    final newResult = CompatibilityResult(
      selectedFish: Map<String, int>.from(_selectedFish),
      compatibilityLevel: compatibilityLevel,
      reasons: baseReasons,
      pairAnalysis: pairAnalysis,
      tankmateRecommendations: tankmateRecommendations,
      dateChecked: DateTime.now(),
    );
    logbookProvider.addCompatibilityResult(newResult);
    Navigator.of(dialogContext).pop();
    showCustomNotification(context, 'Result saved to History');
    
    // Clear the selected fish inputs after saving
    setState(() {
      _selectedFish.clear();
      _fish1Name = '';
      _fish2Name = '';
      _fish1ImagePath = '';
      _fish2ImagePath = '';
      _capturedImage1 = null;
      _capturedImage2 = null;
    });
  }

  // Multi-fish display
  Widget _buildSimplifiedFishDisplay() {
    final selectedFishNames = _selectedFish.keys.toList();
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.black.withOpacity(0.1)),
                    boxShadow: [
                      BoxShadow(
            color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
      child: Column(
        children: [
          // Header
          Row(
                  children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF00BCD4).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                      child: const Icon(
                  FontAwesomeIcons.fish,
                        color: Color(0xFF00BCD4),
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Selected Fish (${selectedFishNames.length})',
                style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Fish grid
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = selectedFishNames.length <= 2 ? 2 : 3;
              final itemWidth = (constraints.maxWidth - (crossAxisCount - 1) * 12) / crossAxisCount;
              
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: selectedFishNames.map((fishName) {
                  return Container(
                    width: itemWidth,
            child: Column(
              children: [
                Container(
                          width: 60,
                          height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                            child: _buildFishResultImage(fishName),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                                fishName,
                        style: const TextStyle(
                                  fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                              onTap: () => _showFishInfoDialog(fishName),
                      child: const Icon(
                        Icons.remove_red_eye,
                                size: 14,
                        color: Color(0xFF00BCD4),
                      ),
                    ),
                  ],
                ),
              ],
            ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  // Enhanced compatibility status for multiple fish
  Widget _buildCompatibilityStatus(String compatibilityLevel) {
    Color statusColor = _getCompatibilityColor(compatibilityLevel);
    final fishCount = _selectedFish.length;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: statusColor.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _getCompatibilityIcon(compatibilityLevel),
            color: statusColor,
            size: 28,
          ),
          const SizedBox(width: 12),
          Text(
            _getCompatibilityText(compatibilityLevel),
            style: TextStyle(
              color: statusColor,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
            ],
          ),
          if (fishCount > 2) ...[
            const SizedBox(height: 8),
            Text(
              'Compatibility checked for $fishCount fish',
              style: TextStyle(
                color: statusColor.withOpacity(0.8),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Enhanced main reason display for multiple fish
  Widget _buildMainReason(List<String> baseReasons, String compatibilityLevel) {
    if (baseReasons.isEmpty) return const SizedBox.shrink();
    
    final fishCount = _selectedFish.length;
    final fishNames = _selectedFish.keys.toList();
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.black.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
              const Icon(
                Icons.info_outline,
                color: Color(0xFF00BCD4),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                fishCount > 2 ? 'Analysis Summary' : 'Why?',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Show fish names if multiple
          if (fishCount > 2) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF00BCD4).withOpacity(0.05),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: const Color(0xFF00BCD4).withOpacity(0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Fish being analyzed:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF00BCD4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: fishNames.map((name) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00BCD4).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF00BCD4),
                        ),
                      ),
                    )).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          
          Text(
            baseReasons.first, // Show only the main reason
            style: const TextStyle(
              fontSize: 15,
              color: Colors.black,
              height: 1.4,
            ),
          ),
          if (baseReasons.length > 1) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => _showDetailedReasons(baseReasons, compatibilityLevel),
              child: const Text(
                'View detailed analysis',
                style: TextStyle(
                  color: Color(0xFF00BCD4),
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Show detailed reasons dialog for multiple fish
  void _showDetailedReasons(List<String> reasons, String compatibilityLevel) {
    final fishCount = _selectedFish.length;
    final fishNames = _selectedFish.keys.toList();
    
    showDialog(
      context: context,
      useRootNavigator: true,
      builder: (context) => Dialog.fullscreen(
        backgroundColor: Colors.white,
        child: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                // Header with close button
              Row(
                  children: [
                    Expanded(
                      child: Row(
                children: [
                  const Icon(
                            Icons.analytics,
                            color: Color(0xFF00BCD4),
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              fishCount > 2 ? 'Multi-Fish Compatibility Analysis' : 'Detailed Analysis',
                              style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.close,
                        color: Colors.black,
                        size: 24,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
                
                // Scrollable content
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
              
              // Show fish count and names
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF00BCD4).withOpacity(0.05),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: const Color(0xFF00BCD4).withOpacity(0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Analyzing $fishCount fish:',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF00BCD4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: fishNames.map((name) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00BCD4).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF00BCD4),
                          ),
                        ),
                      )).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Compatibility level indicator
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getCompatibilityColor(compatibilityLevel).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _getCompatibilityColor(compatibilityLevel).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _getCompatibilityIcon(compatibilityLevel),
                      color: _getCompatibilityColor(compatibilityLevel),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _getCompatibilityText(compatibilityLevel),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _getCompatibilityColor(compatibilityLevel),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Detailed reasons
              const Text(
                'Analysis Details:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              ...reasons.asMap().entries.map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: _getCompatibilityColor(compatibilityLevel),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        entry.value,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.black,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00BCD4),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    elevation: 0,
                  ),
                  child: const Text('Got it'),
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
      ),
    );
  }

  // Detailed compatibility breakdown
  Widget _buildCompatibilityBreakdown(String compatibilityLevel, List<String> baseReasons, {Function? setDialogState}) {
    final fishNames = _selectedFish.keys.toList();
    final pairs = _generateFishPairs(fishNames);
    if (pairs.isEmpty) return const SizedBox.shrink();
    
    return Container(
      width: MediaQuery.of(context).size.width * 0.9,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.black.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.compare_arrows,
                color: Colors.black,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Pair-by-Pair Analysis',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Generate all possible pairs
          ..._generateFishPairs(fishNames).take(_showAllPairs ? _generateFishPairs(fishNames).length : 5).map((pair) {
            final fish1 = pair[0];
            final fish2 = pair[1];
            final pairCompatibility = _getPairCompatibility(fish1, fish2, compatibilityLevel, baseReasons);
            
            return GestureDetector(
              onTap: () => _showPairAnalysisDialog(fish1, fish2, pairCompatibility),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getCompatibilityColor(pairCompatibility).withOpacity(0.05),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _getCompatibilityColor(pairCompatibility).withOpacity(0.3),
                  ),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final availableWidth = constraints.maxWidth;
                    final imageSize = (availableWidth * 0.15).clamp(40.0, 60.0);
                    
                    return Row(
                      children: [
                        // Fish 1
                        Container(
                          width: imageSize,
                          height: imageSize,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: _buildFishResultImage(fish1),
                          ),
                        ),
                        
                        // Compatibility indicator with fish names above
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Fish names above compatibility badge
                                Text(
                                  '$fish1 + $fish2',
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                // Compatibility badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _getCompatibilityColor(pairCompatibility).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _getCompatibilityIcon(pairCompatibility),
                                        color: _getCompatibilityColor(pairCompatibility),
                                        size: 14,
                                      ),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          _getCompatibilityText(pairCompatibility),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: _getCompatibilityColor(pairCompatibility),
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        // Fish 2
                        Container(
                          width: imageSize,
                          height: imageSize,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: _buildFishResultImage(fish2),
                          ),
                        ),
                        
                        // Click indicator
                        const SizedBox(width: 8),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 12,
                          color: Colors.black.withOpacity(0.4),
                        ),
                      ],
                    );
                  },
                ),
              ),
            );
          }).toList(),
          
          // Show More/Less button for pairs
          if (_generateFishPairs(fishNames).length > 5) ...[
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: () {
                  if (setDialogState != null) {
                    setDialogState(() {
                      _showAllPairs = !_showAllPairs;
                    });
                  } else {
                    setState(() {
                      _showAllPairs = !_showAllPairs;
                    });
                  }
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                    side: BorderSide(color: Colors.black.withOpacity(0.3)),
                  ),
                ),
                child: Text(
                  _showAllPairs ? 'Show Less' : 'Show More (${_generateFishPairs(fishNames).length - 5} more)',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Generate all possible fish pairs
  List<List<String>> _generateFishPairs(List<String> fishNames) {
    List<List<String>> pairs = [];
    Map<String, int> fishCounts = {};
    
    // Count occurrences of each fish based on quantity
    _selectedFish.forEach((fishName, quantity) {
      fishCounts[fishName] = quantity;
    });

    // If we only have 2 fish with quantity 1 each, return empty list
    if (fishNames.length == 2 && 
        fishCounts[fishNames[0]] == 1 && 
        fishCounts[fishNames[1]] == 1) {
      return pairs;
    }

    // Generate pairs considering quantities
    for (int i = 0; i < fishNames.length; i++) {
      String fish1 = fishNames[i];
      int fish1Qty = fishCounts[fish1] ?? 1;

      // If this fish has quantity > 1, create pairs with itself
      if (fish1Qty > 1) {
        pairs.add([fish1, fish1]);
      }

      // Create pairs with other fish
      for (int j = i + 1; j < fishNames.length; j++) {
        String fish2 = fishNames[j];
        pairs.add([fish1, fish2]);
      }
    }
    
    return pairs;
  }

  // Get compatibility status for a specific pair
  String _getPairCompatibility(String fish1, String fish2, String overallLevel, List<String> reasons) {
    final a = fish1.toLowerCase();
    final b = fish2.toLowerCase();
    final key = ([a, b]..sort()).join('|');
    
    // Return the stored individual pair result, or default to compatible if not found
    return _pairCompatibilityResults[key] ?? 'compatible';
  }


  // Enhanced tankmate section for all selected fish
  Widget _buildSimplifiedTankmateSection(Map<String, Map<String, dynamic>> tankmates, bool isLoadingTankmates, {Function? setDialogState}) {
    if (isLoadingTankmates) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00BCD4)),
              ),
            ),
            SizedBox(width: 12),
            Text(
              'Loading recommendations...',
              style: TextStyle(color: Colors.black),
            ),
          ],
        ),
      );
    }

    if (!_hasTankmateData(tankmates)) {
      return const SizedBox.shrink();
    }

    final selectedFishNames = _selectedFish.keys.toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.black.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(FontAwesomeIcons.fish, color: Color(0xFF00BCD4), size: 16),
              const SizedBox(width: 8),
              Text(
                'Tankmate Recommendations (${selectedFishNames.length} fish)',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Show recommendations for each selected fish (limit to 3 initially)
          ...selectedFishNames.take(_showAllTankmateFish ? selectedFishNames.length : 3).map((fishName) {
            final fishData = tankmates[fishName];
            if (fishData == null || !_hasFishTankmates(fishData)) {
              return const SizedBox.shrink();
            }
            
            final fullyCompatible = (fishData['fully_compatible'] as List<String>?) ?? [];
            final conditional = (fishData['conditional'] as List<Map<String, dynamic>>?) ?? [];
            final totalCount = fullyCompatible.length + conditional.length;
            
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Fish header with image
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: _buildFishResultImage(fishName),
                        ),
                      ),
                      const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fishName,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          Text(
                            '$totalCount compatible tankmates',
                            style: const TextStyle(
                              fontSize: 12,
                                color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                      GestureDetector(
                        onTap: () => _showTankmateDetails(fishName, fishData),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00BCD4).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.arrow_forward_ios,
                            size: 14,
                            color: Color(0xFF00BCD4),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Quick preview of tankmates
                  if (fullyCompatible.isNotEmpty || conditional.isNotEmpty) ...[
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        // Fully compatible preview
                        ...fullyCompatible.take(3).map((tankmate) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.green.withOpacity(0.3)),
                        ),
                        child: Text(
                            tankmate,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.green,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        )),
                        
                        // Conditional preview
                        ...conditional.take(2).map((tankmateData) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.orange.withOpacity(0.3)),
                        ),
                        child: Text(
                            tankmateData['name'] as String? ?? 'Unknown',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.orange,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        )),
                        
                        // Show more indicator if there are more tankmates
                        if (totalCount > 5)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.grey.withOpacity(0.3)),
                            ),
                            child: Text(
                              '+${totalCount - 5} more',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                  
                  // Count badges
                  if (fullyCompatible.isNotEmpty || conditional.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (fullyCompatible.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${fullyCompatible.length} fully compatible',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.green,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (conditional.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${conditional.length} conditional',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.orange,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
          
          // Show More/Less button for tankmate fish cards
          if (selectedFishNames.length > 3) ...[
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: () {
                  if (setDialogState != null) {
                    setDialogState(() {
                      _showAllTankmateFish = !_showAllTankmateFish;
                    });
                  } else {
                    setState(() {
                      _showAllTankmateFish = !_showAllTankmateFish;
                    });
                  }
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                    side: BorderSide(color: Colors.black.withOpacity(0.3)),
                  ),
                ),
                child: Text(
                  _showAllTankmateFish ? 'Show Less' : 'Show More (${selectedFishNames.length - 3} more fish)',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
              ),
            ),
          ),
          ],
        ],
      ),
    );
  }


  Widget _buildFishResultImage(String fishName) {
    // Try to get image from captured images first
    if (fishName == _fish1Name && _capturedImage1 != null) {
      return Image.file(
        _capturedImage1!,
                fit: BoxFit.cover,
                gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholderImage(),
      );
    } else if (fishName == _fish2Name && _capturedImage2 != null) {
      return Image.file(
        _capturedImage2!,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholderImage(),
      );
    }
    
    // Fallback to network image
    return _buildNetworkImage(fishName);
  }



  Widget _buildNetworkImage(String imagePathOrName) {
    // If it's a fish name, try to get the image from the API
    if (!imagePathOrName.startsWith('http') && !imagePathOrName.startsWith('/')) {
      final imageUrl = '${ApiConfig.baseUrl}/fish-image/$imagePathOrName';
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                  : null,
              color: const Color(0xFF00BCD4),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          print('Error loading network image: $error');
          return _buildPlaceholderImage();
        },
      );
    }
    
    // If it's already a URL, use it directly
    return Image.network(
      imagePathOrName,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Center(
          child: CircularProgressIndicator(
            value: loadingProgress.expectedTotalBytes != null
                ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                : null,
            color: const Color(0xFF00BCD4),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        print('Error loading network image: $error');
        return _buildPlaceholderImage();
      },
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      color: Colors.grey[200],
      child: const Icon(
        Icons.image_not_supported,
        color: Colors.grey,
        size: 40,
      ),
    );
  }

  // Removed _buildLoadingAnimation - no longer needed


  @override
  Widget build(BuildContext context) {
    // Check if keyboard is visible
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardVisible = keyboardHeight > 0;
    
    return Container(
      color: Colors.white,
      child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF00BCD4),
                  ),
                )
          : Column(
                      children: [
                // Suggestion Section
                _buildSuggestionSection(),
                
                // Fish Selection Widget
                Expanded(
                  child: FishSelectionWidget(
                    selectedFish: _selectedFish,
                    availableFish: _availableFish.isNotEmpty ? _availableFish : _fishSpecies.map((species) => <String, dynamic>{
                      'common_name': species,
                      'scientific_name': species,
                      'water_type': 'Unknown',
                      'temperament': 'Unknown',
                      'social_behavior': 'Unknown',
                      'diet': 'Unknown',
                      'max_size': 'Unknown',
                      'lifespan': 'Unknown',
                      'ph_range': 'Unknown',
                      'temperature_range': 'Unknown',
                      'minimum_tank_size_(l)': 0, // Use number instead of string
                      'tank_level': 'Unknown',
                      'description': 'No description available.',
                      'compatibility_notes': 'No compatibility notes available.',
                    }).toList(),
                    onFishSelectionChanged: (newSelection) {
                      setState(() {
                        _selectedFish = newSelection;
                      });
                    },
                    canProceed: _canCheckCompatibility() && !isKeyboardVisible, // Check if compatibility can be enabled
                    isLastStep: true,
                    onNext: null, // Hide compatibility button from main screen
                    onCheckCompatibility: _checkCompatibility, // Add compatibility callback
                    compatibilityResults: const {},
                    tankShapeWarnings: const {},
                    nextButtonText: 'Check Compatibility',
                    hideButtonsWhenKeyboardVisible: true, // Add this parameter
                    maxDraggableHeight: 0.50, // 60% of screen height for sync screen
                              ),
                            ),
                          ],
      ),
    );
  }




  // Helper methods for tankmate data checking
  bool _hasTankmateData(Map<String, Map<String, dynamic>> tankmates) {
    return tankmates.values.any((fishData) => _hasFishTankmates(fishData));
  }

  bool _hasFishTankmates(Map<String, dynamic>? fishData) {
    if (fishData == null) return false;
    final fullyCompatible = fishData['fully_compatible'] as List<String>?;
    final conditional = fishData['conditional'] as List<Map<String, dynamic>>?;
    return (fullyCompatible?.isNotEmpty == true) || 
           (conditional?.isNotEmpty == true);
  }

  // Show tankmate details dialog
  void _showTankmateDetails(String fishName, Map<String, dynamic> fishData) {
    final fullyCompatible = (fishData['fully_compatible'] as List<String>?) ?? [];
    final conditional = (fishData['conditional'] as List<Map<String, dynamic>>?) ?? [];
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        child: Container(
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.height,
          color: Colors.white,
          child: SafeArea(
            child: Column(
              children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Colors.white,
                ),
                child: Row(
                  children: [
                    const Icon(FontAwesomeIcons.fish, color: Colors.black, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Tankmates for $fishName',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.black),
                    ),
                  ],
                ),
              ),
              
              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Fully Compatible Section
                      if (fullyCompatible.isNotEmpty) ...[
                        const Text(
                          'Fully Compatible',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: fullyCompatible.map((tankmate) => GestureDetector(
                            onTap: () => _showFishInfoDialog(tankmate),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      tankmate,
                                      style: const TextStyle(
                                        color: Colors.green,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Icon(
                                      Icons.remove_red_eye,
                                      size: 16,
                                      color: Colors.green,
                                    ),
                                  ],
                                ),
                              ),
                          )).toList(),
                        ),
                        const SizedBox(height: 20),
                      ],
                      
                      // Conditional Section
                      if (conditional.isNotEmpty) ...[
                        const Text(
                          'Compatible with Conditions',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...conditional.map((tankmateData) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.orange.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => _showFishInfoDialog(tankmateData['name'] as String),
                                  child: Row(
                                    children: [
                                      Text(
                                        tankmateData['name'] as String,
                                        style: const TextStyle(
                                          color: Colors.orange,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Icon(
                                        Icons.remove_red_eye,
                                        size: 16,
                                        color: Colors.orange,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => _showFishConditionsDialog(
                                  fishName,
                                  tankmateData['name'] as String,
                                  List<String>.from(tankmateData['conditions'] ?? [])
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(
                                    Icons.info_outline,
                                    size: 16,
                                    color: Colors.orange,
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
          ),
        ),
      ),
    );
  }

  // Show fish info dialog
  void _showFishInfoDialog(String fishName) {
    showDialog(
      context: context,
      builder: (context) => FishInfoDialog(fishName: fishName),
    );
  }

  // Show pair analysis dialog
  void _showPairAnalysisDialog(String fish1, String fish2, String compatibility) {
    // Get detailed reasons for this specific pair from the stored compatibility results
    final a = fish1.toLowerCase();
    final b = fish2.toLowerCase();
    final key = ([a, b]..sort()).join('|');
    
    List<String> reasons = [];
    List<String> conditions = [];
    String detailedAnalysis = '';
    
    // Try to find specific reasons for this pair from the stored API response
    // We need to look in the compatibility results that were stored during the compatibility check
    bool foundDetailedReasons = false;
    
    // Look through the stored compatibility results for this specific pair
    for (var result in _storedCompatibilityResults) {
      if (result.containsKey('pair')) {
        final pair = List<String>.from(result['pair']);
        if (pair.length == 2) {
          final pairFish1 = pair[0].toLowerCase();
          final pairFish2 = pair[1].toLowerCase();
          final pairKey = ([pairFish1, pairFish2]..sort()).join('|');
          
          if (pairKey == key) {
            // Found the specific pair result
            reasons = List<String>.from(result['reasons'] ?? []);
            conditions = List<String>.from(result['conditions'] ?? []);
            foundDetailedReasons = true;
            
            // Create detailed analysis based on the actual reasons
            if (reasons.isNotEmpty) {
              detailedAnalysis = reasons.first;
              if (reasons.length > 1) {
                detailedAnalysis += ' Additional factors include: ${reasons.skip(1).take(2).join(', ')}';
              }
            } else {
              // Fallback to compatibility level
              switch (compatibility) {
                case 'compatible':
                  detailedAnalysis = 'These fish are compatible and can live together peacefully.';
                  break;
                case 'conditional':
                  detailedAnalysis = 'These fish can coexist under specific conditions.';
                  break;
                case 'incompatible':
                  detailedAnalysis = 'These fish are not compatible due to conflicting needs.';
                  break;
              }
            }
            break;
          }
        }
      }
    }
    
    // If we didn't find detailed reasons, use fallback
    if (!foundDetailedReasons) {
      switch (compatibility) {
        case 'compatible':
          reasons = ['These fish are compatible and can live together peacefully'];
          detailedAnalysis = 'Both fish have similar requirements and temperaments that make them good tankmates.';
          break;
        case 'conditional':
          reasons = ['These fish can coexist under specific conditions'];
          detailedAnalysis = 'While compatible, certain environmental or behavioral considerations should be met for optimal cohabitation.';
          break;
        case 'incompatible':
          reasons = ['These fish are not compatible due to conflicting needs'];
          detailedAnalysis = 'These fish have incompatible requirements or behaviors that make them unsuitable tankmates.';
          break;
      }
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog.fullscreen(
          backgroundColor: Colors.white,
          child: SafeArea(
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(color: Colors.grey, width: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _getCompatibilityIcon(compatibility),
                        color: _getCompatibilityColor(compatibility),
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pair Analysis',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$fish1 + $fish2',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.black),
                      ),
                    ],
                  ),
                ),
                
                // Scrollable content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Fish images - responsive layout
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final screenWidth = MediaQuery.of(context).size.width;
                            final isSmallScreen = screenWidth < 400;
                            final imageSize = isSmallScreen ? 50.0 : 60.0;
                            final fontSize = isSmallScreen ? 10.0 : 12.0;
                            
                            return Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    children: [
                                      Container(
                                        width: imageSize,
                                        height: imageSize,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(6),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.1),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(6),
                                          child: _buildFishResultImage(fish1),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        fish1,
                                        style: TextStyle(
                                          fontSize: fontSize,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black,
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                
                                // VS indicator
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: Column(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.all(isSmallScreen ? 6 : 8),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'VS',
                                          style: TextStyle(
                                            fontSize: isSmallScreen ? 10 : 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _getCompatibilityColor(compatibility).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              _getCompatibilityIcon(compatibility),
                                              color: _getCompatibilityColor(compatibility),
                                              size: isSmallScreen ? 10 : 12,
                                            ),
                                            const SizedBox(width: 4),
                                            Flexible(
                                              child: Text(
                                                _getCompatibilityText(compatibility),
                                                style: TextStyle(
                                                  fontSize: isSmallScreen ? 8 : 10,
                                                  fontWeight: FontWeight.w600,
                                                  color: _getCompatibilityColor(compatibility),
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                
                                Expanded(
                                  child: Column(
                                    children: [
                                      Container(
                                        width: imageSize,
                                        height: imageSize,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(6),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.1),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(6),
                                          child: _buildFishResultImage(fish2),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        fish2,
                                        style: TextStyle(
                                          fontSize: fontSize,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black,
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                
                const SizedBox(height: 20),
                
                        // Show different content based on compatibility type
                        if (compatibility == 'conditional' && conditions.isNotEmpty) ...[
                          // For conditional compatibility, only show bulleted conditions
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.orange.withOpacity(0.2)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'Required Conditions',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.orange,
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
                                        decoration: const BoxDecoration(
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
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )),
                              ],
                            ),
                          ),
                        ] else ...[
                          // For compatible/incompatible, show analysis section
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: _getCompatibilityColor(compatibility).withOpacity(0.05),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: _getCompatibilityColor(compatibility).withOpacity(0.2),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.analytics,
                                      color: _getCompatibilityColor(compatibility),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Analysis',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: _getCompatibilityColor(compatibility),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  detailedAnalysis,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // Analysis Details section removed - redundant with Analysis card
                        ],
                        
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Show fish conditions dialog
  void _showFishConditionsDialog(String baseFishName, String tankmateName, List<String> conditions) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    const Icon(Icons.warning_amber, color: Colors.black, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Conditional Compatibility',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$baseFishName + $tankmateName',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.black),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // Conditions section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
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
                      if (conditions.isNotEmpty)
                        ...conditions.map((condition) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                margin: const EdgeInsets.only(top: 6),
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Colors.black,
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
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ))
                      else
                        Text(
                          'No specific conditions available.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Close button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00BCD4),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    elevation: 0,
                  ),
                    child: const Text(
                      'Got it',
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
        );
      },
    );
  }

  // Helper methods for conditional compatibility display
  IconData _getCompatibilityIcon(String level) {
    switch (level) {
      case 'compatible':
        return Icons.check_circle;
      case 'conditional':
        return Icons.warning;
      case 'incompatible':
      default:
        return Icons.cancel;
    }
  }

  Color _getCompatibilityColor(String level) {
    switch (level) {
      case 'compatible':
        return Colors.green;
      case 'conditional':
        return Colors.orange;
      case 'incompatible':
      default:
        return Colors.red;
    }
  }


  String _getCompatibilityText(String level) {
    switch (level) {
      case 'compatible':
        return 'Compatible';
      case 'conditional':
        return 'Conditional';
      case 'incompatible':
      default:
        return 'Not Compatible';
    }
  }

}
