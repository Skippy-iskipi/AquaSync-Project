import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../models/fish_prediction.dart';
import '../models/compatibility_result.dart';
import '../config/api_config.dart';
import '../widgets/custom_notification.dart';
import '../widgets/snap_tips_dialog.dart';
import '../widgets/expandable_reason.dart';
import '../services/openai_service.dart'; // OpenAI AI service
import '../widgets/description_widget.dart';
import '../widgets/fish_images_grid.dart';
import '../widgets/fish_info_dialog.dart';
import '../screens/subscription_page.dart';
import '../screens/logbook_provider.dart';
import '../widgets/auth_required_dialog.dart';

import '../services/enhanced_tankmate_service.dart';

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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
  String? _selectedFish1;
  String? _selectedFish2;
  bool _isLoading = false;
  // Confidence threshold for accepting predictions (50%)
  static const double _confidenceThreshold = 0.7;
  // Cache for resolving fish image URLs so FutureBuilder doesn't refetch on rebuild
  final Map<String, Future<http.Response?>> _imageResolveCache = {};
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



  Widget _buildAIRequirementsSection(String fish1Name, String fish2Name, String compatibilityLevel) {
    // Only show AI analysis for Pro users
    if (_userPlan.toLowerCase() != 'pro') {
      return const SizedBox.shrink();
    }
    
    // Hide AI analysis when incompatible or same species to avoid contradictions
    if (compatibilityLevel == 'incompatible' ||
        fish1Name.trim().toLowerCase() == fish2Name.trim().toLowerCase()) {
      return const SizedBox.shrink();
    }
    
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFE0F7FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF00BCD4).withOpacity(0.3), width: 1),
      ),
      child: FutureBuilder<List<dynamic>>(
        future: Future.wait([
          EnhancedTankmateService.getCompatibilityReasons(fish1Name, fish2Name),
          EnhancedTankmateService.getCompatibilityConditions(fish1Name, fish2Name),
        ]),
        builder: (context, snapshot) {
          final isLoading = snapshot.connectionState == ConnectionState.waiting;
          final hasData = snapshot.hasData && snapshot.data != null;
          final List<String> reasons = hasData ? List<String>.from(snapshot.data![0] as List) : const <String>[];
          final List<String> conditions = hasData ? List<String>.from(snapshot.data![1] as List) : const <String>[];

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isLoading)
                  _buildLoadingState()
                else ...[
                  if (reasons.isNotEmpty) ...[
                    const Text(
                      'Analysis',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF006064),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...reasons.map((reason) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                margin: const EdgeInsets.only(top: 6),
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF00BCD4),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  reason,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black87,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
                  // For compatible results, also show Care Recommendations (AI-sourced),
                  // similar to water_calculator style but concise.
                  if (compatibilityLevel == 'compatible') ...[
                    const SizedBox(height: 12),
                    FutureBuilder<Map<String, dynamic>?>(
                      future: EnhancedTankmateService.getAICompatibilityAnalysis(fish1Name, fish2Name),
                      builder: (context, careSnap) {
                        if (careSnap.connectionState == ConnectionState.waiting) {
                          return _buildLoadingState();
                        }
                        if (!careSnap.hasData || careSnap.data == null) {
                          return const SizedBox.shrink();
                        }
                        final analysisData = careSnap.data!['data'] ?? careSnap.data!;
                        final List<String> careRequirements = List<String>.from(analysisData['care_requirements'] ?? []);
                        if (careRequirements.isEmpty) return const SizedBox.shrink();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0F7FA),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF00BCD4).withOpacity(0.3)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: const [
                                      Icon(Icons.eco, color: Color(0xFF006064), size: 18),
                                      SizedBox(width: 8),
                                      Text(
                                        'Care Recommendations',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF006064),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  ...careRequirements.map((req) => Padding(
                                        padding: const EdgeInsets.only(bottom: 4),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              '• ',
                                              style: TextStyle(
                                                color: Color(0xFF00BCD4),
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Expanded(
                                              child: Text(
                                                req,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  color: Color(0xFF006064),
                                                  height: 1.3,
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
                        );
                      },
                    ),
                  ],
                  if (compatibilityLevel == 'conditional' && conditions.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F7FA),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF00BCD4).withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.warning_amber, color: Color(0xFF006064), size: 18),
                              SizedBox(width: 8),
                              Text(
                                'Required Conditions',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF006064),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ...conditions.map((c) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('• ', style: TextStyle(color: Color(0xFF00BCD4), fontSize: 14, fontWeight: FontWeight.bold)),
                                    Expanded(
                                      child: Text(
                                        c,
                                        style: const TextStyle(fontSize: 13, color: Color(0xFF006064), height: 1.3),
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                        ],
                      ),
                    ),
                  ],
                  if (reasons.isEmpty)
                    FutureBuilder<Map<String, dynamic>?>(
                      future: EnhancedTankmateService.getAICompatibilityAnalysis(fish1Name, fish2Name),
                      builder: (context, aiSnap) {
                        if (aiSnap.connectionState == ConnectionState.waiting) {
                          return _buildLoadingState();
                        } else if (aiSnap.hasData && aiSnap.data != null) {
                          return _buildAIAnalysisContent(aiSnap.data!);
                        } else {
                          return _buildFallbackAnalysis(fish1Name, fish2Name);
                        }
                      },
                    ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return Column(
      children: [
        Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00BCD4)),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Generating compatibility analysis...',
              style: const TextStyle(
                color: Color(0xFF006064),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'This may take a few seconds',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  // _buildErrorState removed (no longer used)



  Widget _buildFallbackAnalysis(String fish1Name, String fish2Name) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFE0F7FA),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF00BCD4).withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.analytics, color: Color(0xFF006064), size: 16),
              const SizedBox(width: 8),
              Text(
                'Basic Analysis',
                style: const TextStyle(
                  color: Color(0xFF006064),
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Basic compatibility analysis
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFE0F7FA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF00BCD4).withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.lightbulb_outline, color: Color(0xFF006064), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Compatibility Notes',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF006064),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'AI-powered analysis is temporarily unavailable. Please check the tankmate recommendations below for compatible species, or consult aquarium compatibility guides for detailed information about keeping $fish1Name and $fish2Name together.',
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF006064),
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        
        // Generation Info
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'Basic compatibility info • ${DateTime.now().toString().split(' ')[0]}',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAIAnalysisContent(Map<String, dynamic> data) {
    // Extract the actual data from the response structure
    final analysisData = data['data'] ?? data;
    
    final reasons = List<String>.from(analysisData['compatibility_reasons'] ?? []);
    final conditions = List<String>.from(analysisData['conditions'] ?? []);
    final careRequirements = List<String>.from(analysisData['care_requirements'] ?? []);
    // confidence score and compatibility level omitted from UI for minimalist design
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Reasons
        if (reasons.isNotEmpty) ...[
          Text(
            'Analysis',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF006064),
            ),
          ),
          const SizedBox(height: 8),
          ...reasons.map((reason) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFF00BCD4),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    reason,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
        
        // Conditions (if conditional compatibility)
        if (conditions.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE0F7FA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF00BCD4).withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.warning_amber, color: Color(0xFF006064), size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Requirements for Compatibility',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF006064),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...conditions.map((condition) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '• ',
                        style: const TextStyle(
                          color: Color(0xFF00BCD4),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          condition,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF006064),
                            height: 1.3,
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
        
        // Care Requirements
        if (careRequirements.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE0F7FA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF00BCD4).withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.eco, color: Color(0xFF006064), size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Care Recommendations',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF006064),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...careRequirements.map((requirement) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '• ',
                        style: const TextStyle(
                          color: Color(0xFF00BCD4),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          requirement,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF006064),
                            height: 1.3,
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
    );
  }

  Future<Map<String, Map<String, dynamic>>> _loadTankmateRecommendations(String fish1Name, String fish2Name) async {
    try {
      // Get enhanced tankmate recommendations from Supabase
      final supabase = Supabase.instance.client;
      
      Map<String, Map<String, dynamic>> recommendations = {
        fish1Name: {
          'fully_compatible': <String>[],
          'conditional': <Map<String, dynamic>>[],
        },
        fish2Name: {
          'fully_compatible': <String>[],
          'conditional': <Map<String, dynamic>>[],
        },
      };
      
      // Get recommendations for fish1
      try {
        final response1 = await supabase
            .from('fish_tankmate_recommendations')
            .select('fully_compatible_tankmates, conditional_tankmates')
            .ilike('fish_name', fish1Name)
            .maybeSingle();
        
        if (response1 != null) {
          List<String> fullyCompatible = [];
          List<Map<String, dynamic>> conditional = [];
          
          // Add fully compatible tankmates
          if (response1['fully_compatible_tankmates'] != null) {
            fullyCompatible.addAll(List<String>.from(response1['fully_compatible_tankmates']));
          }
          
          // Add conditional tankmates (preserve full objects with conditions)
          if (response1['conditional_tankmates'] != null) {
            List<dynamic> conditionalData = response1['conditional_tankmates'];
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
          
          // Remove self and the other selected fish from both lists
          fullyCompatible.remove(fish1Name);
          fullyCompatible.remove(fish2Name);
          conditional.removeWhere((item) => item['name'] == fish1Name || item['name'] == fish2Name);
          
          // Sort and limit
          fullyCompatible.sort();
          conditional.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
          
          recommendations[fish1Name] = {
            'fully_compatible': fullyCompatible.take(6).toList(),
            'conditional': conditional.take(6).toList(),
          };
        }
      } catch (e1) {
        print('Warning: Could not get recommendations for $fish1Name: $e1');
      }
      
      // Get recommendations for fish2
      try {
        final response2 = await supabase
            .from('fish_tankmate_recommendations')
            .select('fully_compatible_tankmates, conditional_tankmates')
            .ilike('fish_name', fish2Name)
            .maybeSingle();
        
        if (response2 != null) {
          List<String> fullyCompatible = [];
          List<Map<String, dynamic>> conditional = [];
          
          // Add fully compatible tankmates
          if (response2['fully_compatible_tankmates'] != null) {
            fullyCompatible.addAll(List<String>.from(response2['fully_compatible_tankmates']));
          }
          
          // Add conditional tankmates (preserve full objects with conditions)
          if (response2['conditional_tankmates'] != null) {
            List<dynamic> conditionalData = response2['conditional_tankmates'];
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
          
          // Remove self and the other selected fish from both lists
          fullyCompatible.remove(fish1Name);
          fullyCompatible.remove(fish2Name);
          conditional.removeWhere((item) => item['name'] == fish1Name || item['name'] == fish2Name);
          
          // Sort and limit
          fullyCompatible.sort();
          conditional.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
          
          recommendations[fish2Name] = {
            'fully_compatible': fullyCompatible.take(6).toList(),
            'conditional': conditional.take(6).toList(),
          };
        }
      } catch (e2) {
        print('Warning: Could not get recommendations for $fish2Name: $e2');
      }
      
      return recommendations;
      
    } catch (e) {
      print('Error loading tankmate recommendations from Supabase: $e');
      return {
        fish1Name: {
          'fully_compatible': <String>[],
          'conditional': <Map<String, dynamic>>[],
        },
        fish2Name: {
          'fully_compatible': <String>[],
          'conditional': <Map<String, dynamic>>[],
        },
      };
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
      // If connected, load fish species
      await _loadFishSpecies();
    } else if (mounted) {
      // If not connected, show error message
      showCustomNotification(
        context,
        'Unable to connect to server. Please check your network connection.',
        isError: true,
      );
    }
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
        
        // Generate description using Hugging Face
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
                        // Diet recommendation and care details via Hugging Face
                        FutureBuilder<Map<String, dynamic>>(
                          future: OpenAIService.generateCareRecommendations(
                            highestPrediction.commonName,
                            highestPrediction.scientificName,
                          ),
                          builder: (context, snapshot) {
                            // Fallback to baseline info from prediction while loading or on error
                            final fallbackData = {
                              'diet_type': highestPrediction.diet,
                              'preferred_foods': highestPrediction.preferredFood,
                              'feeding_frequency': highestPrediction.feedingFrequency,
                              'portion_size': 'N/A',
                              'fasting_schedule': 'N/A',
                              'overfeeding_risks': 'N/A',
                              'behavioral_notes': 'N/A',
                              'tankmate_feeding_conflict': 'N/A',
                              'oxygen_needs': 'N/A',
                              'filtration_needs': 'N/A',
                            };

                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: const [
                                  SizedBox(height: 8),
                                  Center(child: CircularProgressIndicator(color: Color(0xFF00BCD4))),
                                  SizedBox(height: 12),
                                  Text(
                                    'Generating care recommendations...',
                                    style: TextStyle(color: Colors.black54),
                                  ),
                                ],
                              );
                            }

                            Map<String, dynamic> careData = fallbackData;
                            bool hasError = false;
                            if (snapshot.hasData && snapshot.data != null) {
                              final data = snapshot.data!;
                              if (data['error'] == null) {
                                careData = {
                                  ...fallbackData,
                                  ...data,
                                };
                              } else {
                                hasError = true;
                              }
                            } else if (snapshot.hasError) {
                              hasError = true;
                            }

                            final fields = [
                              {'label': 'Diet Type', 'key': 'diet_type', 'icon': Icons.restaurant},
                              {'label': 'Preferred Foods', 'key': 'preferred_foods', 'icon': Icons.set_meal},
                              {'label': 'Feeding Frequency', 'key': 'feeding_frequency', 'icon': Icons.schedule},
                              {'label': 'Portion Size', 'key': 'portion_size', 'icon': Icons.line_weight},
                              {'label': 'Fasting Schedule', 'key': 'fasting_schedule', 'icon': Icons.calendar_today},
                              {'label': 'Overfeeding Risks', 'key': 'overfeeding_risks', 'icon': Icons.error},
                              {'label': 'Behavioral Notes', 'key': 'behavioral_notes', 'icon': Icons.psychology},
                              {'label': 'Tankmate Feeding Conflict', 'key': 'tankmate_feeding_conflict', 'icon': Icons.warning},
                              {'label': 'Oxygen Needs', 'key': 'oxygen_needs', 'icon': Icons.air},
                              {'label': 'Filtration Needs', 'key': 'filtration_needs', 'icon': Icons.water_damage},
                            ];

                            final List<List<Map<String, dynamic>>> fieldGroups = [
                              fields.sublist(0, 2), // Diet basics
                              fields.sublist(2, 5), // Feeding logistics
                              fields.sublist(5, 8), // Risks and behavior
                              fields.sublist(8, 10), // System needs
                            ];

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (hasError)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8.0),
                                    child: Text(
                                      'Using baseline info. AI recommendations unavailable.',
                                      style: TextStyle(color: Colors.red[600], fontSize: 13),
                                    ),
                                  ),
                                ...fieldGroups
                                    .map((group) => _RecommendationExpansionGroup(fields: group, data: careData))
                                    .toList(),
                              ],
                            );
                          },
                        ),
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
                                  backgroundColor: const Color(0xFF00BCD4),
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
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Color(0xFF006064),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.right,
                softWrap: true,
              ),
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
      if (!mounted) return;
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
          if (!mounted) return;
          setState(() {
            _compatibilityChecksCount = data['compatibility_checks_count'] ?? 0;
          });
        } catch (e) {
          print('Error loading compatibility checks count: $e');
          if (!mounted) return;
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
          if (!mounted) return;
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
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      showDialog(
        context: context,
        builder: (BuildContext context) => const AuthRequiredDialog(
          title: 'Sign In Required',
          message: 'You need to sign in to check fish compatibility and access premium features.',
        ),
      );
      return false;
    }
    
    if (_userPlan == 'free' && _compatibilityChecksCount >= 2) {
      _showUpgradeDialog('You have reached the limit of 2 compatibility checks for the free plan. Upgrade to Pro for unlimited checks with detailed breakdown and advanced deep compatibility analysis!');
      return false;
    }
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
          message: 'You need to sign in to access premium features and compatibility checks.',
        ),
      );
      return;
    }
    
    // User is authenticated, directly navigate to subscription page
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SubscriptionPage()),
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
          
          // Parse enhanced compatibility response
          final String compatibility = firstResult['compatibility'] ?? 'Incompatible';
          final String compatibilityLevel = firstResult['compatibility_level'] ?? 
              (compatibility == 'Compatible' ? 'compatible' : 'incompatible');
          
          // Extract reasons and conditions
          final List<String> baseReasons = List<String>.from(firstResult['reasons'] ?? []);
          final List<String> conditions = List<String>.from(firstResult['conditions'] ?? []);
          
          // Handle backward compatibility with simple boolean check
          final bool isCompatible = compatibility == 'Compatible' || compatibilityLevel == 'compatible';

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
            _showCompatibilityDialog(isCompatible, baseReasons, compatibilityLevel, conditions);
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

  void _showCompatibilityDialog(bool isCompatible, List<String> baseReasons, String compatibilityLevel, List<String> conditions) {
    // Enhanced compatibility dialog with full support for conditional compatibility
    List<String> currentReasons = baseReasons;
    bool isLoadingDetails = false;
    bool hasFetched = false;
    bool showAllReasons = false; // UI toggle: show all vs top 3
    Map<String, Map<String, dynamic>> tankmates = {}; // Store tankmate recommendations for each fish
    bool isLoadingTankmates = false;

    // Normalize plan string for robust comparison
    String normalizedPlan = _userPlan.trim().toLowerCase().replaceAll(' ', '_');

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
                          // Only fetch detailed reasons for Pro users and incompatible fish
              if (!hasFetched && compatibilityLevel == 'incompatible' && normalizedPlan == 'pro') {
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
            
            // Load tankmate recommendations (for all users)
            if (tankmates.isEmpty && !isLoadingTankmates) {
              isLoadingTankmates = true;
              _loadTankmateRecommendations(_fish1Name, _fish2Name).then((recommendations) {
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

            return Dialog(
              insetPadding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
              ),
                                                           child: Container(
                                width: MediaQuery.of(dialogContext).size.width,
                                height: MediaQuery.of(dialogContext).size.height,
                                                                 decoration: const BoxDecoration(
                                   color: Colors.white,
                                 ),
                                child: SingleChildScrollView(
                   child: Column(
                     mainAxisSize: MainAxisSize.min,
                     children: [
                                               // Back button at the top left
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.only(top: 16, left: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              IconButton(
                                onPressed: () => Navigator.of(dialogContext).pop(),
                                icon: const Icon(
                                  Icons.arrow_back,
                                  color: Color(0xFF006064),
                                  size: 28,
                                ),
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.white.withOpacity(0.9),
                                  shape: const CircleBorder(),
                                  padding: const EdgeInsets.all(8),
                                ),
                              ),
                            ],
                          ),
                        ),
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
                            Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      // Use smaller font on smaller screens
                                      double fontSize = constraints.maxWidth < 400 ? 18 : 24;
                                      return Column(
                                        children: [
                                          // Individual fish names with responsive layout
                                          if (constraints.maxWidth < 400) ...[
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    _fish1Name,
                                                    style: TextStyle(
                                                      fontSize: fontSize,
                                                      fontWeight: FontWeight.bold,
                                                      color: const Color(0xFF006064),
                                                    ),
                                                    textAlign: TextAlign.center,
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const SizedBox(width: 2),
                                                IconButton(
                                                  icon: const Icon(Icons.remove_red_eye, color: Color(0xFF006064), size: 18),
                                                  padding: EdgeInsets.zero,
                                                  constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                                  onPressed: () {
                                                    showDialog(
                                                      context: context,
                                                      builder: (context) => FishInfoDialog(fishName: _fish1Name),
                                                    );
                                                  },
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Icon(
                                              Icons.add,
                                              color: Colors.grey[600],
                                              size: 20,
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    _fish2Name,
                                                    style: TextStyle(
                                                      fontSize: fontSize,
                                                      fontWeight: FontWeight.bold,
                                                      color: const Color(0xFF006064),
                                                    ),
                                                    textAlign: TextAlign.center,
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const SizedBox(width: 2),
                                                IconButton(
                                                  icon: const Icon(Icons.remove_red_eye, color: Color(0xFF006064), size: 18),
                                                  padding: EdgeInsets.zero,
                                                  constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                                  onPressed: () {
                                                    showDialog(
                                                      context: context,
                                                      builder: (context) => FishInfoDialog(fishName: _fish2Name),
                                                    );
                                                  },
                                                ),
                                              ],
                                            ),
                                          ] else
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    '$_fish1Name & $_fish2Name',
                                                    style: TextStyle(
                                                      fontSize: fontSize,
                                                      fontWeight: FontWeight.bold,
                                                      color: const Color(0xFF006064),
                                                    ),
                                                    textAlign: TextAlign.center,
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                IconButton(
                                                  icon: const Icon(Icons.remove_red_eye, color: Color(0xFF006064)),
                                                  tooltip: 'View ${'_fish1Name'} info',
                                                  onPressed: () {
                                                    showDialog(
                                                      context: context,
                                                      builder: (context) => FishInfoDialog(fishName: _fish1Name),
                                                    );
                                                  },
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.remove_red_eye, color: Color(0xFF006064)),
                                                  tooltip: 'View ${'_fish2Name'} info',
                                                  onPressed: () {
                                                    showDialog(
                                                      context: context,
                                                      builder: (context) => FishInfoDialog(fishName: _fish2Name),
                                                    );
                                                  },
                                                ),
                                              ],
                                            ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _getCompatibilityIcon(compatibilityLevel),
                                  color: _getCompatibilityColor(compatibilityLevel),
                                  size: 24,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _getCompatibilityText(compatibilityLevel),
                                  style: TextStyle(
                                    color: _getCompatibilityColor(compatibilityLevel),
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                                              ),
                                             // Tankmate Recommendations (for all users)
                                               if (tankmates.isNotEmpty || isLoadingTankmates)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(FontAwesomeIcons.fish, color: Color(0xFF006064), size: 18),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Tankmate Recommendations',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF006064),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (isLoadingTankmates)
                                const Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF006064)),
                                    ),
                                  ),
                                )
                              else if (tankmates.isNotEmpty && _hasTankmateData(tankmates))
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // First Fish Recommendations
                                    if (_hasFishTankmates(tankmates[_fish1Name]))
                                      _buildFishTankmateSection(_fish1Name, tankmates[_fish1Name]!),
                                    
                                    // Add spacing between fish sections
                                    if (_hasFishTankmates(tankmates[_fish1Name]) && _hasFishTankmates(tankmates[_fish2Name]))
                                      const SizedBox(height: 12),
                                    
                                    // Second Fish Recommendations
                                    if (_hasFishTankmates(tankmates[_fish2Name]))
                                      _buildFishTankmateSection(_fish2Name, tankmates[_fish2Name]!),
                                    
                                    // Show message if no recommendations for either fish
                                    if (!_hasFishTankmates(tankmates[_fish1Name]) && !_hasFishTankmates(tankmates[_fish2Name]))
                                      Text(
                                        'No recommendations available for either fish.',
                                        style: const TextStyle(
                                          color: Color(0xFF00BCD4),
                                          fontSize: 12,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                  ],
                                )
                              else
                                Text(
                                  'No tankmate recommendations available at this time.',
                                  style: const TextStyle(
                                    color: Color(0xFF00BCD4),
                                    fontSize: 14,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      // AI Requirements Section (for all compatibility levels)
                      _buildAIRequirementsSection(_fish1Name, _fish2Name, compatibilityLevel),
                                             // Free User Upgrade Prompt (only show if incompatible)
                                               if (_userPlan == 'free' && compatibilityLevel == 'incompatible')
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                                             Row(
                                 children: [
                                   const Icon(Icons.star, color: Color(0xFF006064), size: 20),
                                   const SizedBox(width: 8),
                                   const Text(
                                     'Want Detailed Analysis?',
                                     style: TextStyle(
                                       fontSize: 16,
                                       fontWeight: FontWeight.bold,
                                       color: Color(0xFF006064),
                                     ),
                                   ),
                                 ],
                               ),
                               const SizedBox(height: 12),
                               const Text(
                                 'Upgrade to Pro to get detailed AI-powered explanations for incompatibility reasons and advanced compatibility analysis.',
                                 style: TextStyle(
                                   fontSize: 14,
                                   color: Color(0xFF006064),
                                 ),
                               ),
                               const SizedBox(height: 16),
                               SizedBox(
                                 width: double.infinity,
                                 child: ElevatedButton(
                                   onPressed: () {
                                     Navigator.of(dialogContext).pop();
                                     Navigator.push(
                                       context,
                                       MaterialPageRoute(builder: (context) => const SubscriptionPage()),
                                     );
                                   },
                                   style: ElevatedButton.styleFrom(
                                     backgroundColor: const Color(0xFF00BCD4),
                                     foregroundColor: Colors.white,
                                     padding: const EdgeInsets.symmetric(vertical: 12),
                                     shape: RoundedRectangleBorder(
                                       borderRadius: BorderRadius.circular(8),
                                     ),
                                   ),
                                   child: const Text(
                                     'Upgrade to Pro',
                                     style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                   ),
                                 ),
                               ),
                            ],
                          ),
                        ),
                                                                                           // Pro Features Section
                                                 if (_userPlan != 'free')
                           Container(
                             width: double.infinity,
                             padding: const EdgeInsets.all(24),
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
                                    // Removed extra top whitespace
                                    // Show a concise list by default (top 3). Allow user to expand/collapse.
                                    Builder(
                                      builder: (context) {
                                        final reasonsToShow = showAllReasons
                                            ? currentReasons
                                            : currentReasons.take(3).toList();
                                        return Column(
                                          children: [
                                            ...List.generate(
                                              reasonsToShow.length,
                                              (index) => Padding(
                                                padding: const EdgeInsets.symmetric(vertical: 6),
                                                child: Row(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Icon(
                                                      Icons.info,
                                                      size: 20,
                                                      color: compatibilityLevel == 'compatible' ? Colors.green :
                                                             compatibilityLevel == 'conditional' ? Colors.orange : Colors.red,
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          ExpandableReason(
                                                            text: compatibilityLevel == 'compatible' && index == 0 && !showAllReasons
                                                                ? "Both can be kept together in the same aquarium"
                                                                : reasonsToShow[index],
                                                            textStyle: const TextStyle(
                                                              fontSize: 16,
                                                              color: Colors.black87,
                                                              height: 1.4,
                                                            ),
                                                            textAlign: TextAlign.justify,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            if (currentReasons.length > 3)
                                              Padding(
                                                padding: const EdgeInsets.only(top: 4.0),
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    if (!showAllReasons)
                                                      Text(
                                                        '+ ${currentReasons.length - 3} more',
                                                        style: const TextStyle(
                                                          color: Colors.black54,
                                                          fontSize: 14,
                                                        ),
                                                      ),
                                                    TextButton(
                                                      onPressed: () {
                                                        setDialogState(() {
                                                          showAllReasons = !showAllReasons;
                                                        });
                                                      },
                                                      child: Text(showAllReasons ? 'Show less' : 'Show more'),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                          ],
                                        );
                                      },
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
                                                final user = Supabase.instance.client.auth.currentUser;
                                                if (user == null) {
                                                  // Show auth required dialog
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
                                                final newResult = CompatibilityResult(
                                                  fish1Name: _fish1Name,
                                                  fish1ImagePath: _fish1ImagePath,
                                                  fish2Name: _fish2Name,
                                                  fish2ImagePath: _fish2ImagePath,
                                                  isCompatible: compatibilityLevel == 'compatible',
                                                  reasons: currentReasons,
                                                  dateChecked: DateTime.now(),
                                                  savedPlan: _userPlan,
                                                );
                                                logbookProvider.addCompatibilityResult(newResult);
                                                Navigator.of(dialogContext).pop();
                                                showCustomNotification(context, 'Result saved to History');
                                              },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF00BCD4),
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
          gaplessPlayback: true,
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
    final cacheKey = imagePathOrName;
    _imageResolveCache[cacheKey] ??= ApiConfig.makeRequestWithFailover(
      endpoint: '/fish-image/${Uri.encodeComponent(imagePathOrName.replaceAll(' ', ''))}',
      method: 'GET',
    );
    return FutureBuilder<http.Response?>(
      future: _imageResolveCache[cacheKey],
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
                gaplessPlayback: true,
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
                gaplessPlayback: true,
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
                      gaplessPlayback: true,
                      errorBuilder: (context, error, stackTrace) {
                        // If base64 render fails, attempt local file path next, then network.
                        try {
                          if (imagePathOrName.isNotEmpty && File(imagePathOrName).existsSync()) {
                            return Image.file(
                              File(imagePathOrName),
                              fit: BoxFit.cover,
                              gaplessPlayback: true,
                            );
                          }
                        } catch (_) {}
                        // Fall back to network resolution
                        return _buildNetworkFishImage(imagePathOrName);
                      },
                    );
                  } catch (_) {
                    // If base64 decoding fails, try local file path, then network
                    try {
                      if (imagePathOrName.isNotEmpty && File(imagePathOrName).existsSync()) {
                        return Image.file(
                          File(imagePathOrName),
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                        );
                      }
                    } catch (_) {}
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
                                    backgroundColor: const Color(0xFFF5F5F5),
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
                                    backgroundColor: const Color(0xFF00BCD4),
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
        backgroundColor: const Color(0xFF00BCD4),
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
                        icon: const Icon(Icons.camera, size: 40, color: Color(0xFF00BCD4)),
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
                        icon: const Icon(Icons.photo_library, size: 40, color: Color(0xFF00BCD4)),
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
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
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
          final result = await _getPredictions(image, isFirstFish);
          if (!result && mounted) {
            showCustomNotification(
              context,
              'No fish detected in the image. Please try again with a clearer image.',
              isError: true,
            );
          }
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
      print('Gallery image error: $e');
      showCustomNotification(
        context,
        'Failed to select image. Please try again.',
        isError: true,
      );
    }
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

  Widget _buildFishTankmateSection(String fishName, Map<String, dynamic> fishTankmates) {
    final fullyCompatible = (fishTankmates['fully_compatible'] as List<String>?) ?? [];
    final conditional = (fishTankmates['conditional'] as List<Map<String, dynamic>>?) ?? [];
    final totalCount = fullyCompatible.length + conditional.length;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFE0F7FA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF00BCD4).withOpacity(0.3)),
      ),
      child: ExpansionTile(
        initiallyExpanded: false,
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        leading: const Icon(FontAwesomeIcons.fish, color: Color(0xFF006064), size: 18),
        title: Text(
          fishName,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF006064),
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '$totalCount compatible tankmates',
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF00BCD4),
          ),
        ),
        children: [
          // Fully Compatible Section
          if (fullyCompatible.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.check_circle, color: Color(0xFF00BCD4), size: 16),
                const SizedBox(width: 8),
                Text(
                  'Fully Compatible (${fullyCompatible.length})',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF006064),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: fullyCompatible.map((fish) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F7FA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF00BCD4).withOpacity(0.3)),
                ),
                child: Text(
                  fish,
                  style: const TextStyle(
                    color: Color(0xFF006064),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )).toList(),
            ),
          ],
          
          // Add spacing if both sections exist
          if (fullyCompatible.isNotEmpty && conditional.isNotEmpty)
            const SizedBox(height: 16),
          
          // Conditional Section
          if (conditional.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.warning_amber, color: Color(0xFF006064), size: 16),
                const SizedBox(width: 8),
                Text(
                  'Compatible with Conditions (${conditional.length})',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF006064),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: conditional.map((fishData) => GestureDetector(
                onTap: () => _showFishConditionsDialog(
                  fishName, 
                  fishData['name'] as String, 
                  List<String>.from(fishData['conditions'] ?? [])
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F7FA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF00BCD4).withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        fishData['name'] as String,
                        style: const TextStyle(
                          color: Color(0xFF006064),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.info_outline,
                        size: 12,
                        color: Color(0xFF006064),
                      ),
                    ],
                  ),
                ),
              )).toList(),
            ),
          ],
        ],
      ),
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
        return 'Compatible with Conditions';
      case 'incompatible':
      default:
        return 'Not Compatible';
    }
  }

  void _showFishConditionsDialog(String baseFishName, String tankmateName, List<String> conditions) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.white,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F7FA),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.warning_amber,
                        color: Color(0xFF006064),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Conditional Compatibility',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF006064),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$baseFishName + $tankmateName',
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
                
                const SizedBox(height: 20),
                
                // Conditions section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F7FA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF00BCD4).withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.checklist,
                            color: Color(0xFF006064),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Required Conditions',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF006064),
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
                                  color: Color(0xFF00BCD4),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  condition,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF006064),
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
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Info section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F7FA),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF00BCD4).withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.lightbulb_outline,
                        color: Color(0xFF006064),
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'These fish can coexist if the above conditions are met. Monitor their behavior closely when introducing them to the same tank.',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF006064),
                            height: 1.3,
                          ),
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
                        borderRadius: BorderRadius.circular(8),
                      ),
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
}
