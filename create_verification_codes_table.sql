-- Create verification_codes table for email verification codes
CREATE TABLE IF NOT EXISTS verification_codes (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    email VARCHAR(255) NOT NULL,
    code VARCHAR(6) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    is_verified BOOLEAN DEFAULT FALSE,
    is_used BOOLEAN DEFAULT FALSE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_verification_codes_email ON verification_codes(email);
CREATE INDEX IF NOT EXISTS idx_verification_codes_code ON verification_codes(code);
CREATE INDEX IF NOT EXISTS idx_verification_codes_expires_at ON verification_codes(expires_at);
CREATE INDEX IF NOT EXISTS idx_verification_codes_user_id ON verification_codes(user_id);

-- Create a function to clean up expired codes (optional)
CREATE OR REPLACE FUNCTION cleanup_expired_verification_codes()
RETURNS void AS $$
BEGIN
    DELETE FROM verification_codes 
    WHERE expires_at < NOW() OR is_used = TRUE;
END;
$$ LANGUAGE plpgsql;

-- Create a trigger to automatically clean up expired codes (optional)
-- You can run this manually or set up a cron job
-- SELECT cleanup_expired_verification_codes();

-- Row Level Security (RLS) policies
ALTER TABLE verification_codes ENABLE ROW LEVEL SECURITY;

-- Policy to allow users to insert their own verification codes
CREATE POLICY "Users can insert their own verification codes" ON verification_codes
    FOR INSERT WITH CHECK (email = auth.jwt() ->> 'email');

-- Policy to allow users to read their own verification codes
CREATE POLICY "Users can read their own verification codes" ON verification_codes
    FOR SELECT USING (email = auth.jwt() ->> 'email');

-- Policy to allow users to update their own verification codes
CREATE POLICY "Users can update their own verification codes" ON verification_codes
    FOR UPDATE USING (email = auth.jwt() ->> 'email');

-- For password reset, we might need to allow access without authentication
-- This is a more permissive policy for password reset scenarios
CREATE POLICY "Allow verification code access for password reset" ON verification_codes
    FOR ALL USING (true);

-- Comments for documentation
COMMENT ON TABLE verification_codes IS 'Stores email verification codes for password reset and other verification purposes';
COMMENT ON COLUMN verification_codes.email IS 'The email address the verification code was sent to';
COMMENT ON COLUMN verification_codes.code IS 'The 6-digit verification code';
COMMENT ON COLUMN verification_codes.expires_at IS 'When the code expires (typically 10 minutes after creation)';
COMMENT ON COLUMN verification_codes.is_verified IS 'Whether the code has been verified';
COMMENT ON COLUMN verification_codes.is_used IS 'Whether the code has been used (for one-time use)';
COMMENT ON COLUMN verification_codes.user_id IS 'Reference to the user (if they exist in auth.users)'; 