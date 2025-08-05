# Implementation Guide: Email Column in Profiles Table

## Overview
This solution adds an email column to the profiles table to reliably check user existence without relying on Supabase auth error messages.

## Step 1: Run the SQL Script

1. **Open Supabase Dashboard** → Go to your project
2. **Navigate to SQL Editor** → Click on "SQL Editor" in the sidebar
3. **Copy and paste** the contents of `add_email_to_profiles.sql`
4. **Click "Run"** to execute the script

### What the SQL script does:
- ✅ Adds `email` column to `profiles` table
- ✅ Creates an index on email for fast lookups
- ✅ Updates existing profiles with emails from `auth.users`
- ✅ Updates the trigger to include email for new users
- ✅ Updates RLS policies
- ✅ Grants necessary permissions

## Step 2: Verify the Changes

After running the SQL script, verify:

1. **Check profiles table structure**:
   ```sql
   SELECT * FROM profiles LIMIT 5;
   ```
   You should see the new `email` column populated.

2. **Test the trigger** by creating a new user:
   - Sign up with a new email in your app
   - Check that the profile is created with the email automatically

## Step 3: Test the Updated App

The `AuthService` now uses:
```dart
// Query profiles table directly for the email
final response = await _supabase
    .from('profiles')
    .select('id')
    .eq('email', email)
    .maybeSingle();
```

### Expected Behavior:

1. **Existing Email** (like `lemuel.dionisio090502@gmail.com`):
   - ✅ Should find the email in profiles table
   - ✅ Should return `true` for user exists
   - ✅ Should proceed to send password reset email

2. **Non-existing Email** (like `yieeemuel@gmail.com`):
   - ✅ Should NOT find the email in profiles table
   - ✅ Should return `false` for user exists
   - ✅ Should show "No account found with this email address"
   - ✅ Should NOT advance to the next screen

## Step 4: Debug Logs

The console will now show:
```
AuthService: Checking if user exists in profiles table: email@example.com
AuthService: User exists (found in profiles table)
```
OR
```
AuthService: Checking if user exists in profiles table: email@example.com
AuthService: User does not exist (not found in profiles table)
```

## Benefits of This Solution

### ✅ Reliable
- No more ambiguous auth error messages
- Direct database query is definitive
- Fast and accurate results

### ✅ Secure
- Prevents email enumeration attacks
- Clear error messages for users
- Proper timeout handling

### ✅ Maintainable
- Simple logic - just query the profiles table
- Easy to debug with clear logs
- Automatic email population for new users

### ✅ Performance
- Indexed email column for fast lookups
- 5-second timeout prevents hanging
- Minimal database queries

## Troubleshooting

### Issue: "Column email does not exist"
- **Solution**: Make sure you ran the SQL script completely
- **Check**: `\d profiles` in SQL editor to see table structure

### Issue: "No rows returned"
- **Solution**: Run the UPDATE query to populate existing profiles:
  ```sql
  UPDATE profiles 
  SET email = auth.users.email 
  FROM auth.users 
  WHERE profiles.id = auth.users.id 
  AND profiles.email IS NULL;
  ```

### Issue: "Permission denied"
- **Solution**: Make sure the GRANT statements ran successfully
- **Check**: RLS policies are properly configured

## Testing Checklist

- [ ] SQL script executed successfully
- [ ] Email column exists in profiles table
- [ ] Existing profiles have email populated
- [ ] New user signup creates profile with email
- [ ] Password reset works for existing emails
- [ ] Password reset fails for non-existing emails
- [ ] No long loading times
- [ ] Clear error messages shown 