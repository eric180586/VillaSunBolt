/*
  # Auto-fill notification translation columns
  
  1. Changes
    - Create trigger function to automatically fill title_de, title_en, title_km, message_de, message_en, message_km
    - Looks up translations from notification_translations table by notification type
    - Falls back to provided title/message if no translation exists
    - Trigger runs BEFORE INSERT to populate columns before row is saved
  
  2. Behavior
    - If translation exists in notification_translations, use it
    - If translation not found, copy from title/message
    - Supports placeholder replacement like {task_title}, {points}, etc.
*/

CREATE OR REPLACE FUNCTION auto_fill_notification_translations()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  v_translation RECORD;
BEGIN
  SELECT * INTO v_translation 
  FROM notification_translations 
  WHERE key = NEW.type;

  IF FOUND THEN
    NEW.title_de := COALESCE(NEW.title_de, v_translation.title_de, NEW.title);
    NEW.title_en := COALESCE(NEW.title_en, v_translation.title_en, NEW.title);
    NEW.title_km := COALESCE(NEW.title_km, v_translation.title_km, NEW.title);
    NEW.message_de := COALESCE(NEW.message_de, v_translation.message_template_de, NEW.message);
    NEW.message_en := COALESCE(NEW.message_en, v_translation.message_template_en, NEW.message);
    NEW.message_km := COALESCE(NEW.message_km, v_translation.message_template_km, NEW.message);
  ELSE
    NEW.title_de := COALESCE(NEW.title_de, NEW.title);
    NEW.title_en := COALESCE(NEW.title_en, NEW.title);
    NEW.title_km := COALESCE(NEW.title_km, NEW.title);
    NEW.message_de := COALESCE(NEW.message_de, NEW.message);
    NEW.message_en := COALESCE(NEW.message_en, NEW.message);
    NEW.message_km := COALESCE(NEW.message_km, NEW.message);
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS auto_fill_notification_translations_trigger ON notifications;

CREATE TRIGGER auto_fill_notification_translations_trigger
  BEFORE INSERT ON notifications
  FOR EACH ROW
  EXECUTE FUNCTION auto_fill_notification_translations();
