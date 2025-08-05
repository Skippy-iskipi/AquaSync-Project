# Debugging Password Reset Issues

## Problem: Some accounts work, others don't

**Working**: `lemuel.dionisio090502@gmail.com` - receives verification code  
**Not Working**: Other accounts - no verification code sent  

## Possible Causes & Solutions

### 1. **Account Existence Check**

The Edge Function checks if the user exists before sending the code. If the account doesn't exist, it won't send anything.

**Check this in your Supabase Dashboard:**
1. Go to **Authentication → Users**
2. Search for the email addresses that aren't working
3. **Are they listed there?**

**If the account doesn't exist:**
- The user needs to sign up first
- Password reset only works for existing accounts

### 2. **Edge Function Error Handling**

The Edge Function might be failing silently for some accounts.

**Check Supabase Edge Function Logs:**
1. Go to **Edge Functions** in your Supabase dashboard
2. Click on **password-reset** function
3. Check the **Logs** tab
4. Look for any error messages when you try the non-working accounts

### 3. **Email Service Issues**

If you're using Resend or another email service, there might be rate limiting or delivery issues.

**Check your email service dashboard:**
- Look for failed deliveries
- Check if you've hit rate limits
- Verify sender domain is properly configured

### 4. **Database Table Issues**

The verification codes might not be getting stored properly.

**Check the `password_reset_codes` table:**
1. Go to **Table Editor** in Supabase
2. Open the `password_reset_codes` table
3. Check if codes are being inserted for the non-working accounts

## Debugging Steps

### Step 1: Check Account Existence
```sql
-- Run this in Supabase SQL Editor
SELECT id, email, email_confirmed_at 
FROM auth.users 
WHERE email = 'your-test-email@example.com';
```

### Step 2: Test Edge Function Directly
```bash
# Test the Edge Function with curl
curl -X POST 'https://your-project.supabase.co/functions/v1/password-reset' \
  -H 'Authorization: Bearer YOUR_ANON_KEY' \
  -H 'Content-Type: application/json' \
  -d '{
    "action": "send-code",
    "email": "test-email@example.com"
  }'
```

### Step 3: Check Database for Codes
```sql
-- Check if codes are being stored
SELECT * FROM password_reset_codes 
WHERE email = 'your-test-email@example.com' 
ORDER BY created_at DESC 
LIMIT 5;
```

### Step 4: Add More Debug Logging

Update the Edge Function to add more detailed logging:

```typescript
// In the send-code action, add these logs:
console.log(`Processing email: ${email}`);

// After user existence check:
console.log(`User exists check result: ${userExists}`);

// After code generation:
console.log(`Generated code: ${verificationCode}`);

// After database insert:
console.log(`Code stored in database: ${insertError ? 'FAILED' : 'SUCCESS'}`);

// After email sending:
console.log(`Email sending result: ${emailSent ? 'SUCCESS' : 'FAILED'}`);
```

## Quick Test

### Test with a Known Working Account:
1. Try `lemuel.dionisio090502@gmail.com` again
2. Check if it still works
3. Look at the Edge Function logs

### Test with a Non-Working Account:
1. Try another email address
2. Check Edge Function logs immediately
3. Look for any error messages

## Common Issues & Fixes

### Issue: "User not found" in logs
**Solution**: The account doesn't exist. User needs to sign up first.

### Issue: Database insert fails
**Solution**: Check if the `password_reset_codes` table exists and has proper permissions.

### Issue: Email service fails
**Solution**: Check your email service configuration and rate limits.

### Issue: Edge Function times out
**Solution**: The function might be taking too long. Check for performance issues.

## Next Steps

1. **Check the Edge Function logs** for the non-working accounts
2. **Verify account existence** in Supabase Authentication
3. **Test the Edge Function directly** with curl
4. **Check the database** for stored codes

Let me know what you find in the logs and I can help you fix the specific issue! 