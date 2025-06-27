import 'package:flutter/material.dart';
import 'screens/homepage.dart'; // Import the new homepage file
import 'package:provider/provider.dart';
import 'screens/logbook_provider.dart'; // Adjust the import as necessary
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/auth_screen.dart';
import 'services/auth_service.dart';
import 'screens/email_not_confirmed_screen.dart'; // Import the new screen
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/subscription_page.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  print('Starting main()');
  await dotenv.load();
  print('Loaded .env');
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
  print('Initialized Supabase');

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
          seedColor: const Color(0xFF00BFB3), // Teal color from your design
        ),
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
      // Defining routes without admin
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
  User? _currentUser; // State to hold the current user
  bool _isLoadingUser = true; // State to manage loading
  bool _hasSeenWelcome = false;
  bool _hasSeenSubscription = false;

  @override
  void initState() {
    super.initState();
    _setupAuthListener();

  }

  void _setupAuthListener() {
    final authService = Provider.of<AuthService>(context, listen: false);
    authService.onAuthStateChange.listen((data) async {
      if (!mounted) return;

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

    // Also handle initial session check here to set _currentUser properly on app start
    _checkInitialSession();
  }

  // This function will check the initial session state when the app starts
  // It handles cases where the session might already exist from a previous run
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
          _currentUser = latestUserResponse.user; // User is considered authenticated if session exists
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
      return WelcomeScreen(
        onFinish: () {
          setState(() {
            _hasSeenWelcome = true;
          });
        },
      );
    }

    if (!_hasSeenWelcome) {
      return WelcomeScreen(
        onFinish: () {
          setState(() {
            _hasSeenWelcome = true;
          });
        },
      );
    }

    if (!_hasSeenSubscription) {
      return SubscriptionPage(
        onPlanSelected: () {
          setState(() {
            _hasSeenSubscription = true;
          });
        },
      );
    }

    if (_currentUser != null) {
      // Check if email is confirmed
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

class WelcomeScreen extends StatefulWidget {
  final VoidCallback? onFinish;
  const WelcomeScreen({super.key, this.onFinish});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  void _finish() {
    if (widget.onFinish != null) widget.onFinish!();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Full screen PageView
          PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            children: const [
              ImageFeatureCard(
                imagePath: 'lib/icons/discoverfish.jpeg',
                title: 'Discover Fish',
                description: 'Browse our extensive database of freshwater and saltwater fish species. Get detailed information about their care requirements, compatibility, and more.',
              ),
              ImageFeatureCard(
                imagePath: 'lib/icons/picturefish.jpeg',
                title: 'Scan & Identify',
                description: 'Use our advanced AI technology to instantly identify fish species through your camera. Get accurate results and detailed information about the identified fish.',
              ),
              ImageFeatureCard(
                imagePath: 'lib/icons/aquarium-pic.jpg',
                title: 'Fish Compatibility Checker',
                description: 'Determine which fish can safely live together in your aquarium. Get instant compatibility results based on water parameters, temperament, and habitat needs.',
              ),
              ImageFeatureCard(
                imagePath: 'lib/icons/logbook-pic.jpg',
                title: 'Save & Track Results',
                description: 'Keep a personal record of all your identified fish, compatibility checks, and recommended setups. Easily access your history whenever you need it.',
                isLastCard: true,
              ),
            ],
          ),
          
          // Page indicator overlay at bottom center
          Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                return Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentPage == index
                        ? const Color(0xFF006064)
                        : Colors.white.withOpacity(0.5),
                  ),
                );
              }),
            ),
          ),
          
          // Skip button at top right
          Positioned(
            top: 48,
            right: 24,
            child: TextButton(
              onPressed: _finish,
              style: TextButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: const Text(
                'Skip',
                style: TextStyle(
                  color: Color(0xFF006064),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ImageFeatureCard extends StatelessWidget {
  final String imagePath;
  final String title;
  final String description;
  final bool isLastCard;

  const ImageFeatureCard({
    super.key,
    required this.imagePath,
    required this.title,
    required this.description,
    this.isLastCard = false,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final cardHeight = screenHeight - 150; // Allow space for indicators
    final textCardHeight = screenHeight * 0.30; // 25% of screen height
    
    return Stack(
      children: [
        // Full height background image with proper fit and quality
        Container(
          height: cardHeight,
          width: screenWidth,
          margin: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            child: Image.asset(
              imagePath,
              fit: BoxFit.fill,
              width: double.infinity,
              height: double.infinity,
              filterQuality: FilterQuality.high,
              cacheHeight: (cardHeight * 2).toInt(), // Higher resolution for caching
              cacheWidth: (screenWidth * 2).toInt(),
            ),
          ),
        ),
        
        // Overlapping text card with top rounded corners - 100% width
        Positioned(
          bottom: 16,
          left: 0,
          right: 0,
          child: Container(
            height: textCardHeight,
            width: screenWidth,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: isLastCard 
                ? Column(
                    children: [
                      // Title with teal color and centered
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF006064),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Description
                      Expanded(
                        child: SingleChildScrollView(
                          child: Text(
                            description,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Get Started button for the last card
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => const SubscriptionPage()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00ACC1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32, 
                            vertical: 12,
                          ),
                          minimumSize: const Size(200, 45),
                        ),
                        child: const Text(
                          'Get Started',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ) 
                : Column(
                    children: [
                      // Title with teal color and centered
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF006064),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Description with smaller text, dark gray and aligned left
                      Expanded(
                        child: SingleChildScrollView(
                          child: Text(
                            description,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
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

class UserPlanProvider with ChangeNotifier {
  String _plan = 'free';
  String get plan => _plan;

  Future<void> fetchPlan() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final data = await Supabase.instance.client
          .from('profiles')
          .select('tier_plan')
          .eq('id', user.id)
          .single();
      _plan = data['tier_plan'] ?? 'free';
      notifyListeners();
    }
  }
}

