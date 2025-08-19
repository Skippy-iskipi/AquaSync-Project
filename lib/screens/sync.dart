import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';
import '../models/fish_prediction.dart';
import '../config/api_config.dart';
import '../widgets/custom_notification.dart';
import '../widgets/snap_tips_dialog.dart';
import '../services/openai_service.dart';
import '../widgets/description_widget.dart';
import '../widgets/fish_images_grid.dart';
import '../screens/subscription_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:provider/provider.dart';
import '../models/compatibility_result.dart';
import '../screens/logbook_provider.dart';



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
  String? _selectedFish1;
  String? _selectedFish2;
  bool _isLoading = false;
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
  String? _fish1Base64Image;
  String? _fish2Base64Image;
  int _compatibilityChecksCount = 0;
  String _userPlan = 'free';
  
  @override
  void initState() {
    super.initState();
    // Try to connect to server and load data
    _checkServerAndLoadData();
    _loadUserPlan();
    _loadCompatibilityChecksCount();
    
    if (widget.initialFish != null) {
      setState(() {
        _selectedFish1 = widget.initialFish;
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

  @override
  void dispose() {
    // _controller1.dispose(); // No longer needed
    // _controller2.dispose(); // No longer needed
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _checkServerAndLoadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });
    
    // Check server connection first
    final isConnected = await ApiConfig.checkServerConnection();
    
    if (isConnected && mounted) {
      // If connected, load fish species
      await _loadFishSpecies();
    } else if (mounted) {
      // If not connected, show error message
      setState(() {
        _isLoading = false;
      });
      showCustomNotification(
        context,
        'Unable to connect to server. Please check your network connection.',
        isError: true,
      );
    }
  }

  Future<void> _loadFishSpecies() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

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
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
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
                            borderRadius: BorderRadius.circular(10),
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
                                    if (!result) {
                                      showCustomNotification(
                                        context,
                                        'No fish detected in the image. Please try again with a clearer image.',
                                        isError: true,
                                      );
                                    } else {
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

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async => false,
          child: Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 16),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 300,
                        height: 300,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          image: DecorationImage(
                            image: FileImage(io.File(imageFile.path)),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Container(
                        width: 300,
                        height: 300,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: Colors.black.withOpacity(0.3),
                        ),
                      ),
                      // Scanning line animations
                      ...List.generate(10, (i) => 
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: -300 - (i * 100), end: 500),
                          duration: const Duration(seconds: 4),
                          curve: Curves.linear,
                          builder: (context, double value, child) {
                            return Positioned(
                              top: value,
                              child: Container(
                                width: 300,
                                height: 3,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.teal.withOpacity(0.5),
                                      Colors.teal.withOpacity(1),
                                      Colors.teal.withOpacity(0.5),
                                    ],
                                    stops: const [0.0, 0.5, 1.0],
                                  ),
                                ),
                              ),
                            );
                          },
                          onEnd: () {
                            // Restart animation when it reaches the bottom
                            if (mounted) {
                              setState(() {});
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Identifying Fish Species',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF006064),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please wait...',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );

    // Add a minimum delay of 4 seconds for the scanning animation
    await Future.delayed(const Duration(seconds: 4));

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
        
        // Create temp prediction to get the fish names
        final commonName = decodedResponse['common_name'] ?? 'Unknown';
        final scientificName = decodedResponse['scientific_name'] ?? 'Unknown';
        
        // Generate description using OpenAI
        String description = '';
        try {
          description = await OpenAIService.generateFishDescription(
            commonName, 
            scientificName
          );
        } catch (e) {
          print('Error generating description: $e');
          description = 'No description available. Try again later.';
        }
        
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
          temperatureRange: decodedResponse['temperature_range_c'] ?? '',
          phRange: decodedResponse['ph_range'] ?? '',
          socialBehavior: decodedResponse['social_behavior'] ?? '',
          minimumTankSize: decodedResponse['minimum_tank_size_l'] != null ? '${decodedResponse['minimum_tank_size_l']} L' : ''
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
        
        if (decodedResponse.containsKey('has_fish') && decodedResponse['has_fish'] == false) {
          if (mounted) {
            showCustomNotification(
              context,
              'No fish detected in the image. Please try again with a clearer image.',
              isError: true,
            );
          }
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
                'Prediction Result',
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
                    child: Image.file(
                      File(imageFile.path),
                      fit: BoxFit.cover,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          highestPrediction.commonName,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF006064),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          highestPrediction.scientificName,
                          style: TextStyle(
                            fontSize: 20,
                            fontStyle: FontStyle.italic,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        // Add description section before Basic Information
                        DescriptionWidget(
                          description: highestPrediction.description,
                          maxLines: 3,
                        ),
                        
                        // Add fish images grid right after description
                        const SizedBox(height: 20),
                        FishImagesGrid(fishName: highestPrediction.commonName),
                        
                        const SizedBox(height: 40),
                        const Text(
                          'Basic Information',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF006064),
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildDetailRow('Water Type', highestPrediction.waterType),
                        _buildDetailRow('Maximum Size', highestPrediction.maxSize),
                        _buildDetailRow('Temperament', highestPrediction.temperament),
                        _buildDetailRow('Care Level', highestPrediction.careLevel),
                        _buildDetailRow('Lifespan', highestPrediction.lifespan),
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
                        _buildDetailRow('Temperature Range', highestPrediction.temperatureRange.isNotEmpty ? highestPrediction.temperatureRange : 'Unknown'),
                        _buildDetailRow('pH Range', highestPrediction.phRange.isNotEmpty ? highestPrediction.phRange : 'Unknown'),
                        _buildDetailRow('Minimum Tank Size', highestPrediction.minimumTankSize.isNotEmpty ? highestPrediction.minimumTankSize : 'Unknown'),
                        _buildDetailRow('Social Behavior', highestPrediction.socialBehavior.isNotEmpty ? highestPrediction.socialBehavior : 'Unknown'),
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
                        _buildDetailRow('Diet Type', highestPrediction.diet),
                        _buildDetailRow('Preferred Food', highestPrediction.preferredFood),
                        _buildDetailRow('Feeding Frequency', highestPrediction.feedingFrequency),
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
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text(
                                  'Retry',
                                  style: TextStyle(
                                    color: Colors.black87,
                                    fontSize: 18,
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
                                    if (isFirstFish) {
                                      _selectedFish1 = highestPrediction.commonName;
                                      // _controller1.text = highestPrediction.commonName;
                                    } else {
                                      _selectedFish2 = highestPrediction.commonName;
                                      // _controller2.text = highestPrediction.commonName;
                                    }
                                  });
                                  Navigator.of(context).pop();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00ACC1),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text(
                                  'Select Fish',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                  ),
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

  void _showSnapTips() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const SnapTipsDialog(),
    );
  }


  Future<void> _loadUserPlan() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final data = await Supabase.instance.client
          .from('profiles')
          .select('tier_plan')
          .eq('id', user.id)
          .single();
      setState(() {
        _userPlan = data['tier_plan'] ?? 'free';
      });
    }
  }

  Future<void> _loadCompatibilityChecksCount() async {
    if (_userPlan == 'free') {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        try {
          final data = await Supabase.instance.client
              .from('profiles')
              .select('compatibility_checks_count')
              .eq('id', user.id)
              .single();
          setState(() {
            _compatibilityChecksCount = data['compatibility_checks_count'] ?? 0;
          });
        } catch (e) {
          print('Error loading compatibility checks count: $e');
          setState(() {
            _compatibilityChecksCount = 0;
          });
        }
      }
    }
  }

  Future<void> _incrementCompatibilityChecksCount() async {
    if (_userPlan == 'free') {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        try {
          await Supabase.instance.client
              .from('profiles')
              .update({
                'compatibility_checks_count': _compatibilityChecksCount + 1
              })
              .eq('id', user.id);
          setState(() {
            _compatibilityChecksCount++;
          });
        } catch (e) {
          print('Error incrementing compatibility checks count: $e');
        }
      }
    }
  }

  bool _canCheckCompatibility() {
    if (_userPlan == 'free' && _compatibilityChecksCount >= 2) {
      _showUpgradeDialog('You have reached the limit of 2 compatibility checks for the free plan. Upgrade to Pro for unlimited checks with detailed breakdown and advanced deep compatibility analysis!');
      return false;
    }
    return true;
  }

  void _showUpgradeDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Upgrade to Pro'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SubscriptionPage()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00ACC1),
              ),
              child: const Text('Upgrade to Pro'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _checkCompatibility() async {
    if (!_canCheckCompatibility()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await ApiConfig.makeRequestWithFailover(
        endpoint: '/check-group',
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        },
        body: jsonEncode({
          'fish_names': [_selectedFish1!, _selectedFish2!],
        }),
      );

      if (response != null) {
        final decodedResponse = jsonDecode(response.body);
        final results = decodedResponse['results'] as List;
        
        if (results.isNotEmpty) {
          final firstResult = results[0];
          final isCompatible = firstResult['compatibility'] == 'Compatible';
          final baseReasons = List<String>.from(firstResult['reasons']);

          String? fish1Base64 = firstResult['fish1_image'];
          String? fish2Base64 = firstResult['fish2_image'];
          if (fish1Base64 != null && fish1Base64.contains(',')) {
            fish1Base64 = fish1Base64.split(',')[1];
          }
          if (fish2Base64 != null && fish2Base64.contains(',')) {
            fish2Base64 = fish2Base64.split(',')[1];
          }

          setState(() {
            _fish1Name = _selectedFish1!;
            _fish2Name = _selectedFish2!;
            _fish1Base64Image = fish1Base64;
            _fish2Base64Image = fish2Base64;
            if (_capturedImage1 != null) {
              _fish1ImagePath = _capturedImage1!.path;
            } else if (_fish1ImagePath.isEmpty) {
              // Store the fish name so the renderer can resolve via /fish-image/{name}
              _fish1ImagePath = _selectedFish1!;
            }
            if (_capturedImage2 != null) {
              _fish2ImagePath = _capturedImage2!.path;
            } else if (_fish2ImagePath.isEmpty) {
              // Store the fish name so the renderer can resolve via /fish-image/{name}
              _fish2ImagePath = _selectedFish2!;
            }
          });
          
          // Increment the count before showing results
          if (_userPlan == 'free') {
            await _incrementCompatibilityChecksCount();
          }
          
          if (mounted) {
            _showCompatibilityDialog(isCompatible, baseReasons);
          }
        }
      } else {
        throw Exception('Failed to check compatibility - no servers available');
      }
    } catch (e) {
      print('Error checking compatibility: $e');
      showCustomNotification(
        context,
        'Error checking compatibility: Provide details for Fish 2',
        isError: true,
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showCompatibilityDialog(bool isCompatible, List<String> baseReasons) {
    List<String> currentReasons = baseReasons;
    bool isLoadingDetails = false;
    bool hasFetched = false;

    // Normalize plan string for robust comparison
    String normalizedPlan = _userPlan.trim().toLowerCase().replaceAll(' ', '_');

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Only fetch detailed reasons for Pro
            if (!hasFetched && !isCompatible && normalizedPlan == 'pro') {
              hasFetched = true;
              isLoadingDetails = true;
              OpenAIService.explainIncompatibilityReasons(
                _fish1Name,
                _fish2Name,
                baseReasons,
              ).then((detailedReasons) {
                if (mounted) {
                  setDialogState(() {
                    currentReasons = detailedReasons;
                    isLoadingDetails = false;
                  });
                }
              }).catchError((e) {
                print('Error fetching detailed reasons: $e');
                if (mounted) {
                  setDialogState(() {
                    isLoadingDetails = false;
                  });
                }
              });
            }

            return Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                width: MediaQuery.of(dialogContext).size.width,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(dialogContext).size.height * 0.9,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: _buildFishResultImageWithBase64(_capturedImage1, _fish1Base64Image, _fish1ImagePath),
                                ),
                                Container(
                                  height: 2,
                                  width: 40,
                                  margin: const EdgeInsets.symmetric(horizontal: 8),
                                  color: const Color(0xFF006064),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: _buildFishResultImageWithBase64(_capturedImage2, _fish2Base64Image, _fish2ImagePath),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            Text(
                              '$_fish1Name & $_fish2Name',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF006064),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  isCompatible ? Icons.check_circle : Icons.cancel,
                                  color: isCompatible ? Colors.green : Colors.red,
                                  size: 24,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isCompatible ? 'Compatible' : 'Not Compatible',
                                  style: TextStyle(
                                    color: isCompatible ? Colors.green : Colors.red,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (_userPlan != 'free')
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
                          ),
                          child: isLoadingDetails
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const SizedBox(height: 24),
                                    _buildLoadingAnimation(),
                                    const SizedBox(height: 24),
                                    const Text(
                                      'Analyzing compatibility...',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Color(0xFF006064),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'This may take a few seconds',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.black54,
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                  ],
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: const [
                                        Text(
                                          'Details:',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF006064),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    ...List.generate(
                                      currentReasons.length,
                                      (index) => Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 6),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Icon(
                                              Icons.info,
                                              size: 20,
                                              color: isCompatible ? Colors.green : Colors.red,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                isCompatible && index == 0
                                                    ? "Both can be kept together in the same aquarium"
                                                    : currentReasons[index],
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  color: Colors.black87,
                                                  height: 1.4,
                                                ),
                                                textAlign: TextAlign.justify,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextButton(
                                            onPressed: () {
                                              Navigator.of(dialogContext).pop();
                                            },
                                            style: TextButton.styleFrom(
                                              backgroundColor: Colors.grey[200],
                                              padding: const EdgeInsets.symmetric(vertical: 12),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                            ),
                                            child: const Text(
                                              'Close',
                                              style: TextStyle(
                                                color: Colors.black87,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ),
                                        ),
                                        if (_userPlan == 'pro') ...[
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: ElevatedButton(
                                              onPressed: () {
                                                final logbookProvider = Provider.of<LogBookProvider>(context, listen: false);
                                                final newResult = CompatibilityResult(
                                                  fish1Name: _fish1Name,
                                                  fish1ImagePath: _fish1ImagePath,
                                                  fish2Name: _fish2Name,
                                                  fish2ImagePath: _fish2ImagePath,
                                                  isCompatible: isCompatible,
                                                  reasons: currentReasons,
                                                  dateChecked: DateTime.now(),
                                                  savedPlan: _userPlan,
                                                );
                                                logbookProvider.addCompatibilityResult(newResult);
                                                Navigator.of(dialogContext).pop();
                                                showCustomNotification(context, 'Result saved to History');
                                              },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF00ACC1),
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(vertical: 12),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                              ),
                                              child: const Text(
                                                'Save',
                                                style: TextStyle(fontSize: 16),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
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

  Widget _buildNetworkFishImage(String imagePathOrName) {
    final width = MediaQuery.of(context).size.width * 0.35;

    // If a URL is provided, but it's the API endpoint (/fish-image/{name}),
    // we must resolve it first. Only treat as direct image if it's NOT the API.
    if (imagePathOrName.startsWith('http')) {
      final lower = imagePathOrName.toLowerCase();
      final isApiEndpoint = lower.contains('/fish-image/');
      if (!isApiEndpoint) {
        return Image.network(
          imagePathOrName,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(
              Icons.error_outline,
              color: Colors.grey,
              size: 40,
            );
          },
        );
      }

      // Extract fish name from the API URL path if possible
      try {
        final uri = Uri.parse(imagePathOrName);
        final idx = uri.pathSegments.indexOf('fish-image');
        if (idx != -1 && idx + 1 < uri.pathSegments.length) {
          imagePathOrName = Uri.decodeComponent(uri.pathSegments[idx + 1]);
        }
      } catch (_) {
        // If parsing fails, fall back to using the original string as a name
      }
    }

    // Resolve via backend: fetch JSON to get the real image URL
    return FutureBuilder<http.Response?>(
      future: ApiConfig.makeRequestWithFailover(
        endpoint: '/fish-image/${Uri.encodeComponent(imagePathOrName)}',
        method: 'GET',
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            width: width,
            height: width,
            color: Colors.grey[200],
          );
        }
        final resp = snapshot.data;
        if (resp != null && resp.statusCode == 200) {
          try {
            final Map<String, dynamic> jsonData = json.decode(resp.body);
            final String url = (jsonData['url'] ?? '').toString();
            if (url.isNotEmpty) {
              return Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.error_outline,
                    color: Colors.grey,
                    size: 40,
                  );
                },
              );
            }
          } catch (_) {}
        }
        return const Icon(
          Icons.error_outline,
          color: Colors.grey,
          size: 40,
        );
      },
    );
  }

  Widget _buildFishResultImageWithBase64(File? capturedImage, String? base64Image, String imagePathOrName) {
    final width = MediaQuery.of(context).size.width * 0.35;
    return Container(
      width: width,
      height: width,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: capturedImage != null
            ? Image.file(
                capturedImage,
                fit: BoxFit.cover,
              )
            : () {
                // Prefer base64 image if provided. Decode safely and fall back to network on error.
                if (base64Image != null && base64Image.isNotEmpty) {
                  try {
                    final String cleaned = base64Image.contains(',')
                        ? base64Image.split(',')[1]
                        : base64Image;
                    final bytes = base64Decode(cleaned);
                    return Image.memory(
                      bytes,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        // If base64 render fails, attempt local file path next, then network.
                        try {
                          if (imagePathOrName.isNotEmpty && File(imagePathOrName).existsSync()) {
                            return Image.file(
                              File(imagePathOrName),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return _buildNetworkFishImage(imagePathOrName);
                              },
                            );
                          }
                        } catch (_) {
                          // Ignore and fall through to network
                        }
                        return _buildNetworkFishImage(imagePathOrName);
                      },
                    );
                  } catch (e) {
                    // If base64 is invalid, try local file path first, then network
                    try {
                      if (imagePathOrName.isNotEmpty && File(imagePathOrName).existsSync()) {
                        return Image.file(
                          File(imagePathOrName),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildNetworkFishImage(imagePathOrName);
                          },
                        );
                      }
                    } catch (_) {
                      // Ignore and fall through to network
                    }
                    return _buildNetworkFishImage(imagePathOrName);
                  }
                }
                // No captured or base64 image: try local file path first, then network URL.
                try {
                  if (imagePathOrName.isNotEmpty && File(imagePathOrName).existsSync()) {
                    return Image.file(
                      File(imagePathOrName),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildNetworkFishImage(imagePathOrName);
                      },
                    );
                  }
                } catch (_) {
                  // Ignore and fall through to network
                }
                return _buildNetworkFishImage(imagePathOrName);
              }(),
      ),
    );
  }

  Widget _buildLoadingAnimation() {
    return SizedBox(
      width: 250,
      height: 250,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(seconds: 3),
        builder: (context, value, child) {
          return Lottie.asset(
            'lib/lottie/BowlAnimation.json',
            width: 250,
            height: 250,
            fit: BoxFit.contain,
            repeat: false,
            frameRate: FrameRate(60),
          );
        },
      ),
    );
  }

  void _onClearPressed() {
    setState(() {
      _selectedFish1 = null;
      _selectedFish2 = null;
      // _controller1.clear();
      // _controller2.clear();
      // _suggestions1 = [];
      // _suggestions2 = [];
      _fish1Name = '';
      _fish2Name = '';
      _fish1ImagePath = '';
      _fish2ImagePath = '';
      _capturedImage1 = null;
      _capturedImage2 = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Stack(
        children: [
          _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF00BCD4),
                  ),
                )
              : SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 16.0),
                    child: Column(
                      children: [
                        _buildFishSelector(true),
                        const SizedBox(height: 16),
                        _buildFishSelector(false),
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              SizedBox(
                                width: 120,
                                child: ElevatedButton(
                                  onPressed: _onClearPressed,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.grey[300],
                                    foregroundColor: Colors.black87,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Text(
                                    'Clear',
                                    style: TextStyle(fontSize: 14),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 120,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _checkCompatibility,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF00ACC1),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        )
                                      : const Text(
                                          'Check',
                                          style: TextStyle(fontSize: 14),
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
          // Suggestion lists are no longer needed
          /*
          if (_suggestions1.isNotEmpty)
            Positioned(
              top: 216,
              left: 16,
              right: 16,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: _suggestions1.length,
                    itemBuilder: (context, index) => InkWell(
                      onTap: () {
                        setState(() {
                          _selectedFish1 = _suggestions1[index];
                          _controller1.text = _suggestions1[index];
                          _suggestions1 = [];
                        });
                        FocusScope.of(context).unfocus();
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Text(
                          _suggestions1[index],
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (_suggestions2.isNotEmpty)
            Positioned(
              top: 412, // Adjusted for second fish selector
              left: 16,
              right: 16,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: _suggestions2.length,
                    itemBuilder: (context, index) => InkWell(
                      onTap: () {
                        setState(() {
                          _selectedFish2 = _suggestions2[index];
                          _controller2.text = _suggestions2[index];
                          _suggestions2 = [];
                        });
                        FocusScope.of(context).unfocus();
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Text(
                          _suggestions2[index],
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            */
        ],
      ),
    );
  }

  Widget _buildFishSelector(bool isFirstFish) {
    // final controller = isFirstFish ? _controller1 : _controller2;
    final selectedFish = isFirstFish ? _selectedFish1 : _selectedFish2;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.07),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isFirstFish ? 'First Fish' : 'Second Fish',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF006064),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildCaptureButton(isFirstFish),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownSearch<String>(
                  popupProps: PopupProps.menu(
                    showSearchBox: true,
                    isFilterOnline: true, // Correct parameter for filtering
                    searchFieldProps: TextFieldProps(
                      decoration: InputDecoration(
                        hintText: "Search for a fish",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    menuProps: MenuProps(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  items: _fishSpecies,
                  dropdownDecoratorProps: DropDownDecoratorProps(
                    dropdownSearchDecoration: InputDecoration(
                      hintText: "Select a fish",
                      filled: true,
                      fillColor: const Color(0xFFF5F5F5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  onChanged: (String? newValue) {
                    setState(() {
                      if (isFirstFish) {
                        _selectedFish1 = newValue;
                      } else {
                        _selectedFish2 = newValue;
                      }
                    });
                  },
                  selectedItem: selectedFish,
                ),
              ),
            ],
          ),
          if (selectedFish != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                'Selected: $selectedFish',
                style: const TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCaptureButton(bool isFirstFish) {
    return ElevatedButton(
      onPressed: () => _showCaptureOptions(isFirstFish),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF00ACC1),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.all(8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
        minimumSize: const Size(0, 0), // Allow button to be smaller
      ),
      child: const Icon(Icons.camera_alt, size: 20),
    );
  }

  Future<void> _showCaptureOptions(bool isFirstFish) async {
    return showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                isFirstFish ? 'Capture First Fish' : 'Capture Second Fish',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF006064),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Column(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.camera, size: 40, color: Color(0xFF00ACC1)),
                        onPressed: () {
                          Navigator.pop(context);
                          _captureImageForIdentification(isFirstFish);
                        },
                      ),
                      const Text('Camera'),
                    ],
                  ),
                  Column(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.photo_library, size: 40, color: Color(0xFF00ACC1)),
                        onPressed: () {
                          Navigator.pop(context);
                          _pickImageForIdentification(isFirstFish);
                        },
                      ),
                      const Text('Gallery'),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Future<void> _captureImageForIdentification(bool isFirstFish) async {
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
                            borderRadius: BorderRadius.circular(10),
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
                                    if (!result) {
                                      showCustomNotification(
                                        context,
                                        'No fish detected in the image. Please try again with a clearer image.',
                                        isError: true,
                                      );
                                    } else {
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

  Future<void> _pickImageForIdentification(bool isFirstFish) async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        final result = await _getPredictions(image, isFirstFish);
        if (!result && mounted) {
          showCustomNotification(
            context,
            'No fish detected in the image. Please try again with a clearer image.',
            isError: true,
          );
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
  }
}
