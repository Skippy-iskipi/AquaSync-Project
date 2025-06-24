import 'package:flutter/material.dart';
import 'auth_screen.dart';

class SubscriptionPage extends StatelessWidget {
  final VoidCallback? onPlanSelected;
  const SubscriptionPage({super.key, this.onPlanSelected});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> tiers = [
      {
        'name': 'Free',
        'price': 'Free',
        'color': Colors.grey[200],
        'features': [
          {'label': 'Explore fish info/list', 'enabled': true},
          {'label': 'Capture fish (limit)', 'enabled': true, 'note': 'Up to 5'},
          {'label': 'Save captured fish', 'enabled': true},
          {'label': 'Fish & water calculator', 'enabled': true, 'note': 'Basic'},
          {'label': 'Compatibility check (limit)', 'enabled': true, 'note': '2 times, cannot save'},
          {'label': 'Compatibility result breakdown', 'enabled': false},
          {'label': 'Save compatibility results', 'enabled': false},
          {'label': 'Advanced/deep compatibility analysis', 'enabled': false},
        ],
        'button': 'Get Started',
      },
      {
        'name': 'Pro',
        'price': '₱2.99/mo',
        'color': Colors.blue[50],
        'features': [
          {'label': 'Explore fish info/list', 'enabled': true},
          {'label': 'Capture fish (limit)', 'enabled': true, 'note': 'Up to 20'},
          {'label': 'Save captured fish', 'enabled': true},
          {'label': 'Fish & water calculator', 'enabled': true, 'note': 'Advanced'},
          {'label': 'Compatibility check (limit)', 'enabled': true, 'note': 'Unlimited (no deep analysis)'},
          {'label': 'Compatibility result breakdown', 'enabled': true, 'note': 'Standard'},
          {'label': 'Save compatibility results', 'enabled': true},
          {'label': 'Advanced/deep compatibility analysis', 'enabled': false},
        ],
        'button': 'Upgrade to Pro',
      },
      {
        'name': 'Pro Plus',
        'price': '₱4.99/mo',
        'color': Colors.amber[50],
        'features': [
          {'label': 'Explore fish info/list', 'enabled': true},
          {'label': 'Capture fish (limit)', 'enabled': true, 'note': 'Unlimited'},
          {'label': 'Save captured fish', 'enabled': true},
          {'label': 'Fish & water calculator', 'enabled': true, 'note': 'Advanced + Recommendations'},
          {'label': 'Compatibility check (limit)', 'enabled': true, 'note': 'Unlimited (deep analysis)'},
          {'label': 'Compatibility result breakdown', 'enabled': true, 'note': 'Detailed'},
          {'label': 'Save compatibility results', 'enabled': true},
          {'label': 'Advanced/deep compatibility analysis', 'enabled': true},
        ],
        'button': 'Upgrade to Pro Plus',
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Your Plan'),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      backgroundColor: const Color(0xFFF5F7FA),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 700;
            return isWide
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: tiers.map((tier) => Expanded(child: _TierCard(tier: tier, onPlanSelected: onPlanSelected))).toList(),
                  )
                : Column(
                    children: tiers.map((tier) => _TierCard(tier: tier, onPlanSelected: onPlanSelected)).toList(),
                  );
          },
        ),
      ),
    );
  }
}

class _TierCard extends StatelessWidget {
  final Map<String, dynamic> tier;
  final VoidCallback? onPlanSelected;
  const _TierCard({required this.tier, this.onPlanSelected});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      color: tier['color'],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  tier['name'],
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal[800],
                  ),
                ),
                const Spacer(),
                Text(
                  tier['price'],
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            ...tier['features'].map<Widget>((feature) {
              final bool enabled = feature['enabled'] ?? false;
              final String label = feature['label'];
              final String? note = feature['note'];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      enabled ? Icons.check_circle : Icons.cancel,
                      color: enabled ? Colors.green : Colors.redAccent,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          text: label,
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                          children: note != null
                              ? [
                                  TextSpan(
                                    text: ' ($note)',
                                    style: const TextStyle(
                                      color: Colors.black54,
                                      fontWeight: FontWeight.normal,
                                      fontSize: 14,
                                    ),
                                  ),
                                ]
                              : [],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (onPlanSelected != null) onPlanSelected!();
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const AuthScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal[700],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  tier['button'],
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 