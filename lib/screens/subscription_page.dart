import 'package:flutter/material.dart';
import 'package:aquasync/screens/auth_screen.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class SubscriptionPage extends StatelessWidget {
  final VoidCallback? onPlanSelected;
  const SubscriptionPage({super.key, this.onPlanSelected});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> tiers = [
      {
        'name': 'Pro',
        'price': '₱199/mo',
        'color': Colors.white,
        'features': [
          {'label': 'Explore fish info/list', 'enabled': true},
          {'label': 'Capture fish', 'enabled': true, 'note': 'Unlimited'},
          {'label': 'Save captured fish', 'enabled': true},
          {'label': 'Fish & water calculator', 'enabled': true, 'note': 'Advanced + Recommendations'},
          {'label': 'Compatibility check', 'enabled': true, 'note': 'Unlimited'},
          {'label': 'Compatibility result breakdown', 'enabled': true, 'note': 'Detailed'},
          {'label': 'Save compatibility results', 'enabled': true},
          {'label': 'Advanced/deep compatibility analysis', 'enabled': true, 'note': 'Comprehensive'},
        ],
        'button': 'Upgrade to Pro',
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Upgrade Your Plan'),
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

class SubscriptionService {
  static const String backendUrl = 'https://aquasync.onrender.com';
  static const String paymongoBaseUrl = 'https://api.paymongo.com/v1';
  static const String paymongoSecretKey = 'PAYMONGO_SECRET_KEY';

  static Map<String, String> getPayMongoHeaders() {
    final basicAuth = base64Encode(utf8.encode('$paymongoSecretKey:'));
    return {
      'Authorization': 'Basic $basicAuth',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  static Future<Map<String, dynamic>> createPaymentLink({
    required String userId,
    required String tierPlan,
  }) async {
    try {
      final uri = Uri.parse('$backendUrl/create-payment-link');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'user_id': userId,
          'tier_plan': tierPlan,
        }),
      );
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return responseData;
      } else {
        throw Exception('Failed to create payment link: \\${response.body}');
      }
    } catch (e) {
      throw Exception('Error during payment process: $e');
    }
  }

  /// Create a payment method (GCash example)
  static Future<Map<String, dynamic>> createEwalletPaymentMethod({
    required String type, // 'gcash', 'paymaya', etc.
    required String billingEmail,
    required String billingName,
  }) async {
    final url = Uri.parse('$paymongoBaseUrl/payment_methods');
    final body = jsonEncode({
      'data': {
        'attributes': {
          'type': type,
          'billing': {
            'email': billingEmail,
            'name': billingName,
          }
        }
      }
    });
    final response = await http.post(url, headers: getPayMongoHeaders(), body: body);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body)['data'];
    } else {
      throw Exception('Failed to create payment method: ${response.body}');
    }
  }

  /// Create a payment method (Card example)
  static Future<Map<String, dynamic>> createCardPaymentMethod({
    required String cardNumber,
    required String expMonth,
    required String expYear,
    required String cvc,
    required String billingEmail,
  }) async {
    final url = Uri.parse('$paymongoBaseUrl/payment_methods');
    final body = jsonEncode({
      'data': {
        'attributes': {
          'type': 'card',
          'details': {
            'card_number': cardNumber,
            'exp_month': expMonth,
            'exp_year': expYear,
            'cvc': cvc,
          },
          'billing': {
            'email': billingEmail,
          }
        }
      }
    });
    final response = await http.post(url, headers: getPayMongoHeaders(), body: body);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body)['data'];
    } else {
      throw Exception('Failed to create card payment method: ${response.body}');
    }
  }

  /// Attach payment method to payment intent
  static Future<Map<String, dynamic>> attachPaymentMethodToIntent({
    required String paymentIntentId,
    required String paymentMethodId,
    required String clientKey,
    String? returnUrl, // Optional for e-wallets
  }) async {
    final url = Uri.parse('$paymongoBaseUrl/payment_intents/$paymentIntentId/attach');
    final attributes = {
      'payment_method': paymentMethodId,
      'client_key': clientKey,
    };
    if (returnUrl != null) {
      attributes['return_url'] = returnUrl;
    }
    final body = jsonEncode({
      'data': {
        'attributes': attributes
      }
    });
    final response = await http.post(url, headers: getPayMongoHeaders(), body: body);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body)['data'];
    } else {
      throw Exception('Failed to attach payment method: ${response.body}');
    }
  }
}

class _TierCard extends StatelessWidget {
  final Map<String, dynamic> tier;
  final VoidCallback? onPlanSelected;
  const _TierCard({required this.tier, this.onPlanSelected});

  Future<String?> showPaymentMethodDialog(BuildContext context) async {
    return showDialog<String>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text('Choose Payment Method'),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, 'card'),
              child: const Text('Credit/Debit Card'),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, 'gcash'),
              child: const Text('GCash'),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, 'paymaya'),
              child: const Text('PayMaya'),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, 'grab_pay'),
              child: const Text('GrabPay'),
            ),
          ],
        );
      },
    );
  }

  Future<Map<String, String>> promptForNameAndEmail(BuildContext context) async {
    String email = '';
    String name = '';
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Enter your name and email'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                keyboardType: TextInputType.name,
                onChanged: (value) => name = value,
                decoration: const InputDecoration(hintText: 'Full Name'),
              ),
              const SizedBox(height: 8),
              TextField(
                keyboardType: TextInputType.emailAddress,
                onChanged: (value) => email = value,
                decoration: const InputDecoration(hintText: 'Email'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
    return {'email': email, 'name': name};
  }

  Future<void> pollPaymentStatusAndShowResult(BuildContext context, String paymentIntentId) async {
    // TODO: Implement polling logic to check payment status from your backend or PayMongo
    // For now, just show a placeholder dialog
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Payment Status'),
        content: const Text('Payment status check after return from e-wallet is not yet implemented.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 60), // Space for big ribbon
                  Center(
                    child: Text(
                      tier['price'],
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
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
                                          text: ' ( $note)',
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
                      onPressed: () async {
                        if (tier['name'] == 'Free') {
                          if (onPlanSelected != null) onPlanSelected!();
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => const AuthScreen()),
                          );
                          return;
                        }
                        final userId = Supabase.instance.client.auth.currentUser?.id;
                        if (userId == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('You must be logged in to subscribe.')),
                          );
                          return;
                        }
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (_) => const Center(child: CircularProgressIndicator()),
                        );
                        try {
                          final result = await SubscriptionService.createPaymentLink(
                            userId: userId,
                            tierPlan: tier['name'].toLowerCase().replaceAll(' ', '_'),
                          );
                          Navigator.pop(context); // Remove loading
                          final checkoutUrl = result['checkout_url'];
                          if (checkoutUrl != null) {
                            if (await canLaunch(checkoutUrl)) {
                              await launch(checkoutUrl, forceSafariVC: false, forceWebView: false);
                            } else {
                              throw 'Could not launch $checkoutUrl';
                            }
                          } else {
                            showDialog(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('Error'),
                                content: const Text('No checkout URL returned.'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('OK'),
                                  ),
                                ],
                              ),
                            );
                          }
                        } catch (e) {
                          Navigator.pop(context); // Remove loading
                          showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Error'),
                              content: Text(e.toString()),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('OK'),
                                ),
                              ],
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.cyan[700],
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
            // Big Ribbon at top right
            Positioned(
              top: -12,
              right: -22,
              child: Image.asset(
                'lib/icons/Ribbon_Pro.png',
                width: 300,
                height: 120,
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
      ),
    );
  }
}