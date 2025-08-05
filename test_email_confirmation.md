# Testing Email Confirmation Flow

## Current Setup

✅ **AuthService**: Added `emailRedirectTo: 'io.supabase.aquasync://login-callback/'` to signup  
✅ **Android Manifest**: Has intent filter for `login-callback`  
✅ **Main.dart**: Handles `AuthChangeEvent.signedIn` events  
✅ **AuthWrapper**: Checks `emailConfirmedAt` and navigates to HomePage  

## How to Test

### 1. **Create a New Account**
- Open your Flutter app
- Go to Sign Up
- Enter email and password
- Click "Sign Up"

### 2. **Check Email**
- You should receive a confirmation email
- The email will have a "Confirm Your Email" button

### 3. **Click the Confirmation Link**
- Click the confirmation link in your email
- This should redirect to: `io.supabase.aquasync://login-callback/`

### 4. **Expected Behavior**
- The app should open (if not already open)
- You should see a green snackbar: "Email confirmed successfully! Welcome to AquaSync!"
- You should be redirected to the HomePage

## Debugging

### If the link doesn't work:

1. **Check the redirect URL**:
   - Make sure it's exactly: `io.supabase.aquasync://login-callback/`
   - No extra characters or spaces

2. **Check Android Manifest**:
   - Verify the intent filter exists for `login-callback`

3. **Check Supabase Settings**:
   - Go to Authentication → URL Configuration
   - Add `io.supabase.aquasync://login-callback/` to Site URL or Redirect URLs

4. **Test with a simple URL**:
   - Try opening `io.supabase.aquasync://login-callback/` directly in your browser
   - It should prompt to open your app

### If the app opens but doesn't navigate:

1. **Check console logs**:
   - Look for "User signed in via deep link" messages
   - Look for "Email confirmation detected via deep link" messages

2. **Check AuthWrapper logic**:
   - Verify `_currentUser!.emailConfirmedAt != null` is true
   - Verify the user is being set correctly

## Common Issues

### Issue: Link opens browser instead of app
**Solution**: Make sure the intent filter is properly configured in AndroidManifest.xml

### Issue: App opens but stays on login screen
**Solution**: Check if the auth state change is being detected properly

### Issue: No success message appears
**Solution**: Verify the snackbar is being shown in the correct context

## Manual Testing Alternative

If the deep link doesn't work, you can manually confirm the email:

1. **Go to Supabase Dashboard**
2. **Navigate to Authentication → Users**
3. **Find your user**
4. **Click "Confirm"** next to the email
5. **Refresh your app** - it should now show the HomePage 