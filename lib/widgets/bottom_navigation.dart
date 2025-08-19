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
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8.0,
      color: const Color(0xFF006064),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: <Widget>[
          _buildNavItem(context, 0, 'Explore', 'lib/icons/explore_icon.png', exploreKey),
          _buildNavItem(context, 1, 'History', 'lib/icons/logbook_icon.png', logbookKey),
          const SizedBox(width: 48), // The space for the FAB
          _buildNavItem(context, 2, 'Calculator', 'lib/icons/calculator_icon.png', calculatorKey),
          _buildNavItem(context, 3, 'Sync', 'lib/icons/sync_icon.png', syncKey),
        ],
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, int index, String label, String iconPath, GlobalKey? key) {
    final bool isSelected = selectedIndex == index;
    return InkWell(
      key: key,
      onTap: () => onItemTapped(index),
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 12.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              iconPath,
              width: 24,
              height: 24,
              color: isSelected ? Colors.white : Colors.white70,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
