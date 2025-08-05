# AquaSync Verification Code System - Deployment Guide

## 🎯 **Step 1: Create the Database Table**

1. **Open your Supabase Dashboard**
2. **Go to SQL Editor**
3. **Run the SQL script** from `create_verification_codes_table.sql`

```sql
-- Copy and paste the entire content from create_verification_codes_table.sql
```

## 🎯 **Step 2: Deploy the Edge Function (Optional)**

For proper email sending with verification codes:

1. **Install Supabase CLI** (if not already installed):
   ```bash
   npm install -g supabase
   ```

2. **Login to Supabase**:
   ```bash
   supabase login
   ```

3. **Link your project**:
   ```bash
   supabase link --project-ref YOUR_PROJECT_REF
   ```

4. **Deploy the Edge Function**:
   ```bash
   supabase functions deploy send-verification-email
   ```

5. **Update the AuthService** to use the Edge Function:
   - Uncomment the Edge Function call in `lib/services/auth_service.dart`
   - Comment out the simulation code

## 🎯 **Step 3: Test the System**

1. **Rebuild your Flutter app**
2. **Test the password reset flow**:
   - Click "Forgot Password?"
   - Enter email and new password
   - Click "Send Verification Code"
   - Check console for the verification code
   - Enter the code and verify

## 🎯 **Current Status**

✅ **Database Table**: Ready to create  
✅ **Flutter UI**: Complete and working  
✅ **Code Generation**: Working  
✅ **Code Storage**: Using database  
✅ **Code Verification**: Working  
⚠️ **Email Sending**: Currently simulated (needs Edge Function)  

## 🎯 **Next Steps**

1. **Create the database table** using the SQL script
2. **Test the current implementation** (codes will be shown in console)
3. **Deploy Edge Function** for proper email sending
4. **Update AuthService** to use real email sending

## 🎯 **Troubleshooting**

### **Database Connection Issues**
- Check your Supabase URL and API keys
- Ensure RLS policies are correctly set

### **Code Verification Fails**
- Check if the verification_codes table exists
- Verify the code format (6 digits)
- Check expiration times

### **Email Not Received**
- Edge Function needs to be deployed
- Check Supabase email settings
- Verify email address format 