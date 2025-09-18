import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'fish_info_dialog.dart';

class CalculationResultWidget extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<CalculationInfoRow> infoRows;
  final List<CalculationCard>? additionalCards;
  final Widget? customContent;

  const CalculationResultWidget({
    Key? key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.infoRows,
    this.additionalCards,
    this.customContent,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF00ACC1),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  icon,
                  color: const Color(0xFF00ACC1),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Custom content or info rows
            if (customContent != null)
              customContent!
            else
              ...infoRows.map((row) => _buildInfoRow(context, row)),
            
            // Additional cards
            if (additionalCards != null) ...[
              const SizedBox(height: 16),
              ...additionalCards!.map((card) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildAdditionalCard(card),
              )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, CalculationInfoRow row) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: const Color(0xFF00ACC1).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            row.icon,
            color: const Color(0xFF00ACC1),
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${row.label}: ${row.value}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.normal,
                color: Colors.black,
              ),
            ),
          ),
          if (row.showEyeIcon) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                // Extract fish name from the label
                // Handle formats like "2x Fish Name" or "Fish1 & Fish2"
                String fishName;
                if (row.label.contains('x ')) {
                  // Format: "2x Fish Name" - extract everything after "x "
                  fishName = row.label.split('x ')[1];
                } else if (row.label.contains(' & ')) {
                  // Format: "Fish1 & Fish2" - get first fish name
                  fishName = row.label.split(' & ')[0];
                } else {
                  // Fallback: use the entire label
                  fishName = row.label;
                }
                showDialog(
                  context: context,
                  builder: (context) => FishInfoDialog(fishName: fishName),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF00ACC1).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(
                  Icons.remove_red_eye_rounded,
                  color: Color(0xFF00ACC1),
                  size: 16,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAdditionalCard(CalculationCard card) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: const Color(0xFF00ACC1).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            card.icon,
            color: const Color(0xFF00ACC1),
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              card.content,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.normal,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CalculationInfoRow {
  final IconData icon;
  final String label;
  final String value;
  final bool showEyeIcon;

  const CalculationInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.showEyeIcon = false,
  });
}

class CalculationCard {
  final IconData icon;
  final String content;
  final Color borderColor;
  final Color textColor;

  const CalculationCard({
    required this.icon,
    required this.content,
    this.borderColor = const Color(0xFF00ACC1),
    this.textColor = const Color(0xFF006064),
  });
}

// Specialized widgets for different calculation types

class FishSelectionCard extends StatelessWidget {
  final Map<String, int> fishSelections;
  final String cardTitle;
  final String cardSubtitle;

