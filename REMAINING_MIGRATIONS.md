# 📋 Verbleibende Migrationen für Villa Sun App

## ✅ Was bereits erfolgreich angewendet wurde (10 Migrationen):

1. ✅ create_villa_sun_schema - Basis-Schema
2. ✅ add_admin_review_fields - Task Admin-Review
3. ✅ update_checklists_structure - Checklist-Struktur
4. ✅ create_weekly_schedules_system - Wöchentliche Zeitpläne
5. ✅ add_items_to_checklists - Checklist Items
6. ✅ fix_profile_creation_trigger - Profile Trigger
7. ✅ add_departure_requests_and_read_receipts - Departure & Read Receipts
8. ✅ create_humor_modules - Humor Module (mit Gossip/TikTok)
9. ✅ create_point_templates - Punkte-Templates
10. ✅ create_checkin_system - Check-in System

**Datenbank Status:** 17 Tabellen mit RLS erfolgreich erstellt!

---

## 🔄 Noch anzuwendende Migrationen (130 verbleibend)

### 🎯 PRIORITÄT 1: Deine gewünschten Features

#### 1. Patrol Rounds System ⭐⭐⭐
**Datei:** `20251012023157_create_patrol_rounds_system.sql`

**Was es macht:**
- Patrol Locations mit QR-Codes
- Patrol Schedules (Zuweisung wer wann patrouilliert)
- Patrol Rounds (Zeitfenster für Kontrollen)
- Patrol Scans (Gescannte QR-Codes mit Fotos)
- **3 Standard-Locations:** Entrance, Pool, Staircase

**Anwendung via Supabase Dashboard:**
```sql
-- Kopiere den Inhalt aus der Datei und führe ihn im SQL Editor aus
```

---

#### 2. Shopping List System ⭐⭐⭐
**Datei:** `20251012015837_create_shopping_list_table.sql`

**Was es macht:**
- Shopping Items Liste
- Jeder kann Items hinzufügen
- Items als "gekauft" markieren
- Fotos von Items hochladen

**SQL:**
```sql
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
  ON shopping_items FOR SELECT TO authenticated USING (true);

CREATE POLICY "Anyone authenticated can add shopping items"
  ON shopping_items FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = created_by);

CREATE POLICY "Anyone authenticated can update shopping items"
  ON shopping_items FOR UPDATE TO authenticated
  USING (true) WITH CHECK (true);

CREATE POLICY "Admins can delete shopping items"
  ON shopping_items FOR DELETE TO authenticated
  USING (EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = 'admin'));

CREATE INDEX IF NOT EXISTS idx_shopping_items_purchased ON shopping_items(is_purchased);
CREATE INDEX IF NOT EXISTS idx_shopping_items_created_at ON shopping_items(created_at DESC);
```

---

#### 3. Notes Admin Permissions ⭐⭐
**Datei:** `20251012014059_update_notes_admin_permissions.sql`

**Was es macht:**
- Admins können alle Notizen bearbeiten/löschen
- User können nur ihre eigenen Notizen bearbeiten

**SQL:**
```sql
DROP POLICY IF EXISTS "Users can delete their notes" ON notes;
DROP POLICY IF EXISTS "Users can update their notes" ON notes;

CREATE POLICY "Users and admins can delete notes"
  ON notes FOR DELETE TO authenticated
  USING (
    auth.uid() = created_by OR
    EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = 'admin')
  );

CREATE POLICY "Users and admins can update notes"
  ON notes FOR UPDATE TO authenticated
  USING (
    auth.uid() = created_by OR
    EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = 'admin')
  )
  WITH CHECK (
    auth.uid() = created_by OR
    EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = 'admin')
  );
```

---

#### 4. How-To Documents System ⭐⭐⭐
**Datei:** `20251012231815_create_how_to_documents_system.sql`

**Features:**
- How-To Dokumente mit Steps
- Kategorien (cleaning, maintenance, reception, etc.)
- Sortierung und Favoriten

Prüfe die Datei für vollständiges SQL.

---

### 🎯 PRIORITÄT 2: Punktesystem-Optimierungen

Das Punktesystem hat **26 aufeinanderfolgende Fixes**. Die **wichtigste** ist:

**Datei:** `20251017120000_FINAL_APPROVED_points_calculation_system.sql`

Diese Migration ist **531 Zeilen** und enthält das komplette, finale Punktesystem mit:
- Erreichbare Punkte Berechnung
- Team Punkte
- Check-in Integration
- Deadline Boni
- Penalties

**⚠️ Wichtig:** Diese Migration muss **nach** allen anderen Check-in/Task/Checklist Migrationen angewendet werden!

---

### 🎯 PRIORITÄT 3: Nice-to-Have Features

- **Fortune Wheel System** (`20251013003610_create_fortune_wheel_system.sql`)
- **Team Chat System** (`20251012233216_create_team_chat_system.sql`)
- **Tutorial Slides System** (`20251017140000_create_tutorial_slides_system.sql`)
- **Room Cleaning Tutorial** (`20251018140000_create_complete_room_cleaning_tutorial.sql`)
- **Quiz Highscores** (`20251015001121_add_quiz_highscores_table.sql`)

---

## 🚀 Empfohlene Vorgehensweise

### Option A: Schnell-Start (Minimal, ~30 Min)

Wende NUR diese 4 Migrationen an:
1. ✅ Patrol Rounds System
2. ✅ Shopping List
3. ✅ Notes Admin Permissions
4. ✅ How-To Documents

**Dann:** App deployen und testen!

---

### Option B: Vollständig (~2-3 Stunden)

1. Wende alle Migrations-Dateien in chronologischer Reihenfolge an
2. Nutze Supabase Dashboard SQL Editor
3. Kopiere jede Datei einzeln und führe sie aus
4. Prüfe nach jeder Migration auf Fehler

---

### Option C: Automatisch (mit Supabase CLI)

```bash
# Installiere Supabase CLI
npm install -g supabase

# Link zu deinem Projekt
supabase link --project-ref YOUR_PROJECT_REF

# Wende alle Migrationen an
supabase db push
```

---

## 📊 Aktueller Stand

**✅ Funktioniert bereits:**
- User Management & Auth
- Task System mit Admin Review
- Checklist System
- Check-in System mit Punkten
- Weekly Schedules
- Departure Requests
- Humor Modules
- Point Templates
- Notifications

**⏳ Fehlt noch:**
- Patrol Rounds (Priorität 1)
- Shopping List (Priorität 1)
- Notes Admin Permissions (Priorität 2)
- How-To Documents (Priorität 2)
- Komplettes Punktesystem (130 weitere Migrationen)

---

## 💡 Tipp

**Für deine 4 gewünschten Features (Patrol, Shopping, Notes, How-To):**

Du kannst die 4 SQL-Dateien auch zu **einer großen Datei kombinieren** und in einem Durchlauf im Supabase Dashboard ausführen:

1. Öffne Supabase Dashboard → SQL Editor
2. Erstelle neues Query
3. Kopiere nacheinander:
   - Patrol Rounds SQL
   - Shopping List SQL
   - Notes Permissions SQL
   - How-To SQL
4. Führe alles auf einmal aus
5. Fertig! ✅

---

## ❓ Fragen?

Sag mir Bescheid was du als Nächstes brauchst:
- Soll ich die 4 Priority-Migrations zu einer Datei kombinieren?
- Brauchst du Hilfe beim Anwenden?
- Sollen wir direkt zum Deployment übergehen?
