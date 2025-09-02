import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class BeginnerGuideDialog extends StatefulWidget {
  final String calculatorType;

  const BeginnerGuideDialog({super.key, required this.calculatorType});

  @override
  State<BeginnerGuideDialog> createState() => _BeginnerGuideDialogState();
}

class _BeginnerGuideDialogState extends State<BeginnerGuideDialog> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<GuideSection> _getGuideContent() {
    switch (widget.calculatorType) {
      case 'water':
        return _getWaterCalculatorGuide();
      case 'dimensions':
        return _getDimensionsCalculatorGuide();
      case 'volume':
        return _getVolumeCalculatorGuide();
      default:
        return _getGeneralGuide();
    }
  }

  List<GuideSection> _getWaterCalculatorGuide() {
    return [
      GuideSection(
        title: 'Welcome to Water Calculator',
        icon: Icons.water_drop,
        content: 'This tool helps you determine the optimal water conditions and tank requirements for your fish combination.',
        tips: [
          'Choose fish that are compatible with each other',
          'Consider the adult size of your fish',
          'Think about water parameter requirements',
        ],
      ),
      GuideSection(
        title: 'Adding Fish Species',
        icon: FontAwesomeIcons.fish,
        content: 'Start by selecting the fish species you want to keep together. Use the search feature to find specific fish.',
        tips: [
          'Type fish names in the search box',
          'Select from the dropdown suggestions',
          'Adjust quantities using +/- buttons',
          'You can add multiple fish cards',
        ],
      ),
      GuideSection(
        title: 'Understanding Results',
        icon: Icons.analytics,
        content: 'The calculator shows compatibility issues, minimum tank volume, and water parameters.',
        tips: [
          'Red warnings indicate incompatible fish',
          'Green results show successful combinations',
          'Check oxygen and filtration needs',
          'Save successful calculations to your history',
        ],
      ),
      GuideSection(
        title: 'Tank Shape Considerations',
        icon: Icons.crop_square,
        content: 'Different tank shapes affect fish behavior and water circulation.',
        tips: [
          'Rectangle tanks: Best for most fish, good swimming space',
          'Square tanks: Suitable for territorial fish',
          'Bowl tanks: Only for small, low-bioload fish',
          'Consider fish swimming patterns when choosing shape',
        ],
      ),
    ];
  }

  List<GuideSection> _getDimensionsCalculatorGuide() {
    return [
      GuideSection(
        title: 'Tank Dimensions Calculator',
        icon: FontAwesomeIcons.ruler,
        content: 'Calculate how many fish can fit in your specific tank dimensions.',
        tips: [
          'Measure your tank accurately',
          'Consider usable space vs. total volume',
          'Account for decorations and equipment',
        ],
      ),
      GuideSection(
        title: 'Measuring Your Tank',
        icon: Icons.straighten,
        content: 'Use accurate measurements for the best results. Choose between centimeters or inches.',
        tips: [
          'Measure internal dimensions only',
          'Length × Width × Height = Volume',
          'Subtract space for substrate and decorations',
          'Don\'t fill tank to the very top',
        ],
      ),
      GuideSection(
        title: 'Tank Shape Guide',
        icon: Icons.crop_square,
        content: 'Different tank shapes have different benefits for fish keeping.',
        tips: [
          'Long tanks: Better for active swimmers',
          'Tall tanks: Good for vertical territories',
          'Cube tanks: Suitable for less active fish',
          'Surface area matters more than height for oxygenation',
        ],
      ),
      GuideSection(
        title: 'Bioload Management',
        icon: Icons.eco,
        content: 'Understanding your tank\'s biological capacity is crucial for fish health.',
        tips: [
          'More fish = more waste = more filtration needed',
          'Large fish produce more waste than small fish',
          'Overstocking leads to poor water quality',
          'Start with fewer fish and add gradually',
        ],
      ),
    ];
  }

  List<GuideSection> _getVolumeCalculatorGuide() {
    return [
      GuideSection(
        title: 'Volume Calculator',
        icon: FontAwesomeIcons.water,
        content: 'Determine how many fish can safely live in your known tank volume.',
        tips: [
          'Know your tank\'s exact volume',
          'Consider net volume vs. total volume',
          'Account for displacement from decorations',
        ],
      ),
      GuideSection(
        title: 'Volume Units',
        icon: Icons.science,
        content: 'Choose between liters and gallons for your tank volume measurement.',
        tips: [
          'Liters (L): Common in metric countries',
          'Gallons (gal): Common in US',
          '1 gallon ≈ 3.79 liters',
          'Be consistent with your measurements',
        ],
      ),
      GuideSection(
        title: 'Stocking Guidelines',
        icon: FontAwesomeIcons.fish,
        content: 'General rules for how many fish can fit in your tank volume.',
        tips: [
          'Freshwater: ~1 inch of fish per gallon',
          'Saltwater: ~1 inch of fish per 2-3 gallons',
          'Consider adult fish size, not current size',
          'Aggressive fish need more space per individual',
        ],
      ),
      GuideSection(
        title: 'Water Quality',
        icon: Icons.water_damage,
        content: 'Larger volumes are more stable and forgiving for beginners.',
        tips: [
          'Bigger tanks = more stable water parameters',
          'Easier to maintain consistent temperature',
          'Dilutes waste products more effectively',
          'More room for error in feeding and care',
        ],
      ),
    ];
  }

  List<GuideSection> _getGeneralGuide() {
    return [
      GuideSection(
        title: 'Getting Started',
        icon: Icons.lightbulb,
        content: 'Welcome to AquaSync! This guide will help you understand the basics of aquarium planning.',
        tips: [
          'Start with compatible fish species',
          'Research before buying',
          'Plan for adult fish sizes',
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final guideContent = _getGuideContent();
    
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Container(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.zero,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF006064), Color(0xFF00ACC1)],
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.school, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Beginner\'s Guide',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            
            // Page indicator
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  guideContent.length,
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentPage == index
                          ? const Color(0xFF00BCD4)
                          : Colors.grey.shade300,
                    ),
                  ),
                ),
              ),
            ),
            
            // Content
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: guideContent.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemBuilder: (context, index) {
                  return _buildGuidePage(guideContent[index]);
                },
              ),
            ),
            
            // Navigation buttons
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: _currentPage > 0
                        ? () {
                            _pageController.previousPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          }
                        : null,
                    child: Text(
                      'Previous',
                      style: TextStyle(
                        color: _currentPage > 0 ? const Color(0xFF006064) : Colors.grey,
                      ),
                    ),
                  ),
                  Text(
                    '${_currentPage + 1} of ${guideContent.length}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      if (_currentPage < guideContent.length - 1) {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      } else {
                        Navigator.of(context).pop();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00BCD4),
                    ),
                    child: Text(
                      _currentPage < guideContent.length - 1 ? 'Next' : 'Got It!',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildGuidePage(GuideSection section) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Icon and title
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFE0F7FA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  section.icon,
                  size: 40,
                  color: const Color(0xFF006064),
                ),
                const SizedBox(height: 8),
                Text(
                  section.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF006064),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Content
          Flexible(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                section.content,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.visible,
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Tips
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.tips_and_updates, color: Color(0xFF00BCD4)),
                      SizedBox(width: 8),
                      Text(
                        'Tips',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF006064),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: section.tips.map((tip) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                margin: const EdgeInsets.only(top: 6),
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF00BCD4),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  tip,
                                  style: const TextStyle(fontSize: 14, height: 1.4),
                                ),
                              ),
                            ],
                          ),
                        )).toList(),
                      ),
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

class GuideSection {
  final String title;
  final IconData icon;
  final String content;
  final List<String> tips;

  GuideSection({
    required this.title,
    required this.icon,
    required this.content,
    required this.tips,
  });
}
