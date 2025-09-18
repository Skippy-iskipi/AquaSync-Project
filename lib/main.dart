import 'package:flutter/material.dart';
import 'screens/homepage.dart';
import 'screens/capture.dart';
import 'screens/auth_screen.dart';
import 'package:provider/provider.dart';
import 'screens/logbook_provider.dart';
import 'providers/tank_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/auth_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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
  }

  void _setupAuthListener() {
    final authService = Provider.of<AuthService>(context, listen: false);
    authService.onAuthStateChange.listen((data) async {
      if (!mounted) return;
      
      print('Auth state changed: ${data.event}'); // Debug log
      print('Auth data: ${data.toString()}'); // Debug log
      
      // Handle email confirmation and sign in
      if (data.event == AuthChangeEvent.signedIn) {
        print('User signed in event detected'); // Debug log
        final user = data.session?.user;
        
        if (user != null && user.emailConfirmedAt != null) {
          print('Email confirmation detected'); // Debug log
          // Notification removed as requested
        }
      }
      
      setState(() {
        _isLoadingUser = true;
      });
      
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
              // Header with cancel button
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 60),
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: TextButton(
                        onPressed: () {
                          if (widget.onFinish != null) widget.onFinish!();
                        },
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            color: Color(0xFF00BFB3),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
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
                            icon: Icons.group,
                            title: 'Check Compatibility',
                            description: 'Find perfect tank mates for your fish',
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
                      
                      // Animated get started button
                      ScaleTransition(
                        scale: _scaleAnimation,
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: SizedBox(
                            width: 200,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const AuthScreen(
                                      showBackButton: true,
                                      initialMode: false, // Start in sign-up mode
                                    ),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00BFB3),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                elevation: 4,
                                shadowColor: const Color(0xFF00BFB3).withOpacity(0.3),
                              ),
                              child: const Text(
                                'Get Started',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // Animated sign in option
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const AuthScreen(
                                  showBackButton: true,
                                  initialMode: true, // Start in sign-in mode
                                ),
                              ),
                            );
                          },
                          child: const Text(
                            'Already have an account? Sign In',
                            style: TextStyle(
                              color: Color(0xFF00BFB3),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
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
  
  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.description,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF00BFB3).withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF00BFB3).withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
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



