/*
  # Auto-Generate Checklist Instances on Template Creation
  
  ## Changes:
  1. Creates a trigger that automatically generates the first instance when a new checklist template is created
  2. Only generates instances for templates with recurrence (not 'one_time')
  3. Generates for current date to make them immediately visible
*/

-- Function to auto-generate instance on template creation
CREATE OR REPLACE FUNCTION auto_generate_first_instance()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Only generate if it's a template and not one_time
  IF NEW.is_template = true AND NEW.recurrence != 'one_time' THEN
    -- Generate instance for today
    PERFORM generate_checklist_instance(NEW.id, CURRENT_DATE);
  END IF;
  
  RETURN NEW;
END;
$$;

-- Create trigger
DROP TRIGGER IF EXISTS trigger_auto_generate_first_instance ON checklists;
CREATE TRIGGER trigger_auto_generate_first_instance
  AFTER INSERT ON checklists
  FOR EACH ROW
  EXECUTE FUNCTION auto_generate_first_instance();
