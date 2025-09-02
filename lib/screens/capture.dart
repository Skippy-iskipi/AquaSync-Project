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
import '../services/openai_service.dart'; // OpenAI AI service
import '../widgets/description_widget.dart';
import '../widgets/fish_images_grid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/subscription_page.dart';
import 'package:lottie/lottie.dart';
import '../widgets/auth_required_dialog.dart';

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



  // Plan-based state
  String _userPlan = 'free';
  int _savedCapturesCount = 0;

  // Cache for AI-generated results to avoid re-calling APIs
  static final Map<String, String> _descriptionCache = {};
  static final Map<String, Map<String, dynamic>> _careRecommendationsCache = {};
  static final Map<String, String> _imagePathCache = {};

  // Static methods to access cached data from other screens
  static String? getCachedDescription(String commonName, String scientificName) {
    final cacheKey = '$commonName-$scientificName';
    return _descriptionCache[cacheKey];
  }

  static Map<String, dynamic>? getCachedCareRecommendations(String commonName, String scientificName) {
    final cacheKey = '$commonName-$scientificName';
    return _careRecommendationsCache[cacheKey];
  }

  static String? getCachedImagePath(String commonName, String scientificName) {
    final cacheKey = '$commonName-$scientificName';
    return _imagePathCache[cacheKey];
  }

  String get apiUrl => ApiConfig.predictEndpoint;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _initializeCamera();
    }
    _loadUserPlanAndCount();
  }

  Future<void> _loadUserPlanAndCount() async {
    if (!mounted) return;
    final user = Supabase.instance.client.auth.currentUser;
    String plan = 'free';
    int count = 0;
    if (user != null) {
      try {
        final data = await Supabase.instance.client
            .from('profiles')
            .select('tier_plan')
            .eq('id', user.id)
            .single();
        plan = (data['tier_plan'] ?? 'free').toString().toLowerCase().replaceAll(' ', '_');
      } catch (_) {}
      try {
        // Count saved captures from logbook provider
        if (!mounted) return; // context not valid if unmounted
        final provider = Provider.of<LogBookProvider>(context, listen: false);
        count = provider.savedPredictions.length;
      } catch (_) {}
    } else {
      // For unauthenticated users, set plan to 'free' and count to 0
      plan = 'free';
      count = 0;
    }
    if (!mounted) return;
    setState(() {
      _userPlan = plan;
      _savedCapturesCount = count;
    });
  }

  bool _canSave() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return false; // Don't show dialog here, let the calling method handle it
    }
    if (_userPlan == 'free' && _savedCapturesCount >= 5) return false;
    // Pro tier has unlimited captures
    if (_userPlan == 'pro') return true;
    return true;
  }

  void _showUpgradeDialog(String message) {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      // Show auth required dialog instead
      showDialog(
        context: context,
        builder: (BuildContext context) => const AuthRequiredDialog(
          title: 'Sign In Required',
          message: 'You need to sign in to access premium features and save more captures.',
        ),
      );
      return;
    }
    
    // User is authenticated, show upgrade dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Upgrade to Pro'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.maybePop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.maybePop(context);
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

  // Safely pop the current route/dialog if possible
  void _safePop() {
    if (!mounted) return;
    final navigator = Navigator.of(context, rootNavigator: true);
    navigator.maybePop();
  }

  // Handle back navigation safely to avoid popping when no history exists
  void _handleBack() {
    if (!mounted) return;
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const HomePage(initialTabIndex: 0),
        ),
      );
    }
  }

  // Show snap tips dialog for no fish or low confidence
  void _showSnapTipsDialog(bool fromCamera, String reason) {
    showDialog(
      context: context,
      useRootNavigator: true,
      builder: (context) => SnapTipsDialog(message: reason),
    );
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

  // Normalize temperature range from backend into a clean display string
  String _cleanTempRange(dynamic raw) {
    String s = (raw ?? '').toString().trim();
    if (s.isEmpty) return '';
    // Fix encoding artifacts
    s = s.replaceAll('Â°', '°').replaceAll(' ', ' ');
    // If it doesn't contain °C, append unit for clarity
    final lower = s.toLowerCase();
    if (!lower.contains('°c')) {
      // Avoid duplicating unit if value already ends with a degree symbol
      if (s.contains('°')) {
        s = s.replaceAll('°', '°C');
      } else {
        s = '$s °C';
      }
    }
    return s;
  }

  Future<void> _analyzeFishImage(XFile imageFile, String savedImagePath, {required bool fromCamera}) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
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
                              borderRadius: BorderRadius.circular(20),
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
                                borderRadius: BorderRadius.circular(20),
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
                                    borderRadius: BorderRadius.circular(20),
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
                                      borderRadius: BorderRadius.circular(20),
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

      // Try all configured servers with failover for the multipart request
      http.Response? lastResponse;
      Exception? lastError;
      for (int attempt = 0; attempt < ApiConfig.serverUrls.length; attempt++) {
        final uri = Uri.parse(ApiConfig.predictEndpoint);
        print('Attempt ${attempt + 1} to $uri');

        final client = http.Client();
        try {
          final request = http.MultipartRequest('POST', uri);
          request.headers['Accept'] = 'application/json';
          if (!kIsWeb) {
            request.files.add(await http.MultipartFile.fromPath(
              'file', imageFile.path,
              filename: path.basename(imageFile.path),
            ));
          } else {
            // Web platform: adjust if web capture uses a blob/file picker
            request.files.add(await http.MultipartFile.fromPath(
              'file', imageFile.path,
              filename: path.basename(imageFile.path),
            ));
          }

          print('Sending request to ${uri.toString()}...');
          final streamedResponse = await client.send(request).timeout(ApiConfig.timeout);
          print('Response status code: ${streamedResponse.statusCode}');
          final response = await http.Response.fromStream(streamedResponse);
          print('Response body: ${response.body}');

          // Success
          if (response.statusCode == 200) {
            var decodedResponse = json.decode(response.body);
            print('Decoded response: $decodedResponse');

            final numCc = (decodedResponse['classification_confidence'] ?? 0) as num;
            final double confidence = numCc.toDouble();
            final bool hasFish = decodedResponse['has_fish'] == null ? true : (decodedResponse['has_fish'] == true);

            // Show dialog for no fish or low confidence
            if ((!hasFish || confidence < 0.5)) {
              if (mounted) {
                _safePop(); // Close scanning dialog first
                await Future.delayed(const Duration(milliseconds: 200));
                if (mounted) {
                  _showSnapTipsDialog(fromCamera, !hasFish ? 'No fish detected' : 'Low confidence: ${(confidence * 100).toStringAsFixed(1)}%');
                }
              }
              return; // Stop further processing for this attempt
            }

            FishPrediction prediction = FishPrediction.fromJson(decodedResponse)
                .copyWith(
                  imagePath: savedImagePath,
                  probability: '${((decodedResponse['classification_confidence'] ?? 0) * 100).toStringAsFixed(2)}%',
                  minimumTankSize: decodedResponse['minimum_tank_size_l'] != null
                      ? '${decodedResponse['minimum_tank_size_l']} L'
                      : (decodedResponse['minimum_tank_size']?.toString() ?? ''),
                );

            print('Created prediction object: ${prediction.toJson()}');

            if (mounted) {
              _safePop();
              // Small delay to ensure scanning dialog closes before showing description dialog
              await Future.delayed(const Duration(milliseconds: 200));
              if (mounted) {
                _loadDescriptionAndShowResults(imageFile, prediction, prediction.commonName, prediction.scientificName);
              }
            }
            return; // Done
          }

          // Handle 404 special case (fish detected but not in DB)
          if (response.statusCode == 404) {
            var decodedResponse = json.decode(response.body);
            if (decodedResponse.containsKey('has_fish') && decodedResponse['has_fish'] == true &&
                decodedResponse.containsKey('predicted_name')) {
              if (mounted) {
                _safePop();
                showCustomNotification(
                  context,
                  'Fish detected but not found in our database: ${decodedResponse['predicted_name']}.',
                  isError: true,
                );
              }
            } else if (decodedResponse.containsKey('has_fish') && decodedResponse['has_fish'] == false) {
              if (mounted) {
                _safePop(); // Close scanning dialog first
                await Future.delayed(const Duration(milliseconds: 200));
                if (mounted) {
                  String message = 'No fish detected';
                  if (decodedResponse.containsKey('detail')) {
                    message = decodedResponse['detail'];
                  }
                  _showSnapTipsDialog(fromCamera, message);
                }
              }
            } else {
              throw Exception('API returned error: ${decodedResponse['detail']}');
            }
          } else if (response.statusCode == 400) {
            // Handle 400 status code with has_fish: false
            try {
              var decodedResponse = json.decode(response.body);
              if (decodedResponse.containsKey('has_fish') && decodedResponse['has_fish'] == false) {
                if (mounted) {
                  _safePop(); // Close scanning dialog first
                  await Future.delayed(const Duration(milliseconds: 200));
                  if (mounted) {
                    String message = 'No fish detected';
                    if (decodedResponse.containsKey('detail')) {
                      message = decodedResponse['detail'];
                    }
                    _showSnapTipsDialog(fromCamera, message);
                  }
                }
                return; // Stop processing for this attempt
              }
            } catch (parseError) {
              // If we can't parse the response, fall through to general error
            }
            throw Exception('Failed to get predictions. Status code: ${response.statusCode}, Body: ${response.body}');
          } else if (response.statusCode != 200) {
            // Non-404 terminal HTTP error
            throw Exception('Failed to get predictions. Status code: ${response.statusCode}, Body: ${response.body}');
          }
        } catch (e) {
          print('Request error: $e');
          lastError = Exception(e.toString());
          if (!ApiConfig.tryNextServer()) {
            break;
          }
        } finally {
          client.close();
        }
      }

      // If we reached here, either we have a final non-200 response or an error
      if (lastResponse != null && lastResponse.statusCode == 404) {
        var decodedResponse = json.decode(lastResponse.body);
        if (decodedResponse.containsKey('has_fish') && decodedResponse['has_fish'] == true &&
            decodedResponse.containsKey('predicted_name')) {
          if (mounted) {
            _safePop();
            showCustomNotification(
              context,
              'Fish detected but not found in our database: ${decodedResponse['predicted_name']}.',
              isError: true,
            );
          }
        } else if (decodedResponse.containsKey('has_fish') && decodedResponse['has_fish'] == false) {
          if (mounted) {
            _safePop(); // Close scanning dialog first
            await Future.delayed(const Duration(milliseconds: 200));
            if (mounted) {
              _showSnapTipsDialog(fromCamera, 'No fish detected');
            }
          }
        } else {
          throw Exception('API returned error: ${decodedResponse['detail']}');
        }
      } else if (lastResponse != null) {
        // Non-404 terminal HTTP error
        throw Exception('Failed to get predictions. Status code: ${lastResponse.statusCode}, Body: ${lastResponse.body}');
      } else if (lastError != null) {
        // Network or timeout error after exhausting servers
        throw Exception('Failed to get predictions due to network error: ${lastError.toString()}');
      } else {
        throw Exception('Failed to get predictions due to unknown error.');
      }
    } catch (e, stackTrace) {
      if (mounted) {
        _safePop();
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
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _savePredictions(List<FishPrediction> predictions) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      // Show auth required dialog
      showDialog(
        context: context,
        builder: (BuildContext context) => const AuthRequiredDialog(
          title: 'Sign In Required',
          message: 'You need to sign in to save fish captures to your collection.',
        ),
      );
      return;
    }
    
    if (!_canSave()) {
      _showUpgradeDialog(_userPlan == 'free'
        ? 'You have reached the limit of 5 saved captures for the Free plan. Upgrade to Pro for unlimited captures!'
        : 'You have reached the limit of 20 saved captures for the Pro plan. Upgrade to Pro for unlimited captures!');
      return;
    }
    final logBookProvider = Provider.of<LogBookProvider>(context, listen: false);
    try {
      final bool saved = await logBookProvider.addPredictions(predictions);
      if (saved) {
        if (mounted) {
          showCustomNotification(context, 'Fish saved to collection');
          await Future.delayed(const Duration(milliseconds: 1500));
          if (mounted) {
            // Ensure any transient dialogs are closed
            _safePop();
            Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (context) => const HomePage(initialTabIndex: 3),
              ),
              (route) => false,
            );
            return; // Stop further execution; widget will likely be disposed
          }
        }
      } else {
        if (mounted) {
          showCustomNotification(context, 'Fish already exists in collection');
          await Future.delayed(const Duration(milliseconds: 1500));
          if (mounted) {
            Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (context) => const HomePage(initialTabIndex: 3),
              ),
              (route) => false,
            );
          }
        }
      }
    } catch (e) {
      print('Error saving prediction: $e');
      if (mounted) {
        showCustomNotification(context, 'Error saving fish to collection');
      }
    }
    // Refresh plan/count after save
    if (mounted) {
      await _loadUserPlanAndCount();
    }
  }

  void _showPredictionResults(XFile imageFile, List<FishPrediction> predictions, [Map<String, dynamic>? careData]) {
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
              // Redirect to homepage initial state instead of going back
              Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) => const HomePage(initialTabIndex: 0),
                ),
                (route) => false,
              );
              return false;
            },
            child: Scaffold(
              backgroundColor: Colors.white,
              appBar: AppBar(
                backgroundColor: Colors.white,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Color(0xFF006064)),
                  onPressed: () {
                    // Redirect to homepage initial state instead of going back
                    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (context) => const HomePage(initialTabIndex: 0),
                      ),
                      (route) => false,
                    );
                  },
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
                          _buildDetailCard('Social Behavior', highestPrediction.socialBehavior, Icons.group),
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
                          // Diet recommendation with expandable groups like fish_list_screen
                          if (careData?.containsKey('error') == true)
                            Text(careData!['error'], style: const TextStyle(color: Colors.red)),
                          if (careData?.containsKey('error') != true) ...[
                            Builder(
                              builder: (context) {
                                final dietData = careData ?? {
                                  'diet_type': highestPrediction.diet,
                                  'preferred_foods': highestPrediction.preferredFood,
                                  'feeding_frequency': highestPrediction.feedingFrequency,
                                  'portion_size': 'N/A',
                                  'fasting_schedule': 'N/A',
                                  'overfeeding_risks': 'N/A',
                                  'behavioral_notes': 'N/A',
                                  'tankmate_feeding_conflict': 'N/A',
                                };
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
                                    ...fieldGroups.map((group) => _RecommendationExpansionGroup(fields: group, data: dietData)).toList(),
                                  ],
                                );
                              },
                            ),
                          ],
                          const SizedBox(height: 40),
                          
                          // Action buttons
                          Row(
                            children: [
                              if (_canSave()) ...[
                                Expanded(
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF006064),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 2,
                                    ),
                                    onPressed: () {
                                      _savePredictions([highestPrediction]);
                                    },
                                    child: const Text(
                                      'Save to Collection',
                                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ),
                              ],
                              if (!_canSave()) ...[
                                Expanded(
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.grey[400],
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    onPressed: () {
                                      _showUpgradeDialog(_userPlan == 'free'
                                        ? 'You have reached the limit of 5 saved captures for the Free plan. Upgrade to Pro for unlimited captures!'
                                        : 'You have reached the limit of 20 saved captures for the Pro plan. Upgrade to Pro for unlimited captures!');
                                    },
                                    child: const Text(
                                      'Upgrade to Save',
                                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(width: 16),
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF00ACC1),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 2,
                                  ),
                                  onPressed: () {
                                    // Navigate to sync screen directly without saving
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => HomePage(
                                          initialTabIndex: 1,
                                          initialFish: highestPrediction.commonName,
                                          initialFishImage: io.File(imageFile.path),
                                        ),
                                      ),
                                    );
                                  },
                                  child: const Text(
                                    'Sync',
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
          );
        },
      ),
    );
  }

  // Method to fetch fish species data from Supabase
  Future<Map<String, dynamic>?> _fetchFishSpeciesData(String commonName, String scientificName) async {
    try {
      final response = await Supabase.instance.client
          .from('fish_species')
          .select('*')
          .or('common_name.ilike.%$commonName%,scientific_name.ilike.%$scientificName%')
          .limit(1)
          .single();
      
      return response;
    } catch (e) {
      print('Error fetching fish species data: $e');
      return null;
    }
  }

  // Method to load the description and care recommendations, then show results
  Future<void> _loadDescriptionAndShowResults(XFile imageFile, FishPrediction prediction, String commonName, String scientificName) async {
    try {
      print('Attempting to generate description and care recommendations for $commonName ($scientificName)');
      
      // Create cache key
      final cacheKey = '$commonName-$scientificName';
      
      // Check cache first
      String description;
      Map<String, dynamic> careRecommendations;
      
      if (_descriptionCache.containsKey(cacheKey) && _careRecommendationsCache.containsKey(cacheKey)) {
        print('Using cached results for $commonName');
        description = _descriptionCache[cacheKey]!;
        careRecommendations = _careRecommendationsCache[cacheKey]!;
      } else {
        print('Generating new results for $commonName');
        // Generate both description and care recommendations in parallel
        final results = await Future.wait([
                  OpenAIService.generateFishDescription(commonName, scientificName),
        OpenAIService.generateCareRecommendations(commonName, scientificName),
        ]);
        
        description = results[0] as String;
        careRecommendations = results[1] as Map<String, dynamic>;
        
        // Cache the results
        _descriptionCache[cacheKey] = description;
        _careRecommendationsCache[cacheKey] = careRecommendations;
      }
      
      // Fetch fish species data from Supabase
      final fishSpeciesData = await _fetchFishSpeciesData(commonName, scientificName);
      
      // Cache the image path for this fish
      _imagePathCache[cacheKey] = imageFile.path;
      
              // Update the prediction with the description, care recommendations, and fish species data
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
          temperatureRange: fishSpeciesData?['temperature_range'] ?? prediction.temperatureRange, 
          phRange: fishSpeciesData?['ph_range'] ?? prediction.phRange,
          socialBehavior: fishSpeciesData?['social_behavior'] ?? prediction.socialBehavior,
          minimumTankSize: fishSpeciesData?['minimum_tank_size_(l)'] != null 
              ? '${fishSpeciesData!['minimum_tank_size_(l)']} L' 
              : prediction.minimumTankSize,
          compatibilityNotes: fishSpeciesData?['compatibility_notes'] ?? 'No compatibility notes available',
          tankLevel: fishSpeciesData?['tank_level'] ?? prediction.tankLevel,
        );
      
      if (mounted) {
        _showPredictionResults(imageFile, [updatedPrediction], careRecommendations);
      }
    } catch (e) {
      print('Error loading description and care recommendations: $e');
      if (mounted) {
        // Even if AI generation fails, still try to fetch Supabase data
        final fishSpeciesData = await _fetchFishSpeciesData(commonName, scientificName);
        
        // Still show results but with error messages
        final fallbackPrediction = FishPrediction(
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
          temperatureRange: fishSpeciesData?['temperature_range'] ?? prediction.temperatureRange, 
          phRange: fishSpeciesData?['ph_range'] ?? prediction.phRange,
          socialBehavior: fishSpeciesData?['social_behavior'] ?? prediction.socialBehavior,
          minimumTankSize: fishSpeciesData?['minimum_tank_size_(l)'] != null 
              ? '${fishSpeciesData!['minimum_tank_size_(l)']} L' 
              : prediction.minimumTankSize,
          compatibilityNotes: fishSpeciesData?['compatibility_notes'] ?? 'No compatibility notes available',
          tankLevel: fishSpeciesData?['tank_level'] ?? prediction.tankLevel,
        );
        final errorCareData = {'error': 'Failed to load diet/care recommendations.'};
        _showPredictionResults(imageFile, [fallbackPrediction], errorCareData);
      }
    }
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF00ACC1).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
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
                Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.right,
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
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                color: Colors.black87,
              ),
              textAlign: TextAlign.right,
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
      await _analyzeFishImage(image, await _saveImageToStorage(image), fromCamera: true);
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
          await _analyzeFishImage(image, await _saveImageToStorage(image), fromCamera: false);
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
          onPressed: _handleBack,
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
              final nav = Navigator.of(context);
              if (nav.canPop()) {
                nav.pop();
                return false;
              } else {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const HomePage(initialTabIndex: 0)),
                );
                return false;
              }
            },
            child: Scaffold(
              backgroundColor: Colors.white,
              appBar: AppBar(
                backgroundColor: Colors.white,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Color(0xFF006064)),
                  onPressed: () {
                    final nav = Navigator.of(context);
                    if (nav.canPop()) {
                      nav.pop();
                    } else {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const HomePage(initialTabIndex: 0)),
                      );
                    }
                  },
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
                                  onPressed: () => Navigator.maybePop(context),
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