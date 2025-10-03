import 'package:flutter/material.dart';
import 'screens/homepage.dart';
import 'screens/capture.dart';
import 'package:provider/provider.dart';
import 'screens/logbook_provider.dart';
import 'providers/tank_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/auth_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Global navigator key for showing dialogs from anywhere
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Global function to show account deactivated dialog
void showAccountDeactivatedDialog() {
  print('Global: Showing account deactivated dialog');
  showDialog(
    context: navigatorKey.currentContext!,
    barrierDismissible: false,
    builder: (BuildContext context) {
      print('Global: Dialog builder called');
      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning, color: Colors.red[600], size: 24),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Account Deactivated',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: const Text(
          'Your account has been deactivated by an administrator. Please contact support for assistance if you believe this is an error.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'OK',
                style: TextStyle(
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
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  print('Starting main()');
  
  try {
  await dotenv.load();
  print('Loaded .env');
    
    final supabaseUrl = dotenv.env['SUPABASE_URL'];
    final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];
    
    print('Supabase URL: ${supabaseUrl ?? 'NOT FOUND'}');
    print('Supabase Anon Key: ${supabaseAnonKey != null ? 'FOUND' : 'NOT FOUND'}');
    
    if (supabaseUrl == null || supabaseAnonKey == null) {
      throw Exception('Missing Supabase configuration in .env file');
    }
    
  await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
  );
  print('Initialized Supabase');
  } catch (error) {
    print('Error during initialization: $error');
    // Continue with the app but Supabase features won't work
  }

  print('Initialized LogBookProvider');
   print('Current user id: ${Supabase.instance.client.auth.currentUser?.id}');
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<LogBookProvider>(create: (_) => LogBookProvider()),
        ChangeNotifierProvider<TankProvider>(create: (_) => TankProvider()),
        Provider<AuthService>(create: (_) => AuthService()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AquaSync',
      navigatorKey: navigatorKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00BFB3),
        ),
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
      routes: {
        '/home': (context) => const HomePage(),
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  User? _currentUser;
  bool _isLoadingUser = true;
  bool _hasSeenOnboarding = false;
  bool _hasSeenTour = false;

  @override
  void initState() {
    super.initState();
    _setupAuthListener();
    _checkOnboardingStatus();
    // Debug authentication state on startup
    _debugAuthState();
  }

  Future<void> _checkOnboardingStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bool hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;
      final bool hasSeenTour = prefs.getBool('hasSeenTour') ?? false;
      
      setState(() {
        _hasSeenOnboarding = hasSeenOnboarding;
        _hasSeenTour = hasSeenTour;
      });
      
      print('Onboarding status - Seen onboarding: $hasSeenOnboarding, Seen tour: $hasSeenTour');
    } catch (e) {
      print('Error checking onboarding status: $e');
      // Default to showing onboarding if there's an error
      setState(() {
        _hasSeenOnboarding = false;
        _hasSeenTour = false;
      });
    }
  }

  Future<void> _debugAuthState() async {
    await Future.delayed(const Duration(seconds: 1));
    final authService = Provider.of<AuthService>(context, listen: false);
    authService.debugAuthState();
  }



  void _setupAuthListener() {
    print('AuthWrapper: Setting up auth listener');
    final authService = Provider.of<AuthService>(context, listen: false);
    
    // Test if the stream is working
    print('AuthWrapper: Auth stream: ${authService.onAuthStateChange}');
    
    authService.onAuthStateChange.listen((data) async {
      print('AuthWrapper: *** AUTH STATE CHANGE DETECTED ***');
      print('AuthWrapper: Event: ${data.event}');
      print('AuthWrapper: Session: ${data.session}');
      print('AuthWrapper: User: ${data.session?.user}');
      print('AuthWrapper: Mounted check: $mounted');
      
      // Don't return early if not mounted - we need to handle auth events
      // even if the widget is not fully mounted yet
      if (!mounted) {
        print('AuthWrapper: Not mounted, but continuing to handle auth event');
      }
      
      print('AuthWrapper: Continuing with auth event handling...');
      
      print('AuthWrapper: Auth state changed: ${data.event}'); // Debug log
      print('AuthWrapper: Auth data: ${data.toString()}'); // Debug log
      print('AuthWrapper: Session: ${data.session}'); // Debug log
      print('AuthWrapper: User: ${data.session?.user}'); // Debug log
      
      print('AuthWrapper: *** ABOUT TO ENTER EVENT HANDLING ***');
      
      // Handle different auth events
      print('AuthWrapper: *** REACHING EVENT HANDLING SECTION ***');
      print('AuthWrapper: Checking event type: ${data.event}');
      print('AuthWrapper: Event type comparison: ${data.event == AuthChangeEvent.signedIn}');
      print('AuthWrapper: AuthChangeEvent.signedIn: ${AuthChangeEvent.signedIn}');
      print('AuthWrapper: Event type string: ${data.event.toString()}');
      
      if (data.event == AuthChangeEvent.signedIn) {
        print('AuthWrapper: *** SIGNED IN EVENT DETECTED ***');
        print('AuthWrapper: Mounted: $mounted');
        final user = data.session?.user;
        print('AuthWrapper: User from session: ${user?.id}');
        
        if (user != null && user.emailConfirmedAt != null) {
          print('Email confirmation detected'); // Debug log
          // Notification removed as requested
        }
        
         // Check if user is active (for OAuth and email sign-ins)
         if (user != null) {
           print('AuthWrapper: User is not null, checking active status for OAuth user: ${user.id}');
           
           // We can check active status even if widget is unmounted
           // Get authService from the global instance instead of context
           final authService = AuthService();
           print('AuthWrapper: About to call isUserActive...');
           final isActive = await authService.isUserActive(userId: user.id);
           print('AuthWrapper: OAuth user active status result: $isActive');
          
           if (!isActive) {
             print('AuthWrapper: OAuth user is inactive, signing out');
             await authService.signOut();
             // Show dialog immediately using global function
             showAccountDeactivatedDialog();
             return;
           } else {
             print('AuthWrapper: OAuth user is active, allowing access');
           }
        }
      } else if (data.event == AuthChangeEvent.signedOut) {
        print('AuthWrapper: *** SIGNED OUT EVENT DETECTED ***');
        print('AuthWrapper: User was signed out');
      } else {
        print('AuthWrapper: *** OTHER AUTH EVENT: ${data.event} ***');
      }
      
      if (mounted) {
        setState(() {
          _isLoadingUser = true;
        });
      }
      
      final session = data.session;
      if (session != null) {
        final latestUserResponse = await Supabase.instance.client.auth.getUser();
        if (mounted) {
          setState(() {
            _currentUser = latestUserResponse.user;
            _isLoadingUser = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _currentUser = null;
            _isLoadingUser = false;
          });
        }
      }
    });
    _checkInitialSession();
  }

  Future<void> _checkInitialSession() async {
    if (!mounted) return;
    setState(() {
      _isLoadingUser = true;
    });
    final session = Supabase.instance.client.auth.currentSession;
    print('AuthWrapper: Checking initial session: ${session != null ? 'Found' : 'Not found'}');
    if (session != null) {
      print('AuthWrapper: Found existing session, checking user status');
      print('AuthWrapper: Session user ID: ${session.user.id}');
      print('AuthWrapper: Session user email: ${session.user.email}');
      final latestUserResponse = await Supabase.instance.client.auth.getUser();
      final user = latestUserResponse.user;
      print('AuthWrapper: Latest user response: ${user?.id}');
      
      if (user != null) {
        print('AuthWrapper: Checking active status for existing session user: ${user.id}');
        final authService = Provider.of<AuthService>(context, listen: false);
        final isActive = await authService.isUserActive(userId: user.id);
        print('AuthWrapper: Existing session user active status: $isActive');
        
        if (!isActive) {
          print('AuthWrapper: Existing session user is inactive, signing out');
          await authService.signOut();
          showAccountDeactivatedDialog();
          return;
        } else {
          print('AuthWrapper: Existing session user is active, allowing access');
        }
      }
      
      if (mounted) {
        setState(() {
          _currentUser = user;
          _isLoadingUser = false;
        });
      }
    } else {
      print('AuthWrapper: No existing session found');
      if (mounted) {
        setState(() {
          _currentUser = null;
          _isLoadingUser = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {

    if (_isLoadingUser) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!_hasSeenOnboarding) {
      return OnboardingScreen(
        onFinish: () async {
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('hasSeenOnboarding', true);
            setState(() {
              _hasSeenOnboarding = true;
            });
            print('Onboarding completed and saved to SharedPreferences');
          } catch (e) {
            print('Error saving onboarding status: $e');
            setState(() {
              _hasSeenOnboarding = true;
            });
          }
        },
      );
    }
    if (!_hasSeenTour) {
      return AppTourScreen(
        onFinish: () async {
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('hasSeenTour', true);
            setState(() {
              _hasSeenTour = true;
            });
            print('Tour completed and saved to SharedPreferences');
          } catch (e) {
            print('Error saving tour status: $e');
            setState(() {
              _hasSeenTour = true;
            });
          }
        },
      );
    }
    // After onboarding and tour, go to the main app
    return const HomePage();
  }
}

class OnboardingScreen extends StatefulWidget {
  final VoidCallback? onFinish;
  const OnboardingScreen({super.key, this.onFinish});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> 
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.2, 0.8, curve: Curves.easeOut),
    ));

    // Delay the animation start to ensure everything is initialized
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _animationController.forward();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              const Color(0xFF00BFB3).withOpacity(0.1),
              const Color(0xFF4DD0E1).withOpacity(0.1),
              Colors.white,
            ],
            stops: const [0.0, 0.3, 0.7, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header spacing
              const SizedBox(height: 32),
              
              // Main content - fixed layout
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Animated AquaSync logo
                      ScaleTransition(
                        scale: _scaleAnimation,
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: Image.asset(
                            'lib/icons/AquaSync_Logo.png',
                            fit: BoxFit.contain,
                            width: 200,
                            height: 200,
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Features list
                      SlideTransition(
                        position: _slideAnimation,
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: const _FeatureItem(
                            icon: Icons.camera_alt,
                            title: 'Identify Fish Species',
                            description: 'AI-powered fish identification',
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      
                      SlideTransition(
                        position: _slideAnimation,
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: const _FeatureItem(
                            icon: Icons.camera_alt, // Placeholder since we'll use custom image
                            title: 'Check Compatibility',
                            description: 'Find perfect tank mates for your fish',
                            customIconPath: 'lib/icons/goldfish.png',
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      
                      SlideTransition(
                        position: _slideAnimation,
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: const _FeatureItem(
                            icon: Icons.collections_bookmark,
                            title: 'Save Your Collection',
                            description: 'Keep track of your fish collection',
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Animated capture fish button
                      ScaleTransition(
                        scale: _scaleAnimation,
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {
                                if (widget.onFinish != null) widget.onFinish!();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00BFB3),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 12),
                                elevation: 4,
                                shadowColor: const Color(0xFF00BFB3).withOpacity(0.3),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Get Started',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
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
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? customIconPath;
  
  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.description,
    this.customIconPath,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF00BFB3).withOpacity(0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: const Color(0xFF00BFB3).withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          customIconPath != null ? Image.asset(
            customIconPath!,
            width: 32,
            height: 32,
            fit: BoxFit.contain,
          ) : Icon(
            icon,
            color: const Color(0xFF00BFB3),
            size: 32,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00BFB3),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.grey,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class AppTourScreen extends StatefulWidget {
  final VoidCallback? onFinish;
  const AppTourScreen({super.key, this.onFinish});

  @override
  State<AppTourScreen> createState() => _AppTourScreenState();
}

class _AppTourScreenState extends State<AppTourScreen> 
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late PageController _pageViewController;
  late Animation<Offset> _slideAnimation;
  int _currentStep = 0;
  
  final List<TourStep> _tourSteps = [
    TourStep(
      title: 'Welcome to AquaSync!',
      description: 'Let\'s take a quick tour of the app to help you get started.',
      icon: Icons.waving_hand,
      highlightIndex: -1, // No highlight for welcome
      previewImage: null,
    ),
    TourStep(
      title: 'Home Tab',
      description: 'Explore your fish collection, view recent activity, and manage your tanks.',
      icon: Icons.explore_outlined,
      highlightIndex: 0,
      previewImage: 'lib/icons/homepage_preview.jpg',
    ),
    TourStep(
      title: 'Sync Tab',
      description: 'Check fish compatibility and find perfect tank mates for your aquarium.',
      icon: Icons.sync_outlined,
      highlightIndex: 1,
      previewImage: 'lib/icons/sync_preview.jpg',
    ),
    TourStep(
      title: 'Capture Button',
      description: 'Tap here to identify fish species using AI-powered camera recognition.',
      icon: Icons.camera_alt,
      highlightIndex: 2, // Capture button is index 2
      previewImage: 'lib/icons/capture_preview.jpg',
      customIcon: 'lib/icons/capture_icon.png',
    ),
    TourStep(
      title: 'Calculator Tab',
      description: 'Calculate water requirements, tank capacity, and feeding portions.',
      icon: Icons.calculate_outlined,
      highlightIndex: 3,
      previewImage: 'lib/icons/calculate_preview.jpg',
    ),
    TourStep(
      title: 'History Tab',
      description: 'View your saved fish collection and identification history.',
      icon: Icons.book_outlined,
      highlightIndex: 4,
      previewImage: 'lib/icons/history_preview.jpg',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _pageViewController = PageController(initialPage: _currentStep);

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.3), // Slide from bottom
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward();
  }

  void _showImagePreview(BuildContext context, String imagePath) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.black.withOpacity(0.9),
          insetPadding: EdgeInsets.zero,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.black.withOpacity(0.9),
            child: Stack(
              children: [
                // Full-screen image viewer
                Positioned.fill(
                  child: InteractiveViewer(
                    panEnabled: true,
                    boundaryMargin: const EdgeInsets.all(20),
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Container(
                      width: double.infinity,
                      height: double.infinity,
                      child: Image.asset(
                        imagePath,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              color: const Color(0xFF00BFB3).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(
                              Icons.image_not_supported,
                              size: 60,
                              color: Color(0xFF00BFB3),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                
                // Close button
                Positioned(
                  top: 50,
                  right: 20,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
                
                // Zoom instructions
                Positioned(
                  bottom: 50,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Pinch to zoom • Drag to pan • Tap to close',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
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

  @override
  void dispose() {
    _animationController.dispose();
    _pageViewController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < _tourSteps.length - 1) {
      _pageViewController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _showActionChoice();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _pageViewController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _showActionChoice() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            constraints: const BoxConstraints(
              maxWidth: 400,
              minHeight: 500,
            ),
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with icon and title
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00BFB3).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.rocket_launch,
                    color: Color(0xFF00BFB3),
                    size: 40,
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Title
                const Text(
                  'Ready to Start?',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00BFB3),
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 12),
                
                // Description
                Text(
                  'Choose how you\'d like to begin your AquaSync journey',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 32),
                
                // Action buttons
                Column(
                  children: [
                    // Capture Fish Button
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (context) => const CaptureScreen()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00BFB3),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 3,
                          shadowColor: const Color(0xFF00BFB3).withOpacity(0.3),
                        ),
                        icon: const Icon(Icons.camera_alt, size: 24),
                        label: const Text(
                          'Capture & Identify Fish',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Compatibility Check Button
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (context) => const HomePage(initialTabIndex: 1)),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF00BFB3),
                          side: const BorderSide(color: Color(0xFF00BFB3), width: 2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        icon: const Icon(Icons.sync, size: 24),
                        label: const Text(
                          'Check Compatibility',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Calculator Button
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (context) => const HomePage(initialTabIndex: 2)),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[100],
                          foregroundColor: const Color(0xFF00BFB3),
                          side: BorderSide(color: Colors.grey[300]!, width: 1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 1,
                        ),
                        icon: const Icon(Icons.calculate, size: 24),
                        label: const Text(
                          'Use Calculator',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Skip button
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        widget.onFinish?.call();
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey[600],
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: const Text(
                        'Skip for now',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator
            Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_currentStep + 1} of ${_tourSteps.length}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          widget.onFinish?.call();
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey[600],
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        child: const Text(
                          'Skip',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: (_currentStep + 1) / _tourSteps.length,
                    backgroundColor: Colors.grey[200],
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00BFB3)),
                  ),
                ],
              ),
            ),
            
            // Main content with PageView
            Expanded(
              child: PageView.builder(
                controller: _pageViewController,
                onPageChanged: (index) {
                  setState(() {
                    _currentStep = index;
                  });
                  // Reset and restart slide animation smoothly
                  _animationController.reset();
                  Future.delayed(const Duration(milliseconds: 100), () {
                    if (mounted) {
                      _animationController.forward();
                    }
                  });
                },
                itemCount: _tourSteps.length,
                itemBuilder: (context, index) {
                  final currentTourStep = _tourSteps[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Preview Image or Icon
                        SlideTransition(
                          position: _slideAnimation,
                          child: currentTourStep.previewImage != null
                                  ? GestureDetector(
                                      onTap: () => _showImagePreview(context, currentTourStep.previewImage!),
                                      child: Container(
                                        width: double.infinity,
                                        height: 160,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(20),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.grey.withOpacity(0.3),
                                              blurRadius: 15,
                                              offset: const Offset(0, 6),
                                            ),
                                          ],
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(20),
                                          child: Stack(
                                            fit: StackFit.expand,
                                            children: [
                                              // Vertically scrollable image that fits container width
                                              SingleChildScrollView(
                                                scrollDirection: Axis.vertical,
                                                child: Image.asset(
                                                  currentTourStep.previewImage!,
                                                  fit: BoxFit.fitWidth,
                                                  errorBuilder: (context, error, stackTrace) {
                                                    return Container(
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFF00BFB3).withOpacity(0.1),
                                                        borderRadius: BorderRadius.circular(20),
                                                      ),
                                                      child: Icon(
                                                        currentTourStep.icon,
                                                        size: 80,
                                                        color: const Color(0xFF00BFB3),
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),
                                              // Click indicator overlay - more prominent
                                              Positioned(
                                                top: 16,
                                                right: 16,
                                                child: Container(
                                                  padding: const EdgeInsets.all(12),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFF00BFB3).withOpacity(0.9),
                                                    borderRadius: BorderRadius.circular(25),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.black.withOpacity(0.2),
                                                        blurRadius: 8,
                                                        offset: const Offset(0, 2),
                                                      ),
                                                    ],
                                                  ),
                                                  child: const Icon(
                                                    Icons.zoom_in,
                                                    color: Colors.white,
                                                    size: 20,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    )
                                  : Container(
                                      width: 120,
                                      height: 120,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF00BFB3).withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        currentTourStep.icon,
                                        size: 60,
                                        color: const Color(0xFF00BFB3),
                                      ),
                                    ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Title
                        SlideTransition(
                          position: _slideAnimation,
                          child: Text(
                            currentTourStep.title,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF00BFB3),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Description
                        SlideTransition(
                          position: _slideAnimation,
                          child: Text(
                            currentTourStep.description,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            
            // Bottom navigation preview (if not welcome step)
            if (_tourSteps[_currentStep].highlightIndex >= 0)
              SlideTransition(
                position: _slideAnimation,
                child: Container(
                    margin: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF00BFB3).withOpacity(0.3),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.15),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: _buildBottomNavPreview(_tourSteps[_currentStep].highlightIndex),
                  ),
                ),
            
            // Navigation buttons
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: SlideTransition(
                position: _slideAnimation,
                child: Row(
                    children: [
                      // Back button (only show if not first step)
                      if (_currentStep > 0) ...[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _previousStep,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF00BFB3),
                              side: const BorderSide(color: Color(0xFF00BFB3)),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Back',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                      ],
                      // Next button
                      Expanded(
                        flex: _currentStep == 0 ? 1 : 1,
                        child: ElevatedButton(
                          onPressed: _nextStep,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00BFB3),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 2,
                          ),
                          child: Text(
                            _currentStep == _tourSteps.length - 1 ? 'Let\'s Go!' : 'Next',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavPreview(int highlightIndex) {
    return Container(
      height: 60,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
      child: Row(
        children: [
          Expanded(child: _buildPreviewNavItem(0, 'Home', Icons.explore_outlined, highlightIndex == 0)),
          Expanded(child: _buildPreviewNavItem(1, 'Sync', Icons.sync_outlined, highlightIndex == 1)),
          Expanded(child: _buildPreviewCaptureButton(highlightIndex == 2)),
          Expanded(child: _buildPreviewNavItem(3, 'Calculator', Icons.calculate_outlined, highlightIndex == 3)),
          Expanded(child: _buildPreviewNavItem(4, 'History', Icons.book_outlined, highlightIndex == 4)),
        ],
      ),
    );
  }

  Widget _buildPreviewNavItem(int index, String label, IconData icon, bool isHighlighted) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: isHighlighted ? const Color(0xFF00BFB3).withOpacity(0.1) : Colors.transparent,
        border: isHighlighted ? Border.all(color: const Color(0xFF00BFB3), width: 2) : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 20,
            color: isHighlighted ? const Color(0xFF00BFB3) : Colors.grey,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: isHighlighted ? const Color(0xFF00BFB3) : Colors.grey,
              fontSize: 9,
              fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewCaptureButton(bool isHighlighted) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: isHighlighted ? const Color(0xFF00BFB3).withOpacity(0.1) : Colors.transparent,
        border: isHighlighted ? Border.all(color: const Color(0xFF00BFB3), width: 2) : null,
      ),
      child: Center(
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF00BFB3),
            shape: BoxShape.circle,
            border: isHighlighted ? Border.all(color: const Color(0xFF00BFB3), width: 2) : null,
          ),
          child: Image.asset(
            'lib/icons/capture_icon.png',
            width: 20,
            height: 20,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(
                Icons.camera_alt,
                color: Colors.white,
                size: 20,
              );
            },
          ),
        ),
      ),
    );
  }
}

class TourStep {
  final String title;
  final String description;
  final IconData icon;
  final int highlightIndex; // -1 for no highlight, 0-4 for bottom nav items
  final String? previewImage; // Path to preview image
  final String? customIcon; // Path to custom icon image

  TourStep({
    required this.title,
    required this.description,
    required this.icon,
    required this.highlightIndex,
    this.previewImage,
    this.customIcon,
  });
}

class FeatureScreen extends StatelessWidget {
  final String title;
  final String description;

  const FeatureScreen({
    super.key,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              description,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            // Add feature-specific content here
          ],
        ),
      ),
    );
  }
}



