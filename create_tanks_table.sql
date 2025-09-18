-- Create tanks table
CREATE TABLE IF NOT EXISTS tanks (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  tank_shape TEXT NOT NULL DEFAULT 'rectangle',
  length DECIMAL(10,2) NOT NULL,
  width DECIMAL(10,2) NOT NULL,
  height DECIMAL(10,2) NOT NULL,
  unit TEXT NOT NULL DEFAULT 'CM',
  volume DECIMAL(10,2) NOT NULL,
  fish_selections JSONB DEFAULT '{}',
  compatibility_results JSONB DEFAULT '{}',
  feeding_recommendations JSONB DEFAULT '{}',
  recommended_fish_quantities JSONB DEFAULT '{}',
  available_feeds JSONB DEFAULT '{}',
  feed_inventory JSONB DEFAULT '{}',
  feed_portion_data JSONB DEFAULT '{}',
  date_created TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  last_updated TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_tanks_user_id ON tanks(user_id);
CREATE INDEX IF NOT EXISTS idx_tanks_created_at ON tanks(created_at DESC);

-- Enable Row Level Security
ALTER TABLE tanks ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
CREATE POLICY "Users can view their own tanks" ON tanks
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own tanks" ON tanks
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own tanks" ON tanks
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own tanks" ON tanks
  FOR DELETE USING (auth.uid() = user_id);

-- Create function to automatically update last_updated timestamp
CREATE OR REPLACE FUNCTION update_tanks_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.last_updated = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to automatically update last_updated
CREATE TRIGGER update_tanks_updated_at_trigger
  BEFORE UPDATE ON tanks
  FOR EACH ROW
  EXECUTE FUNCTION update_tanks_updated_at();
