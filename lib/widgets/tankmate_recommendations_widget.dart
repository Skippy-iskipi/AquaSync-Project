import 'package:flutter/material.dart';
import '../services/enhanced_tankmate_service.dart';
import 'fish_info_dialog.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class TankmateRecommendationsWidget extends StatefulWidget {
  final List<String> selectedFish;
  final Function(String) onFishSelected;

  const TankmateRecommendationsWidget({
    super.key,
    required this.selectedFish,
    required this.onFishSelected,
  });

  @override
  State<TankmateRecommendationsWidget> createState() => _TankmateRecommendationsWidgetState();
}

class _TankmateRecommendationsWidgetState extends State<TankmateRecommendationsWidget> {
  Map<String, DetailedTankmateInfo> tankmateData = {};
  bool isLoading = false;
  List<String> commonTankmates = [];
  List<String> conditionalTankmates = [];

  @override
  void initState() {
    super.initState();
    if (widget.selectedFish.isNotEmpty) {
      _loadTankmateRecommendations();
    }
  }

  @override
  void didUpdateWidget(TankmateRecommendationsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedFish != widget.selectedFish && widget.selectedFish.isNotEmpty) {
      _loadTankmateRecommendations();
    }
  }

  Future<void> _loadTankmateRecommendations() async {
    if (widget.selectedFish.isEmpty) return;

    setState(() {
      isLoading = true;
    });

    try {
      // Load tankmate data for each selected fish
      final Map<String, DetailedTankmateInfo> newTankmateData = {};
      for (String fishName in widget.selectedFish) {
        final data = await EnhancedTankmateService.getTankmateDetails(fishName);
        if (data != null) {
          newTankmateData[fishName] = data;
        }
      }

      // Find common tankmates across all selected fish
      final Set<String> commonSet = <String>{};
      final Set<String> conditionalSet = <String>{};

      if (newTankmateData.isNotEmpty) {
        // Start with tankmates of the first fish
        final firstFish = newTankmateData.values.first;
        commonSet.addAll(firstFish.fullyCompatibleTankmates);
        conditionalSet.addAll(firstFish.conditionalTankmates.map((t) => t.name));

        // Find intersection with other fish
        for (var data in newTankmateData.values.skip(1)) {
          commonSet.retainAll(data.fullyCompatibleTankmates);
          conditionalSet.retainAll(data.conditionalTankmates.map((t) => t.name));
        }

        // Remove already selected fish from recommendations
        commonSet.removeWhere((fish) => widget.selectedFish.contains(fish));
        conditionalSet.removeWhere((fish) => widget.selectedFish.contains(fish));
      }

      setState(() {
        tankmateData = newTankmateData;
        commonTankmates = commonSet.toList()..sort();
        conditionalTankmates = conditionalSet.toList()..sort();
        isLoading = false;
      });
    } catch (e) {
      print('Error loading tankmate recommendations: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.selectedFish.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFE0F7FA),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                const Icon(FontAwesomeIcons.userGroup, color: Color(0xFF006064)),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Tankmate Recommendations',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF006064),
                    ),
                  ),
                ),
                if (isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF006064)),
                    ),
                  ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: isLoading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('Loading recommendations...'),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (commonTankmates.isEmpty && conditionalTankmates.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Colors.grey,
                                  size: 32,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'No common tankmate recommendations found for your current fish selection.',
                                  style: TextStyle(color: Colors.grey),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      else ...[
                        // Fully compatible section
                        if (commonTankmates.isNotEmpty) ...[
                          _buildSectionHeader(
                            'Fully Compatible',
                            Icons.check_circle,
                            Colors.green,
                            commonTankmates.length,
                          ),
                          const SizedBox(height: 12),
                          _buildTankmateGrid(commonTankmates, Colors.green),
                          const SizedBox(height: 16),
                        ],

                        // Conditional section
                        if (conditionalTankmates.isNotEmpty) ...[
                          _buildSectionHeader(
                            'Conditional Compatibility',
                            Icons.warning,
                            Colors.orange,
                            conditionalTankmates.length,
                          ),
                          const SizedBox(height: 12),
                          _buildTankmateGrid(conditionalTankmates, Colors.orange),
                        ],
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color, int count) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Text(
            count.toString(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTankmateGrid(List<String> tankmates, Color accentColor) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: tankmates.map((fishName) => _buildTankmateChip(fishName, accentColor)).toList(),
    );
  }

  Widget _buildTankmateChip(String fishName, Color accentColor) {
    return InkWell(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => FishInfoDialog(fishName: fishName),
        );
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: accentColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accentColor.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              FontAwesomeIcons.fish,
              size: 12,
              color: accentColor,
            ),
            const SizedBox(width: 6),
            Text(
              fishName,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: accentColor.withOpacity(0.8),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.add_circle_outline,
              size: 16,
              color: accentColor,
            ),
          ],
        ),
      ),
    );
  }
}
