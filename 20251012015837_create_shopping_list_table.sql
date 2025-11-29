/*
  # Create Shopping List System
  
  1. New Tables
    - `shopping_items`
      - `id` (uuid, primary key)
      - `item_name` (text) - Name of the item needed
      - `description` (text, optional) - Additional details
      - `photo_url` (text, optional) - Photo of the item/location
      - `is_purchased` (boolean) - Whether item has been bought
      - `created_by` (uuid) - User who added the item
      - `purchased_by` (uuid, optional) - User who bought it
      - `created_at` (timestamptz)
      - `purchased_at` (timestamptz, optional)
  
  2. Security
    - Enable RLS on `shopping_items` table
    - All authenticated users can view items
    - All authenticated users can add items
    - All authenticated users can mark items as purchased
    - Admins can delete items
*/

CREATE TABLE IF NOT EXISTS shopping_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  item_name text NOT NULL,
  description text,
  photo_url text,
  is_purchased boolean DEFAULT false,
  created_by uuid REFERENCES profiles(id) ON DELETE SET NULL,
  purchased_by uuid REFERENCES profiles(id) ON DELETE SET NULL,
  created_at timestamptz DEFAULT now(),
  purchased_at timestamptz
);

ALTER TABLE shopping_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone authenticated can view shopping items"
  ON shopping_items
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Anyone authenticated can add shopping items"
  ON shopping_items
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = created_by);

CREATE POLICY "Anyone authenticated can update shopping items"
  ON shopping_items
  FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Admins can delete shopping items"
  ON shopping_items
  FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

CREATE INDEX IF NOT EXISTS idx_shopping_items_purchased ON shopping_items(is_purchased);
CREATE INDEX IF NOT EXISTS idx_shopping_items_created_at ON shopping_items(created_at DESC);
