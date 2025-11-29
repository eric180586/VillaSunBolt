/*
  # Fix Chat Photos Bucket to be Public

  1. Problem
    - chat-photos bucket is private but uses getPublicUrl()
    - This causes photos to not be visible in chat
    
  2. Solution
    - Make bucket public so getPublicUrl() works
    - Keep RLS policies for security
*/

-- Make chat-photos bucket public
UPDATE storage.buckets
SET public = true
WHERE name = 'chat-photos';