  const FishSelectionCard({
    Key? key,
    required this.fishSelections,
    required this.cardTitle,
    required this.cardSubtitle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CalculationResultWidget(
      title: cardTitle,
      subtitle: cardSubtitle,
      icon: FontAwesomeIcons.fish,
      infoRows: [],
      customContent: Column(
        children: fishSelections.entries.map((entry) {
          final fishName = entry.key;
          final quantity = entry.value;
          
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: const Color(0xFF00ACC1).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  FontAwesomeIcons.fish,
                  color: Color(0xFF00ACC1),
                  size: 14,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${quantity}x $fishName',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.normal,
                      color: Colors.black,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => FishInfoDialog(fishName: fishName),
                    );
                  },
                  child: const Icon(
                    Icons.remove_red_eye_rounded,
                    color: Color(0xFF00ACC1),
                    size: 16,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class TankVolumeCard extends StatelessWidget {
  final String volume;

  const TankVolumeCard({
    Key? key,
    required this.volume,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: const Color(0xFF00ACC1).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.water,
            color: Color(0xFF00ACC1),
            size: 16,
          ),
          const SizedBox(width: 8),
          const Text(
            'Tank Volume: ',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.normal,
              color: Colors.black,
            ),
          ),
          Text(
            volume,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

class TankmateRecommendationsCard extends StatefulWidget {
  final List<String> tankmates;
  final List<String>? compatibleWithConditions;

  const TankmateRecommendationsCard({
    Key? key,
    required this.tankmates,
    this.compatibleWithConditions,
  }) : super(key: key);

  @override
  State<TankmateRecommendationsCard> createState() => _TankmateRecommendationsCardState();
}

class _TankmateRecommendationsCardState extends State<TankmateRecommendationsCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return CalculationResultWidget(
      title: 'Tankmate Recommendations',
      subtitle: 'Compatible fish for your tank',
      icon: FontAwesomeIcons.users,
      infoRows: [],
      customContent: Column(
        children: [
          // Expandable header
          GestureDetector(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: const Color(0xFF00ACC1).withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    FontAwesomeIcons.users,
                    color: Color(0xFF00ACC1),
                    size: 14,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tankmate Recommendations (${widget.tankmates.length + (widget.compatibleWithConditions?.length ?? 0)} fish)',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.normal,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: const Color(0xFF00ACC1),
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
          
          // Expandable content
          if (_isExpanded) ...[
            const SizedBox(height: 12),
            
            // Fully Compatible Section
            if (widget.tankmates.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: const Color(0xFF00ACC1).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Color(0xFF00ACC1),
                          size: 14,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Fully Compatible',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: widget.tankmates.map((tankmate) => GestureDetector(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) => FishInfoDialog(fishName: tankmate),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(
                              color: const Color(0xFF00ACC1).withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                tankmate,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.black,
                                  fontWeight: FontWeight.normal,
                                ),
                              ),
                              const SizedBox(width: 3),
                              const Icon(
                                Icons.remove_red_eye,
                                size: 10,
                                color: Color(0xFF00ACC1),
                              ),
                            ],
                          ),
                        ),
                      )).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
            ],
            
            // Compatible with Conditions Section
            if (widget.compatibleWithConditions != null && widget.compatibleWithConditions!.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: const Color(0xFF00ACC1).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.warning,
                          color: Color(0xFF00ACC1),
                          size: 14,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Compatible with Conditions',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: widget.compatibleWithConditions!.map((tankmate) => GestureDetector(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) => FishInfoDialog(fishName: tankmate),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(
                              color: const Color(0xFF00ACC1).withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                tankmate,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.black,
                                  fontWeight: FontWeight.normal,
                                ),
                              ),
                              const SizedBox(width: 3),
                              const Icon(
                                Icons.remove_red_eye,
                                size: 10,
                                color: Color(0xFF00ACC1),
                              ),
                            ],
                          ),
                        ),
                      )).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class FeedingInformationCard extends StatelessWidget {
  final Map<String, dynamic> feedingInformation;

  const FeedingInformationCard({
    Key? key,
    required this.feedingInformation,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CalculationResultWidget(
      title: 'Feeding Information',
      subtitle: 'Diet and feeding guidelines for your fish',
      icon: Icons.restaurant_rounded,
      infoRows: [],
      customContent: feedingInformation.isEmpty 
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: const Color(0xFF00ACC1).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: const Center(
              child: Text(
                'No feeding information available',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          )
        : Column(
            children: feedingInformation.entries.map((entry) {
              final fishName = entry.key;
              final feedingData = entry.value as Map<String, dynamic>?;
              if (feedingData == null) return const SizedBox.shrink();
              
              return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: const Color(0xFF00ACC1).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      FontAwesomeIcons.fish,
                      size: 14,
                      color: Color(0xFF00ACC1),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      fishName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Only show the specific fields you mentioned
                if (feedingData['portion_grams'] != null) ...[
                  _buildFeedingInfoRow(
                    Icons.scale_rounded,
                    'Portion Grams',
                    '${feedingData['portion_grams']} grams each',
                  ),
                  const SizedBox(height: 4),
                ],
                if (feedingData['preferred_food'] != null) ...[
                  _buildFeedingInfoRow(
                    Icons.restaurant_menu_rounded,
                    'Preferred Food',
                    feedingData['preferred_food'].toString(),
                  ),
                  const SizedBox(height: 4),
                ],
                if (feedingData['feeding_notes'] != null) ...[
                  _buildFeedingInfoRow(
                    Icons.note_rounded,
                    'Feeding Notes',
                    feedingData['feeding_notes'].toString(),
                  ),
                  const SizedBox(height: 4),
                ],
                if (feedingData['overfeeding_risks'] != null) ...[
                  _buildFeedingInfoRow(
                    Icons.warning_rounded,
                    'Overfeeding Risks',
                    feedingData['overfeeding_risks'].toString(),
                  ),
                ],
              ],
            ),
          );
            }).toList(),
          ),
    );
  }

  Widget _buildFeedingInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(
          icon,
          color: const Color(0xFF00ACC1),
          size: 12,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '$label: $value',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.normal,
              color: Colors.black,
            ),
          ),
        ),
      ],
    );
  }
}
