import 'package:flutter/material.dart';
import '../services/enhanced_tankmate_service.dart';

class EnhancedTankmateInfoWidget extends StatefulWidget {
  final String fishName;
  final VoidCallback? onClose;

  const EnhancedTankmateInfoWidget({
    Key? key,
    required this.fishName,
    this.onClose,
  }) : super(key: key);

  @override
  State<EnhancedTankmateInfoWidget> createState() => _EnhancedTankmateInfoWidgetState();
}

class _EnhancedTankmateInfoWidgetState extends State<EnhancedTankmateInfoWidget> {
  DetailedTankmateInfo? _tankmateInfo;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadTankmateInfo();
  }

  Future<void> _loadTankmateInfo() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final info = await EnhancedTankmateService.getTankmateDetails(widget.fishName);
      
      if (mounted) {
        setState(() {
          _tankmateInfo = info;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load tankmate information: $e';
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
                  'Tankmate Info: ${widget.fishName}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
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
          else if (_tankmateInfo != null)
            _buildTankmateInfo()
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
            onPressed: _loadTankmateInfo,
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
            'No tankmate information available for ${widget.fishName}',
            style: TextStyle(color: Colors.grey.shade700),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTankmateInfo() {
    final info = _tankmateInfo!;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary stats
        _buildSummaryStats(info),
        const SizedBox(height: 16),

        // Fully compatible tankmates
        if (info.fullyCompatibleTankmates.isNotEmpty)
          _buildTankmateSection(
            'Fully Compatible',
            info.fullyCompatibleTankmates,
            Colors.green,
            Icons.check_circle,
          ),

        // Conditional tankmates
        if (info.conditionalTankmates.isNotEmpty)
          _buildConditionalTankmateSection(info.conditionalTankmates),

        // Incompatible tankmates
        if (info.incompatibleTankmates.isNotEmpty)
          _buildTankmateSection(
            'Incompatible',
            info.incompatibleTankmates,
            Colors.red,
            Icons.cancel,
          ),

        // Special requirements
        if (info.specialRequirements.isNotEmpty)
          _buildSpecialRequirementsSection(info.specialRequirements),

        // Care level
        if (info.careLevel.isNotEmpty)
          _buildCareLevelSection(info.careLevel),

        // Confidence score
        _buildConfidenceSection(info.confidenceScore),
      ],
    );
  }

  Widget _buildSummaryStats(DetailedTankmateInfo info) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Fully Compatible', info.totalFullyCompatible, Colors.green),
          _buildStatItem('Conditional', info.totalConditional, Colors.orange),
          _buildStatItem('Incompatible', info.totalIncompatible, Colors.red),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildTankmateSection(String title, List<String> tankmates, Color color, IconData icon) {
    return Column(
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
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: tankmates.map((tankmate) => _buildTankmateChip(tankmate, color)).toList(),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildConditionalTankmateSection(List<TankmateRecommendation> conditionalTankmates) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.warning, color: Colors.orange, size: 20),
            const SizedBox(width: 8),
            Text(
              'Conditional Compatibility',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...conditionalTankmates.map((tankmate) => _buildConditionalTankmateTile(tankmate)),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildConditionalTankmateTile(TankmateRecommendation tankmate) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tankmate.name,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.orange,
            ),
          ),
          if (tankmate.conditions.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Conditions:',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            ...tankmate.conditions.map((condition) => Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• ', style: TextStyle(color: Colors.grey.shade600)),
                  Expanded(
                    child: Text(
                      condition,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }

  Widget _buildTankmateChip(String tankmate, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        tankmate,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildSpecialRequirementsSection(List<String> requirements) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.info, color: Colors.blue, size: 20),
            const SizedBox(width: 8),
            Text(
              'Special Requirements',
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
            children: requirements.map((requirement) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• ', style: TextStyle(color: Colors.blue.shade600)),
                  Expanded(
                    child: Text(
                      requirement,
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

  Widget _buildCareLevelSection(String careLevel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.star, color: Colors.amber, size: 20),
            const SizedBox(width: 8),
            Text(
              'Care Level',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.amber,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.amber.shade200),
          ),
          child: Text(
            careLevel,
            style: TextStyle(
              fontSize: 14,
              color: Colors.amber.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildConfidenceSection(double confidenceScore) {
    final percentage = (confidenceScore * 100).round();
    Color confidenceColor;
    
    if (confidenceScore >= 0.8) {
      confidenceColor = Colors.green;
    } else if (confidenceScore >= 0.6) {
      confidenceColor = Colors.orange;
    } else {
      confidenceColor = Colors.red;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.analytics, color: confidenceColor, size: 20),
            const SizedBox(width: 8),
            Text(
              'Confidence Score',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: confidenceColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: confidenceColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: confidenceColor.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: confidenceScore,
                  backgroundColor: confidenceColor.withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(confidenceColor),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$percentage%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: confidenceColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
