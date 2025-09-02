import 'package:flutter/material.dart';
import '../services/enhanced_tankmate_service.dart';

class CompatibilityMatrixWidget extends StatefulWidget {
  final String fish1Name;
  final String fish2Name;
  final VoidCallback? onClose;

  const CompatibilityMatrixWidget({
    Key? key,
    required this.fish1Name,
    required this.fish2Name,
    this.onClose,
  }) : super(key: key);

  @override
  State<CompatibilityMatrixWidget> createState() => _CompatibilityMatrixWidgetState();
}

class _CompatibilityMatrixWidgetState extends State<CompatibilityMatrixWidget> {
  CompatibilityMatrixInfo? _compatibilityInfo;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCompatibilityInfo();
  }

  Future<void> _loadCompatibilityInfo() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final info = await EnhancedTankmateService.getCompatibilityMatrix(
        widget.fish1Name,
        widget.fish2Name,
      );
      
      if (mounted) {
        setState(() {
          _compatibilityInfo = info;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load compatibility information: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Compatibility: ${widget.fish1Name} + ${widget.fish2Name}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple,
                  ),
                ),
              ),
              if (widget.onClose != null)
                IconButton(
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close, color: Colors.grey),
                ),
            ],
          ),
          const SizedBox(height: 16),

          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_errorMessage != null)
            _buildErrorWidget()
          else if (_compatibilityInfo != null)
            _buildCompatibilityInfo()
          else
            _buildNoDataWidget(),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade400, size: 32),
          const SizedBox(height: 8),
          Text(
            _errorMessage!,
            style: TextStyle(color: Colors.red.shade700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _loadCompatibilityInfo,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildNoDataWidget() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.info_outline, color: Colors.grey.shade400, size: 32),
          const SizedBox(height: 8),
          Text(
            'No compatibility data available for ${widget.fish1Name} and ${widget.fish2Name}',
            style: TextStyle(color: Colors.grey.shade700),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCompatibilityInfo() {
    final info = _compatibilityInfo!;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Compatibility status
        _buildCompatibilityStatus(info),
        const SizedBox(height: 16),

        // Compatibility level
        _buildCompatibilityLevel(info.compatibilityLevel),
        const SizedBox(height: 16),

        // Compatibility score
        _buildCompatibilityScore(info.compatibilityScore),
        const SizedBox(height: 16),

        // Confidence score
        _buildConfidenceScore(info.confidenceScore),
        const SizedBox(height: 16),

        // Compatibility reasons
        if (info.compatibilityReasons.isNotEmpty)
          _buildCompatibilityReasons(info.compatibilityReasons),

        // Conditions (if conditional)
        if (info.conditions.isNotEmpty)
          _buildConditionsSection(info.conditions),

        // Generation method
        if (info.generationMethod.isNotEmpty)
          _buildGenerationMethod(info.generationMethod),
      ],
    );
  }

  Widget _buildCompatibilityStatus(CompatibilityMatrixInfo info) {
    final isCompatible = info.isCompatible;
    final color = isCompatible ? Colors.green : Colors.red;
    final icon = isCompatible ? Icons.check_circle : Icons.cancel;
    final text = isCompatible ? 'Compatible' : 'Not Compatible';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompatibilityLevel(String level) {
    Color color;
    IconData icon;
    String displayText;

    switch (level.toLowerCase()) {
      case 'compatible':
        color = Colors.green;
        icon = Icons.check_circle;
        displayText = 'Fully Compatible';
        break;
      case 'conditional':
        color = Colors.orange;
        icon = Icons.warning;
        displayText = 'Conditionally Compatible';
        break;
      case 'incompatible':
        color = Colors.red;
        icon = Icons.cancel;
        displayText = 'Incompatible';
        break;
      default:
        color = Colors.grey;
        icon = Icons.help;
        displayText = 'Unknown Compatibility';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Text(
            displayText,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompatibilityScore(double score) {
    final percentage = (score * 100).round();
    Color color;
    
    if (score >= 0.8) {
      color = Colors.green;
    } else if (score >= 0.6) {
      color = Colors.orange;
    } else if (score >= 0.4) {
      color = Colors.red;
    } else {
      color = Colors.grey;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.analytics, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              'Compatibility Score',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: score,
                  backgroundColor: color.withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$percentage%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConfidenceScore(double score) {
    final percentage = (score * 100).round();
    Color color;
    
    if (score >= 0.8) {
      color = Colors.green;
    } else if (score >= 0.6) {
      color = Colors.orange;
    } else {
      color = Colors.red;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.verified, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              'Confidence Score',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: score,
                  backgroundColor: color.withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$percentage%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompatibilityReasons(List<String> reasons) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.lightbulb, color: Colors.blue, size: 20),
            const SizedBox(width: 8),
            Text(
              'Compatibility Reasons',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: reasons.map((reason) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• ', style: TextStyle(color: Colors.blue.shade600)),
                  Expanded(
                    child: Text(
                      reason,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            )).toList(),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildConditionsSection(List<String> conditions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.warning, color: Colors.orange, size: 20),
            const SizedBox(width: 8),
            Text(
              'Required Conditions',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: conditions.map((condition) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• ', style: TextStyle(color: Colors.orange.shade600)),
                  Expanded(
                    child: Text(
                      condition,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            )).toList(),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildGenerationMethod(String method) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.settings, color: Colors.grey, size: 20),
            const SizedBox(width: 8),
            Text(
              'Generation Method',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Text(
            method,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
