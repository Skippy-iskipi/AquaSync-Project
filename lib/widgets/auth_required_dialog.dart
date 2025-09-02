import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../screens/auth_screen.dart';

class AuthRequiredDialog extends StatefulWidget {
  final String title;
  final String message;
  final String? actionButtonText;
  final VoidCallback? onActionPressed;
  
  const AuthRequiredDialog({
    super.key,
    required this.title,
    required this.message,
    this.actionButtonText,
    this.onActionPressed,
  });

  @override
  State<AuthRequiredDialog> createState() => _AuthRequiredDialogState();
}

class _AuthRequiredDialogState extends State<AuthRequiredDialog>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _slideController;
  late AnimationController _pulseController;
  
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 0.7,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
    ));
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    // Start animations
    _scaleController.forward();
    _slideController.forward();
    _pulseController.repeat(reverse: true);
    
    // Haptic feedback
    HapticFeedback.lightImpact();
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _slideController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 380;
    final statusBarHeight = MediaQuery.of(context).padding.top;
    
    return AnimatedBuilder(
      animation: Listenable.merge([_scaleController, _slideController]),
      builder: (context, child) {
        return Scaffold(
          backgroundColor: Colors.black.withOpacity(0.6),
          extendBodyBehindAppBar: true, // Extend behind status bar
          body: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Center(
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: GestureDetector(
                      onTap: () {}, // Prevent closing when tapping on dialog
                      child: Container(
                        width: screenSize.width, // Full width
                        height: screenSize.height, // Full height
                        margin: EdgeInsets.zero, // Remove all margins
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                          borderRadius: BorderRadius.circular(0), // Remove rounded corners for full screen
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 30,
                              offset: const Offset(0, 15),
                              spreadRadius: 0,
                            ),
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 60,
                              offset: const Offset(0, 30),
                              spreadRadius: -10,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(0), // Remove rounded corners
                          child: Column(
                            mainAxisSize: MainAxisSize.max, // Use max to fill height
                            children: [
                              _buildHeader(context, isDark, isSmallScreen, statusBarHeight),
                              _buildContent(context, isDark, isSmallScreen),
                              _buildActions(context, isDark, isSmallScreen),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark, bool isSmallScreen, double statusBarHeight) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        isSmallScreen ? 20 : 32,
        (isSmallScreen ? 24 : 32) + statusBarHeight, // Add status bar height to top padding
        isSmallScreen ? 20 : 32,
        isSmallScreen ? 20 : 28,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF00BCD4),
            const Color(0xFF00ACC1),
            const Color(0xFF0097A7),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(0), // Remove rounded corners for full screen
          topRight: Radius.circular(0),
        ),
      ),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  padding: EdgeInsets.all(isSmallScreen ? 12 : 16), // Reduced from 14/18
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(60),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.1),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.lock_person_outlined,
                    color: Colors.white,
                    size: isSmallScreen ? 26 : 32, // Reduced from 28/36
                  ),
                ),
              );
            },
          ),
          SizedBox(height: isSmallScreen ? 14 : 18), // Reduced from 16/20
          Text(
            widget.title,
            style: TextStyle(
              fontSize: isSmallScreen ? 19 : 22, // Reduced from 20/24
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.5,
              shadows: [
                Shadow(
                  color: Colors.black.withOpacity(0.2),
                  offset: const Offset(0, 1),
                  blurRadius: 3,
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: isSmallScreen ? 4 : 6), // Reduced from 6/8
          Text(
            'Unlock the full AquaSync experience',
            style: TextStyle(
              fontSize: isSmallScreen ? 12 : 13, // Reduced from 13/14
              fontWeight: FontWeight.w500,
              color: Colors.white.withOpacity(0.9),
              letterSpacing: 0.3,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, bool isDark, bool isSmallScreen) {
    return Expanded( // This is now the only Expanded widget
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          isSmallScreen ? 20 : 28,
          isSmallScreen ? 16 : 20,
          isSmallScreen ? 20 : 28,
          isSmallScreen ? 16 : 20,
        ),
        child: SingleChildScrollView( // ScrollView is now inside the Expanded
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.message,
                style: TextStyle(
                  fontSize: isSmallScreen ? 14 : 15,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white.withOpacity(0.9) : const Color(0xFF374151),
                  height: 1.5,
                  letterSpacing: 0.2,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: isSmallScreen ? 16 : 20),
              _buildBenefitsCard(isDark, isSmallScreen),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBenefitsCard(bool isDark, bool isSmallScreen) {
    final benefits = [
      {
        'icon': Icons.bookmark_added_outlined,
        'text': 'Save fish captures & calculations',
        'color': const Color(0xFF10B981)
      },
      {
        'icon': Icons.collections_bookmark_outlined,
        'text': 'Access your personal collection',
        'color': const Color(0xFF3B82F6)
      },
      {
        'icon': Icons.auto_awesome_outlined,
        'text': 'Unlock premium AI features',
        'color': const Color(0xFF8B5CF6)
      },
      {
        'icon': Icons.devices_outlined,
        'text': 'Sync across all devices',
        'color': const Color(0xFFF59E0B)
      },
    ];

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isSmallScreen ? 14 : 18), // Reduced from 16/20
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF1F2937).withOpacity(0.8),
                  const Color(0xFF111827).withOpacity(0.6),
                ]
              : [
                  const Color(0xFFF8FAFC),
                  const Color(0xFFF1F5F9),
                ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? const Color(0xFF374151).withOpacity(0.5)
              : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.2)
                : const Color(0xFF64748B).withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(isSmallScreen ? 7 : 9), // Reduced from 8/10
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF00BCD4),
                      Color(0xFF00ACC1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00ACC1).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.workspace_premium_outlined,
                  color: Colors.white,
                  size: isSmallScreen ? 15 : 17, // Reduced from 16/18
                ),
              ),
              SizedBox(width: isSmallScreen ? 10 : 12),
              Expanded(
                child: Text(
                  'What you\'ll get:',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 14 : 15, // Reduced from 15/16
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1F2937),
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isSmallScreen ? 14 : 18), // Reduced from 16/20
          ...benefits.asMap().entries.map((entry) {
            final index = entry.key;
            final benefit = entry.value;
            return TweenAnimationBuilder<double>(
              duration: Duration(milliseconds: 300 + (index * 100)),
              tween: Tween(begin: 0.0, end: 1.0),
              builder: (context, value, child) {
                return Transform.translate(
                  offset: Offset(20 * (1 - value), 0),
                  child: Opacity(
                    opacity: value,
                    child: Container(
                      margin: EdgeInsets.only(
                        bottom: index < benefits.length - 1 ? (isSmallScreen ? 10 : 14) : 0, // Reduced from 12/16
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            padding: EdgeInsets.all(isSmallScreen ? 7 : 9), // Reduced from 8/10
                            decoration: BoxDecoration(
                              color: (benefit['color'] as Color).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: (benefit['color'] as Color).withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              benefit['icon'] as IconData,
                              color: benefit['color'] as Color,
                              size: isSmallScreen ? 17 : 19, // Reduced from 18/20
                            ),
                          ),
                          SizedBox(width: isSmallScreen ? 12 : 16),
                          Expanded(
                            child: Text(
                              benefit['text'] as String,
                              style: TextStyle(
                                fontSize: isSmallScreen ? 13 : 14, // Reduced from 14/15
                                fontWeight: FontWeight.w500,
                                color: isDark
                                    ? Colors.white.withOpacity(0.9)
                                    : const Color(0xFF4B5563),
                                height: 1.3, // Reduced from 1.4
                                letterSpacing: 0.1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context, bool isDark, bool isSmallScreen) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        isSmallScreen ? 20 : 28,
        isSmallScreen ? 14 : 18, // Reduced from 16/20
        isSmallScreen ? 20 : 28,
        isSmallScreen ? 20 : 28, // Reduced from 24/32
      ),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                HapticFeedback.mediumImpact();
                
                if (widget.onActionPressed != null) {
                  widget.onActionPressed!();
                } else {
                  // Navigate to auth screen WITHOUT closing dialog first
                  if (context.mounted) {
                    await Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            const AuthScreen(showBackButton: true), // Explicitly show back button
                        transitionsBuilder: (context, animation, secondaryAnimation, child) {
                          // Combined slide up + fade + scale transition
                          final slideAnimation = Tween<Offset>(
                            begin: const Offset(0.0, 1.0), // Start from bottom
                            end: Offset.zero,
                          ).animate(CurvedAnimation(
                            parent: animation,
                            curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic),
                          ));
                          
                          final fadeAnimation = Tween<double>(
                            begin: 0.0,
                            end: 1.0,
                          ).animate(CurvedAnimation(
                            parent: animation,
                            curve: const Interval(0.1, 0.9, curve: Curves.easeOut),
                          ));
                          
                          final scaleAnimation = Tween<double>(
                            begin: 0.95,
                            end: 1.0,
                          ).animate(CurvedAnimation(
                            parent: animation,
                            curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
                          ));

                          return SlideTransition(
                            position: slideAnimation,
                            child: FadeTransition(
                              opacity: fadeAnimation,
                              child: Transform.scale(
                                scale: scaleAnimation.value,
                                child: child,
                              ),
                            ),
                          );
                        },
                        transitionDuration: const Duration(milliseconds: 600),
                        reverseTransitionDuration: const Duration(milliseconds: 400),
                        opaque: true, // Ensures auth screen covers everything
                      ),
                    );
                    
                    // Only close dialog AFTER returning from auth screen
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00BCD4),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  vertical: isSmallScreen ? 12 : 16, // Reduced from 14/18
                  horizontal: isSmallScreen ? 20 : 24,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 8,
                shadowColor: const Color(0xFF00BCD4).withOpacity(0.4),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.login_rounded,
                      size: isSmallScreen ? 17 : 19, // Reduced from 18/20
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: isSmallScreen ? 10 : 12),
                  Text(
                    widget.actionButtonText ?? 'Sign In / Sign Up',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 14 : 15, // Reduced from 15/16
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: isSmallScreen ? 10 : 14), // Reduced from 12/16
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  vertical: isSmallScreen ? 10 : 14, // Reduced from 12/16
                  horizontal: isSmallScreen ? 16 : 20,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: isDark
                        ? Colors.white.withOpacity(0.2)
                        : Colors.grey.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                backgroundColor: isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.grey.withOpacity(0.05),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.close_rounded,
                    size: isSmallScreen ? 15 : 17, // Reduced from 16/18
                    color: isDark
                        ? Colors.white.withOpacity(0.7)
                        : Colors.grey[600],
                  ),
                  SizedBox(width: isSmallScreen ? 6 : 8),
                  Text(
                    'Continue without signing in',
                    style: TextStyle(
                      color: isDark
                          ? Colors.white.withOpacity(0.7)
                          : Colors.grey[600],
                      fontSize: isSmallScreen ? 13 : 14, // Reduced from 14/15
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}