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
  late TabController _tabController;
  
  // Collapsible state for tankmate sections (initially collapsed)
  bool _showGreatTankmates = false;
  bool _showMaybeCompatible = false;
  bool _showAvoidFish = false;
  
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
      insetPadding: EdgeInsets.zero,
      child: Container(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        decoration: const BoxDecoration(
          color: Colors.white,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Enhanced Header with fish image background
              Container(
                height: 220,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF006064),
                      Color(0xFF00838F),
                      Color(0xFF00ACC1),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF006064).withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Fish image background
                    _buildFishHeaderImage(),
                    // Dark overlay for better text readability
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.2),
                            Colors.black.withOpacity(0.7),
                          ],
                        ),
                      ),
                    ),
                    // Header content
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                      child: Column(
                        children: [
                          // Close button at top-right
                          Row(
                            children: [
                              const Spacer(),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.close, color: Colors.white, size: 24),
                                  onPressed: () => Navigator.of(context).pop(),
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          // Fish name and scientific name at bottom-left
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.fishName,
                                      style: const TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        letterSpacing: 0.5,
                                        shadows: [
                                          Shadow(
                                            offset: Offset(2, 2),
                                            blurRadius: 8,
                                            color: Colors.black54,
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (fishInfo?['scientific_name'] != null) ...[
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                            color: Colors.white.withOpacity(0.3),
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          fishInfo!['scientific_name'].toString(),
                                          style: const TextStyle(
                                            fontSize: 16,
                                            color: Colors.white,
                                            fontStyle: FontStyle.italic,
                                            fontWeight: FontWeight.w500,
                                            shadows: [
                                              Shadow(
                                                offset: Offset(1, 1),
                                                blurRadius: 4,
                                                color: Colors.black54,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
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
              
              // Tab Navigation
              if (!isLoading && error == null)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TabBar(
                    controller: _tabController,
                    labelColor: const Color(0xFF006064),
                    unselectedLabelColor: Colors.grey[600],
                    indicatorColor: const Color(0xFF00ACC1),
                    indicatorWeight: 3,
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
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
      ),
    );
  }


  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFE0F7FA),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00ACC1).withOpacity(0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const CircularProgressIndicator(
              color: Color(0xFF00ACC1),
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Loading fish information...',
            style: TextStyle(
              color: Color(0xFF006064),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
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
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.red.withOpacity(0.1),
                    Colors.red.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.red.withOpacity(0.2),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Oops! Something went wrong',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF00ACC1),
                    Color(0xFF26C6DA),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00ACC1).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: _loadFishInfo,
                icon: const Icon(Icons.refresh_rounded, size: 20),
                label: const Text(
                  'Try Again',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildDescriptionCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
        border: Border.all(
          color: const Color(0xFF00ACC1).withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF00ACC1),
                        Color(0xFF26C6DA),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.info_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'About This Fish',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              fishInfo!['description'].toString(),
              style: const TextStyle(
                fontSize: 16,
                height: 1.6,
                color: Color(0xFF374151),
                fontWeight: FontWeight.w400,
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
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              'Basic information not available for ${widget.fishName}',
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: const Color(0xFF00ACC1).withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF006064),
                        Color(0xFF00838F),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.summarize_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Fish Details',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildInfoGrid(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoGrid() {
    final info = [
      {'icon': Icons.straighten, 'label': 'Max Size', 'value': fishInfo!['max_size' ] != null ? '${fishInfo!['max_size']} cm' : 'N/A'},
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFF8FAFC),
            const Color(0xFFE0F7FA).withOpacity(0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF00ACC1).withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00ACC1).withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF00ACC1).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  item['icon'] as IconData,
                  size: 16,
                  color: const Color(0xFF00ACC1),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item['label'] as String,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item['value'] as String,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F2937),
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

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: const Color(0xFF00ACC1).withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF00ACC1),
                        Color(0xFF26C6DA),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    FontAwesomeIcons.fish,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Care Requirements',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildCareRequirement(
              Icons.thermostat_rounded,
              'Temperature',
              _getTemperatureRange(),
              const Color(0xFF00ACC1),
            ),
            _buildCareRequirement(
              Icons.science_rounded,
              'pH Level',
              fishInfo!['ph_range']?.toString() ?? 'N/A',
              const Color(0xFF00ACC1),
            ),
            _buildCareRequirement(
              null,
              'Minimum Tank Size',
              _getTankSizeDisplay(),
              const Color(0xFF00ACC1),
            ),
            _buildCareRequirement(
              Icons.restaurant_rounded,
              'Diet',
              fishInfo!['diet']?.toString() ?? 'N/A',
              const Color(0xFF00ACC1),
            ),
            _buildCareRequirement(
              Icons.star_rounded,
              'Care Level',
              fishInfo!['care_level']?.toString() ?? 'N/A',
              const Color(0xFF00ACC1),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCareRequirement(IconData? icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFE0F7FA),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF00ACC1).withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: icon != null 
                ? Icon(icon, size: 18, color: const Color(0xFF00ACC1))
                : Image.asset(
                    'lib/icons/Create_Aquarium.png',
                    width: 18,
                    height: 18,
                    color: const Color(0xFF00ACC1),
                  ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF006064),
                      fontSize: 14,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF374151),
                      height: 1.3,
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
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F7FA),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.group_off_rounded,
                  size: 48,
                  color: Color(0xFF00ACC1),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Tankmate information not available',
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Fully Compatible Tankmates
          if (tankmateInfo!.fullyCompatibleTankmates.isNotEmpty)
            _buildSimpleTankmateSection(
              'Compatible Tankmates',
              tankmateInfo!.fullyCompatibleTankmates,
              const Color(0xFF4CAF50),
              Icons.check_circle_outline_rounded,
              _showGreatTankmates,
              () => setState(() => _showGreatTankmates = !_showGreatTankmates),
            ),
          
          // Conditional Tankmates
          if (tankmateInfo!.conditionalTankmates.isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildSimpleTankmateSection(
              'Compatible with Conditions',
              tankmateInfo!.conditionalTankmates.map((t) => t.name).toList(),
              const Color(0xFFFF9800),
              Icons.warning_outlined,
              _showMaybeCompatible,
              () => setState(() => _showMaybeCompatible = !_showMaybeCompatible),
            ),
          ],
          
          // Incompatible Tankmates
          if (tankmateInfo!.incompatibleTankmates.isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildSimpleTankmateSection(
              'Incompatible Tankmates',
              tankmateInfo!.incompatibleTankmates,
              const Color(0xFFF44336),
              Icons.cancel_outlined,
              _showAvoidFish,
              () => setState(() => _showAvoidFish = !_showAvoidFish),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSimpleTankmateSection(String title, List<String> fish, Color color, IconData icon, bool isExpanded, VoidCallback onToggle) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header (clickable to toggle)
          InkWell(
            onTap: onToggle,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withOpacity(0.1),
                    color.withOpacity(0.05),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
                border: Border(
                  bottom: BorderSide(
                    color: color.withOpacity(0.2),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(icon, color: color, size: 16),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: color,
                        letterSpacing: 0.3,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${fish.length}',
                      style: TextStyle(
                        fontSize: 12,
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: color,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
          
          // Fish list (collapsible)
          if (isExpanded) ...[
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: fish.map((fishName) => _buildSimpleFishItem(fishName, color)).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSimpleFishItem(String fishName, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _showFishInfoDialog(fishName),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: color.withOpacity(0.15),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // Fish icon
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  FontAwesomeIcons.fish,
                  size: 12,
                  color: color,
                ),
              ),
              const SizedBox(width: 8),
              // Fish name
              Expanded(
                child: Text(
                  fishName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color.withOpacity(0.9),
                    letterSpacing: 0.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Eye icon
              Icon(
                Icons.remove_red_eye,
                size: 14,
                color: color.withOpacity(0.6),
              ),
            ],
          ),
        ),
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
      return tempRange.contains('°C') ? tempRange : '${tempRange}°C';
    }
    
    return 'N/A';
  }

  String _getTankSizeDisplay() {
    if (fishInfo == null) return 'N/A';
    
    // Try different possible field names for tank size
    final tankSizeL = fishInfo!['minimum_tank_size_l'] ?? 
                      fishInfo!['minimum_tank_size_(l)'] ?? 
                      fishInfo!['min_tank_size'] ?? 
                      fishInfo!['tank_size'];
    
    if (tankSizeL != null && tankSizeL.toString().isNotEmpty && tankSizeL.toString() != 'null') {
      return '${tankSizeL} L';
    }
    
    return 'N/A';
  }

  Widget _buildFishHeaderImage() {
    // Try to get fish image from API
    final imageUrl = '${ApiConfig.baseUrl}/fish-image/${widget.fishName}';
    
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          color: const Color(0xFF006064),
          child: const Center(
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        // Fallback to gradient background if image fails to load
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF006064), Color(0xFF00ACC1)],
            ),
          ),
        );
      },
    );
  }

  // Show fish info dialog for tankmate fish
  void _showFishInfoDialog(String fishName) {
    showDialog(
      context: context,
      builder: (context) => FishInfoDialog(fishName: fishName),
    );
  }
}

