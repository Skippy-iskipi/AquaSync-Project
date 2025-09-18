import 'package:flutter/material.dart';
import '../widgets/bottom_navigation.dart';
import '../screens/capture.dart';
import '../screens/sync.dart';
import '../screens/logbook.dart';
import '../screens/fish_list_screen.dart';
import 'package:provider/provider.dart';
import 'logbook_provider.dart';

import 'dart:io';
import 'dart:async';
import '../models/water_calculation.dart';
import '../models/fish_calculation.dart';
import '../models/compatibility_result.dart';
import '../models/fish_prediction.dart';
import '../models/diet_calculation.dart';
import '../models/fish_volume_calculation.dart';
import '../models/tank.dart';
import '../screens/calculator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/auth_screen.dart';
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
  Timer? _timeUpdateTimer;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialTabIndex;
    _checkFirstTime();
    _startTimeUpdateTimer();
    // The LogBookProvider is now self-initializing.
    // This call is redundant and has been removed to prevent race conditions.
    /*
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<LogBookProvider>(context, listen: false).init();
    });
    */
  }

  void _startTimeUpdateTimer() {
    // Update time display every minute for real-time relative time
    _timeUpdateTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        setState(() {
          // This will trigger a rebuild of the recent activity cards
        });
      }
    });
  }

  @override
  void dispose() {
    _timeUpdateTimer?.cancel();
    super.dispose();
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
      color: Colors.grey[50],
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 32),
            // Explore Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.remove_red_eye, color: Color(0xFF00BFB3), size: 24),
                      SizedBox(width: 10),
                      Text(
                        'Explore',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00BFB3),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Explore Card
                  _ModernExploreCard(),
                ],
              ),
            ),
            const SizedBox(height: 40),
            // Recent Activity Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: const [
                  Icon(Icons.show_chart, color: Color(0xFF00BFB3), size: 24),
                  SizedBox(width: 10),
                  Text(
                    'Recent Activity',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00BFB3),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Consumer<LogBookProvider>(
              builder: (context, logBookProvider, child) {
                final allItems = logBookProvider.allItems;
                if (allItems.isEmpty) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.inbox_outlined,
                            size: 48,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'No recent activities yet',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Learn more about fish species, check their compatibility, and more.',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }
                return Column(
                  children: allItems.take(5).map((item) => _ModernRecentActivityCard(item: item, onTap: () {
                    setState(() {
                      if (item is FishPrediction) {
                        // Fish captured -> Fish Collection tab
                        _selectedIndex = 3;
                        _logBookTabIndex = 1;
                      } else if (item is WaterCalculation || item is FishCalculation || item is DietCalculation || item is FishVolumeCalculation) {
                        // All calculators -> Fish Calculator tab
                        _selectedIndex = 3;
                        _logBookTabIndex = 2;
                      } else if (item is CompatibilityResult) {
                        // Compatibility -> Fish Compatibility tab
                        _selectedIndex = 3;
                        _logBookTabIndex = 3;
                      } else if (item is Tank) {
                        // Tank -> My Tanks tab
                        _selectedIndex = 3;
                        _logBookTabIndex = 0;
                      }
                    });
                  })).toList(),
                );
              },
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }





  @override
  Widget build(BuildContext context) {
    final bool isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    
    return Stack(
      children: [
        Scaffold(
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
                _selectedIndex == 2 ? 'Calculator' : 'Profile',
                style: const TextStyle(
                  color: Color(0xFF00BFB3),
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              actions: [],
            ),
          ),
          body: _getSelectedScreen(),
          floatingActionButton: null, // We'll handle FAB positioning in the bottom navigation
          bottomNavigationBar: Container(
            key: const ValueKey('stable_bottom_nav'),
            child: BottomNavigation(
              selectedIndex: _selectedIndex,
              onItemTapped: _onItemTapped,
              exploreKey: null,
              logbookKey: null,
              calculatorKey: null,
              syncKey: null,
              isKeyboardVisible: isKeyboardVisible,
              onCapturePressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CaptureScreen()),
                );
              },
            ),
          ),
        ),
        if (_showGuide)
          GuideOverlay(
            onFinish: _finishGuide,
          ),
      ],
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
                  title: 'Fish Database',
                  isSaltWater: null,
                ),
              ),
            );
          },
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00BFB3), Color(0xFF4DD0E1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00BFB3).withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Background pattern
                Positioned(
                  top: -20,
                  right: -20,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -30,
                  left: -30,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.05),
                    ),
                  ),
                ),
                // Content
                Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Fish Database',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Discover and learn about different fish species',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w400,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Explore Now',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.arrow_forward,
                              color: Colors.white,
                              size: 20,
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
    
    if (diff.inSeconds < 60) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return diff.inMinutes == 1 ? '1 minute ago' : '${diff.inMinutes} minutes ago';
    } else if (diff.inHours < 24) {
      return diff.inHours == 1 ? '1 hour ago' : '${diff.inHours} hours ago';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else if (diff.inDays < 30) {
      final weeks = (diff.inDays / 7).floor();
      return weeks == 1 ? '1 week ago' : '$weeks weeks ago';
    } else if (diff.inDays < 365) {
      final months = (diff.inDays / 30).floor();
      return months == 1 ? '1 month ago' : '$months months ago';
    } else {
      final years = (diff.inDays / 365).floor();
      return years == 1 ? '1 year ago' : '$years years ago';
    }
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
      final fishNames = item.selectedFish.keys.join(' & ');
      title = fishNames;
      subtitle = item.compatibilityLevel == 'Compatible' ? 'Compatible' : 'Not Compatible';
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
    } else if (item is Tank) {
      title = 'Tank Created';
      final fishCount = item.fishSelections.values.fold(0, (sum, count) => sum + count);
      subtitle = '${item.name}\n${fishCount} fish • ${item.volume.toStringAsFixed(1)}L';
      icon = Icons.water;
      iconColor = Colors.cyan;
      time = _relativeTime(item.createdAt ?? item.dateCreated);
    } else {
      // Skip unknown item types - don't display placeholder activities
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: iconColor,
                    width: 4,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            iconColor.withOpacity(0.1),
                            iconColor.withOpacity(0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(icon, color: iconColor, size: 26),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            subtitle,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                              height: 1.4,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: iconColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            time,
                            style: TextStyle(
                              fontSize: 12,
                              color: iconColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.grey,
                            size: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
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
        child: FutureBuilder<Map<String, dynamic>>(
          future: _fetchProfile(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final profile = snapshot.data ?? {};
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
                          colors: [Color(0xFF00BFB3), Color(0xFF4DD0E1)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00BFB3).withOpacity(0.2),
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
                            ? const Color(0xFF00BFB3)  // Aqua for logout
                            : const Color(0xFF00BFB3), // Aqua for sign in
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
        ),
      ),
    );
  }
}
