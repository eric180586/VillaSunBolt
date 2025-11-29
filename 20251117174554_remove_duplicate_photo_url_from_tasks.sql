/*
  # Remove Duplicate photo_url Column from tasks
  
  1. Changes
    - Remove photo_url (single text) column
    - Keep photo_urls (jsonb array) column
    - Frontend doesn't use photo_url for tasks
*/

ALTER TABLE tasks
DROP COLUMN IF EXISTS photo_url;
