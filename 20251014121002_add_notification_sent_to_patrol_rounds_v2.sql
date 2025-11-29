/*
  # Add notification tracking to patrol rounds
  
  ## Changes:
  1. Add notification_sent boolean to patrol_rounds
  2. Add scheduled_time column (combination of date + time_slot)
  3. This prevents duplicate notifications for the same patrol
*/

-- Add notification_sent column to patrol_rounds
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'patrol_rounds' 
    AND column_name = 'notification_sent'
  ) THEN
    ALTER TABLE patrol_rounds 
    ADD COLUMN notification_sent boolean DEFAULT false;
  END IF;
  
  -- Add scheduled_time for easier querying
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'patrol_rounds' 
    AND column_name = 'scheduled_time'
  ) THEN
    ALTER TABLE patrol_rounds 
    ADD COLUMN scheduled_time timestamptz;
    
    -- Update existing records to set scheduled_time from date + time_slot
    UPDATE patrol_rounds
    SET scheduled_time = date + time_slot::time
    WHERE scheduled_time IS NULL;
  END IF;
END $$;

-- Create index for efficient querying
CREATE INDEX IF NOT EXISTS idx_patrol_notification_pending 
ON patrol_rounds(scheduled_time, notification_sent) 
WHERE completed_at IS NULL AND notification_sent = false;