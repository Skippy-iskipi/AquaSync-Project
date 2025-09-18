import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/enhanced_tankmate_service.dart';
import 'fish_info_dialog.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../config/api_config.dart';

class FishCardTankmates extends StatefulWidget {
  final List<String> selectedFishNames;
  final Map<String, int>? fishQuantities; // Add quantities parameter
  final Function(String) onFishSelected;

  const FishCardTankmates({
    super.key,
    required this.selectedFishNames,
    this.fishQuantities,
    required this.onFishSelected,
  });

  @override
  State<FishCardTankmates> createState() => _FishCardTankmatesState();
}

class _FishCardTankmatesState extends State<FishCardTankmates> {
  List<String> commonTankmates = [];
  List<String> fullyCompatibleTankmates = [];
  List<String> conditionalTankmates = [];
  bool isLoading = false;
  bool isExpanded = false;
  bool isCheckingCompatibility = false;
  Map<String, dynamic>? compatibilityResult;

  @override
  void initState() {
    super.initState();
    _loadCommonTankmates();
    _checkCompatibility();
  }

  @override
  void didUpdateWidget(FishCardTankmates oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedFishNames != widget.selectedFishNames) {
      _loadCommonTankmates();
      _checkCompatibility();
    }
  }

  Future<void> _loadCommonTankmates() async {
    if (widget.selectedFishNames.isEmpty) return;

    setState(() {
      isLoading = true;
    });

    try {
      // Get tankmate recommendations for each selected fish
      Map<String, Set<String>> fishFullyCompatible = {};
      Map<String, Set<String>> fishConditional = {};
      
      for (String fishName in widget.selectedFishNames) {
        try {
          final data = await EnhancedTankmateService.getTankmateDetails(fishName);
          
          if (data != null) {
            // Add fully compatible tankmates
            fishFullyCompatible[fishName] = data.fullyCompatibleTankmates.toSet();
            
            // Add conditional tankmates
            Set<String> conditionalNames = {};
            for (var tankmate in data.conditionalTankmates) {
              conditionalNames.add(tankmate.name);
            }
            fishConditional[fishName] = conditionalNames;
          } else {
            fishFullyCompatible[fishName] = <String>{};
            fishConditional[fishName] = <String>{};
          }
        } catch (e) {
          print('Error loading tankmate data for $fishName: $e');
          fishFullyCompatible[fishName] = <String>{};
          fishConditional[fishName] = <String>{};
        }
      }
      
      // Find fully compatible tankmates that work with ALL selected fish
      Set<String> commonFullyCompatible = fishFullyCompatible.values.first;
      for (Set<String> tankmates in fishFullyCompatible.values) {
        commonFullyCompatible = commonFullyCompatible.intersection(tankmates);
      }
      
      // Find conditional tankmates that work with ALL selected fish
      Set<String> commonConditional = fishConditional.values.first;
      for (Set<String> tankmates in fishConditional.values) {
        commonConditional = commonConditional.intersection(tankmates);
      }
      
      // Remove selected fish from recommendations
      final fullyCompatibleFinal = commonFullyCompatible
          .where((rec) => !widget.selectedFishNames.contains(rec))
          .toList();
      
      final conditionalFinal = commonConditional
          .where((rec) => !widget.selectedFishNames.contains(rec))
          .toList();
      
      // Sort and limit recommendations
      fullyCompatibleFinal.sort();
      conditionalFinal.sort();
      
      setState(() {
        fullyCompatibleTankmates = fullyCompatibleFinal.take(10).toList();
        conditionalTankmates = conditionalFinal.take(10).toList();
        commonTankmates = [...fullyCompatibleFinal, ...conditionalFinal].take(10).toList();
        isLoading = false;
      });
    } catch (e) {
      print('Error loading common tankmates: $e');
      setState(() {
        commonTankmates = [];
        fullyCompatibleTankmates = [];
        conditionalTankmates = [];
        isLoading = false;
      });
    }
  }

  Future<void> _checkCompatibility() async {
    if (widget.selectedFishNames.length < 2) {
      setState(() {
        compatibilityResult = null;
        isCheckingCompatibility = false;
      });
      return;
    }

    setState(() {
      isCheckingCompatibility = true;
    });

    try {
      // Expand fish names by quantity to match main calculation logic
      List<String> expandedFishNames;
      if (widget.fishQuantities != null) {
        // Use the same expansion logic as main calculation
        expandedFishNames = widget.fishQuantities!.entries
            .expand((e) => List.filled(e.value, e.key))
            .toList();
      } else {
        // Fallback to just the fish names if no quantities provided
        expandedFishNames = widget.selectedFishNames;
      }
      
      print('Real-time compatibility check - expanded fish names: $expandedFishNames');
      
      // Check compatibility using the API
      final response = await http.post(
        Uri.parse(ApiConfig.checkGroupEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        },
        body: json.encode({'fish_names': expandedFishNames}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Real-time compatibility API response: $data');
        
        // Process the response the same way as main calculation
        final compatibilityData = data;
        print('Real-time compatibility results: ${compatibilityData['results']?.length ?? 0} pairs checked');
        
        bool hasIncompatiblePairs = false;
        bool hasConditionalPairs = false;
        final List<Map<String, dynamic>> incompatiblePairs = [];
        final List<Map<String, dynamic>> conditionalPairs = [];
        final Set<String> seenPairs = {};
        
        for (var result in compatibilityData['results']) {
          final compatibility = result['compatibility'];
          
          if (compatibility == 'Not Compatible' || compatibility == 'Conditional' || compatibility == 'Conditionally Compatible') {
            final pair = List<String>.from(result['pair'].map((e) => e.toString()));
            if (pair.length == 2) {
              final a = pair[0].toLowerCase();
              final b = pair[1].toLowerCase();
              final key = ([a, b]..sort()).join('|');
              if (!seenPairs.contains(key)) {
                seenPairs.add(key);
                
                if (compatibility == 'Not Compatible') {
                  hasIncompatiblePairs = true;
                  incompatiblePairs.add({
                    'pair': result['pair'],
                    'reasons': result['reasons'],
                    'type': 'incompatible',
                  });
                } else if (compatibility == 'Conditional' || compatibility == 'Conditionally Compatible') {
                  hasConditionalPairs = true;
                  conditionalPairs.add({
                    'pair': result['pair'],
                    'reasons': result['reasons'],
                    'type': 'conditional',
                  });
                }
              }
            }
          }
        }
        
        print('Real-time found ${incompatiblePairs.length} incompatible pairs and ${conditionalPairs.length} conditional pairs');
        
        setState(() {
          compatibilityResult = {
            'incompatible_pairs': incompatiblePairs,
            'conditional_pairs': conditionalPairs,
            'has_incompatible': hasIncompatiblePairs,
            'has_conditional': hasConditionalPairs,
          };
          isCheckingCompatibility = false;
        });
      } else {
        setState(() {
          compatibilityResult = {'error': 'Failed to check compatibility'};
          isCheckingCompatibility = false;
        });
      }
    } catch (e) {
      print('Error checking compatibility: $e');
      setState(() {
        compatibilityResult = {'error': 'Compatibility check failed'};
        isCheckingCompatibility = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.selectedFishNames.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        // Compatibility Status Card (separate from tankmates)
        _buildCompatibilityStatusCard(),
        const SizedBox(height: 4),
        // Tankmates Recommendation Card
        Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          elevation: 0,
          child: Theme(
            data: Theme.of(context).copyWith(
              dividerColor: Colors.transparent,
            ),
            child: ExpansionTile(
              initiallyExpanded: false,
              onExpansionChanged: (expanded) {
                setState(() {
                  isExpanded = expanded;
                });
              },
              leading: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F7FA),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  FontAwesomeIcons.userGroup,
                  color: Color(0xFF006064),
                  size: 14,
                ),
              ),
              title: Row(
                children: [
                  Text(
                    'Tankmates Recommendation(${commonTankmates.length})',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF006064),
                    ),
                  ),
                ],
              ),
              children: [
                if (isLoading)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: Text(
                        'Finding common tankmate...',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                else
                  _buildCommonTankmateContent(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompatibilityStatusCard() {
    if (widget.selectedFishNames.length < 2) {
      return const SizedBox.shrink();
    }

    final hasIncompatible = compatibilityResult?['has_incompatible'] as bool? ?? false;
    final hasConditional = compatibilityResult?['has_conditional'] as bool? ?? false;
    final hasIssues = hasIncompatible || hasConditional;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: hasIssues ? _getCompatibilityColor().withOpacity(0.3) : Colors.grey.shade200,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: ExpansionTile(
          initiallyExpanded: hasIssues, // Auto-expand if there are issues
          onExpansionChanged: (expanded) {
            // Optional: Add state management for expansion if needed
          },
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          collapsedIconColor: _getCompatibilityColor(),
          iconColor: _getCompatibilityColor(),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _getCompatibilityColor().withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getCompatibilityIcon(),
              color: _getCompatibilityColor(),
              size: 16,
            ),
          ),
          title: Row(
            children: [
              if (isCheckingCompatibility) ...[
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(_getCompatibilityColor()),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Checking compatibility...',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                  ),
                ),
              ] else ...[
                Expanded(
                  child: Text(
                    _getCompatibilityMessage(),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _getCompatibilityColor(),
                    ),
                  ),
                ),
              ],
            ],
          ),
          children: [
            if (!isCheckingCompatibility && compatibilityResult != null && !compatibilityResult!.containsKey('error'))
              _buildDetailedCompatibilityInfo(),
          ],
        ),
      ),
    );
  }


  Widget _buildDetailedCompatibilityInfo() {
    final hasIncompatible = compatibilityResult!['has_incompatible'] as bool? ?? false;
    final hasConditional = compatibilityResult!['has_conditional'] as bool? ?? false;
    
    if (!hasIncompatible && !hasConditional) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Incompatible pairs
          if (hasIncompatible) ...[
            _buildCompatibilitySection(
              title: 'Incompatible Fish Pairs',
              pairs: compatibilityResult!['incompatible_pairs'] as List<Map<String, dynamic>>? ?? [],
              color: Colors.red,
              icon: Icons.cancel,
            ),
            const SizedBox(height: 8),
          ],
          // Conditional pairs
          if (hasConditional) ...[
            _buildCompatibilitySection(
              title: 'Conditional Fish Pairs',
              pairs: compatibilityResult!['conditional_pairs'] as List<Map<String, dynamic>>? ?? [],
              color: Colors.orange,
              icon: Icons.warning,
            ),
            const SizedBox(height: 8),
          ],
          // Suggestions
          _buildCompatibilitySuggestions(),
        ],
      ),
    );
  }

  Widget _buildCompatibilitySection({
    required String title,
    required List<Map<String, dynamic>> pairs,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ...pairs.map((pair) => _buildFishPairItem(pair, color)),
        ],
      ),
    );
  }

  Widget _buildFishPairItem(Map<String, dynamic> pair, Color color) {
    final fishPair = pair['pair'] as List<dynamic>? ?? [];
    final reasons = pair['reasons'] as List<dynamic>? ?? [];
    
    if (fishPair.length != 2) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.only(left: 18, top: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${fishPair[0]} + ${fishPair[1]}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
          if (reasons.isNotEmpty) ...[
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.only(left: 10),
              child: Text(
                reasons.first.toString(),
                style: TextStyle(
                  fontSize: 9,
                  color: color.withOpacity(0.8),
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompatibilitySuggestions() {
    final hasIncompatible = compatibilityResult!['has_incompatible'] as bool? ?? false;
    final hasConditional = compatibilityResult!['has_conditional'] as bool? ?? false;
    
    if (!hasIncompatible && !hasConditional) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, color: Colors.blue, size: 14),
              const SizedBox(width: 4),
              Text(
                'Suggestions',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (hasIncompatible) ...[
            Text(
              '• Remove incompatible fish pairs to proceed',
              style: TextStyle(
                fontSize: 9,
                color: Colors.blue.shade700,
              ),
            ),
          ],
          if (hasConditional) ...[
            Text(
              '• Monitor conditional pairs closely or remove one fish',
              style: TextStyle(
                fontSize: 9,
                color: Colors.blue.shade700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getCompatibilityColor() {
    if (isCheckingCompatibility) return Colors.orange;
    if (compatibilityResult == null) return Colors.grey;
    if (compatibilityResult!.containsKey('error')) return Colors.red;
    
    final hasIncompatible = compatibilityResult!['has_incompatible'] as bool? ?? false;
    final hasConditional = compatibilityResult!['has_conditional'] as bool? ?? false;
    
    if (hasIncompatible) return Colors.red;
    if (hasConditional) return Colors.orange;
    return Colors.green;
  }

  IconData _getCompatibilityIcon() {
    if (compatibilityResult == null) return Icons.help_outline;
    if (compatibilityResult!.containsKey('error')) return Icons.error_outline;
    
    final hasIncompatible = compatibilityResult!['has_incompatible'] as bool? ?? false;
    final hasConditional = compatibilityResult!['has_conditional'] as bool? ?? false;
    
    if (hasIncompatible) return Icons.cancel;
    if (hasConditional) return Icons.warning;
    return Icons.check_circle;
  }

  String _getCompatibilityMessage() {
    if (compatibilityResult == null) return 'Compatibility status unknown';
    if (compatibilityResult!.containsKey('error')) return 'Failed to check compatibility';
    
    final hasIncompatible = compatibilityResult!['has_incompatible'] as bool? ?? false;
    final hasConditional = compatibilityResult!['has_conditional'] as bool? ?? false;
    
    if (hasIncompatible) {
      return 'Incompatible fish detected! Consider removing conflicting fish.';
    }
    if (hasConditional) {
      return 'Some fish may have compatibility issues.';
    }
    return 'All selected fish are compatible.';
  }

  Widget _buildCommonTankmateContent() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (fullyCompatibleTankmates.isNotEmpty || conditionalTankmates.isNotEmpty) ...[
            // Fully Compatible Tankmates
            if (fullyCompatibleTankmates.isNotEmpty) ...[
              _buildTankmateSection(
                title: 'Fully Compatible',
                tankmates: fullyCompatibleTankmates,
                icon: Icons.check_circle,
                color: const Color(0xFF4CAF50),
                description: 'These fish are highly compatible with all your selected fish.',
              ),
              if (conditionalTankmates.isNotEmpty) const SizedBox(height: 16),
            ],
            
            // Conditional Tankmates
            if (conditionalTankmates.isNotEmpty) ...[
              _buildTankmateSection(
                title: 'Conditionally Compatible',
                tankmates: conditionalTankmates,
                icon: Icons.warning,
                color: const Color(0xFFFF9800),
                description: 'These fish may work with proper conditions and monitoring.',
              ),
            ],
            
            const SizedBox(height: 16),
            // Info text
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE0F7FA),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF00BCD4).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Color(0xFF00BCD4),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'These ${commonTankmates.length} fish are compatible with all your selected fish.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF006064),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const Text(
              'No common tankmates found for selected fish.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTankmateSection({
    required String title,
    required List<String> tankmates,
    required IconData icon,
    required Color color,
    required String description,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${tankmates.length}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Tankmate Chips
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: tankmates.map((tankmate) => _buildTankmateChip(tankmate, color: color)).toList(),
        ),
        const SizedBox(height: 8),
        // Description
        Text(
          description,
          style: TextStyle(
            fontSize: 11,
            color: color.withOpacity(0.8),
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildTankmateChip(String tankmate, {Color? color}) {
    final chipColor = color ?? const Color(0xFF00BCD4);
    
    return InkWell(
      onTap: () {
        widget.onFishSelected(tankmate);
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: chipColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: chipColor.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              FontAwesomeIcons.fish,
              size: 12,
              color: chipColor,
            ),
            const SizedBox(width: 6),
            Text(
              tankmate,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: chipColor,
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => FishInfoDialog(fishName: tankmate),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: chipColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.remove_red_eye,
                  size: 10,
                  color: chipColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }



}
