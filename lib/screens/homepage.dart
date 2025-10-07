import 'package:flutter/material.dart';
import '../widgets/bottom_navigation.dart';
import '../screens/capture.dart';
import '../screens/sync.dart';
import '../screens/logbook.dart';
import '../screens/fish_list_screen.dart';
import 'package:provider/provider.dart';
import 'logbook_provider.dart';
import '../widgets/auth_required_dialog.dart';
import '../services/auth_service.dart';
import 'auth_screen.dart';

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
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/guide_overlay.dart';
import 'guide_webview.dart';
import 'tank_management.dart';
import 'add_edit_tank.dart';


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
      isDismissible: true,
      enableDrag: true,
        builder: (modalContext) => Container(
          height: MediaQuery.of(modalContext).size.height,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: _UserProfileSheet(),
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
            // Tips & Guides Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: const [
                  Icon(Icons.lightbulb_outline, color: Color(0xFF00BFB3), size: 24),
                  SizedBox(width: 10),
                  Text(
                    'Tips & Guides',
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
            _TipsAndGuidesSection(),
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
                  children: allItems.map((item) => _ModernRecentActivityCard(item: item, onTap: () {
                    setState(() {
                      if (item is FishPrediction) {
                        // Fish captured -> Captured tab
                        _selectedIndex = 3;
                        _logBookTabIndex = 0;
                      } else if (item is WaterCalculation || item is FishCalculation || item is DietCalculation || item is FishVolumeCalculation) {
                        // All calculators -> Calculation tab
                        _selectedIndex = 3;
                        _logBookTabIndex = 1;
                      } else if (item is CompatibilityResult) {
                        // Compatibility -> Compatibility tab
                        _selectedIndex = 3;
                        _logBookTabIndex = 2;
                      } else if (item is Tank) {
                        // Tank -> Profile (show user info modal)
                        _showUserInfo(context);
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
            preferredSize: const Size.fromHeight(80),
            child: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              automaticallyImplyLeading: false,
              title: Row(
                children: [
                  Text(
                    _selectedIndex == 0 ? 'AquaSync' :
                    _selectedIndex == 1 ? 'Sync' :
                    _selectedIndex == 2 ? 'Calculator' : 'History',
                    style: const TextStyle(
                      color: Color(0xFF00BFB3),
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  // Profile section
                  Consumer<AuthService>(
                    builder: (context, authService, child) {
                      return GestureDetector(
                        onTap: () => _showUserInfo(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                const Color(0xFF00BFB3),
                                const Color(0xFF4DD0E1),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF00BFB3).withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.person,
                                  size: 18,
                                  color: Color(0xFF00BFB3),
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.keyboard_arrow_down,
                                color: Colors.white,
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
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
              borderRadius: BorderRadius.circular(12),
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
                              borderRadius: BorderRadius.circular(6),
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
                        borderRadius: BorderRadius.circular(6),
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
class _UserProfileSheet extends StatefulWidget {
  const _UserProfileSheet();

  @override
  State<_UserProfileSheet> createState() => _UserProfileSheetState();
}

class _UserProfileSheetState extends State<_UserProfileSheet> {
  @override
  void initState() {
    super.initState();
    // Listen for auth state changes and rebuild when signed in
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn && mounted) {
        setState(() {});
      }
      if (data.event == AuthChangeEvent.signedOut && mounted) {
        setState(() {});
      }
    });
  }
  Future<Map<String, dynamic>> _fetchProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
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
    return Padding(
      padding: MediaQuery.of(context).viewInsets + const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
          const SizedBox(height: 18),
          
          // Profile header
          _buildProfileHeader(),
          
          const SizedBox(height: 20),
          
          // My Tanks section
          Expanded(
            child: _buildTanksSection(),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    final theme = Theme.of(context);
    final user = Supabase.instance.client.auth.currentUser;
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchProfile(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final profile = snapshot.data ?? {};
        final String email = (profile['email'] ?? user?.email ?? '').toString();

        return Column(
          children: [
            // Profile avatar and info
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00BFB3), Color(0xFF4DD0E1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00BFB3).withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.person,
                size: 40,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            // User info
            if (user != null) ...[
              Text(
                email.isNotEmpty ? email : 'No Email',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.grey[800],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ] else ...[
              Text(
                'Guest User',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.grey[800],
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Sign in to access premium features',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
            const SizedBox(height: 16),
            // Auth button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  if (user != null) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (context) => const AuthScreen(showBackButton: false),
                      ),
                      (route) => false,
                    );
                    Supabase.instance.client.auth.signOut();
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AuthScreen(showBackButton: true),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00BFB3),
                  foregroundColor: Colors.white,
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: Icon(
                  user != null ? Icons.logout : Icons.login,
                  size: 20,
                ),
                label: Text(
                  user != null ? 'Sign Out' : 'Sign In / Sign Up',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTanksSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header with create button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF00BFB3).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.water,
                  color: Color(0xFF00BFB3),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'My Tanks',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
              const Spacer(),
              // Create new tank button
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF00BFB3),
                      Color(0xFF4DD0E1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00BFB3).withOpacity(0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: () => _navigateToAddTank(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  icon: const Icon(
                    Icons.add,
                    color: Colors.white,
                    size: 16,
                  ),
                  label: const Text(
                    'New Tank',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        
        // Tanks content
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.grey[200]!,
                width: 1,
              ),
            ),
            child: const ClipRRect(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              child: TankManagement(),
            ),
          ),
        ),
      ],
    );
  }

  void _navigateToAddTank(BuildContext context) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isAuthenticated) {
      // Show auth required dialog
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => AuthRequiredDialog(
          title: 'Authentication Required',
          message: 'Please sign in to create a new tank.',
        ),
      );
      // Listen for authentication state change
      if (result == true || authService.isAuthenticated) {
        // User is now authenticated, navigate to AddEditTank
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddEditTank()),
          );
        }
      }
      return;
    }
    // Already authenticated, go directly
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddEditTank()),
    );
  }

  void _showAuthRequiredDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AuthRequiredDialog(
        title: title,
        message: message,
        actionButtonText: 'Sign In to Continue',
        onActionPressed: () {
          // Navigate to auth screen
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const AuthScreen(showBackButton: true),
            ),
          );
        },
      ),
    );
  }
}

