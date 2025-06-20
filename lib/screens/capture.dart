import 'dart:async';
import 'dart:io' as io;
import 'dart:io' show File;
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/services.dart';  // Add this import for PlatformException
import 'logbook_provider.dart';
import '../models/fish_prediction.dart';
import '../config/api_config.dart';
import '../widgets/custom_notification.dart';
import '../screens/homepage.dart';
import '../widgets/snap_tips_dialog.dart';
import '../services/openai_service.dart';
import '../widgets/description_widget.dart';
import '../widgets/fish_images_grid.dart';

class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});

  @override
  CaptureScreenState createState() => CaptureScreenState();
}

class CaptureScreenState extends State<CaptureScreen> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  bool _isCameraAvailable = false;

  String get apiUrl => ApiConfig.predictEndpoint;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _isCameraAvailable = false;
        });
        return;
      }

      final firstCamera = cameras.first;
      _controller = CameraController(
        firstCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      _initializeControllerFuture = _controller?.initialize();
      if (mounted) {
        setState(() {
          _isCameraAvailable = true;
        });
      }
    } catch (e) {
      print('Camera initialization error: $e');
      if (mounted) {
        setState(() {
          _isCameraAvailable = false;
        });
        showCustomNotification(
          context,
          'Camera not available: $e',
          isError: true,
        );
      }
    }
  }

  Future<String> _saveImageToStorage(XFile imageFile) async {
    if (kIsWeb) return imageFile.path;  // For web, return the original path
    
    final directory = await getApplicationDocumentsDirectory();
    final fileName = 'fish_${DateTime.now().millisecondsSinceEpoch}${path.extension(imageFile.path)}';
    final savedImage = await io.File(imageFile.path).copy('${directory.path}/$fileName');
    return savedImage.path;
  }

  Future<void> _analyzeFishImage(XFile imageFile, String savedImagePath) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Show loading dialog with scanning animation
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Dialog(
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
      }

      // Add a minimum delay of 3 seconds for the scanning animation
      await Future.delayed(const Duration(seconds: 3));

      final uri = Uri.parse(ApiConfig.predictEndpoint);
      
      var request = http.MultipartRequest('POST', uri);
      
      // Add the image file to the request
      if (kIsWeb) {
        final byteData = await imageFile.readAsBytes();
        request.files.add(http.MultipartFile.fromBytes(
          'file',
          byteData,
          filename: 'image.jpg',
        ));
      } else {
        request.files.add(await http.MultipartFile.fromPath(
          'file',
          imageFile.path,
          filename: 'image.jpg',
        ));
      }

      print('Sending request...');
      var streamedResponse = await request.send();
      print('Response status code: ${streamedResponse.statusCode}');
      
      var response = await http.Response.fromStream(streamedResponse);
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        var decodedResponse = json.decode(response.body);
        print('Decoded response: $decodedResponse');
        
        // Check if the confidence is low (less than 60%)
        final confidenceLevel = decodedResponse['classification_confidence'] ?? 0;
        final bool isLowConfidence = confidenceLevel < 0.60;
        
        if (isLowConfidence && !kIsWeb) {
          print('Low confidence detection (${(confidenceLevel * 100).toStringAsFixed(2)}%), trying OpenAI Vision API');
          
          // Show a different loading dialog for AI analysis
          if (mounted) {
            Navigator.pop(context); // Close the previous loading dialog
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => Dialog(
                backgroundColor: Colors.transparent,
                elevation: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Colors.teal),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        "Using AI for detailed analysis...",
                        style: TextStyle(color: Colors.teal),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          
          // Use OpenAI Vision API for better identification
          final aiResult = await OpenAIService.analyzeUnidentifiedFish(File(imageFile.path));
          
          if (mounted) {
            Navigator.pop(context); // Close the AI loading dialog
          }
          
          // Create an AI-assisted prediction
          FishPrediction aiPrediction = FishPrediction(
            commonName: aiResult['common_name'] ?? 'Unidentified Fish',
            scientificName: aiResult['scientific_name'] ?? 'Unknown',
            waterType: aiResult['water_type'] ?? 'Unknown',
            probability: '${aiResult['confidence_level'] ?? 'Low'} (AI-assisted)',
            imagePath: savedImagePath,
            maxSize: 'Unknown (AI estimate)',
            temperament: 'Unknown (AI estimate)',
            careLevel: 'Unknown (AI estimate)',
            lifespan: 'Unknown (AI estimate)',
            diet: 'Unknown (AI estimate)',
            preferredFood: 'Unknown (AI estimate)',
            feedingFrequency: 'Unknown (AI estimate)',
            description: aiResult['care_notes'] ?? 'No AI-generated description available.',
            temperatureRange: aiResult['temperature_range'] ?? 'Unknown (AI estimate)',
            phRange: aiResult['pH_range'] ?? 'Unknown (AI estimate)',
            socialBehavior: aiResult['social_behavior'] ?? 'Unknown (AI estimate)',
            minimumTankSize: aiResult['tank_size'] ?? 'Unknown (AI estimate)'
          );
          
          // Add distinctive features to the description
          if (aiResult.containsKey('distinctive_features') && 
              aiResult['distinctive_features'] != null &&
              aiResult['distinctive_features'].toString().isNotEmpty) {
            aiPrediction = aiPrediction.copyWith(
              description: 'Distinctive features: ${aiResult['distinctive_features']}\n\n${aiPrediction.description}'
            );
          }
          
          if (mounted) {
            _showAiAssistedResults(imageFile, aiPrediction);
          }
          
        } else {
          // Proceed with regular prediction
          FishPrediction prediction = FishPrediction(
            commonName: decodedResponse['common_name'] ?? 'Unknown',
            scientificName: decodedResponse['scientific_name'] ?? 'Unknown',
            waterType: decodedResponse['water_type'] ?? 'Unknown',
            probability: '${((decodedResponse['classification_confidence'] ?? 0) * 100).toStringAsFixed(2)}%',
            imagePath: savedImagePath,  // Use the saved image path
            maxSize: '${decodedResponse['max_size'] ?? 'Unknown'}',
            temperament: decodedResponse['temperament'] ?? 'Unknown',
            careLevel: decodedResponse['care_level'] ?? 'Unknown',
            lifespan: '${decodedResponse['lifespan'] ?? 'Unknown'}',
            diet: decodedResponse['diet'] ?? 'Unknown',
            preferredFood: decodedResponse['preferred_food'] ?? 'Unknown',
            feedingFrequency: decodedResponse['feeding_frequency'] ?? 'Unknown',
            description: '',  // Empty description that will be filled by OpenAI API
            temperatureRange: decodedResponse['temperature_range_c'] ?? '',
            phRange: decodedResponse['ph_range'] ?? '',
            socialBehavior: decodedResponse['social_behavior'] ?? '',
            minimumTankSize: decodedResponse['minimum_tank_size_l'] != null ? '${decodedResponse['minimum_tank_size_l']} L' : ''
          );

          print('Created prediction object: ${prediction.toJson()}');

          if (mounted) {
            Navigator.pop(context); // Close the scanning dialog
            _loadDescriptionAndShowResults(imageFile, prediction, prediction.commonName, prediction.scientificName);
          }
        }
      } else if (response.statusCode == 404) {
        // Check if this is a "fish not found in database" error
        var decodedResponse = json.decode(response.body);
        
        if (decodedResponse.containsKey('has_fish') && decodedResponse['has_fish'] == true &&
            decodedResponse.containsKey('predicted_name')) {
          // Fish was detected but not found in the database, try OpenAI Vision
          if (!kIsWeb) {
            print('Fish detected but not in database, trying OpenAI Vision API');
            
            // Show a different loading dialog for AI analysis
            if (mounted) {
              Navigator.pop(context); // Close the previous loading dialog
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => Dialog(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: Colors.teal),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          "Using AI for detailed analysis...",
                          style: TextStyle(color: Colors.teal),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            
            // Use OpenAI Vision API for better identification
            final aiResult = await OpenAIService.analyzeUnidentifiedFish(File(imageFile.path));
            
            if (mounted) {
              Navigator.pop(context); // Close the AI loading dialog
            }
            
            // Create an AI-assisted prediction
            FishPrediction aiPrediction = FishPrediction(
              commonName: aiResult['common_name'] ?? decodedResponse['predicted_name'] ?? 'Unidentified Fish',
              scientificName: aiResult['scientific_name'] ?? 'Unknown',
              waterType: aiResult['water_type'] ?? 'Unknown',
              probability: '${aiResult['confidence_level'] ?? 'Low'} (AI-assisted)',
              imagePath: savedImagePath,
              maxSize: 'Unknown (AI estimate)',
              temperament: 'Unknown (AI estimate)',
              careLevel: 'Unknown (AI estimate)',
              lifespan: 'Unknown (AI estimate)',
              diet: 'Unknown (AI estimate)',
              preferredFood: 'Unknown (AI estimate)',
              feedingFrequency: 'Unknown (AI estimate)',
              description: aiResult['care_notes'] ?? 'No AI-generated description available.',
              temperatureRange: aiResult['temperature_range'] ?? 'Unknown (AI estimate)',
              phRange: aiResult['pH_range'] ?? 'Unknown (AI estimate)',
              socialBehavior: aiResult['social_behavior'] ?? 'Unknown (AI estimate)',
              minimumTankSize: aiResult['tank_size'] ?? 'Unknown (AI estimate)'
            );
            
            // Add distinctive features to the description
            if (aiResult.containsKey('distinctive_features') && 
                aiResult['distinctive_features'] != null &&
                aiResult['distinctive_features'].toString().isNotEmpty) {
              aiPrediction = aiPrediction.copyWith(
                description: 'Distinctive features: ${aiResult['distinctive_features']}\n\n${aiPrediction.description}'
              );
            }
            
            if (mounted) {
              _showAiAssistedResults(imageFile, aiPrediction);
            }
          } else {
            // For web version, just show an error
            if (mounted) {
              Navigator.pop(context); // Close the scanning dialog
              showCustomNotification(
                context,
                'Fish detected but not found in our database.',
                isError: true,
              );
            }
          }
        } else {
          // Handle other 404 errors
          if (mounted) {
            Navigator.pop(context);
            showCustomNotification(
              context,
              'Error: ${decodedResponse['detail']}',
              isError: true,
            );
          }
        }
      } else if (response.statusCode == 400) {
        if (mounted) {
          Navigator.pop(context); // Close the scanning dialog
        }
        var decodedResponse = json.decode(response.body);
        
        // Check if the error is due to no fish being detected
        if (decodedResponse.containsKey('has_fish') && decodedResponse['has_fish'] == false) {
          if (mounted) {
            showCustomNotification(
              context,
              'No fish detected in the image. Please try again with a clearer image.',
              isError: true,
            );
          }
        } else {
          throw Exception('API returned error: ${decodedResponse['detail']}');
        }
      } else {
        print('Error response: ${response.body}');
        throw Exception('Failed to get predictions. Status code: ${response.statusCode}, Body: ${response.body}');
      }
    } catch (e, stackTrace) {
      if (mounted) {
        Navigator.pop(context); // Close the scanning dialog
      }
      print('Error getting predictions: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        showCustomNotification(
          context,
          'Failed to get predictions: ${e.toString()}',
          isError: true,
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _savePredictions(List<FishPrediction> predictions) async {
    final logBookProvider = Provider.of<LogBookProvider>(context, listen: false);
    
    try {
      final bool saved = await logBookProvider.addPredictions(predictions);

      if (saved) {
        if (mounted) {
          showCustomNotification(context, 'Fish saved to collection');
          
          // Wait for 1.5 seconds to ensure notification is visible
          await Future.delayed(const Duration(milliseconds: 1500));
          
          // Navigate to homepage if the widget is still mounted
          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (context) => const HomePage(initialTabIndex: 1),
              ),
              (route) => false,
            );
          }
        }
      } else {
        if (mounted) {
          showCustomNotification(context, 'Fish already exists in collection');
        }
      }
    } catch (e) {
      print('Error saving prediction: $e');
      if (mounted) {
        showCustomNotification(context, 'Error saving fish to collection');
      }
    }
  }

  void _showPredictionResults(XFile imageFile, List<FishPrediction> predictions) {
    final highestPrediction = predictions.reduce((curr, next) {
      double currProb = double.parse(curr.probability.replaceAll('%', ''));
      double nextProb = double.parse(next.probability.replaceAll('%', ''));
      return currProb > nextProb ? curr : next;
    });

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (BuildContext context) {
          return WillPopScope(
            onWillPop: () async {
              Navigator.of(context).pop();
              return false;
            },
            child: Scaffold(
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
                      height: 300, // Increased image height
                      child: kIsWeb
                          ? Image.network(
                              imageFile.path,
                              fit: BoxFit.cover,
                            )
                          : Image.file(
                              io.File(imageFile.path),
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
                          
                          // Description section - moved above Basic Information
                          DescriptionWidget(
                            description: highestPrediction.description,
                            maxLines: 3,
                          ),
                          
                          // Add fish images grid right after description
                          const SizedBox(height: 20),
                          FishImagesGrid(fishName: highestPrediction.commonName),
                          
                          const SizedBox(height: 30), // Space between description and basic info
                          const Text(
                            'Basic Information',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF006064),
                            ),
                          ),
                          const SizedBox(height: 20), // Increased spacing
                          _buildDetailRow('Water Type', highestPrediction.waterType),
                          _buildDetailRow('Maximum Size', highestPrediction.maxSize),
                          _buildDetailRow('Temperament', highestPrediction.temperament),
                          _buildDetailRow('Care Level', highestPrediction.careLevel),
                          _buildDetailRow('Lifespan', highestPrediction.lifespan),
                          const SizedBox(height: 40), // Increased spacing
                          
                          const Text(
                            'Habitat Information',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF006064),
                            ),
                          ),
                          const SizedBox(height: 20), // Increased spacing
                          _buildDetailRow('Temperature Range', highestPrediction.temperatureRange.isNotEmpty ? highestPrediction.temperatureRange : 'Unknown'),
                          _buildDetailRow('pH Range', highestPrediction.phRange.isNotEmpty ? highestPrediction.phRange : 'Unknown'),
                          _buildDetailRow('Minimum Tank Size', highestPrediction.minimumTankSize.isNotEmpty ? highestPrediction.minimumTankSize : 'Unknown'),
                          _buildDetailRow('Social Behavior', highestPrediction.socialBehavior.isNotEmpty ? highestPrediction.socialBehavior : 'Unknown'),
                          const SizedBox(height: 40), // Increased spacing
                          
                          const Text(
                            'Diet Information',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF006064),
                            ),
                          ),
                          const SizedBox(height: 20), // Increased spacing
                          _buildDetailRow('Diet Type', highestPrediction.diet),
                          _buildDetailRow('Preferred Food', highestPrediction.preferredFood),
                          _buildDetailRow('Feeding Frequency', highestPrediction.feedingFrequency),
                          const SizedBox(height: 40), // Increased spacing
                          
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF006064),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: () {
                                    _savePredictions([highestPrediction]);
                                  },
                                  child: const Text(
                                    'Save',
                                    style: TextStyle(fontSize: 18),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF00ACC1),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: () {
                                    final logBookProvider = Provider.of<LogBookProvider>(context, listen: false);
                                    logBookProvider.addPredictions([highestPrediction]);
                                    
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => HomePage(
                                          initialTabIndex: 3,
                                          initialFish: highestPrediction.commonName,
                                          initialFishImage: io.File(imageFile.path),
                                        ),
                                      ),
                                    );
                                  },
                                  child: const Text(
                                    'Sync',
                                    style: TextStyle(fontSize: 18),
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
          );
        },
      ),
    );
  }

  // Method to load the description and then show results
  Future<void> _loadDescriptionAndShowResults(XFile imageFile, FishPrediction prediction, String commonName, String scientificName) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Center(
          child: CircularProgressIndicator(
            color: Colors.teal,
          ),
        ),
      ),
    );
    
    try {
      print('Attempting to generate description for $commonName ($scientificName)');
      
      // Generate description using OpenAI
      final description = await OpenAIService.generateFishDescription(
        commonName, 
        scientificName
      );
      
      // Update the prediction with the description
      final updatedPrediction = FishPrediction(
        commonName: prediction.commonName,
        scientificName: prediction.scientificName,
        waterType: prediction.waterType,
        probability: prediction.probability,
        imagePath: prediction.imagePath,
        maxSize: prediction.maxSize,
        temperament: prediction.temperament,
        careLevel: prediction.careLevel,
        lifespan: prediction.lifespan,
        diet: prediction.diet,
        preferredFood: prediction.preferredFood,
        feedingFrequency: prediction.feedingFrequency,
        description: description,
        temperatureRange: prediction.temperatureRange, 
        phRange: prediction.phRange,
        socialBehavior: prediction.socialBehavior,
        minimumTankSize: prediction.minimumTankSize
      );
      
      if (mounted) {
        Navigator.pop(context); // Close the loading dialog
        _showPredictionResults(imageFile, [updatedPrediction]);
      }
    } catch (e) {
      print('Error loading description: $e');
      if (mounted) {
        Navigator.pop(context); // Close the loading dialog
        // Still show results but with an error message
        prediction = FishPrediction(
          commonName: prediction.commonName,
          scientificName: prediction.scientificName,
          waterType: prediction.waterType,
          probability: prediction.probability,
          imagePath: prediction.imagePath,
          maxSize: prediction.maxSize,
          temperament: prediction.temperament,
          careLevel: prediction.careLevel,
          lifespan: prediction.lifespan,
          diet: prediction.diet,
          preferredFood: prediction.preferredFood,
          feedingFrequency: prediction.feedingFrequency,
          description: 'Failed to generate description. Try again later.',
        );
        _showPredictionResults(imageFile, [prediction]);
      }
    }
  }

  Widget _buildDetailRow(String label, String value) {
    // Special handling for care level to include explanation
    if (label == 'Care Level') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
            const SizedBox(height: 4),
          ],
        ),
      );
    }

    // Default row layout for other details
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

  Future<void> _captureImage() async {
    if (_controller == null || !_isCameraAvailable) {
      showCustomNotification(
        context,
        'Camera is not available',
        isError: true,
      );
      return;
    }

    try {
      await _initializeControllerFuture;
      final image = await _controller!.takePicture();
      await _analyzeFishImage(image, await _saveImageToStorage(image));
    } catch (e) {
      print('Image capture error: $e');
      showCustomNotification(
        context,
        'Failed to capture image: $e',
        isError: true,
      );
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 85, // Slightly reduced quality for better reliability
        maxWidth: 1200,  // Reasonable max dimensions to avoid huge files
        maxHeight: 1200,
      );
      
      if (image != null) {
        // Verify the image exists and is accessible
        try {
          if (!kIsWeb) {
            final file = io.File(image.path);
            if (!await file.exists()) {
              throw Exception('Selected image file does not exist');
            }
          }
          await _analyzeFishImage(image, await _saveImageToStorage(image));
        } catch (fileError) {
          print('File access error: $fileError');
          showCustomNotification(
            context,
            'Cannot access the selected image. Please try again or select a different image.',
            isError: true,
          );
        }
      }
    } on PlatformException catch (e) {
      print('Platform-specific image pick error: $e');
      
      // Show specific error messages based on error code
      if (e.code == 'no_valid_image_uri' || e.code == 'photo_access_denied') {
        showCustomNotification(
          context,
          'Cannot access the image. Please check app permissions in settings and try again.',
          isError: true,
        );
      } else {
        showCustomNotification(
          context,
          'Failed to pick image: ${e.message}',
          isError: true,
        );
      }
    } catch (e) {
      print('Image pick error: $e');
      showCustomNotification(
        context,
        'Failed to select image. Please try again.',
        isError: true,
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 221, 233,235),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: const Color(0xFF006064),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text('Fish Identifier', style: TextStyle(color: Color(0xFF006064))),
      ),
      body: Material(
        color: Colors.white,
        child: _buildBody(),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildBody() {
    if (kIsWeb) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Camera preview is not available on web.\nPlease use the gallery picker instead.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _pickImage(ImageSource.gallery),
              child: const Text('Pick from Gallery'),
            ),
          ],
        ),
      );
    }

    if (!_isCameraAvailable || _controller == null) {
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
          final scale = 1 / (_controller!.value.aspectRatio * size.aspectRatio);
          
          return Stack(
            fit: StackFit.expand,
            children: [
              Transform.scale(
                scale: scale,
                child: Center(
                  child: CameraPreview(_controller!),
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
          );
        } else {
          return const Center(child: CircularProgressIndicator());
        }
      },
    );
  }

  Widget _buildBottomBar() {
    return BottomAppBar(
      color: Colors.grey[200],
      height: 100, // Increased height to accommodate labels
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.photo_library, color: Colors.teal),
                onPressed: () => _pickImage(ImageSource.gallery),
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
            onTap: _captureImage,
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
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => const SnapTipsDialog(),
                  );
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
    );
  }

  // Special method to show AI-assisted results with visual indicator
  void _showAiAssistedResults(XFile imageFile, FishPrediction prediction) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (BuildContext context) {
          return WillPopScope(
            onWillPop: () async {
              Navigator.of(context).pop();
              return false;
            },
            child: Scaffold(
              backgroundColor: Colors.white,
              appBar: AppBar(
                backgroundColor: Colors.white,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Color(0xFF006064)),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                title: const Text(
                  'AI-Assisted Analysis',
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
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          kIsWeb
                            ? Image.network(
                                imageFile.path,
                                fit: BoxFit.cover,
                              )
                            : Image.file(
                                io.File(imageFile.path),
                                fit: BoxFit.cover,
                              ),
                          Positioned(
                            top: 10,
                            right: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.auto_awesome,
                                    color: Colors.yellow,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  const Text(
                                    'AI Assisted',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  prediction.commonName,
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF006064),
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.auto_awesome,
                                color: Colors.amber,
                                size: 24,
                              ),
                            ],
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
                          
                          // AI Analysis notice
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.amber.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.info_outline, color: Colors.amber),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'AI-Assisted Identification',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'This identification was provided by AI and may not be as accurate as our standard database. The information provided is our best estimate.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          
                          // Description section
                          if (prediction.description.isNotEmpty) ...[
                            const Text(
                              'Analysis & Care Notes',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              prediction.description,
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.black87,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                          
                          // Basic information
                          const Text(
                            'Basic Information',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          _buildInfoItem('Water Type', prediction.waterType),
                          _buildInfoItem('Confidence', prediction.probability),
                          
                          const SizedBox(height: 30),
                          
                          // Call to action buttons  
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Color(0xFF006064)),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Text(
                                    'Try Again',
                                    style: TextStyle(
                                      color: Color(0xFF006064),
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => _savePredictions([prediction]),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF006064),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Text(
                                    'Save to Collection',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
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
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
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
}