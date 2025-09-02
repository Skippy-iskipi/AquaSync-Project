import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../services/auth_service.dart';
import 'homepage.dart';
import 'in_app_password_reset_screen.dart';

class AuthScreen extends StatefulWidget {
  final bool showBackButton;
  
  const AuthScreen({
    super.key,
    this.showBackButton = true,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _isLogin = true;
  bool _isLoading = false;
  String? _errorMessage;
  
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));
    
    _slideController.forward();
    _fadeController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _slideController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_isLogin) {
        await _authService.signInWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        if (mounted) {
          // Only navigate to HomePage immediately for successful login
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomePage()),
          );
        }
      } else {
        // For signup, do not navigate immediately. Inform user to check email.
        await _authService.signUpWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        // Profile will be automatically created by database trigger
        // No need to manually insert into profiles table
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Account created! Please check your email to confirm.'),
              duration: Duration(seconds: 5),
            ),
          );
          // Do not navigate, AuthWrapper will handle after confirmation
        }
      }
    } catch (error) {
      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.signInWithGoogle();
      if (mounted) {
        // For Google sign-in, directly navigate to HomePage if successful
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      }
    } catch (error) {
      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {}); // Update state without navigating
      }
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    // Navigate directly to the in-app password reset screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const InAppPasswordResetScreen(),
      ),
    );
  }

  Future<void> _handleBackPress() async {
    HapticFeedback.lightImpact();
    
    // Animate out before popping
    await Future.wait([
      _slideController.reverse(),
      _fadeController.reverse(),
    ]);
    
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final statusBarHeight = MediaQuery.of(context).padding.top;
    
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? [
                        const Color(0xFF0F172A),
                        const Color(0xFF1E293B),
                        const Color(0xFF0F172A),
                      ]
                    : [
                        const Color(0xFFF8FAFC),
                        const Color(0xFFE2E8F0),
                        const Color(0xFFF1F5F9),
                      ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
          
          // Back button (only show if showBackButton is true)
          if (widget.showBackButton)
            Positioned(
              top: statusBarHeight + 16,
              left: 20,
              child: AnimatedBuilder(
                animation: _fadeAnimation,
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _fadeAnimation,
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark 
                            ? Colors.white.withOpacity(0.1)
                            : Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withOpacity(0.2)
                              : const Color(0xFF00ACC1).withOpacity(0.2),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: _handleBackPress,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              size: 20,
                              color: isDark
                                  ? Colors.white.withOpacity(0.9)
                                  : const Color(0xFF006064),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          
          // Main content
          SafeArea(
            child: AnimatedBuilder(
              animation: Listenable.merge([_slideController, _fadeController]),
              builder: (context, child) {
                return SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24.0, 80.0, 24.0, 24.0), // Added top padding for back button
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Logo
                              Hero(
                                tag: 'app_logo',
                                child: Image.asset(
                                  'lib/icons/AquaSync_Logo.png',
                                  height: 160,
                                  width: 160,
                                ),
                              ),
                              const SizedBox(height: 12),
                              
                              // Title
                              Text(
                                _isLogin ? 'Welcome to AquaSync' : 'Create Account',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : const Color(0xFF006064),
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 32),

                              // Email field
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: InputDecoration(
                                  labelText: 'Email',
                                  prefixIcon: Icon(
                                    Icons.email_outlined,
                                    color: isDark ? Colors.white.withOpacity(0.7) : null,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: isDark 
                                          ? Colors.white.withOpacity(0.3)
                                          : Colors.grey.withOpacity(0.5),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF00ACC1),
                                      width: 2,
                                    ),
                                  ),
                                  labelStyle: TextStyle(
                                    color: isDark ? Colors.white.withOpacity(0.7) : null,
                                  ),
                                ),
                                style: TextStyle(
                                  color: isDark ? Colors.white : null,
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your email';
                                  }
                                  if (!value.contains('@')) {
                                    return 'Please enter a valid email';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // Password field
                              TextFormField(
                                controller: _passwordController,
                                obscureText: true,
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon: Icon(
                                    Icons.lock_outline,
                                    color: isDark ? Colors.white.withOpacity(0.7) : null,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: isDark 
                                          ? Colors.white.withOpacity(0.3)
                                          : Colors.grey.withOpacity(0.5),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF00ACC1),
                                      width: 2,
                                    ),
                                  ),
                                  labelStyle: TextStyle(
                                    color: isDark ? Colors.white.withOpacity(0.7) : null,
                                  ),
                                ),
                                style: TextStyle(
                                  color: isDark ? Colors.white : null,
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your password';
                                  }
                                  if (value.length < 6) {
                                    return 'Password must be at least 6 characters';
                                  }
                                  return null;
                                },
                              ),
                              
                              // Forgot Password link (only show in login mode)
                              if (_isLogin)
                                Column(
                                  children: [
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton(
                                        onPressed: _isLoading ? null : _showForgotPasswordDialog,
                                        style: TextButton.styleFrom(
                                          padding: EdgeInsets.zero,
                                          minimumSize: const Size(0, 0),
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        child: const Text(
                                          'Forgot Password?',
                                          style: TextStyle(
                                            color: Color(0xFF00ACC1),
                                            fontSize: 14,
                                            decoration: TextDecoration.underline,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              
                              const SizedBox(height: 24),

                              // Error message
                              if (_errorMessage != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.red.withOpacity(0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      _errorMessage!,
                                      style: const TextStyle(
                                        color: Colors.red,
                                        fontSize: 14,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),

                              // Submit button
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF00ACC1).withOpacity(0.3),
                                      blurRadius: 12,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _submitForm,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF00ACC1),
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: _isLoading
                                      ? const CircularProgressIndicator(color: Colors.white)
                                      : Text(
                                          _isLogin ? 'Sign In' : 'Sign Up',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Google sign in button
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: isDark 
                                          ? Colors.black.withOpacity(0.3)
                                          : Colors.grey.withOpacity(0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: OutlinedButton.icon(
                                  onPressed: _isLoading ? null : _handleGoogleSignIn,
                                  style: OutlinedButton.styleFrom(
                                    backgroundColor: isDark 
                                        ? Colors.white.withOpacity(0.05)
                                        : Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    side: BorderSide(
                                      color: isDark 
                                          ? Colors.white.withOpacity(0.2)
                                          : const Color(0xFF00ACC1),
                                    ),
                                  ),
                                  icon: FaIcon(
                                    FontAwesomeIcons.google,
                                    color: isDark ? Colors.white.withOpacity(0.9) : const Color(0xFF00ACC1),
                                  ),
                                  label: Text(
                                    'Continue with Google',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: isDark ? Colors.white.withOpacity(0.9) : const Color(0xFF00ACC1),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Toggle between login and signup
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _isLogin
                                        ? 'Don\'t have an account? '
                                        : 'Already have an account? ',
                                    style: TextStyle(
                                      color: isDark 
                                          ? Colors.white.withOpacity(0.7)
                                          : const Color.fromARGB(255, 0, 0, 0),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      setState(() {
                                        _isLogin = !_isLogin;
                                        _errorMessage = null;
                                      });
                                    },
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: const Size(0, 0),
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: Text(
                                      _isLogin ? 'Sign Up' : 'Sign In',
                                      style: const TextStyle(
                                        color: Color(0xFF00ACC1),
                                        decoration: TextDecoration.underline,
                                        fontWeight: FontWeight.bold,
                                      ),
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}