// Tips & Guides Section Widget
class _TipsAndGuidesSection extends StatefulWidget {
  const _TipsAndGuidesSection();

  @override
  State<_TipsAndGuidesSection> createState() => _TipsAndGuidesSectionState();
}

class _TipsAndGuidesSectionState extends State<_TipsAndGuidesSection> {
  bool _showAll = false;

  final List<Map<String, String>> _guides = const [
    {
      'title': 'Beginner\'s Guide to Fish Keeping',
      'url': 'https://www.tetra-fish.com/learning-center/getting-started/a-beginners-guide.aspx',
      'image': 'aquarium basic.png',
    },
    {
      'title': 'Setting up a Healthy Aquarium Environment',
      'url': 'https://hikariusa.com/wp/setting-healthy-aquarium-environment-fish',
      'image': 'healthy aquarium.png',
    },
    {
      'title': 'Aquarium Do\'s and Don\'ts',
      'url': 'https://www.aqueon.com/articles/dos-donts',
      'image': 'Aquarium Dos and Donts.png',
    },
    {
      'title': 'How Long to Wait Before Adding Fish',
      'url': 'https://www.aquariumcoop.com/blogs/aquarium/how-to-set-up-a-fish-tank?srsltid=AfmBOoolmQVYUDdFPAlEROIJSno7yzBGajpPXNMqhHeZEOA6tl_wq_i5',
      'image': 'Put fish.png',
    },
  ];

  void _openGuide(BuildContext context, String url, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GuideWebView(
          url: url,
          title: title,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleGuides = _showAll ? _guides : _guides.take(2).toList();
    final hasMoreGuides = _guides.length > 2;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // Guide cards
          ...visibleGuides.map((guide) => _GuideCard(
            title: guide['title']!,
            imagePath: 'lib/icons/${guide['image']!}',
            onTap: () => _openGuide(context, guide['url']!, guide['title']!),
          )),
          
          // Half preview of 3rd card when collapsed
          if (hasMoreGuides && !_showAll)
            Stack(
              children: [
                // Full card
                _GuideCard(
                  title: _guides[2]['title']!,
                  imagePath: 'lib/icons/${_guides[2]['image']!}',
                  onTap: () => _openGuide(context, _guides[2]['url']!, _guides[2]['title']!),
                ),
                // Fade overlay on bottom half
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 100, // Adjust height as needed
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withOpacity(0.0),
                          Colors.white.withOpacity(0.9),
                          Colors.white,
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          
          // Learn More button
          if (hasMoreGuides && !_showAll)
            Padding(
              padding: const EdgeInsets.only(top: 0),
              child: Center(
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      _showAll = true;
                    });
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Learn More',
                        style: TextStyle(
                          color: Color(0xFF00BFB3),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.keyboard_arrow_down,
                        color: Color(0xFF00BFB3),
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// Individual Guide Card Widget
class _GuideCard extends StatelessWidget {
  final String title;
  final String imagePath;
  final VoidCallback onTap;

  const _GuideCard({
    required this.title,
    required this.imagePath,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF00BFB3).withOpacity(0.1),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 100,
                  height: 64,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      imagePath,
                      width: 100,
                      height: 64,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Tap to read guide',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00BFB3).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.open_in_new,
                    color: Color(0xFF00BFB3),
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
