import 'package:flutter/material.dart';

class SnapTipsDialog extends StatefulWidget {
  final String? message;
  
  const SnapTipsDialog({super.key, this.message});

  @override
  State<SnapTipsDialog> createState() => _SnapTipsDialogState();
}

class _SnapTipsDialogState extends State<SnapTipsDialog> with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _fadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _closeWithAnimation() async {
    await _animationController.forward();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 360;
    
    return WillPopScope(
      onWillPop: () async {
        _closeWithAnimation();
        return false;
      },
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
          child: SafeArea(
            child: Scaffold(
              backgroundColor: const Color(0xFF1E1E1E),
              body: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Container(
                    width: screenSize.width,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Error message if provided
                        if (widget.message != null) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.red.withOpacity(0.5)),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  color: Colors.red[300],
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    widget.message!,
                                    style: TextStyle(
                                      color: Colors.red[100],
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                        // Title only, no close icon
                        const Text(
                          'Photo Guidelines',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Good example circle
                        Stack(
                          alignment: Alignment.topRight,
                          children: [
                            Container(
                              width: isSmallScreen ? 120 : 150,
                              height: isSmallScreen ? 120 : 150,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                                image: const DecorationImage(
                                  image: AssetImage('lib/icons/approve.png'),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check,
                                color: Color(0xFF1E1E1E),
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // Bad examples
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildBadExample(
                                'Too close',
                                'lib/icons/tooclose.png',
                                isSmallScreen,
                              ),
                              SizedBox(width: isSmallScreen ? 8 : 16),
                              _buildBadExample(
                                'Mixed Species',
                                'lib/icons/multi.png',
                                isSmallScreen,
                              ),
                              SizedBox(width: isSmallScreen ? 8 : 16),
                              _buildBadExample(
                                'Poor Lighting',
                                'lib/icons/toofardark.png',
                                isSmallScreen,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Guidelines box
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'For Best Results:',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 12),
                              Text(
                                '• Ensure good lighting conditions\n'
                                '• Keep fish in focus and clearly visible\n'
                                '• Multiple fish of the same species are OK\n'
                                '• Avoid mixing different species in one shot\n'
                                '• Avoid extreme angles or partial views\n'
                                '• Keep a reasonable distance (not too far/close)',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                  height: 2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        // Close button
                        Container(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: _closeWithAnimation,
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Close',
                              style: TextStyle(
                                color: Color(0xFF1E1E1E),
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBadExample(String label, String imagePath, bool isSmallScreen) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.topRight,
          children: [
            Container(
              width: isSmallScreen ? 70 : 90,
              height: isSmallScreen ? 70 : 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
                image: DecorationImage(
                  image: AssetImage(imagePath),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                color: Color(0xFF1E1E1E),
                size: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: isSmallScreen ? 10 : 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
} 