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
      case 'diet':
        return _getDietCalculatorGuide();
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
          'Save successful calculations to your history',
        ],
      ),
      GuideSection(
        title: 'Tank Shape Considerations',
        icon: Icons.crop_landscape,
        content: 'Different tank shapes affect fish behavior and water circulation.',
        tips: [
          'Rectangle/Square tanks: Best for most fish, good swimming space',
          'Bowl tanks: Only for small, low-bioload fish',
          'Cylinder tanks: Limited horizontal swimming space',
          'Consider fish swimming patterns when choosing shape',
        ],
      ),
    ];
  }

  List<GuideSection> _getDimensionsCalculatorGuide() {
    return [
      GuideSection(
        title: 'Dimensions Calculator',
        icon: FontAwesomeIcons.ruler,
        content: 'Calculate fish capacity based on your tank\'s specific length, width, and height measurements.',
        tips: [
          'Perfect for custom or irregular tank shapes',
          'Enter exact dimensions in cm or inches',
          'Calculator converts to volume automatically',
          'Accounts for different tank shapes (rectangle, cylinder, bowl)',
        ],
      ),
      GuideSection(
        title: 'Measuring Your Tank',
        icon: Icons.straighten,
        content: 'Get accurate measurements for the best fish stocking recommendations.',
        tips: [
          'Measure internal dimensions only (not external)',
          'Length × Width × Height = Volume',
          'Subtract space for substrate (2-3 inches)',
          'Account for decorations and equipment space',
        ],
      ),
      GuideSection(
        title: 'Tank Shape Selection',
        icon: Icons.crop_landscape,
        content: 'Choose the shape that matches your tank for accurate calculations.',
        tips: [
          'Rectangle/Square: Most common, best for most fish',
          'Cylinder: Limited horizontal swimming space',
          'Bowl: Only for nano fish under 8cm',
          'Shape affects fish behavior and swimming patterns',
        ],
      ),
      GuideSection(
        title: 'Fish Compatibility Check',
        icon: Icons.eco,
        content: 'The calculator checks if your selected fish are compatible with the tank shape and size.',
        tips: [
          'Large fish need more horizontal swimming space',
          'Some fish are incompatible with bowl tanks',
          'Check warnings before adding fish',
          'Consider adult fish size, not current size',
        ],
      ),
    ];
  }

  List<GuideSection> _getVolumeCalculatorGuide() {
    return [
      GuideSection(
        title: 'Volume Calculator',
        icon: FontAwesomeIcons.water,
        content: 'Calculate fish capacity when you already know your tank\'s volume in liters or gallons.',
        tips: [
          'Ideal when you know your tank\'s exact volume',
          'No need to measure dimensions',
          'Works with any tank shape',
          'Quick and easy fish stocking calculation',
        ],
      ),
      GuideSection(
        title: 'Volume Input',
        icon: Icons.science,
        content: 'Enter your tank volume in the unit you prefer - liters or gallons.',
        tips: [
          'Liters (L): Common in metric countries',
          'Gallons (gal): Common in US and UK',
          '1 gallon ≈ 3.79 liters',
          'Use the unit you\'re most comfortable with',
        ],
      ),
      GuideSection(
        title: 'Fish Selection',
        icon: FontAwesomeIcons.fish,
        content: 'Add the fish species you want to keep and see how many fit in your tank.',
        tips: [
          'Search for fish by name',
          'Add multiple species for community tanks',
          'Adjust quantities with +/- buttons',
          'Check compatibility warnings',
        ],
      ),
      GuideSection(
        title: 'Stocking Recommendations',
        icon: Icons.recommend,
        content: 'Get personalized recommendations based on your tank volume and selected fish.',
        tips: [
          'Considers fish adult size and behavior',
          'Accounts for bioload and waste production',
          'Provides optimal fish quantities',
          'Shows water parameter requirements',
        ],
      ),
    ];
  }

  List<GuideSection> _getDietCalculatorGuide() {
    return [
      GuideSection(
        title: 'Welcome to Diet Calculator',
        icon: Icons.restaurant,
        content: 'This tool helps you calculate the optimal feeding amounts and schedules for your fish combination.',
        tips: [
          'Select fish species you want to feed together',
          'The calculator considers each fish\'s dietary needs',
          'Get portion recommendations per fish and total',
          'View feeding schedules and food type suggestions',
        ],
      ),
      GuideSection(
        title: 'Selecting Fish Species',
        icon: FontAwesomeIcons.fish,
        content: 'Choose the fish you want to calculate feeding for. You can select multiple species for community tanks.',
        tips: [
          'Browse fish by visual cards with images',
          'Use search to find specific fish quickly',
          'Adjust quantities with +/- buttons',
          'Check compatibility before calculating',
        ],
      ),
      GuideSection(
        title: 'Understanding Feeding Results',
        icon: Icons.analytics,
        content: 'The calculator provides detailed feeding information based on each fish\'s dietary requirements.',
        tips: [
          'Per-fish breakdown shows individual portions',
          'Total feeding amount for all fish combined',
          'Feeding frequency recommendations',
          'Suggested food types for each species',
        ],
      ),
      GuideSection(
        title: 'Feeding Tips & Best Practices',
        icon: Icons.lightbulb,
        content: 'Follow these guidelines to ensure your fish receive proper nutrition and maintain good health.',
        tips: [
          'Feed small amounts 2-3 times per day',
          'Only feed what fish can consume in 2-3 minutes',
          'Vary food types for balanced nutrition',
          'Monitor fish behavior and adjust portions as needed',
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
                  colors: [Color(0xFF00BFB3), Color(0xFF4DD0E1)],
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
                          ? const Color(0xFF00BFB3)
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
                        color: _currentPage > 0 ? const Color(0xFF00BFB3) : Colors.grey,
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
                      backgroundColor: const Color(0xFF00BFB3),
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
              color: const Color(0xFF00BFB3).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF00BFB3).withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  section.icon,
                  size: 40,
                  color: const Color(0xFF00BFB3),
                ),
                const SizedBox(height: 8),
                Text(
                  section.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00BFB3),
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
                      Icon(Icons.tips_and_updates, color: Color(0xFF00BFB3)),
                      SizedBox(width: 8),
                      Text(
                        'Tips',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00BFB3),
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
                                  color: Color(0xFF00BFB3),
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
