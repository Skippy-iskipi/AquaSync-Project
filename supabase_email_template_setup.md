# Setting Up Custom Email Template in Supabase

Follow these steps to set up a custom email template that displays a verification code instead of a magic link:

1. Go to your Supabase Dashboard
2. Navigate to Authentication > Email Templates
3. Click on "Reset Password"
4. Replace the default template with the following:

## Subject Line
```
Reset Your Password - AquaSync
```

## Custom HTML Template
```html
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Reset Your Password - AquaSync</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 600px;
            margin: 0 auto;
            padding: 20px;
            background-color: #f4f4f4;
        }
        .container {
            background-color: #ffffff;
            padding: 30px;
            border-radius: 10px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        .header {
            text-align: center;
            margin-bottom: 30px;
        }
        .logo {
            font-size: 24px;
            font-weight: bold;
            color: #00ACC1;
            margin-bottom: 10px;
        }
        .code-container {
            text-align: center;
            margin: 30px 0;
            padding: 20px;
            background-color: #f8f9fa;
            border-radius: 8px;
        }
        .verification-code {
            font-size: 32px;
            font-weight: bold;
            letter-spacing: 4px;
            color: #00ACC1;
        }
        .instructions {
            background-color: #f8f9fa;
            padding: 20px;
            border-radius: 8px;
            margin: 20px 0;
        }
        .footer {
            text-align: center;
            margin-top: 30px;
            color: #666;
            font-size: 12px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="logo">AquaSync</div>
            <h2>Reset Your Password</h2>
        </div>
        
        <p>Hello!</p>
        
        <p>You requested to reset your password for your AquaSync account. Use the verification code below to complete the password reset:</p>
        
        <div class="code-container">
            <p>Your verification code is:</p>
            <div class="verification-code">{{ .Token }}</div>
            <p>Enter this code in the AquaSync app to reset your password.</p>
        </div>
        
        <div class="instructions">
            <strong>What happens next?</strong>
            <p>In the AquaSync app:</p>
            <ol>
                <li>Enter the verification code shown above</li>
                <li>Enter your new password</li>
                <li>Confirm your new password</li>
                <li>Click "Update Password" to complete the process</li>
            </ol>
        </div>
        
        <p><strong>Important:</strong></p>
        <ul>
            <li>This code will expire in 1 hour</li>
            <li>If you didn't request this password reset, please ignore this email</li>
            <li>For security reasons, never share this code with anyone</li>
        </ul>
        
        <p>If you have any questions, please contact our support team.</p>
        
        <div class="footer">
            <p>This email was sent from AquaSync. Please do not reply to this email.</p>
            <p>© 2024 AquaSync. All rights reserved.</p>
        </div>
    </div>
</body>
</html>
```

5. Click "Save"

## Important Notes:
- The `{{ .Token }}` variable will be replaced with the actual verification code
- The template uses responsive design and should look good on both desktop and mobile
- The code is displayed prominently in a larger font with letter spacing for readability
- The email includes clear instructions for using the code
- Security warnings are included to prevent code sharing

## Testing:
1. After saving the template, try the "Reset Password" flow in your app
2. You should receive an email with a verification code instead of a magic link
3. The code should be clearly visible and match the format shown in the template
4. Verify that the code works when entered in the app 