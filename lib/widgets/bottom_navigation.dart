import 'package:flutter/material.dart';

class BottomNavigation extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;

  const BottomNavigation({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
  });

  @override
  Widget build(BuildContext context) {
    return MediaQuery.of(context).viewInsets.bottom > 0
        ? const SizedBox() // Hide bottom navigation when keyboard is visible
        : BottomAppBar(
            shape: const CircularNotchedRectangle(),
            color: const Color(0xFF006064),
            notchMargin: 6.0,
            height: 88,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavIcon('lib/icons/explore_icon.png', 0),
                _buildNavIcon('lib/icons/logbook_icon.png', 1),
                const SizedBox(width: 60), // Space for FAB
                _buildNavIcon('lib/icons/calculator_icon.png', 2),
                _buildNavIcon('lib/icons/sync_icon.png', 3),
              ],
            ),
          );
  }

  Widget _buildNavIcon(String iconPath, int index) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Image.asset(
            iconPath,
            width: 30,
            height: 30,
            color: selectedIndex == index ? const Color(0xFF4DD0E1) : Colors.white,
          ),
          onPressed: () => onItemTapped(index),
        ),
        Text(
          index == 0 ? 'Explore' :
          index == 1 ? 'Log Book' :
          index == 2 ? 'Calculator' : 'Sync',
          style: TextStyle(
            fontSize: 10,
            color: selectedIndex == index ? const Color(0xFF4DD0E1) : Colors.white,
          ),
        ),
      ],
    );
  }
}
