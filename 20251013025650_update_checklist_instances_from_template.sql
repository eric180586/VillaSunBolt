/*
  # Update Checklist Instances from Template
  
  ## Purpose
  When a checklist template is updated, this function updates all pending/in-progress
  instances of that checklist to match the new template items.
  
  ## Features
  - Updates only pending or in-progress instances
  - Preserves completed status of items that still exist
  - Adds new items from template
  - Removes items that were deleted from template
  
  ## Function
  - `update_instances_from_template(checklist_id)` - Updates all active instances
*/

-- Function to update checklist instances when template changes
CREATE OR REPLACE FUNCTION update_instances_from_template(
  p_checklist_id uuid
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_template record;
  v_instance record;
  v_updated_count integer := 0;
  v_new_items jsonb;
  v_old_items jsonb;
  v_merged_items jsonb := '[]'::jsonb;
  v_item jsonb;
  v_old_item jsonb;
  v_found boolean;
BEGIN
  -- Get the template
  SELECT * INTO v_template
  FROM checklists
  WHERE id = p_checklist_id AND is_template = true;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Template not found';
  END IF;
  
  -- Update all pending/in-progress instances
  FOR v_instance IN 
    SELECT * FROM checklist_instances
    WHERE checklist_id = p_checklist_id
    AND status IN ('pending', 'in_progress')
  LOOP
    v_merged_items := '[]'::jsonb;
    v_new_items := v_template.items;
    v_old_items := v_instance.items;
    
    -- Process each new template item
    FOR v_item IN SELECT * FROM jsonb_array_elements(v_new_items)
    LOOP
      v_found := false;
      
      -- Check if this item exists in old items (by text match)
      FOR v_old_item IN SELECT * FROM jsonb_array_elements(v_old_items)
      LOOP
        IF v_old_item->>'text' = v_item->>'text' THEN
          -- Keep the old completed status
          v_merged_items := v_merged_items || jsonb_build_array(
            jsonb_build_object(
              'id', v_old_item->>'id',
              'text', v_item->>'text',
              'is_completed', COALESCE((v_old_item->>'is_completed')::boolean, false),
              'completed', COALESCE((v_old_item->>'completed')::boolean, false)
            )
          );
          v_found := true;
          EXIT;
        END IF;
      END LOOP;
      
      -- If not found in old items, add as new uncompleted item
      IF NOT v_found THEN
        v_merged_items := v_merged_items || jsonb_build_array(
          jsonb_build_object(
            'id', v_item->>'id',
            'text', v_item->>'text',
            'is_completed', false,
            'completed', false
          )
        );
      END IF;
    END LOOP;
    
    -- Update the instance
    UPDATE checklist_instances
    SET 
      items = v_merged_items,
      updated_at = now()
    WHERE id = v_instance.id;
    
    v_updated_count := v_updated_count + 1;
  END LOOP;
  
  RETURN v_updated_count;
END;
$$;

-- Trigger to automatically update instances when template is updated
CREATE OR REPLACE FUNCTION trigger_update_instances_on_template_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Only if items changed and is a template
  IF NEW.is_template = true AND (OLD.items IS DISTINCT FROM NEW.items) THEN
    PERFORM update_instances_from_template(NEW.id);
  END IF;
  
  RETURN NEW;
END;
$$;

-- Create the trigger
DROP TRIGGER IF EXISTS update_instances_on_template_change ON checklists;
CREATE TRIGGER update_instances_on_template_change
  AFTER UPDATE ON checklists
  FOR EACH ROW
  EXECUTE FUNCTION trigger_update_instances_on_template_change();
