/*
  # Fix patrol rounds automatic generation from weekly_schedules
  
  The system was using patrol_schedules (old) but now uses weekly_schedules.
  This migration creates a function to generate patrol rounds from weekly_schedules.
  
  1. Function: generate_patrol_rounds_for_date
     - Takes a date parameter
     - Finds all staff with late shift on that date from weekly_schedules
     - Creates 5 patrol rounds per staff (16:00, 17:15, 18:30, 19:45, 21:00)
  
  2. This can be called manually or scheduled via cron
*/

CREATE OR REPLACE FUNCTION generate_patrol_rounds_for_date(p_date date DEFAULT CURRENT_DATE)
RETURNS TABLE(created_count integer, staff_name text) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_schedule record;
  v_shift_info jsonb;
  v_rounds_created integer := 0;
BEGIN
  -- Loop through all published weekly schedules
  FOR v_schedule IN 
    SELECT ws.staff_id, ws.shifts, p.full_name
    FROM weekly_schedules ws
    LEFT JOIN profiles p ON ws.staff_id = p.id
    WHERE ws.is_published = true
  LOOP
    -- Find the shift for the given date in the shifts array
    SELECT shift_data INTO v_shift_info
    FROM jsonb_array_elements(v_schedule.shifts) AS shift_data
    WHERE shift_data->>'date' = p_date::text;
    
    -- If staff has late shift on this date, create patrol rounds
    IF v_shift_info IS NOT NULL AND v_shift_info->>'shift' = 'late' THEN
      -- Insert 5 patrol rounds for late shift
      INSERT INTO patrol_rounds (date, time_slot, assigned_to, scheduled_time, notification_sent, points_calculated)
      VALUES 
        (p_date, '16:00:00', v_schedule.staff_id, (p_date::text || ' 16:00:00+07')::timestamptz, false, false),
        (p_date, '17:15:00', v_schedule.staff_id, (p_date::text || ' 17:15:00+07')::timestamptz, false, false),
        (p_date, '18:30:00', v_schedule.staff_id, (p_date::text || ' 18:30:00+07')::timestamptz, false, false),
        (p_date, '19:45:00', v_schedule.staff_id, (p_date::text || ' 19:45:00+07')::timestamptz, false, false),
        (p_date, '21:00:00', v_schedule.staff_id, (p_date::text || ' 21:00:00+07')::timestamptz, false, false)
      ON CONFLICT (assigned_to, date, time_slot) DO NOTHING;
      
      v_rounds_created := v_rounds_created + 5;
      
      RETURN QUERY SELECT v_rounds_created, v_schedule.full_name;
    END IF;
  END LOOP;
  
  -- If no rounds created, return 0
  IF v_rounds_created = 0 THEN
    RETURN QUERY SELECT 0::integer, 'No late shifts found'::text;
  END IF;
END;
$$;

-- Add unique constraint to prevent duplicate patrol rounds
ALTER TABLE patrol_rounds DROP CONSTRAINT IF EXISTS patrol_rounds_unique_assignment;
ALTER TABLE patrol_rounds ADD CONSTRAINT patrol_rounds_unique_assignment 
  UNIQUE (assigned_to, date, time_slot);

COMMENT ON FUNCTION generate_patrol_rounds_for_date IS 
'Generates patrol rounds for staff with late shift on the given date from weekly_schedules. 
Call daily via cron or manually: SELECT * FROM generate_patrol_rounds_for_date(CURRENT_DATE);';
