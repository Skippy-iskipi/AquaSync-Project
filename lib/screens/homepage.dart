import 'package:flutter/material.dart';
import '../widgets/bottom_navigation.dart';
import '../screens/capture.dart';
import '../screens/sync.dart';
import '../screens/logbook.dart';
import '../screens/fish_list_screen.dart';
import 'package:provider/provider.dart';
import 'logbook_provider.dart';
import 'dart:io';
import '../models/water_calculation.dart';
import '../models/fish_calculation.dart';
import 'package:intl/intl.dart';
import '../models/compatibility_result.dart';
import '../models/fish_prediction.dart';
import '../screens/calculator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/auth_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_config.dart';

class HomePage extends StatefulWidget {
  final int initialTabIndex;
  final String? initialFish;
  final File? initialFishImage;
  
  const HomePage({
    Key? key,
    this.initialTabIndex = 0,
    this.initialFish,
    this.initialFishImage,
  }) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late int _selectedIndex;
  int _logBookTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialTabIndex;
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _showUserInfo(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Profile section
            Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Profile picture
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: const Color(0xFF00BFB3),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.person,
                      size: 50,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Email
                  Text(
                    user?.email ?? 'No email',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF006064),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Account type
                ],
              ),
            ),
            const Divider(height: 1),
            // Settings options
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _buildSettingItem(
                    icon: Icons.person_outline,
                    title: 'Edit Profile',
                    onTap: () {
                      // TODO: Implement edit profile
                      Navigator.pop(context);
                    },
                  ),
                  _buildSettingItem(
                    icon: Icons.notifications_outlined,
                    title: 'Notifications',
                    onTap: () {
                      // TODO: Implement notifications settings
                      Navigator.pop(context);
                    },
                  ),
                  _buildSettingItem(
                    icon: Icons.security_outlined,
                    title: 'Privacy & Security',
                    onTap: () {
                      // TODO: Implement privacy settings
                      Navigator.pop(context);
                    },
                  ),
                  _buildSettingItem(
                    icon: Icons.help_outline,
                    title: 'Help & Support',
                    onTap: () {
                      // TODO: Implement help & support
                      Navigator.pop(context);
                    },
                  ),
                  _buildSettingItem(
                    icon: Icons.info_outline,
                    title: 'About',
                    onTap: () {
                      // TODO: Implement about section
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
            // Logout button
            Container(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton.icon(
                onPressed: () async {
                  await Supabase.instance.client.auth.signOut();
                  if (context.mounted) {
                    Navigator.of(context).pop(); // Close bottom sheet
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => const AuthScreen()),
                      (route) => false,
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF006064),
                  foregroundColor: Colors.white,
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  minimumSize: const Size(double.infinity, 50),
                ),
                icon: const Icon(Icons.logout, size: 24),
                label: const Text(
                  'Logout',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF00BFB3).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: const Color(0xFF00BFB3),
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: Colors.grey,
      ),
      onTap: onTap,
    );
  }

  Widget _getSelectedScreen() {
    switch (_selectedIndex) {
      case 0:
        return _buildHomeContent();
      case 1:
        return LogBook(initialTabIndex: _logBookTabIndex);
      case 2:
        return const Calculator();
      case 3:
        return SyncScreen(
          initialFish: widget.initialFish,
          initialFishImage: widget.initialFishImage,
        );
      default:
        return _buildHomeContent();
    }
  }

  Widget _buildHomeContent() {
    final logBookProvider = Provider.of<LogBookProvider>(context);
    
    // Get recent items from each type
    final recentPredictions = logBookProvider.savedPredictions.take(5).toList();
    final recentWaterCalculations = logBookProvider.getRecentWaterCalculations();
    final recentFishCalculations = logBookProvider.getRecentFishCalculations();
    final recentCompatibilityResults = List<CompatibilityResult>.from(logBookProvider.savedCompatibilityResults)
      ..sort((a, b) => b.dateChecked.compareTo(a.dateChecked));
    
    // Combine all recent items
    final allItems = [
      ...recentPredictions,
      ...recentWaterCalculations,
      ...recentFishCalculations,
      ...recentCompatibilityResults,
    ]..sort((a, b) {
        DateTime dateA;
        DateTime dateB;
        
        if (a is FishPrediction) {
          dateA = DateTime.now(); // Use current time for FishPrediction
        } else if (a is WaterCalculation) {
          dateA = a.dateCalculated;
        } else if (a is FishCalculation) {
          dateA = a.dateCalculated;
        } else {
          dateA = (a as CompatibilityResult).dateChecked;
        }
        
        if (b is FishPrediction) {
          dateB = DateTime.now(); // Use current time for FishPrediction
        } else if (b is WaterCalculation) {
          dateB = b.dateCalculated;
        } else if (b is FishCalculation) {
          dateB = b.dateCalculated;
        } else {
          dateB = (b as CompatibilityResult).dateChecked;
        }
        
        return dateB.compareTo(dateA);
      });

    return Container(
      color: Colors.white,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildExploreSection(),
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.only(left: 16, top: 24, bottom: 8),
              child: Text(
                'Recent Activity',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF006064),
                ),
              ),
            ),
            if (allItems.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                child: Center(
                  child: Text(
                    'No recent activities yet',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 16,
                    ),
                  ),
                ),
              )
            else
              ...allItems.take(5).map((item) => _buildRecentActivityCard(item)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildExploreSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 16.0, right: 16.0, top: 30.0, bottom: 15.0),
          child: Text(
            'Explore',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF006064),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              Expanded(
                child: _buildExploreCard(
                  title: 'Salt\nWater Fish',
                  image: 'lib/icons/saltwater_fish.png',
                  color: const Color(0xFF00BCD4),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const FishListScreen(
                          title: 'Salt Water Fish',
                          isSaltWater: true,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildExploreCard(
                  title: 'Fresh\nWater Fish',
                  image: 'lib/icons/freshwater_fish.png',
                  color: const Color(0xFF00BCD4),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const FishListScreen(
                          title: 'Fresh Water Fish',
                          isSaltWater: false,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExploreCard({
    required String title,
    required String image,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 120,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Stack(
          children: [
            // Image positioned on the right side
            Positioned(
              right: -5,  // Slightly off-screen to the right
              top: -10,    // Positioned from the top
              child: SizedBox(
                width: 130,  // Reduced width
                height: 130, // Reduced height
                child: Image.asset(
                  image,
                  fit: BoxFit.contain,  // Changed to contain for better proportions
                ),
              ),
            ),
            // Text at the bottom
            Positioned(
              left: 12,
              bottom: 12,
              child: Text(
                '${title.split('\n')[0]}\n${title.split('\n')[1]}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivityCard(dynamic item) {
    int logBookTabIndex = 0;
    Widget leadingWidget;
    Widget contentWidget;

    if (item is CompatibilityResult) {
      logBookTabIndex = 2; // Fish Compatibility tab in LogBook
    } else if (item is FishPrediction) {
      logBookTabIndex = 0; // Fish Collection tab in LogBook
    } else if (item is WaterCalculation || item is FishCalculation) {
      logBookTabIndex = 1; // Fish Calculator tab in LogBook
    }

    if (item is CompatibilityResult) {
      logBookTabIndex = 2; // Fish Compatibility tab in LogBook
      leadingWidget = Container(
        width: 150,
        height: 80,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  bottomLeft: Radius.circular(8),
                ),
                child: FutureBuilder<http.Response>(
                  future: http.get(Uri.parse(ApiConfig.getFishImageUrl(item.fish1Name))),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Container(
                        color: Colors.grey[200],
                        child: const Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (snapshot.hasError || !snapshot.hasData || snapshot.data!.statusCode != 200) {
                      return Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.image_not_supported, color: Colors.grey, size: 24),
                      );
                    }
                    final Map<String, dynamic> jsonData = json.decode(snapshot.data!.body);
                    final String? base64Image = jsonData['image_data'];
                    if (base64Image == null || base64Image.isEmpty) {
                      return Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.image_not_supported, color: Colors.grey, size: 24),
                      );
                    }
                    final String base64Str = base64Image.contains(',') ? base64Image.split(',')[1] : base64Image;
                    return Image.memory(
                      base64Decode(base64Str),
                      fit: BoxFit.cover,
                      height: 80,
                    );
                  },
                ),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
                child: FutureBuilder<http.Response>(
                  future: http.get(Uri.parse(ApiConfig.getFishImageUrl(item.fish2Name))),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Container(
                        color: Colors.grey[200],
                        child: const Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (snapshot.hasError || !snapshot.hasData || snapshot.data!.statusCode != 200) {
                      return Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.image_not_supported, color: Colors.grey, size: 24),
                      );
                    }
                    final Map<String, dynamic> jsonData = json.decode(snapshot.data!.body);
                    final String? base64Image = jsonData['image_data'];
                    if (base64Image == null || base64Image.isEmpty) {
                      return Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.image_not_supported, color: Colors.grey, size: 24),
                      );
                    }
                    final String base64Str = base64Image.contains(',') ? base64Image.split(',')[1] : base64Image;
                    return Image.memory(
                      base64Decode(base64Str),
                      fit: BoxFit.cover,
                      height: 80,
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      );
      contentWidget = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${item.fish1Name} & ${item.fish2Name}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.isCompatible ? 'Compatible' : 'Not Compatible',
            style: TextStyle(
              color: item.isCompatible ? Colors.green : Colors.red,
              fontSize: 14,
            ),
          ),
          Text(
            DateFormat('MMM d, y').format(item.dateChecked),
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
        ],
      );
    } else if (item is FishPrediction) {
      leadingWidget = Container(
        width: 150,
        height: 80,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
        ),
        child: ClipRRect(
          child: Image.file(
            File(item.imagePath),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => const Icon(Icons.error),
          ),
        ),
      );
      contentWidget = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'New Fish Identified',
            style: TextStyle(
              color: Color(0xFF006064),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.commonName,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          Text(
            DateFormat('MMM d, y').format(DateTime.now()),
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
        ],
      );
    } else if (item is WaterCalculation) {
      leadingWidget = Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          color: Colors.teal.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(
          Icons.water_drop,
          color: Color(0xFF006064),
          size: 30,
        ),
      );
      contentWidget = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Water Calculator',
            style: TextStyle(
              color: Color(0xFF006064),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tank Volume: ${item.minimumTankVolume}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          Text(
            DateFormat('MMM d, y').format(item.dateCalculated),
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
        ],
      );
    } else if (item is FishCalculation) {
      leadingWidget = Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          color: Colors.teal.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(
          Icons.water,
          color: Color(0xFF006064),
          size: 30,
        ),
      );
      contentWidget = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Fish Calculator',
            style: TextStyle(
              color: Color(0xFF006064),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tank Volume: ${item.tankVolume}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          Text(
            DateFormat('MMM d, y').format(item.dateCalculated),
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
        ],
      );
    } else {
      return const SizedBox.shrink(); // Return empty widget for unknown types
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedIndex = 1; // Set HomePage to LogBook tab
            _logBookTabIndex = logBookTabIndex; // Set the correct LogBook tab
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              leadingWidget,
              const SizedBox(width: 12),
              Expanded(child: contentWidget),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    
    print('Current user id: ${Supabase.instance.client.auth.currentUser?.id}');
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          _selectedIndex == 0 ? 'AquaSync' :
          _selectedIndex == 1 ? 'Log Book' :
          _selectedIndex == 2 ? 'Calculator' : 'Sync',
          style: const TextStyle(
            color: Color(0xFF006064),
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 2,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle),
            onPressed: () => _showUserInfo(context),
            tooltip: 'Account',
          ),
        ],
      ),
      body: _getSelectedScreen(),
      floatingActionButton: isKeyboardVisible ? null : FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CaptureScreen()),
          );
        },
        backgroundColor: Colors.white,
        shape: const CircleBorder(),
        child: Image.asset('lib/icons/capture_icon.png', width: 60, height: 60),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomNavigation(
        selectedIndex: _selectedIndex,
        onItemTapped: _onItemTapped,
      ),
    );
  }
}
