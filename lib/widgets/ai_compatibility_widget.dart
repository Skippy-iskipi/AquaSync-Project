import 'package:flutter/material.dart';
import '../services/enhanced_tankmate_service.dart';

class AICompatibilityWidget extends StatefulWidget {
  final String fish1Name;
  final String fish2Name;
  final VoidCallback? onClose;

  const AICompatibilityWidget({
    Key? key,
    required this.fish1Name,
    required this.fish2Name,
    this.onClose,
  }) : super(key: key);

  @override
  State<AICompatibilityWidget> createState() => _AICompatibilityWidgetState();
}

class _AICompatibilityWidgetState extends State<AICompatibilityWidget>
    with TickerProviderStateMixin {
  Map<String, dynamic>? _compatibilityData;
  bool _isLoading = true;
  String? _errorMessage;
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadAICompatibility();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _loadAICompatibility() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final data = await EnhancedTankmateService.getAICompatibilityAnalysis(
        widget.fish1Name,
        widget.fish2Name,
      );

      if (mounted) {
        setState(() {
          _compatibilityData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load AI compatibility analysis: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
            maxWidth: MediaQuery.of(context).size.width * 0.95,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: _buildContent(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue.shade600,
            Colors.purple.shade600,
          ],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.psychology,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'AI Compatibility Analysis',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${widget.fish1Name} + ${widget.fish2Name}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          if (widget.onClose != null)
            IconButton(
              onPressed: widget.onClose,
              icon: Icon(
                Icons.close,
                color: Colors.white,
                size: 24,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return _buildLoadingState();
    } else if (_errorMessage != null) {
      return _buildErrorState();
    } else if (_compatibilityData != null) {
      return _buildCompatibilityContent();
    } else {
      return _buildNoDataState();
    }
  }

  Widget _buildLoadingState() {
    return Container(
      height: 200,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 50,
            height: 50,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'AI is analyzing compatibility...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This may take a few moments',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.red.shade400,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            'Analysis Failed',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.red.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage!,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _loadAICompatibility,
            icon: Icon(Icons.refresh, size: 18),
            label: Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoDataState() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Icon(
            Icons.info_outline,
            color: Colors.grey.shade400,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            'No Data Available',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Unable to generate compatibility analysis',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCompatibilityContent() {
    final data = _compatibilityData!['data'] as Map<String, dynamic>;
    final isAI = _compatibilityData!['ai_generated'] as bool? ?? false;
    final confidence = _compatibilityData!['confidence_score'] as double? ?? 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // AI Status Badge
        _buildAIStatusBadge(isAI, confidence),
        const SizedBox(height: 20),

        // Compatibility Level
        _buildCompatibilityLevel(data['compatibility_level']),
        const SizedBox(height: 20),

        // Compatibility Reasons
        if (data['compatibility_reasons']?.isNotEmpty == true)
          _buildSection(
            'Analysis Results',
            Icons.lightbulb,
            Colors.amber,
            data['compatibility_reasons'],
          ),

        // Required Conditions
        if (data['conditions']?.isNotEmpty == true)
          _buildSection(
            'Required Conditions',
            Icons.warning,
            Colors.orange,
            data['conditions'],
          ),

        // Care Requirements
        if (data['care_requirements']?.isNotEmpty == true)
          _buildSection(
            'Care Requirements',
            Icons.favorite,
            Colors.red,
            data['care_requirements'],
          ),

        // Generation Method
        _buildGenerationMethod(data['generation_method']),
      ],
    );
  }

  Widget _buildAIStatusBadge(bool isAI, double confidence) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isAI ? Colors.green.shade100 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isAI ? Colors.green.shade300 : Colors.grey.shade300,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isAI ? Icons.psychology : Icons.computer,
            size: 16,
            color: isAI ? Colors.green.shade700 : Colors.grey.shade700,
          ),
          const SizedBox(width: 8),
          Text(
            isAI ? 'AI Generated' : 'Basic Logic',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isAI ? Colors.green.shade700 : Colors.grey.shade700,
            ),
          ),
          if (isAI) ...[
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${(confidence * 100).round()}%',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompatibilityLevel(String level) {
    Color color;
    IconData icon;
    String text;

    switch (level.toLowerCase()) {
      case 'compatible':
        color = Colors.green;
        icon = Icons.check_circle;
        text = 'Fully Compatible';
        break;
      case 'conditional':
        color = Colors.orange;
        icon = Icons.warning;
        text = 'Conditionally Compatible';
        break;
      case 'incompatible':
        color = Colors.red;
        icon = Icons.cancel;
        text = 'Incompatible';
        break;
      default:
        color = Colors.grey;
        icon = Icons.help;
        text = 'Unknown Compatibility';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  'Compatibility Level',
                  style: TextStyle(
                    fontSize: 14,
                    color: color.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, Color color, List<dynamic> items) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Column(
              children: items.map<Widget>((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item.toString(),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenerationMethod(String method) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.settings, color: Colors.grey.shade600, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Generation Method',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                Text(
                  method.replaceAll('_', ' ').toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
