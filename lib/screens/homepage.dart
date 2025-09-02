import 'package:flutter/material.dart';
import '../widgets/bottom_navigation.dart';
import '../screens/capture.dart';
import '../screens/sync.dart';
import '../screens/logbook.dart';
import '../screens/fish_list_screen.dart';
import 'package:provider/provider.dart';
import 'logbook_provider.dart';
import '../providers/user_plan_provider.dart';
import 'dart:io';
import '../models/water_calculation.dart';
import '../models/fish_calculation.dart';
import '../models/compatibility_result.dart';
import '../models/fish_prediction.dart';
import '../models/diet_calculation.dart';
import '../screens/calculator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/auth_screen.dart';
import '../screens/subscription_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/guide_overlay.dart';


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
  bool _showGuide = false;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialTabIndex;
    _checkFirstTime();
    // Ensure user's subscription plan is fetched on first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<UserPlanProvider>(context, listen: false).fetchPlan();
      }
    });
    // The LogBookProvider is now self-initializing.
    // This call is redundant and has been removed to prevent race conditions.
    /*
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<LogBookProvider>(context, listen: false).init();
    });
    */
  }

  Future<void> _checkFirstTime() async {
    final prefs = await SharedPreferences.getInstance();
    final bool hasSeenGuide = prefs.getBool('hasSeenGuide') ?? false;
    if (!hasSeenGuide) {
      setState(() {
        _showGuide = true;
      });
    }
  }

  void _finishGuide() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenGuide', true);
    setState(() {
      _showGuide = false;
    });
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
      builder: (modalContext) => Container(
        height: MediaQuery.of(modalContext).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: _UserProfileSheet(user: user),
      ),
    );
  }


  Widget _getSelectedScreen() {
    switch (_selectedIndex) {
      case 0:
        return _buildHomeContent();
      case 1:
        return SyncScreen(
          initialFish: widget.initialFish,
          initialFishImage: widget.initialFishImage,
        );
      case 2:
        return const Calculator();
      case 3:
        return LogBook(initialTabIndex: _logBookTabIndex);
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
                        _selectedIndex = 3;
                        _logBookTabIndex = 2;
                      } else if (item is FishPrediction) {
                        _selectedIndex = 3;
                        _logBookTabIndex = 0;
                      } else if (item is WaterCalculation || item is FishCalculation) {
                        _selectedIndex = 3;
                        _logBookTabIndex = 1;
                      } else if (item is DietCalculation) {
                        _selectedIndex = 3;
                        _logBookTabIndex = 1; // Diet calculations go to Calculator tab
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
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(35),
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: Text(
            _selectedIndex == 0 ? 'AquaSync' :
            _selectedIndex == 1 ? 'Sync' :
            _selectedIndex == 2 ? 'Calculator' : 'History',
            style: const TextStyle(
              color: Color(0xFF006064),
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            // Upgrade Button for Free Users
            Consumer<UserPlanProvider>(
              builder: (context, userPlanProvider, child) {
                final plan = userPlanProvider.plan.toLowerCase().replaceAll(' ', '_');
                if (plan == 'free') {
                  return Container(
                    margin: const EdgeInsets.only(right: 12),
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
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        elevation: 2,
                      ),
                      child: const Text(
                        'Upgrade',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            // Profile Icon
            Container(
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF006064),
                  width: 4,
                ),
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.person,
                  color: Color(0xFF006064),
                  size: 32,
                ),
                onPressed: () => _showUserInfo(context),
                tooltip: 'Profile',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 40,
                  minHeight: 40,
                ),
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          _getSelectedScreen(),
          if (_showGuide)
            GuideOverlay(
              onFinish: _finishGuide,
            ),
          
        ],
      ),
      floatingActionButton: isKeyboardVisible ? null : FloatingActionButton(
        key: GuideOverlay.captureKey,
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
        exploreKey: GuideOverlay.exploreKey,
        logbookKey: GuideOverlay.logbookKey,
        calculatorKey: GuideOverlay.calculatorKey,
        syncKey: GuideOverlay.syncKey,
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
      // Show scientific name and water type instead of confidence
      final parts = <String>[];
      if (item.scientificName.isNotEmpty) parts.add(item.scientificName);
      if (item.waterType.isNotEmpty) parts.add(item.waterType);
      subtitle = parts.join('\n');
      icon = Icons.remove_red_eye;
      iconColor = Colors.blueAccent;
      time = _relativeTime(item.createdAt);
    } else if (item is WaterCalculation) {
      title = 'Water Calculator';
      final fishNames = item.fishSelections.keys.join(', ');
      subtitle = 'Fish: $fishNames\npH level: ${item.phRange}\nTemperature range: ${item.temperatureRange.replaceAll('Ã‚', '')}';
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
    } else if (item is DietCalculation) {
      title = 'Diet Calculator';
      final fishNames = item.fishSelections.keys.join(', ');
      subtitle = 'Fish: $fishNames\nTotal portions: ${item.totalPortion}';
      icon = Icons.restaurant;
      iconColor = Colors.orange;
      time = _relativeTime(item.dateCalculated);
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

// Add this new widget below HomePageState
class _UserProfileSheet extends StatelessWidget {
  final dynamic user;
  const _UserProfileSheet({required this.user});

  Future<Map<String, dynamic>> _fetchProfile() async {
    if (user == null) return {};
    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select('first_name, last_name, email')
          .eq('id', user.id)
          .maybeSingle();
      return data ?? {};
    } catch (e) {
      return {};
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final double modalHeight = 320;
    return Padding(
      padding: MediaQuery.of(context).viewInsets + const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SizedBox(
        height: modalHeight,
        child: Consumer<UserPlanProvider>(
          builder: (context, userPlanProvider, child) {
            return FutureBuilder<Map<String, dynamic>>(
              future: _fetchProfile(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final profile = snapshot.data ?? {};
                final String tierPlan = userPlanProvider.plan;
                final String email = (profile['email'] ?? user?.email ?? '').toString();

                return Column(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00BCD4), Color(0xFF2196F3)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.person,
                        size: 48,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 18),
                    // Show different content based on authentication status
                    if (user != null) ...[
                      Text(
                        email.isNotEmpty ? email : 'No Email',
                        style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00BCD4).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Plan: ${tierPlan[0].toUpperCase()}${tierPlan.substring(1)}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF006064),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ] else ...[
                      Text(
                        'Guest User',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Sign in to access premium features\nand save your data',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                          height: 1.4,
                        ),
                      ),
                    ],
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // Close bottom sheet and navigate immediately
                          Navigator.of(context).pop();
                          if (user != null) {
                            // User is logged in - sign out
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                builder: (context) => const AuthScreen(showBackButton: false),
                              ),
                              (route) => false,
                            );
                            // Sign out after navigation started
                            Supabase.instance.client.auth.signOut();
                          } else {
                            // User is not logged in - navigate to auth screen
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const AuthScreen(showBackButton: true),
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: user != null 
                            ? const Color(0xFF006064)  // Dark teal for logout
                            : const Color(0xFF00BCD4), // Bright teal for sign in
                          foregroundColor: Colors.white,
                          elevation: 2,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        icon: Icon(
                          user != null ? Icons.logout : Icons.login,
                          size: 24,
                        ),
                        label: Text(
                          user != null ? 'Logout' : 'Sign In / Sign Up',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}