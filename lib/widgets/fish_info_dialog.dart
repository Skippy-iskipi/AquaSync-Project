import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_config.dart';
import '../services/enhanced_tankmate_service.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'fish_images_grid.dart';

class FishInfoDialog extends StatefulWidget {
  final String fishName;

  const FishInfoDialog({super.key, required this.fishName});

  @override
  State<FishInfoDialog> createState() => _FishInfoDialogState();
}

class _FishInfoDialogState extends State<FishInfoDialog> with TickerProviderStateMixin {
  Map<String, dynamic>? fishInfo;
  DetailedTankmateInfo? tankmateInfo;
  bool isLoading = true;
  String? error;
  bool _showAllCompatibility = false;
  late TabController _tabController;
  
  // Animation controllers for smooth transitions
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this); // Changed back to 3 tabs
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _loadFishInfo();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadFishInfo() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      // Load fish information from the fish list endpoint
      final response = await http.get(
        Uri.parse(ApiConfig.fishListEndpoint),
        headers: {'Accept': 'application/json'},
      ).timeout(ApiConfig.timeout);

      Map<String, dynamic>? fishData;
      if (response.statusCode == 200) {
        final List<dynamic> fishList = json.decode(response.body);
        // Find the specific fish
        for (var fish in fishList) {
          if (fish['common_name']?.toString().toLowerCase() == widget.fishName.toLowerCase()) {
            fishData = fish;
            break;
          }
        }
      }

      // Load tankmate information
      final tankmates = await EnhancedTankmateService.getTankmateDetails(widget.fishName);

      setState(() {
        fishInfo = fishData;
        tankmateInfo = tankmates;
        isLoading = false;
      });
      
      _fadeController.forward();
    } catch (e) {
      setState(() {
        error = 'Failed to load fish information: $e';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: MediaQuery.of(context).size.width - 32,
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            // Enhanced Header with gradient and better spacing
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF006064), Color(0xFF00ACC1)],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(FontAwesomeIcons.fish, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.fishName,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            if (fishInfo?['scientific_name'] != null)
                              Text(
                                fishInfo!['scientific_name'].toString(),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(0.8),
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 24),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Key stats row for quick overview
                  if (!isLoading && fishInfo != null) _buildQuickStats(),
                ],
              ),
            ),
            
            // Tab Navigation
            if (!isLoading && error == null)
              Container(
                color: Colors.grey[50],
                child: TabBar(
                  controller: _tabController,
                  labelColor: const Color(0xFF006064),
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: const Color(0xFF00ACC1),
                  indicatorWeight: 3,
                  tabs: const [
                    Tab(text: 'Care Guide', icon: Icon(FontAwesomeIcons.fish, size: 18)),
                    Tab(text: 'Tankmates', icon: Icon(Icons.group, size: 18)),
                    Tab(text: 'Images', icon: Icon(Icons.photo_library, size: 18)),
                  ],
                ),
              ),
            
            // Content
            Expanded(
              child: isLoading
                  ? _buildLoadingState()
                  : error != null
                      ? _buildErrorState()
                      : FadeTransition(
                          opacity: _fadeAnimation,
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              _buildCareGuideTab(),
                              _buildTankmatesTab(),
                              _buildImagesTab(),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStats() {
    if (fishInfo == null) return const SizedBox();
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildQuickStat(Icons.straighten, 'Size', fishInfo!['max_size']?.toString() ?? 'N/A'),
        _buildQuickStat(Icons.water, 'Water Type', fishInfo!['water_type']?.toString() ?? 'N/A'),
        _buildQuickStat(Icons.schedule, 'Lifespan', fishInfo!['lifespan']?.toString() ?? 'N/A'),
      ],
    );
  }

  Widget _buildQuickStat(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFF00BCD4)),
          SizedBox(height: 16),
          Text('Loading fish information...', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.error_outline, size: 48, color: Colors.red),
            ),
            const SizedBox(height: 16),
            Text(
              'Oops! Something went wrong',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadFishInfo,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00ACC1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildDescriptionCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info, color: const Color(0xFF006064), size: 20),
                const SizedBox(width: 8),
                const Text(
                  'About This Fish',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF006064),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              fishInfo!['description'].toString(),
              style: const TextStyle(
                fontSize: 15,
                height: 1.5,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCareGuideTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          if (fishInfo?['description'] != null && fishInfo!['description'].toString().isNotEmpty)
            _buildDescriptionCard(),
          const SizedBox(height: 16),
          _buildBasicInfoCard(),
          const SizedBox(height: 16),
          _buildCareRequirementsCard(),
        ],
      ),
    );
  }

  Widget _buildBasicInfoCard() {
    if (fishInfo == null) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: Text(
              'Basic information not available for ${widget.fishName}',
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.summarize, color: const Color(0xFF006064), size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Quick Facts',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF006064),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoGrid(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoGrid() {
    final info = [
      {'icon': Icons.straighten, 'label': 'Max Size', 'value': fishInfo!['max_size']?.toString() ?? 'N/A'},
      {'icon': Icons.mood, 'label': 'Temperament', 'value': fishInfo!['temperament']?.toString() ?? 'N/A'},
      {'icon': Icons.water, 'label': 'Water Type', 'value': fishInfo!['water_type']?.toString() ?? 'N/A'},
      {'icon': Icons.schedule, 'label': 'Lifespan', 'value': fishInfo!['lifespan']?.toString() ?? 'N/A'},
    ];

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildInfoGridItem(info[0])),
            const SizedBox(width: 12),
            Expanded(child: _buildInfoGridItem(info[1])),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildInfoGridItem(info[2])),
            const SizedBox(width: 12),
            Expanded(child: _buildInfoGridItem(info[3])),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoGridItem(Map<String, dynamic> item) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(item['icon'] as IconData, size: 16, color: const Color(0xFF006064)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  item['label'] as String,
                  style: const TextStyle(
                    fontSize: 11, 
                    color: Colors.grey, 
                    fontWeight: FontWeight.w500
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            item['value'] as String,
            style: const TextStyle(
              fontSize: 13, 
              fontWeight: FontWeight.w600
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildCareRequirementsCard() {
    if (fishInfo == null) return const SizedBox();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(FontAwesomeIcons.fish, color: const Color(0xFF006064), size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Care Requirements',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF006064),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildCareRequirement(
              Icons.thermostat,
              'Temperature',
              _getTemperatureRange(),
              Colors.orange,
            ),
            _buildCareRequirement(
              Icons.science_outlined,
              'pH Level',
              fishInfo!['ph_range']?.toString() ?? 'N/A',
              Colors.blue,
            ),
            _buildCareRequirement(
              Icons.home,
              'Minimum Tank Size',
              fishInfo!['minimum_tank_size_l']?.toString() ?? 'N/A',
              Colors.green,
            ),
            _buildCareRequirement(
              Icons.restaurant,
              'Diet',
              fishInfo!['diet']?.toString() ?? 'N/A',
              Colors.purple,
            ),
            _buildCareRequirement(
              Icons.star,
              'Care Level',
              fishInfo!['care_level']?.toString() ?? 'N/A',
              Colors.red,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCareRequirement(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: color,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTankmatesTab() {
    if (tankmateInfo == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Tankmate information not available',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          if (tankmateInfo!.fullyCompatibleTankmates.isNotEmpty)
            _buildCompatibilitySection(
              'Great Tankmates',
              tankmateInfo!.fullyCompatibleTankmates,
              Colors.green,
              Icons.check_circle,
              6,
            ),
          
          if (tankmateInfo!.conditionalTankmates.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildConditionalSection(),
          ],
          
          if (tankmateInfo!.incompatibleTankmates.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildCompatibilitySection(
              'Avoid These Fish',
              tankmateInfo!.incompatibleTankmates,
              Colors.red,
              Icons.cancel,
              4,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompatibilitySection(String title, List<String> fish, Color color, IconData icon, int initialCount) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: fish
                  .take(_showAllCompatibility ? fish.length : initialCount)
                  .map((fishName) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: color.withOpacity(0.3)),
                        ),
                        child: Text(
                          fishName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: color.withOpacity(0.8),
                          ),
                        ),
                      )).toList(),
            ),
            if (fish.length > initialCount)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      _showAllCompatibility = !_showAllCompatibility;
                    });
                  },
                  child: Text(
                    _showAllCompatibility 
                        ? 'Show Less' 
                        : '+ ${fish.length - initialCount} more',
                    style: TextStyle(color: color, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildConditionalSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Maybe Compatible',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'These fish may work under the right conditions',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            ...(_showAllCompatibility 
                ? tankmateInfo!.conditionalTankmates 
                : tankmateInfo!.conditionalTankmates.take(2)
              ).map((tankmate) => _buildTankmateRecommendation(tankmate)),
            if (tankmateInfo!.conditionalTankmates.length > 2)
              TextButton(
                onPressed: () {
                  setState(() {
                    _showAllCompatibility = !_showAllCompatibility;
                  });
                },
                child: Text(
                  _showAllCompatibility 
                      ? 'Show Less' 
                      : '+ ${tankmateInfo!.conditionalTankmates.length - 2} more',
                  style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w500),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTankmateRecommendation(TankmateRecommendation tankmate) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        backgroundColor: Colors.orange.withOpacity(0.05),
        collapsedBackgroundColor: Colors.orange.withOpacity(0.05),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: Text(
          tankmate.name,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Requirements for compatibility:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(height: 8),
                ...tankmate.conditions.map((condition) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 6),
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(
                          color: Colors.orange,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          condition,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FishImagesGrid(
            fishName: widget.fishName,
            showTitle: true,
            initialDisplayCount: 4, // Show more images initially in dialog
          ),
        ],
      ),
    );
  }

  String _getTemperatureRange() {
    final tempRange = fishInfo!['temperature_range']?.toString();
    
    if (tempRange != null && tempRange.isNotEmpty && tempRange != 'null') {
      return '${tempRange}°F';
    }
    
    return 'N/A';
  }
}

