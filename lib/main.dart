import 'package:flutter/material.dart';
import 'screens/homepage.dart';
import 'screens/capture.dart';
import 'package:provider/provider.dart';
import 'screens/logbook_provider.dart';
import 'providers/tank_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/auth_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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

  @override
  void initState() {
    super.initState();
    _setupAuthListener();
    // Debug authentication state on startup
    _debugAuthState();
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
        onFinish: () {
          setState(() {
            _hasSeenOnboarding = true;
          });
        },
      );
    }
    // After onboarding, go directly to Capture screen to start fish identification
    // Authentication will be required only when trying to save or use premium features
    return const CaptureScreen();
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
                                  Icon(
                                    Icons.camera_alt,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Capture Fish',
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



