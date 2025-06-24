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
import '../models/compatibility_result.dart';
import '../models/fish_prediction.dart';
import '../screens/calculator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/auth_screen.dart';
import '../screens/subscription_page.dart';


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
  int _selectedIndex = 0;
  int _logBookTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialTabIndex;
    // The LogBookProvider is now self-initializing.
    // This call is redundant and has been removed to prevent race conditions.
    /*
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<LogBookProvider>(context, listen: false).init();
    });
    */
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
                  // Display current plan and upgrade button
                  FutureBuilder<Object?>(
                    future: user != null
                        ? Supabase.instance.client
                            .from('profiles')
                            .select('tier_plan')
                            .eq('id', user.id)
                            .single()
                        : Future.value({'tier_plan': 'free'}),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const SizedBox(height: 32, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
                      }
                      final data = snapshot.data as Map<String, dynamic>?;
                      final plan = (data != null && data['tier_plan'] != null)
                          ? data['tier_plan'] as String
                          : 'free';
                      return Column(
                        children: [
                          Text(
                            'Plan: ${plan.isNotEmpty ? plan[0].toUpperCase() + plan.substring(1) : 'Free'}',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Color(0xFF006064),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      );
                    },
                  ),
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
    return Container(
      color: Colors.white,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            // Explore Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.remove_red_eye, color: Color(0xFF00BCD4), size: 22),
                      SizedBox(width: 8),
                      Text(
                        'Explore',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF006064),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Explore Card
                  _ModernExploreCard(),
                ],
              ),
            ),
            const SizedBox(height: 32),
            // Recent Activity Section
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, bottom: 8),
              child: Row(
                children: const [
                  Icon(Icons.show_chart, color: Color(0xFF00C853), size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Recent Activity',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF006064),
                    ),
                  ),
                ],
              ),
            ),
            Consumer<LogBookProvider>(
              builder: (context, logBookProvider, child) {
                final allItems = logBookProvider.allItems;
                if (allItems.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                    child: Center(
                      child: Text(
                        'No recent activities yet',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  );
                }
                return Column(
                  children: allItems.take(5).map((item) => _ModernRecentActivityCard(item: item, onTap: () {
                    setState(() {
                      if (item is CompatibilityResult) {
                        _selectedIndex = 1;
                        _logBookTabIndex = 2;
                      } else if (item is FishPrediction) {
                        _selectedIndex = 1;
                        _logBookTabIndex = 0;
                      } else if (item is WaterCalculation || item is FishCalculation) {
                        _selectedIndex = 1;
                        _logBookTabIndex = 1;
                      }
                    });
                  })).toList(),
                );
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }





  @override
  Widget build(BuildContext context) {
    final bool isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    
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
          FutureBuilder<Object?>(
            future: () async {
              final user = Supabase.instance.client.auth.currentUser;
              if (user != null) {
                final data = await Supabase.instance.client
                    .from('profiles')
                    .select('tier_plan')
                    .eq('id', user.id)
                    .single();
                return data['tier_plan'] ?? 'free';
              }
              return 'free';
            }(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(width: 48, height: 32);
              }
              final plan = (snapshot.data as String?)?.toLowerCase().replaceAll(' ', '_') ?? 'free';
              if (plan == 'free') {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SubscriptionPage()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00BFB3),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Upgrade Your Plan',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                );
              } else {
                return const SizedBox.shrink();
              }
            },
          ),
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

// Modern Explore Card Widget
class _ModernExploreCard extends StatelessWidget {
  const _ModernExploreCard();

  @override
  Widget build(BuildContext context) {
    return Consumer<LogBookProvider>(
      builder: (context, logBookProvider, child) {
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const FishListScreen(
                  title: 'Fish Collection',
                  isSaltWater: null,
                ),
              ),
            );
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00BCD4), Color(0xFF2196F3)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Fish Collection',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Discover and learn about different fish species',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Modern Recent Activity Card Widget
class _ModernRecentActivityCard extends StatelessWidget {
  final dynamic item;
  final VoidCallback onTap;
  const _ModernRecentActivityCard({required this.item, required this.onTap});

  String _relativeTime(DateTime? date) {
    if (date == null) return '';
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return diff.inMinutes == 1 ? '1 minute ago' : '${diff.inMinutes} minutes ago';
    if (diff.inHours < 24) return diff.inHours == 1 ? '1 hour ago' : '${diff.inHours} hours ago';
    if (diff.inDays == 1) return 'Yesterday';
    return diff.inDays == 1 ? '1 day ago' : '${diff.inDays} days ago';
  }

  @override
  Widget build(BuildContext context) {
    String title = '';
    String subtitle = '';
    String time = '';
    IconData icon = Icons.info_outline;
    Color iconColor = Colors.blueAccent;
    if (item is FishPrediction) {
      title = item.commonName.isNotEmpty ? item.commonName : 'Fish Captured';
      subtitle = item.probability.isNotEmpty ? 'Confidence: ${item.probability}' : 'Successfully identified and logged';
      icon = Icons.remove_red_eye;
      iconColor = Colors.blueAccent;
      time = _relativeTime(item.createdAt);
    } else if (item is WaterCalculation) {
      title = 'Water Calculator';
      final fishNames = item.fishSelections.keys.join(', ');
      subtitle = 'Fish: $fishNames\npH Level: ${item.phRange}\nTemperature: ${item.temperatureRange.replaceAll('Â', '')}';
      icon = Icons.science;
      iconColor = Colors.green;
      time = _relativeTime(item.dateCalculated);
    } else if (item is FishCalculation) {
      title = 'Fish Calculator';
      final fishNames = item.fishSelections.keys.join(', ');
      subtitle = 'Fish: $fishNames\nTank Volume: ${item.tankVolume}';
      icon = Icons.water;
      iconColor = Colors.teal;
      time = _relativeTime(item.dateCalculated);
    } else if (item is CompatibilityResult) {
      title = '${item.fish1Name} & ${item.fish2Name}';
      subtitle = item.isCompatible ? 'Compatible' : 'Not Compatible';
      icon = Icons.compare_arrows;
      iconColor = Colors.deepPurple;
      time = _relativeTime(item.dateChecked);
    } else {
      title = 'Activity';
      subtitle = 'Details about the activity';
      icon = Icons.info_outline;
      iconColor = Colors.grey;
      time = 'Some time ago';
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: iconColor.withOpacity(0.15),
              child: Icon(icon, color: iconColor),
            ),
            title: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.black,
              ),
            ),
            subtitle: Text(
              subtitle,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
            trailing: Text(
              time,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          ),
        ),
      ),
    );
  }
}
