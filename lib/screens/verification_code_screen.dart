import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'new_password_screen.dart';

class VerificationCodeScreen extends StatefulWidget {
  final String email;
  
  const VerificationCodeScreen({
    super.key,
    required this.email,
  });

  @override
  State<VerificationCodeScreen> createState() => _VerificationCodeScreenState();
}

class _VerificationCodeScreenState extends State<VerificationCodeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _verificationCodeController = TextEditingController();
  final _authService = AuthService();
  
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _verificationCodeController.dispose();
    super.dispose();
  }

  Future<void> _verifyCode() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      // Verify the code
      await _authService.verifyOTP(
        email: widget.email,
        token: _verificationCodeController.text.trim(),
        type: 'recovery',
      );

      setState(() {
        _successMessage = 'Code verified successfully!';
      });

      // Show success message and navigate to new password screen
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Code verified! Please set your new password.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        // Navigate to new password screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => NewPasswordScreen(email: widget.email),
          ),
        );
      }
    } catch (error) {
      setState(() {
        _errorMessage = error.toString().replaceAll('Exception: ', '');
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _resendCode() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await _authService.sendPasswordResetEmail(
        email: widget.email,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('New verification code sent! Please check your email.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (error) {
      setState(() {
        _errorMessage = error.toString().replaceAll('Exception: ', '');
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Verify Code',
          style: TextStyle(
            color: Color(0xFF006064),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF006064)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo
                  Image.asset(
                    'lib/icons/AquaSync_Logo.png',
                    height: 120,
                    width: 120,
                  ),
                  const SizedBox(height: 24),
                  
                  // Title
                  const Text(
                    'Enter Verification Code',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF006064),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  
                  Text(
                    'Enter the verification code sent to ${widget.email}',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Verification Code field
                  TextFormField(
                    controller: _verificationCodeController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Verification Code',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter the verification code';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Error message
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  // Success message
                  if (_successMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        _successMessage!,
                        style: const TextStyle(
                          color: Colors.green,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  // Verify Code button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _verifyCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00ACC1),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Verify Code',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Resend Code button
                  TextButton(
                    onPressed: _isLoading ? null : _resendCode,
                    child: const Text(
                      'Resend Code',
                      style: TextStyle(
                        color: Color(0xFF00ACC1),
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
} 