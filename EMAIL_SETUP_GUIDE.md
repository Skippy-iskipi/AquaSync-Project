# Email Service Setup Guide for Password Reset

## Option 1: Resend (Recommended)

1. **Sign up for Resend**:
   - Go to [resend.com](https://resend.com)
   - Create a free account
   - Verify your domain or use their test domain

2. **Get your API key**:
   - Go to API Keys in your Resend dashboard
   - Copy your API key

3. **Set up environment variable**:
   ```bash
   # In your Supabase project dashboard
   # Go to Settings > Edge Functions > Environment Variables
   # Add: RESEND_API_KEY = your_api_key_here
   ```

4. **Update the Edge Function**:
   - Replace `noreply@yourdomain.com` with your verified domain
   - Or use `onboarding@resend.dev` for testing

## Option 2: SendGrid

1. **Sign up for SendGrid**:
   - Go to [sendgrid.com](https://sendgrid.com)
   - Create a free account (100 emails/day)

2. **Get your API key**:
   - Go to Settings > API Keys
   - Create a new API key with "Mail Send" permissions

3. **Update the Edge Function**:
   Replace the `sendVerificationEmail` function with:

```typescript
async function sendVerificationEmail(email: string, code: string): Promise<void> {
  const SENDGRID_API_KEY = Deno.env.get('SENDGRID_API_KEY')
  
  if (!SENDGRID_API_KEY) {
    console.log(`No SendGrid API key found. Verification code for ${email}: ${code}`)
    return
  }

  const emailData = {
    personalizations: [{
      to: [{ email: email }]
    }],
    from: { email: 'noreply@yourdomain.com' },
    subject: 'AquaSync - Password Reset Verification Code',
    content: [{
      type: 'text/html',
      value: `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
          <h2 style="color: #006064;">AquaSync Password Reset</h2>
          <p>Your verification code is: <strong>${code}</strong></p>
          <p>Enter this code in the AquaSync app to complete your password reset.</p>
          <p><strong>This code expires in 10 minutes.</strong></p>
        </div>
      `
    }]
  }

  try {
    const response = await fetch('https://api.sendgrid.com/v3/mail/send', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${SENDGRID_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(emailData),
    })

    if (!response.ok) {
      throw new Error(`SendGrid API error: ${response.statusText}`)
    }

    console.log(`Verification email sent successfully to ${email}`)
  } catch (error) {
    console.error(`Failed to send email via SendGrid: ${error.message}`)
    console.log(`FALLBACK - Verification code for ${email}: ${code}`)
  }
}
```

## Option 3: Mailgun

1. **Sign up for Mailgun**:
   - Go to [mailgun.com](https://mailgun.com)
   - Create a free account

2. **Get your API key**:
   - Go to Settings > API Keys
   - Copy your API key

3. **Update the Edge Function**:
   Replace the `sendVerificationEmail` function with:

```typescript
async function sendVerificationEmail(email: string, code: string): Promise<void> {
  const MAILGUN_API_KEY = Deno.env.get('MAILGUN_API_KEY')
  const MAILGUN_DOMAIN = Deno.env.get('MAILGUN_DOMAIN')
  
  if (!MAILGUN_API_KEY || !MAILGUN_DOMAIN) {
    console.log(`No Mailgun credentials found. Verification code for ${email}: ${code}`)
    return
  }

  const formData = new FormData()
  formData.append('from', `noreply@${MAILGUN_DOMAIN}`)
  formData.append('to', email)
  formData.append('subject', 'AquaSync - Password Reset Verification Code')
  formData.append('html', `
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
      <h2 style="color: #006064;">AquaSync Password Reset</h2>
      <p>Your verification code is: <strong>${code}</strong></p>
      <p>Enter this code in the AquaSync app to complete your password reset.</p>
      <p><strong>This code expires in 10 minutes.</strong></p>
    </div>
  `)

  try {
    const response = await fetch(`https://api.mailgun.net/v3/${MAILGUN_DOMAIN}/messages`, {
      method: 'POST',
      headers: {
        'Authorization': `Basic ${btoa(`api:${MAILGUN_API_KEY}`)}`,
      },
      body: formData,
    })

    if (!response.ok) {
      throw new Error(`Mailgun API error: ${response.statusText}`)
    }

    console.log(`Verification email sent successfully to ${email}`)
  } catch (error) {
    console.error(`Failed to send email via Mailgun: ${error.message}`)
    console.log(`FALLBACK - Verification code for ${email}: ${code}`)
  }
}
```

## Testing Without Email Service

If you don't want to set up an email service right now, the Edge Function will:
1. Log the verification code to the console
2. Return the code in the response for testing
3. You can see the code in your Supabase Edge Function logs

## Deployment

After setting up your email service:

1. **Deploy the Edge Function**:
   ```bash
   npx supabase@latest functions deploy password-reset
   ```

2. **Test the flow**:
   - The verification code will be logged in the Edge Function console
   - You can also see it in the Flutter app console
   - Use this code to test the verification flow

## Production Considerations

1. **Remove the code from the response** in production
2. **Set up proper email templates** with your branding
3. **Implement rate limiting** to prevent abuse
4. **Add email validation** and spam protection
5. **Monitor email delivery** and bounce rates 