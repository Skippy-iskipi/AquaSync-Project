import 'package:flutter/material.dart';
import 'screens/homepage.dart';
import 'package:provider/provider.dart';
import 'screens/logbook_provider.dart';
import 'providers/user_plan_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/auth_screen.dart';
import 'services/auth_service.dart';
import 'screens/email_not_confirmed_screen.dart';
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
        Provider<AuthService>(create: (_) => AuthService()),
        ChangeNotifierProvider<UserPlanProvider>(create: (_) => UserPlanProvider()),
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
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Email confirmed successfully! Welcome to AquaSync!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 3),
              ),
            );
          }
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
          // Fetch user's plan when they sign in
          Provider.of<UserPlanProvider>(context, listen: false).fetchPlan();
          // Subscribe to realtime plan changes
          Provider.of<UserPlanProvider>(context, listen: false).subscribeToPlanChanges();
        }
      } else {
        if (mounted) {
          setState(() {
            _currentUser = null;
            _isLoadingUser = false;
          });
          // Reset plan to free on sign-out to avoid stale plan leakage
          Provider.of<UserPlanProvider>(context, listen: false).setPlan('free');
          // Unsubscribe from realtime when signed out
          Provider.of<UserPlanProvider>(context, listen: false).unsubscribeFromPlanChanges();
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
        // Fetch user's plan when they sign in
        Provider.of<UserPlanProvider>(context, listen: false).fetchPlan();
        // Subscribe to realtime plan changes
        Provider.of<UserPlanProvider>(context, listen: false).subscribeToPlanChanges();
      }
    } else {
      if (mounted) {
        setState(() {
          _currentUser = null;
          _isLoadingUser = false;
        });
        // Unsubscribe and reset plan on app start with no session
        Provider.of<UserPlanProvider>(context, listen: false).unsubscribeFromPlanChanges();
        Provider.of<UserPlanProvider>(context, listen: false).setPlan('free');
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
    if (_currentUser != null) {
      if (_currentUser!.emailConfirmedAt != null) {
        return const HomePage();
      } else {
        return const EmailNotConfirmedScreen();
      }
    } else {
      return const AuthScreen();
    }
  }
}

class OnboardingScreen extends StatefulWidget {
  final VoidCallback? onFinish;
  const OnboardingScreen({super.key, this.onFinish});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  final List<_OnboardingPageData> _pages = [
    _OnboardingPageData(
      imageAsset: 'lib/icons/Identify_Fishes.png',
      headline: 'Identify fishes',
      description: 'Unlimited Identification',
    ),
    _OnboardingPageData(
      imageAsset: 'lib/icons/Document_Fishes.png',
      headline: 'Document fishes',
      description: 'Save Fish Compatibility',
    ),
    _OnboardingPageData(
      imageAsset: 'lib/icons/More_Recommendation.png',
      headline: 'More Recommendation',
      description: 'Helps build suitable fish environment',
    ),
    _OnboardingPageData(
      imageAsset: 'lib/icons/Create_Aquarium.png',
      headline: 'Create your\nPerfect Aquarium',
      description: '',
      buttonText: 'Get Started',
    ),
  ];

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _controller.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    } else {
      if (widget.onFinish != null) widget.onFinish!();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                const SizedBox(height: 32),
                const Center(
                  child: _AquaSyncTitle(),
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: _pages.length,
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    itemBuilder: (context, i) {
                      final data = _pages[i];
                      return _OnboardingCard(
                        data: data,
                        isLast: i == _pages.length - 1,
                        onButton: _nextPage,
                        currentPage: _currentPage,
                        totalPages: _pages.length,
                      );
                    },
                  ),
                ),
              ],
            ),
            if (_currentPage < _pages.length - 1)
              Positioned(
                top: 16,
                right: 16,
                child: TextButton(
                  onPressed: () {
                    if (widget.onFinish != null) widget.onFinish!();
                  },
                  child: const Text(
                    'Skip',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AquaSyncTitle extends StatelessWidget {
  const _AquaSyncTitle();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 32.0, top: 0, bottom: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Welcome to',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'AquaSync',
                style: TextStyle(
                  fontSize: 50,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF009688),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OnboardingPageData {
  final String? imageAsset;
  final String headline;
  final String description;
  final String? buttonText;
  _OnboardingPageData({
    this.imageAsset,
    required this.headline,
    required this.description,
    this.buttonText,
  });
}

class _OnboardingCard extends StatelessWidget {
  final _OnboardingPageData data;
  final bool isLast;
  final VoidCallback onButton;
  final int currentPage;
  final int totalPages;
  const _OnboardingCard({
    required this.data,
    required this.isLast,
    required this.onButton,
    required this.currentPage,
    required this.totalPages,
  });

  @override
  Widget build(BuildContext context) {
    final double cardWidth = MediaQuery.of(context).size.width;
    final double cardHeight = MediaQuery.of(context).size.height - 120;
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: cardWidth,
        height: cardHeight,
        decoration: const BoxDecoration(
          color: Color(0xFFB2EBF2),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              if (data.imageAsset != null)
                Center(
                  child: Image.asset(
                    data.imageAsset!,
                    width: 150,
                    height: 150,
                    fit: BoxFit.contain,
                  ),
                ),
              const SizedBox(height: 36),
              Center(
                child: Text(
                  data.headline,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
              if (data.description.isNotEmpty) ...[
                const SizedBox(height: 18),
                Center(
                  child: Text(
                    data.description,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
              if (data.buttonText != null) ...[
                const SizedBox(height: 32),
                Center(
                  child: SizedBox(
                    width: 200,
                    child: ElevatedButton(
                      onPressed: onButton,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00BFB3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 18),
                      ),
                      child: Text(
                        data.buttonText!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              const Spacer(flex: 3),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(totalPages, (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
                  width: currentPage == i ? 16 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: currentPage == i ? const Color(0xFF00BFB3) : Colors.black12,
                    borderRadius: BorderRadius.circular(4),
                  ),
                )),
              ),
            ],
          ),
        ),
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



