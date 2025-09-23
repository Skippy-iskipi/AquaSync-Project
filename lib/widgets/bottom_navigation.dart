import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BottomNavigation extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;
  final GlobalKey? exploreKey;
  final GlobalKey? logbookKey;
  final GlobalKey? calculatorKey;
  final GlobalKey? syncKey;
  final bool isKeyboardVisible;
  final VoidCallback? onCapturePressed;

  const BottomNavigation({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
    this.exploreKey,
    this.logbookKey,
    this.calculatorKey,
    this.syncKey,
    this.isKeyboardVisible = false,
    this.onCapturePressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 65,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: Color(0xFFE0E0E0),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(flex: 20, child: _buildNavItem(0, 'Home', Icons.explore_outlined)),
          Expanded(flex: 20, child: _buildNavItem(1, 'Sync', Icons.sync_outlined)),
          Expanded(flex: 20, child: _buildCaptureButton()),
          Expanded(flex: 20, child: _buildNavItem(2, 'Calculator', Icons.calculate_outlined)),
          Expanded(flex: 20, child: _buildNavItem(3, 'History', Icons.book_outlined)),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, String label, IconData icon) {
    final bool isSelected = selectedIndex == index;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onItemTapped(index);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected ? const Color(0xFF00BCD4) : Colors.grey,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF00BCD4) : Colors.grey,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCaptureButton() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onCapturePressed?.call();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
          child: Center(
            child: Container(
              width: 70,
              height: 70,
              decoration: const BoxDecoration(
                color: Color(0xFF00BCD4),
                shape: BoxShape.circle,
              ),
              child: Image.asset(
                'lib/icons/capture_icon.png',
                width: 55,
                height: 55,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.camera_alt_rounded,
                    color: Colors.white,
                    size: 32,
                  );
                },
              ),
            ),
          ),
      ),
    );
  }
}