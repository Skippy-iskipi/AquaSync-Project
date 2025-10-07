-- Function to archive a water calculation
CREATE OR REPLACE FUNCTION archive_water_calculation(calculation_id uuid)
RETURNS SETOF water_calculations
LANGUAGE plpgsql
SECURITY definer
AS $$
BEGIN
    RETURN QUERY
    UPDATE water_calculations
    SET archived = true,
        archived_at = NOW()
    WHERE id = calculation_id
    AND user_id = auth.uid()
    RETURNING *;
END;
$$;