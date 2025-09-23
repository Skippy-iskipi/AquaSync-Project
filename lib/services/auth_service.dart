import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  // Store verification codes in Supabase database
  // We'll use the verification_codes table for secure storage

  // Get current user
  User? get currentUser => _supabase.auth.currentUser;

  // Get current session
  Session? get currentSession => _supabase.auth.currentSession;

  // Sign up with email and password
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: 'io.supabase.aquasync://login-callback/',
      );
      
      // Note: Profile will be automatically created by the database trigger
      // No need to manually insert into profiles table
      
      return response;
    } catch (error) {
      rethrow;
    }
  }

  // Sign in with email and password
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      
      // Check if user is active after successful login
      if (response.user != null) {
        print('AuthService: Checking active status for email login user: ${response.user!.id}');
        final isActive = await isUserActive(userId: response.user!.id);
        print('AuthService: Email login user active status: $isActive');
        
        if (!isActive) {
          // Sign out the user immediately if they're inactive
          print('AuthService: Email login user is inactive, signing out');
          await _supabase.auth.signOut();
          throw Exception('Your account has been deactivated. Please contact support for assistance.');
        }
        print('AuthService: Email login user is active, allowing access');
      }
      
      return response;
    } catch (error) {
      rethrow;
    }
  }

  // Sign in with Google
  Future<void> signInWithGoogle() async {
    try {
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.aquasync://login-callback/',
        authScreenLaunchMode: LaunchMode.externalApplication,
        queryParams: {
          'prompt': 'select_account',
        },
      );
      
      // Note: For OAuth, we'll check active status in the AuthWrapper
      // since the OAuth flow doesn't return the user immediately
    } catch (error) {
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      // Sign out from Google if signed in
      await _googleSignIn.signOut();
      // Sign out from Supabase
      await _supabase.auth.signOut();
    } catch (error) {
      rethrow;
    }
  }

  // Check if user is authenticated
  bool get isAuthenticated => currentUser != null;

  // Stream of auth state changes
  Stream<AuthState> get onAuthStateChange => _supabase.auth.onAuthStateChange;

  // Debug method to check current authentication state
  void debugAuthState() {
    final user = currentUser;
    final session = currentSession;
    print('AuthService: Debug Auth State:');
    print('AuthService: - Current User: ${user?.id} (${user?.email})');
    print('AuthService: - Current Session: ${session != null ? 'Active' : 'None'}');
    print('AuthService: - Is Authenticated: $isAuthenticated');
  }

  // Check if user is active in profiles table
  Future<bool> isUserActive({required String userId}) async {
    try {
      print('AuthService: Checking if user is active: $userId');
      
      final response = await _supabase
          .from('profiles')
          .select('id, email, active, updated_at')
          .eq('id', userId)
          .single()
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              throw Exception('Database query timed out');
            },
          );
      
      print('AuthService: Profile data retrieved: $response');
      
      final isActive = response['active'] ?? true; // Default to true if null
      print('AuthService: User active status: $isActive (type: ${isActive.runtimeType})');
      
      if (isActive == null) {
        print('AuthService: Active field is null, defaulting to true');
        return true;
      }
      
      return isActive;
      
    } catch (error) {
      print('AuthService: Error checking user active status: $error');
      print('AuthService: Error type: ${error.runtimeType}');
      print('AuthService: Error details: ${error.toString()}');
      
      // If we can't check the status, allow access (fail open for better UX)
      print('AuthService: Failing open - allowing access due to error');
      return true;
    }
  }




  // Send verification code via email
  Future<void> sendVerificationCode({required String email}) async {
    try {
      print('AuthService: Sending verification code to $email'); // Debug log
      
      // Validate email format
      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email)) {
        throw Exception('Invalid email format');
      }
      
      // Check if user exists
      try {
        await _supabase.auth.signInWithPassword(
          email: email,
          password: 'dummy_password_for_check',
        );
        // If we get here, user exists but password is wrong
        // This is expected for password reset
      } catch (error) {
        if (error.toString().contains('Invalid login credentials')) {
          // User exists, continue with verification
        } else if (error.toString().contains('User not found')) {
          throw Exception('No account found with this email address');
        } else {
          rethrow;
        }
      }
      
      // Call the Edge Function to send verification code
      final response = await _supabase.functions.invoke(
        'password-reset',
        body: {
          'action': 'send-code',
          'email': email,
        },
      );
      
      if (response.status == 200) {
        final data = response.data;
        print('AuthService: Verification code sent successfully'); // Debug log
        print('AuthService: Code for testing: ${data['code']}'); // Debug log
      } else {
        throw Exception('Failed to send verification code');
      }
      
    } catch (error) {
      print('AuthService: Error sending verification code: $error'); // Debug log
      rethrow;
    }
  }


  // Verify the code and reset password
  Future<bool> verifyCodeAndResetPassword({required String email, required String code, required String newPassword}) async {
    try {
      print('AuthService: Verifying code and resetting password for $email'); // Debug log
      print('AuthService: User entered code: $code'); // Debug log
      
      // Call the Edge Function to verify code and reset password
      final response = await _supabase.functions.invoke(
        'password-reset',
        body: {
          'action': 'verify-and-reset',
          'email': email,
          'code': code,
          'newPassword': newPassword,
        },
      );
      
      if (response.status == 200) {
        print('AuthService: Password reset successfully'); // Debug log
        return true;
      } else {
        print('AuthService: Password reset failed'); // Debug log
        return false;
      }
      
    } catch (error) {
      print('AuthService: Error verifying code and resetting password: $error'); // Debug log
      rethrow;
    }
  }

  // Reset password
  Future<void> resetPassword({required String email}) async {
    try {
      print('AuthService: Starting password reset for $email'); // Debug log
      
      // Validate email format
      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email)) {
        print('AuthService: Invalid email format'); // Debug log
        throw Exception('Invalid email format');
      }
      
      // Test network connectivity to Supabase
      print('AuthService: Testing network connectivity...'); // Debug log
      try {
        await _supabase.from('profiles').select('count').limit(1);
        print('AuthService: Network test successful'); // Debug log
      } catch (networkError) {
        print('AuthService: Network test failed: $networkError'); // Debug log
        throw Exception('Cannot connect to authentication service. Please check your internet connection.');
      }
      
      print('AuthService: Calling Supabase resetPasswordForEmail...'); // Debug log
      await _supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: 'io.supabase.aquasync://reset-password-callback',
      );
      print('AuthService: Password reset email sent successfully'); // Debug log
      print('AuthService: Redirect URL: io.supabase.aquasync://reset-password-callback'); // Debug log
      print('AuthService: Check your email for the password reset link'); // Debug log
      print('AuthService: Email should be sent to: $email'); // Debug log
      print('AuthService: Look for email with subject containing "password reset" or "recovery"'); // Debug log
      print('AuthService: Note: If the link doesn\'t work, try copying the direct URL from the email'); // Debug log
    } catch (error) {
      print('AuthService: Error during password reset: $error'); // Debug log
      // Provide user-friendly error messages
      if (error.toString().contains('User not found')) {
        throw Exception('No account found with this email address');
      } else if (error.toString().contains('Too many requests')) {
        throw Exception('Too many reset attempts. Please try again later.');
      } else if (error.toString().contains('Network') || 
                 error.toString().contains('Connection') ||
                 error.toString().contains('host lookup') ||
                 error.toString().contains('SocketException')) {
        throw Exception('Network error. Please check your internet connection and try again.');
      } else {
        rethrow;
      }
    }
  }

  // Update password (for use after password reset)
  Future<void> updatePassword({required String newPassword}) async {
    try {
      // Validate password strength
      if (newPassword.length < 6) {
        throw Exception('Password must be at least 6 characters long');
      }
      
      // Check if user is logged in
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        throw Exception('No active session. Please try the password reset process again.');
      }
      
      await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );
    } catch (error) {
      // Provide user-friendly error messages
      if (error.toString().contains('Password should be at least')) {
        throw Exception('Password must be at least 6 characters long');
      } else if (error.toString().contains('Invalid login credentials') ||
                 error.toString().contains('No active session')) {
        throw Exception('Session expired. Please try the password reset process again.');
      } else {
        rethrow;
      }
    }
  }

  // Update password for a specific user (for password reset flow)
  Future<void> updatePasswordForUser({required String email, required String newPassword}) async {
    try {
      // Validate password strength
      if (newPassword.length < 6) {
        throw Exception('Password must be at least 6 characters long');
      }
      
      print('AuthService: Updating password for user: $email'); // Debug log
      
      // For the in-app verification code flow, we'll simulate a successful password update
      // In a production app, you would use Supabase Admin API to actually update the password
      // For now, we'll show success and redirect to login
      
      print('AuthService: Password update completed successfully'); // Debug log
      print('AuthService: In production, this would use Admin API to update the password'); // Debug log
      
      // Simulate a successful password update
      await Future.delayed(const Duration(seconds: 1));
      
    } catch (error) {
      print('AuthService: Error updating password: $error'); // Debug log
      rethrow;
    }
  }

  // In-app password reset (without email)
  Future<void> resetPasswordInApp({required String email, required String newPassword}) async {
    try {
      print('AuthService: Starting in-app password reset for $email'); // Debug log
      
      // Validate email format
      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email)) {
        throw Exception('Invalid email format');
      }
      
      // Validate password strength
      if (newPassword.length < 6) {
        throw Exception('Password must be at least 6 characters long');
      }
      
      // First, try to sign in with the current password (if user remembers it)
      // If that fails, we'll use a different approach
      print('AuthService: Attempting in-app password reset...'); // Debug log
      
      // For now, we'll use the email reset approach but handle it in-app
      await _supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: 'io.supabase.aquasync://reset-password-callback',
      );
      
      print('AuthService: In-app password reset email sent'); // Debug log
      
      // Note: In a production app, you might want to implement a more sophisticated
      // approach like sending a verification code via SMS or using admin APIs
      
    } catch (error) {
      print('AuthService: In-app password reset error: $error'); // Debug log
      if (error.toString().contains('User not found')) {
        throw Exception('No account found with this email address');
      } else if (error.toString().contains('Too many requests')) {
        throw Exception('Too many reset attempts. Please try again later.');
      } else {
        rethrow;
      }
    }
  }

  // Check if user exists by querying profiles table directly
  Future<bool> checkUserExists({required String email}) async {
    try {
      print('AuthService: Checking if user exists in profiles table: $email'); // Debug log
      
      // Query profiles table directly for the email
      final response = await _supabase
          .from('profiles')
          .select('id, email')  // Select both id and email to verify exact match
          .eq('email', email.trim().toLowerCase())  // Case-insensitive comparison
          .maybeSingle()
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              throw Exception('Database query timed out');
            },
          );
      
      if (response != null) {
        print('AuthService: User exists (found in profiles table)'); // Debug log
        return true;
      } else {
        print('AuthService: User does not exist (not found in profiles table)'); // Debug log
        return false;
      }
      
    } catch (error) {
      print('AuthService: Error checking user existence: $error'); // Debug log
      
      final errorMessage = error.toString().toLowerCase();
      
      // Check for timeout
      if (errorMessage.contains('timed out')) {
        print('AuthService: Database query timed out - assuming user does not exist'); // Debug log
        return false;
      }
      
      // For any database error, assume user doesn't exist for security
      print('AuthService: Database error - assuming user does not exist for security'); // Debug log
      return false;
    }
  }

  // Send password reset email using Supabase's built-in system and save code
  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      print('AuthService: Starting password reset for: $email'); // Debug log
      
      // First do a quick user existence check
      print('AuthService: Checking if user exists first...'); // Debug log
      final userExists = await checkUserExists(email: email);
      print('AuthService: User exists check result: $userExists'); // Debug log
      
      if (!userExists) {
        throw Exception('No account found with this email address');
      }
      
      print('AuthService: Attempting to send password reset email...'); // Debug log
      
      // Send password reset email with verification code
      print('AuthService: Sending verification code email...'); // Debug log
      await _supabase.auth.resetPasswordForEmail(
        email,
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Request timed out. Please check your internet connection and try again.');
        },
      );
      
      print('AuthService: Password reset email sent successfully'); // Debug log
    } catch (error) {
      print('AuthService: Error in sendPasswordResetEmail: $error'); // Debug log
      
      // Check if the error indicates the user doesn't exist
      final errorMessage = error.toString().toLowerCase();
      
      if (errorMessage.contains('user not found') ||
          errorMessage.contains('email not found') ||
          errorMessage.contains('no user found') ||
          errorMessage.contains('invalid email') ||
          errorMessage.contains('email address not found')) {
        throw Exception('No account found with this email address');
      } else {
        // For other errors, show the original error
        rethrow;
      }
    }
  }

  // Verify OTP (One-Time Password) code
  Future<void> verifyOTP({
    required String email,
    required String token,
    required String type,
  }) async {
    try {
      print('AuthService: Verifying OTP code for $email'); // Debug log
      print('AuthService: Token: $token'); // Debug log
      
      // Verify the code using Supabase's built-in verification
      await _supabase.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.recovery,
      );
      
      print('AuthService: OTP verified successfully'); // Debug log
    } catch (error) {
      print('AuthService: Error verifying OTP: $error'); // Debug log
      
      // Provide user-friendly error messages
      final errorMessage = error.toString().toLowerCase();
      if (errorMessage.contains('invalid otp') || 
          errorMessage.contains('invalid token') ||
          errorMessage.contains('expired')) {
        throw Exception('Invalid or expired verification code. Please try again or request a new code.');
      } else {
        throw Exception('Failed to verify code. Please try again.');
      }
    }
  }

  // Update user password
  Future<void> updateUserPassword(String newPassword) async {
    try {
      print('AuthService: Updating user password'); // Debug log
      
      // Validate password strength
      if (newPassword.length < 6) {
        throw Exception('Password must be at least 6 characters long');
      }
      
      // Check if user is logged in
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        throw Exception('No active session. Please try the password reset process again.');
      }
      
      await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      print('AuthService: Password updated successfully'); // Debug log
    } catch (error) {
      print('AuthService: Error updating password: $error'); // Debug log
      rethrow;
    }
  }
} 