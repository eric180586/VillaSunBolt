/*
  # Fix notification translations to preserve original content
  
  1. Problem
    - Generic templates like "{message}" overwrite actual notification content
    - We need to preserve the original messages while translating titles
  
  2. Solution
    - Only translate titles with notification_translations
    - Keep original messages as they contain specific information
    - For types without specific translations, copy original title
*/

-- Clear the bad backfill
UPDATE notifications
SET 
  title_de = title,
  title_en = title,
  title_km = title,
  message_de = message,
  message_en = message,
  message_km = message;

-- Now apply translations ONLY to titles, preserve messages
UPDATE notifications n
SET 
  title_de = COALESCE(nt.title_de, n.title),
  title_en = COALESCE(nt.title_en, n.title),
  title_km = COALESCE(nt.title_km, n.title)
FROM notification_translations nt
WHERE nt.key = n.type;

-- For messages, we keep the original since they contain specific data
-- The message templates in notification_translations are only for NEW notifications
-- that need placeholder replacement
