-- Create diet_calculations table
CREATE TABLE IF NOT EXISTS diet_calculations (
    id SERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    fish_selections JSONB NOT NULL,
    total_portion INTEGER NOT NULL,
    portion_details JSONB NOT NULL,
    compatibility_issues TEXT[],
    feeding_notes TEXT,
    date_calculated TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    saved_plan VARCHAR(20) DEFAULT 'free',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add RLS policies
ALTER TABLE diet_calculations ENABLE ROW LEVEL SECURITY;

-- Policy to allow users to read their own calculations
CREATE POLICY "Users can view own diet calculations" ON diet_calculations
    FOR SELECT USING (auth.uid() = user_id);

-- Policy to allow users to insert their own calculations
CREATE POLICY "Users can insert own diet calculations" ON diet_calculations
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Policy to allow users to update their own calculations
CREATE POLICY "Users can update own diet calculations" ON diet_calculations
    FOR UPDATE USING (auth.uid() = user_id);

-- Policy to allow users to delete their own calculations
CREATE POLICY "Users can delete own diet calculations" ON diet_calculations
    FOR DELETE USING (auth.uid() = user_id);
