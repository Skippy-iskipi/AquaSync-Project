import 'package:flutter/material.dart';

class BottomNavigation extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;
  final GlobalKey? exploreKey;
  final GlobalKey? logbookKey;
  final GlobalKey? calculatorKey;
  final GlobalKey? syncKey;

  const BottomNavigation({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
    this.exploreKey,
    this.logbookKey,
    this.calculatorKey,
    this.syncKey,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8.0,
      color: const Color(0xFF006064),
      height: isSmallScreen ? 70 : 75,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 2.0 : 4.0,
          vertical: isSmallScreen ? 2.0 : 3.0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            Expanded(
              child: _buildNavItem(context, 0, 'Explore', 'lib/icons/explore_icon.png', exploreKey, isSmallScreen),
            ),
            Expanded(
              child: _buildNavItem(context, 1, 'Sync', 'lib/icons/sync_icon.png', syncKey, isSmallScreen),
            ),
            SizedBox(width: isSmallScreen ? 50 : 60), // Space for FAB (center camera button)
            Expanded(
              child: _buildNavItem(context, 2, 'Calculator', 'lib/icons/calculator_icon.png', calculatorKey, isSmallScreen),
            ),
            Expanded(
              child: _buildNavItem(context, 3, 'History', 'lib/icons/logbook_icon.png', logbookKey, isSmallScreen),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, int index, String label, String iconPath, GlobalKey? key, bool isSmallScreen) {
    final bool isSelected = selectedIndex == index;
    final double iconSize = isSmallScreen ? 20 : 24;
    final double fontSize = isSmallScreen ? 10 : 11;
    
    return InkWell(
      key: key,
      onTap: () => onItemTapped(index),
      borderRadius: BorderRadius.circular(8),
      splashColor: Colors.white.withOpacity(0.1),
      highlightColor: Colors.white.withOpacity(0.05),
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: isSmallScreen ? 2.0 : 3.0,
          horizontal: isSmallScreen ? 2.0 : 4.0,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Icon with proper error handling
            Image.asset(
              iconPath,
              width: iconSize,
              height: iconSize,
              color: isSelected ? Colors.white : Colors.white70,
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  _getIconFallback(index),
                  size: iconSize,
                  color: isSelected ? Colors.white : Colors.white70,
                );
              },
            ),
            SizedBox(height: isSmallScreen ? 2 : 3),
            // Label with proper constraints
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: fontSize,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                letterSpacing: 0.1,
                height: 1.0,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconFallback(int index) {
    switch (index) {
      case 0:
        return Icons.explore_outlined;
      case 1:
        return Icons.sync;
      case 2:
        return Icons.calculate_outlined;
      case 3:
        return Icons.history;
      default:
        return Icons.home;
    }
  }
}