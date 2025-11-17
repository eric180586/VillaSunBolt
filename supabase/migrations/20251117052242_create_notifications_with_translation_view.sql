/*
  # Create notifications view with automatic translation
  
  1. Changes
    - Create view that automatically returns notifications in user's preferred language
    - Selects correct title/message column based on user's preferred_language
    - Falls back to German if preferred language is not set
  
  2. Security
    - View inherits RLS from base notifications table
    - Users can only see their own notifications
*/

CREATE OR REPLACE VIEW notifications_translated AS
SELECT 
  n.id,
  n.user_id,
  n.type,
  n.link,
  n.created_at,
  n.is_read,
  COALESCE(
    CASE p.preferred_language
      WHEN 'de' THEN n.title_de
      WHEN 'en' THEN n.title_en
      WHEN 'km' THEN n.title_km
      ELSE n.title_de
    END,
    n.title
  ) as title,
  COALESCE(
    CASE p.preferred_language
      WHEN 'de' THEN n.message_de
      WHEN 'en' THEN n.message_en
      WHEN 'km' THEN n.message_km
      ELSE n.message_de
    END,
    n.message
  ) as message,
  p.preferred_language
FROM notifications n
JOIN profiles p ON p.id = n.user_id;

GRANT SELECT ON notifications_translated TO authenticated;
