import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class GuideOverlay extends StatefulWidget {
  final VoidCallback onFinish;

  const GuideOverlay({super.key, required this.onFinish});

  // These keys will be used to get the position of the bottom navigation icons
  static final exploreKey = GlobalKey();
  static final logbookKey = GlobalKey();
  static final captureKey = GlobalKey();
  static final calculatorKey = GlobalKey();
  static final syncKey = GlobalKey();

  @override
  State<GuideOverlay> createState() => _GuideOverlayState();
}

class _GuideOverlayState extends State<GuideOverlay> {
  int _currentStep = 0;

  late final List<_GuideStep> _guideSteps;

  @override
  void initState() {
    super.initState();
    _guideSteps = [
      _GuideStep(
        description: 'Explore tab, where you\'ll find different kinds of fish.',
        targetKey: GuideOverlay.exploreKey,
      ),
      _GuideStep(
        description: 'Log book tab, this is where you\'ll find your saved captures and compatibility results.',
        targetKey: GuideOverlay.logbookKey,
      ),
      _GuideStep(
        description: 'Capture lets you scan fishes in real life.',
        targetKey: GuideOverlay.captureKey,
        padding: const EdgeInsets.all(8),
        shape: BoxShape.circle,
      ),
      _GuideStep(
        description: 'Calculator tab, helps you determine the perfect water environment for your pet fish.',
        targetKey: GuideOverlay.calculatorKey,
      ),
      _GuideStep(
        description: 'Sync tab, determines fishes that are suitable to each other.',
        targetKey: GuideOverlay.syncKey,
      ),
    ];
  }

  void _nextStep() {
    if (_currentStep < _guideSteps.length - 1) {
      setState(() {
        _currentStep++;
      });
    } else {
      widget.onFinish();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      elevation: 1000, // High elevation to ensure it appears above everything
      child: LayoutBuilder(
        builder: (context, constraints) {
          final step = _guideSteps[_currentStep];
          final RenderBox? renderBox = step.targetKey.currentContext?.findRenderObject() as RenderBox?;
          if (renderBox == null) {
            return const SizedBox.shrink();
          }

          final targetSize = renderBox.size;
          final targetPosition = renderBox.localToGlobal(Offset.zero);
          final highlightRect = Rect.fromLTWH(
            targetPosition.dx - step.padding.left,
            targetPosition.dy - step.padding.top,
            targetSize.width + step.padding.horizontal,
            targetSize.height + step.padding.vertical,
          );

          // Check if the target is in the bottom navigation area (last 25% of screen)
          final isBottomNav = targetPosition.dy > constraints.maxHeight * 0.75;
          
          // Calculate available space above the highlight
          final availableSpaceAbove = highlightRect.top;

          return Stack(
            children: [
              ColorFiltered(
                colorFilter: ColorFilter.mode(
                  Colors.black.withValues(alpha: 0.7),
                  BlendMode.srcOut,
                ),
                child: Stack(
                  children: [
                    Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        backgroundBlendMode: BlendMode.dstOut,
                      ),
                    ),
                    Positioned(
                      left: highlightRect.left,
                      top: highlightRect.top,
                      width: highlightRect.width,
                      height: highlightRect.height,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: step.shape,
                          borderRadius: step.shape == BoxShape.rectangle ? BorderRadius.circular(8) : null,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Position tooltip based on available space and target location
              Positioned(
                top: isBottomNav || availableSpaceAbove < 200 ? null : 0,
                bottom: isBottomNav || availableSpaceAbove < 200 
                    ? constraints.maxHeight - highlightRect.top + 60 
                    : null,
                left: 20,
                right: 20,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(20.0),
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(255, 255, 255, 255),
                      borderRadius: BorderRadius.circular(12.0),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          step.description,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.lato(
                            fontSize: 18,
                            color: const Color.fromARGB(255, 0, 0, 0),
                            fontWeight: FontWeight.bold,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextButton(
                              onPressed: widget.onFinish,
                              child: const Text(
                                'Skip',
                                style: TextStyle(color: Color.fromARGB(179, 43, 42, 42)),
                              ),
                            ),
                            const SizedBox(width: 16),
                            ElevatedButton(
                              onPressed: _nextStep,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00BFB3),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                _currentStep == _guideSteps.length - 1 ? 'Finish' : 'Next',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GuideStep {
  final String description;
  final GlobalKey targetKey;
  final EdgeInsets padding;
  final BoxShape shape;

  _GuideStep({
    required this.description,
    required this.targetKey,
    this.padding = const EdgeInsets.all(4),
    this.shape = BoxShape.rectangle,
  });
} 