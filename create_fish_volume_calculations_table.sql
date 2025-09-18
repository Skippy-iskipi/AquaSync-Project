-- Create fish_volume_calculations table
CREATE TABLE IF NOT EXISTS fish_volume_calculations (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    tank_shape TEXT NOT NULL,
    tank_volume TEXT NOT NULL,
    fish_selections JSONB NOT NULL,
    recommended_quantities JSONB NOT NULL,
    tankmate_recommendations JSONB,
    water_requirements JSONB NOT NULL,
    feeding_information JSONB NOT NULL,
    date_calculated TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create index on user_id for better query performance
CREATE INDEX IF NOT EXISTS idx_fish_volume_calculations_user_id ON fish_volume_calculations(user_id);

-- Create index on date_calculated for sorting
CREATE INDEX IF NOT EXISTS idx_fish_volume_calculations_date_calculated ON fish_volume_calculations(date_calculated DESC);

-- Enable RLS (Row Level Security)
ALTER TABLE fish_volume_calculations ENABLE ROW LEVEL SECURITY;

-- Create RLS policy to allow users to only access their own data
CREATE POLICY "Users can view their own fish volume calculations" ON fish_volume_calculations
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own fish volume calculations" ON fish_volume_calculations
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own fish volume calculations" ON fish_volume_calculations
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own fish volume calculations" ON fish_volume_calculations
    FOR DELETE USING (auth.uid() = user_id);

-- Add comments for documentation
COMMENT ON TABLE fish_volume_calculations IS 'Stores fish volume calculator results including tank shape, volume, fish selections, recommendations, and requirements';
COMMENT ON COLUMN fish_volume_calculations.tank_shape IS 'Selected tank shape (bowl, rectangle, cylinder)';
COMMENT ON COLUMN fish_volume_calculations.tank_volume IS 'Calculated tank volume in liters';
COMMENT ON COLUMN fish_volume_calculations.fish_selections IS 'JSON object of selected fish and quantities';
COMMENT ON COLUMN fish_volume_calculations.recommended_quantities IS 'JSON object of recommended fish quantities';
COMMENT ON COLUMN fish_volume_calculations.tankmate_recommendations IS 'JSON array of recommended tankmates';
COMMENT ON COLUMN fish_volume_calculations.water_requirements IS 'JSON object containing temperature and pH ranges';
COMMENT ON COLUMN fish_volume_calculations.feeding_information IS 'JSON object containing feeding details per fish';
