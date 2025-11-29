/*
  # Prevent Duplicate Departure Requests

  1. Add unique constraint
    - Ensure only one pending departure request per user per day
    - Allows multiple if they are processed (approved/rejected)
    
  2. Create partial unique index
    - Only applies to pending requests
    - Users can create new request after previous one is processed
*/

-- Create partial unique index to prevent duplicate pending requests
CREATE UNIQUE INDEX IF NOT EXISTS unique_pending_departure_per_user_per_day
ON departure_requests (user_id, shift_date)
WHERE status = 'pending';