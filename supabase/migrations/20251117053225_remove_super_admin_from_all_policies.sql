/*
  # Remove super_admin role from all RLS policies
  
  1. Changes
    - Update all policies that check for 'super_admin' role
    - Replace ARRAY['admin', 'super_admin'] with just 'admin'
    - This role no longer exists in the system
  
  2. Security
    - All admin functions now only check for 'admin' role
    - No functionality is lost as super_admin was removed from the system
*/

-- Function to update all policies
DO $$
DECLARE
  policy_record RECORD;
  new_qual TEXT;
  new_with_check TEXT;
BEGIN
  FOR policy_record IN 
    SELECT schemaname, tablename, policyname, qual, with_check
    FROM pg_policies 
    WHERE with_check LIKE '%super_admin%' OR qual LIKE '%super_admin%'
  LOOP
    -- Drop existing policy
    EXECUTE format('DROP POLICY IF EXISTS %I ON %I.%I', 
      policy_record.policyname, 
      policy_record.schemaname, 
      policy_record.tablename
    );
    
    -- Prepare new qual and with_check (replace super_admin references)
    new_qual := REPLACE(
      REPLACE(policy_record.qual, 
        'ARRAY[''admin''::text, ''super_admin''::text]', 
        'ARRAY[''admin''::text]'
      ),
      '''super_admin''::text',
      '''admin''::text'
    );
    
    new_with_check := REPLACE(
      REPLACE(policy_record.with_check, 
        'ARRAY[''admin''::text, ''super_admin''::text]', 
        'ARRAY[''admin''::text]'
      ),
      '''super_admin''::text',
      '''admin''::text'
    );
    
    -- Recreate policy with updated conditions
    IF policy_record.qual IS NOT NULL AND policy_record.with_check IS NOT NULL THEN
      EXECUTE format('CREATE POLICY %I ON %I.%I FOR ALL TO authenticated USING (%s) WITH CHECK (%s)',
        policy_record.policyname,
        policy_record.schemaname,
        policy_record.tablename,
        new_qual,
        new_with_check
      );
    ELSIF policy_record.qual IS NOT NULL THEN
      EXECUTE format('CREATE POLICY %I ON %I.%I FOR ALL TO authenticated USING (%s)',
        policy_record.policyname,
        policy_record.schemaname,
        policy_record.tablename,
        new_qual
      );
    ELSIF policy_record.with_check IS NOT NULL THEN
      EXECUTE format('CREATE POLICY %I ON %I.%I FOR ALL TO authenticated WITH CHECK (%s)',
        policy_record.policyname,
        policy_record.schemaname,
        policy_record.tablename,
        new_with_check
      );
    END IF;
  END LOOP;
END $$;
