import 'package:flutter/material.dart';
import '../services/enhanced_tankmate_service.dart';
import 'fish_info_dialog.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class FishCardTankmates extends StatefulWidget {
  final String fishName;
  final Function(String) onFishSelected;

  const FishCardTankmates({
    super.key,
    required this.fishName,
    required this.onFishSelected,
  });

  @override
  State<FishCardTankmates> createState() => _FishCardTankmatesState();
}

class _FishCardTankmatesState extends State<FishCardTankmates> {
  DetailedTankmateInfo? tankmateData;
  bool isLoading = false;
  bool isExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadTankmateData();
  }

  @override
  void didUpdateWidget(FishCardTankmates oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fishName != widget.fishName) {
      _loadTankmateData();
    }
  }

  Future<void> _loadTankmateData() async {
    if (widget.fishName.isEmpty) return;

    setState(() {
      isLoading = true;
    });

    try {
      final data = await EnhancedTankmateService.getTankmateDetails(widget.fishName);
      setState(() {
        tankmateData = data;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading tankmate data for ${widget.fishName}: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.fishName.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 0,
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          initiallyExpanded: false,
          onExpansionChanged: (expanded) {
            setState(() {
              isExpanded = expanded;
            });
          },
          leading: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFE0F7FA),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              FontAwesomeIcons.userGroup,
              color: Color(0xFF006064),
              size: 14,
            ),
          ),
          title: Row(
            children: [
              const Text(
                'Tankmates',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF006064),
                ),
              ),
              if (isLoading)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  width: 12,
                  height: 12,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF006064)),
                  ),
                ),
            ],
          ),
          children: [
            if (isLoading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    'Loading tankmate recommendations...',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else if (tankmateData == null)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No tankmate data available.',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              _buildTankmateContent(),
          ],
        ),
      ),
    );
  }



  Widget _buildTankmateContent() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Only show fully compatible fish (simplified)
          if (tankmateData!.fullyCompatibleTankmates.isNotEmpty) ...[
            const Text(
              'Compatible Fish:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: tankmateData!.fullyCompatibleTankmates
                  .take(6) // Show only first 6
                  .map((fish) => _buildFishChip(fish, Colors.green))
                  .toList(),
            ),
            if (tankmateData!.fullyCompatibleTankmates.length > 6)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '+ ${tankmateData!.fullyCompatibleTankmates.length - 6} more compatible fish',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ] else ...[
            const Text(
              'No fully compatible tankmates found.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          
          // View more button
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => FishInfoDialog(fishName: widget.fishName),
                );
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: const Text(
                'View Compatibility Details',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF006064),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildFishChip(String fishName, Color accentColor) {
    return InkWell(
      onTap: () {
        widget.onFishSelected(fishName);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: accentColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accentColor.withOpacity(0.3), width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              FontAwesomeIcons.fish,
              size: 8,
              color: accentColor,
            ),
            const SizedBox(width: 4),
            Text(
              fishName,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: accentColor.withOpacity(0.8),
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.add_circle_outline,
              size: 10,
              color: accentColor,
            ),
          ],
        ),
      ),
    );
  }
}
