# 📊 Villa Sun Punktesystem - Vollständige Dokumentation

## 🎯 Übersicht

Das Punktesystem trackt die Leistung der Mitarbeiter basierend auf:
- Check-ins (Pünktlichkeit)
- Erledigte Tasks
- Patrol Rounds (Rundgänge)
- Checklist Completion
- Bonus Points (Glücksrad, Admin-Boni)
- Penalties (Verspätungen, Task Reopen, etc.)

---

## 📋 Datenbank-Struktur

### 1. **`points_history`** - Die Source of Truth
Jede Punkteänderung wird hier gespeichert. Wird NIEMALS gelöscht!

**Wichtige Spalten:**
```sql
- user_id: Wer hat die Punkte bekommen/verloren
- points_change: +X oder -X Punkte
- category: Art der Punkte (siehe unten)
- reason: Begründung (z.B. Task-Name)
- created_at: Zeitstempel (mit Kambodscha Timezone)
- created_by: Wer hat es ausgelöst (user_id oder admin_id)
```

**Kategorien (`category`):**
- `check_in` - Check-in Bonus (+5 wenn pünktlich)
- `check_in_late` - Check-in Strafe (negativ, z.B. -116 Punkte bei 10h Verspätung)
- `task_completed` - Task erledigt (Basis-Punkte)
- `deadline_bonus` - Task vor Deadline fertig (+2)
- `quality_bonus` - Task mit hoher Qualität (+1-3)
- `task_reopened` - Task wurde wiedereröffnet (-1 Strafe)
- `patrol_completed` - Patrol Scan erledigt (+1 pro Location)
- `patrol_missed` - Patrol Round verpasst (negativ)
- `checklist_completed` - Checklist approved (Variable Punkte)
- `fortune_wheel` - Glücksrad Bonus (+5-50)
- `bonus` - Admin Bonus (Variable)

### 2. **`daily_point_goals`** - Tägliche Zusammenfassung
Wird automatisch aktualisiert wenn sich Punkte ändern.

**Wichtige Spalten:**
```sql
- user_id: Staff Member
- goal_date: Tag (YYYY-MM-DD)
- achieved_points: Erreichte Punkte (kann negativ sein!)
- theoretically_achievable_points: Was hätte erreicht werden können
- percentage: achieved / achievable * 100 (kann über 100% sein!)
- color_status: 'green', 'yellow', 'red', 'gray' (für UI)
- team_achievable_points: Team-Gesamt Erreichbar
- team_points_earned: Team-Gesamt Erreicht
```

**Farb-Status-Logik:**
- `dark-green`: >= 90%
- `green`: >= 70%
- `yellow`: >= 50%
- `red`: < 50%
- `gray`: achievable = 0 (kein Shift)

### 3. **`monthly_point_goals`** - Monatliche Zusammenfassung
Aggregiert alle `daily_point_goals` eines Monats.

**Wichtige Spalten:**
```sql
- user_id: Staff Member
- month: 'YYYY-MM' Format
- total_achievable_points: Summe aller achievable des Monats
- total_achieved_points: Summe aller achieved des Monats
- percentage: Monatsdurchschnitt
- color_status: Gesamt-Farbe für den Monat
```

### 4. **`profiles.total_points`**
Lifetime-Summe aller Punkte die der User je bekommen/verloren hat.
Wird via Trigger automatisch aktualisiert wenn `points_history` Einträge hinzugefügt werden.

---

## ⚙️ Kern-Funktionen

### 1. `calculate_achieved_points(user_id, date)`
**Was es macht:** Berechnet die erreichten Punkte eines Users an einem bestimmten Tag.

**Logik:**
```sql
SELECT SUM(points_change)
FROM points_history
WHERE user_id = ? AND date = ?
```

**Wichtig:**
- Zählt ALLE Punkte (positiv + negativ)
- Kann negativ sein!
- Beispiel: Check-in +5, Task +9, Check-in-Strafe -116 = Total -102

---

### 2. `calculate_theoretically_achievable_points(user_id, date)`
**Was es macht:** Berechnet was ein User an einem Tag hätte erreichen können.

**AKTUELLE IMPLEMENTIERUNG (26.11.2025):**

#### Für HEUTE (current_date):
1. **Prüfe Shift-Schedule:**
   - Hat User einen Shift heute? → Weiter
   - Hat User eingecheckt? → Weiter
   - Beides NEIN → `return 0`

2. **Berechne Mögliche Punkte:**
   ```
   + 5 Punkte (Check-in Bonus)
   + Alle offenen Tasks (assigned_to = user)
   + Alle Helper Tasks (helper_id = user, halbe Punkte)
   + Alle unassigned Tasks (jeder kann sie nehmen)
   + Patrol Rounds * Anzahl Locations
   + Checklist Instances (points_awarded)
   ```

#### Für VERGANGENE TAGE:
```sql
-- Summe ALLER POSITIVEN Punkte aus points_history
SELECT SUM(points_change) WHERE points_change > 0 AND date = ?
```

**Warum?**
- Tasks werden gelöscht/archiviert → können nicht mehr abgerufen werden
- `points_history` ist die einzige verlässliche Quelle für historische Daten
- Wenn User Punkte bekommen hat, war es erreichbar!

**BEKANNTES PROBLEM (noch nicht gefixt):**
- Wenn User nur NEGATIVE Punkte hat (z.B. Check-in Strafe), zählt Funktion das falsch
- Wenn User KEINE Punkte hat (nicht eingecheckt), zeigt es trotzdem achievable > 0

---

### 3. `update_daily_point_goals_for_user(user_id, date)`
**Was es macht:** Aktualisiert `daily_point_goals` für einen User.

**Wird aufgerufen:**
- Nach jedem `points_history` INSERT (via Trigger)
- Nach Task approval/completion
- Nach Check-in
- Nach Patrol completion
- Manual via Admin

**Logik:**
```sql
achieved = calculate_achieved_points(user_id, date)
achievable = calculate_theoretically_achievable_points(user_id, date)
percentage = (achieved / achievable * 100) -- CAN BE OVER 100%!
color = get_color_status(achievable, achieved)

UPSERT INTO daily_point_goals (...)
```

---

## 🎯 Punktevergabe - Detail

### Check-in System

**Pünktlich:**
```sql
INSERT INTO points_history (
  user_id,
  points_change = 5,
  category = 'check_in',
  reason = 'Punctual check-in'
)
```

**Verspätet:**
Formel: `points_penalty = (minutes_late / 10) + base_late_penalty`

Beispiel: 10 Stunden verspätet = 600 Minuten
```
Penalty = (600 / 10) + 56 = 60 + 56 = 116 Punkte Strafe
```

```sql
INSERT INTO points_history (
  user_id,
  points_change = -116,  -- NEGATIV!
  category = 'check_in_late',
  reason = 'Late check-in: 10 hours 22 minutes late'
)
```

---

### Task System

**Task Completion:**
1. User completed Task → Status = 'completed'
2. Admin approved Task → Funktion `approve_task_with_quality()`
3. Punkte werden berechnet:

```sql
base_points = task.points_value

-- Deadline Bonus (+2)
IF task completed BEFORE due_date THEN
  deadline_bonus = 2
END IF

-- Quality Bonus (0-3)
IF review_quality = 'excellent' THEN quality_bonus = 3
ELSIF review_quality = 'good' THEN quality_bonus = 2
ELSIF review_quality = 'satisfactory' THEN quality_bonus = 1
END IF

-- Helper Split
IF task has helper THEN
  assigned_user gets 50%
  helper gets 50%
END IF

total_points = base_points + deadline_bonus + quality_bonus
```

**Einträge in points_history:**
```sql
-- Basis-Punkte
INSERT (points_change = base_points, category = 'task_completed', reason = task.title)

-- Deadline Bonus (separate)
IF deadline_bonus > 0 THEN
  INSERT (points_change = 2, category = 'deadline_bonus', reason = 'Task: ' || task.title)
END IF

-- Quality Bonus (separate)
IF quality_bonus > 0 THEN
  INSERT (points_change = quality_bonus, category = 'quality_bonus', reason = 'Task: ' || task.title)
END IF
```

**Task Reopen (Strafe):**
Wenn Admin Task reopened:
```sql
INSERT INTO points_history (
  user_id,
  points_change = -1,
  category = 'task_reopened',
  reason = 'Task reopened: ' || task.title
)
```

---

### Patrol Rounds

**Während Patrol:**
- User scannt QR Code an Location
- +1 Punkt pro Location

```sql
-- Trigger: award_patrol_scan_point()
FOR EACH scan:
  INSERT INTO points_history (
    points_change = 1,
    category = 'patrol_completed',
    reason = 'Patrol scan completed: ' || location_name
  )
```

**Patrol Round verpasst:**
Wenn Patrol Round 30 Minuten überfällig:
```sql
INSERT INTO points_history (
  points_change = -(num_locations),  -- z.B. -8 wenn 8 Locations
  category = 'patrol_missed',
  reason = 'Missed patrol round: ' || time_slot
)
```

---

### Checklist System

**Checklist Approval:**
```sql
-- Basis-Punkte aus Checklist Template
points = checklist_template.points_awarded

INSERT INTO points_history (
  points_change = points,
  category = 'checklist_completed',
  reason = checklist.name
)
```

---

### Fortune Wheel (Glücksrad)

**User dreht Rad:**
```sql
-- Random Punkte zwischen 5-50
random_points = RANDOM(5, 50)

INSERT INTO points_history (
  points_change = random_points,
  category = 'fortune_wheel',
  reason = 'Glücksrad Bonus'
)
```

---

### Admin Bonus

**Admin gibt manuelle Punkte:**
```sql
-- Via Funktion add_bonus_points(user_id, points, reason)
INSERT INTO points_history (
  user_id = ?,
  points_change = ?,
  category = 'bonus',
  reason = ?,
  created_by = admin_id
)
```

---

## 🔄 Automatische Aktualisierungen

### Trigger auf `points_history`:
```sql
CREATE TRIGGER update_points_after_history_insert
AFTER INSERT ON points_history
FOR EACH ROW
EXECUTE FUNCTION update_user_total_points();

-- Aktualisiert profiles.total_points
-- Ruft update_daily_point_goals_for_user() auf
```

### Trigger auf `tasks`:
```sql
CREATE TRIGGER update_points_after_task_change
AFTER INSERT OR UPDATE ON tasks
FOR EACH ROW
EXECUTE FUNCTION update_points_after_task_change();

-- Aktualisiert daily_point_goals für alle betroffenen User
```

### Trigger auf `patrol_rounds`:
```sql
CREATE TRIGGER update_points_after_patrol_change
AFTER INSERT OR UPDATE ON patrol_rounds
FOR EACH ROW
EXECUTE FUNCTION update_points_after_patrol_change();
```

---

## 📊 Beispiel-Berechnungen

### Beispiel 1: Sopheaktra 22.11.2025

**points_history Einträge:**
```
08:18:35 | check_in         | +5  | Punctual check-in
18:50:36 | task_completed   | +9  | clean all of this metal
18:54:30 | task_completed   | +15 | Again and Again
```

**Berechnung:**
```
achieved = 5 + 9 + 15 = 29
achievable = SUM(positive points) = 5 + 9 + 15 = 29
percentage = 29 / 29 * 100 = 100%
```

---

### Beispiel 2: Sopheaktra 21.11.2025 (Verspätung)

**points_history Einträge:**
```
18:40:36 | check_in_late | -116 | Late check-in: 10 hours 22 minutes
```

**Berechnung:**
```
achieved = -116
achievable = 0 (nur negative Punkte)
percentage = N/A (kann nicht berechnet werden)
color = 'gray'
```

**PROBLEM:** Aktuell zeigt achievable = 5 (falsch!)

---

### Beispiel 3: Dyroth 26.11.2025

**points_history Einträge:**
```
08:03:42 | check_in        | +5  | Punctual check-in
21:54:37 | task_completed  | +12 | Jupiter
23:29:34 | task_completed  | +12 | Pluto
23:29:39 | task_completed  | +12 | clean fish pound
23:29:43 | task_completed  | +12 | clean camera room
```

**Berechnung:**
```
achieved = 5 + 12 + 12 + 12 + 12 = 53
achievable = SUM(positive) = 53
percentage = 53 / 53 * 100 = 100%
```

**AKTUELLES PROBLEM:** daily_point_goals zeigt achievable = 5 (nur Check-in)
- Grund: Alte Daten wurden noch nicht neu berechnet
- Fix: `recalculate_all_historical_daily_goals()` ausführen

---

## 🐛 Bekannte Probleme (Stand 26.11.2025)

### Problem 1: Achievable bei nur negativen Punkten
**Symptom:** User hat -116 Punkte (Verspätung), aber achievable = 5

**Root Cause:**
```sql
-- In calculate_theoretically_achievable_points()
IF NOT v_is_today THEN
  SELECT SUM(CASE WHEN points_change > 0 THEN points_change ELSE 0 END)
  INTO v_achievable_points
  FROM points_history
  WHERE date = p_date;

  IF v_achievable_points > 0 THEN
    RETURN v_achievable_points;
  END IF;

  -- Falls zurück auf Schätzung → FALSCH!
  -- Sollte return 0 sein!
END IF
```

**Fix:** Wenn keine positiven Punkte existieren, return 0 (nicht fallback)

---

### Problem 2: Achievable bei keinen Einträgen
**Symptom:** User hat keinen Check-in, keine Punkte, aber achievable = 15

**Root Cause:** Gleich wie Problem 1

**Fix:** Wenn points_history leer für Tag → User hatte keinen Shift → return 0

---

### Problem 3: Alte Daten nicht aktualisiert
**Symptom:** Historische daily_point_goals haben falsche achievable Werte

**Root Cause:**
- Funktion wurde geändert
- Alte Daten müssen neu berechnet werden

**Fix:**
```sql
SELECT recalculate_all_historical_daily_goals();
```

---

## 🔧 Wartungs-Funktionen

### Alle historischen Daten neu berechnen
```sql
SELECT recalculate_all_historical_daily_goals();
```

### Alle Punkte zurücksetzen (NUR FÜR TESTING!)
```sql
SELECT reset_all_points();  -- Nur Admins!
```

### Validierung ausführen
```sql
SELECT validate_points_logic();
-- Prüft ob achieved > achievable (sollte nicht vorkommen)
```

### Einzelnen User aktualisieren
```sql
SELECT update_daily_point_goals_for_user(
  'user-uuid-hier',
  '2025-11-22'::date
);
```

---

## 📈 Frontend Integration

### Dashboard anzeigen
```typescript
// Hole daily_point_goals für User
const { data } = await supabase
  .from('daily_point_goals')
  .select('*')
  .eq('user_id', userId)
  .eq('goal_date', today)
  .single();

// Zeige:
// - data.achieved_points
// - data.theoretically_achievable_points
// - data.percentage
// - data.color_status (für Farbe)
```

### Points History anzeigen
```typescript
// Hole alle Punkteänderungen für einen Tag
const { data } = await supabase
  .from('points_history')
  .select('*')
  .eq('user_id', userId)
  .gte('created_at', startOfDay)
  .lte('created_at', endOfDay)
  .order('created_at', { ascending: true });

// Gruppiere nach category für Breakdown
```

### Leaderboard
```typescript
// Top 10 Staff nach total_points
const { data } = await supabase
  .from('profiles')
  .select('id, full_name, avatar_color, total_points')
  .eq('role', 'staff')
  .order('total_points', { ascending: false })
  .limit(10);
```

---

## ✅ Best Practices

1. **NIEMALS `points_history` manuell ändern!**
   - Immer neue Einträge hinzufügen
   - Für Korrekturen: Neue Einträge mit negativen/positiven Werten

2. **daily_point_goals wird automatisch aktualisiert**
   - Nicht manuell updaten
   - Läuft über Trigger

3. **Timezone beachten!**
   - Alle Datumsberechnungen mit `AT TIME ZONE 'Asia/Phnom_Penh'`
   - Sonst werden Punkte falschen Tagen zugeordnet

4. **Prozentsätze können über 100% sein!**
   - Das ist ein Feature, kein Bug
   - Zeigt: User hat mehr erreicht als erwartet

5. **Color Status Logik:**
   - Basiert auf achieved vs achievable
   - Nicht auf percentage (kann irreführend sein)

---

## 🚀 Zukünftige Verbesserungen

1. **Fix: Achievable Berechnung für Tage mit nur Strafen**
2. **Fix: Achievable für Tage ohne Einträge**
3. **Add: Historische Recalculation beim Server-Start**
4. **Add: Audit Log für manuelle Punkt-Änderungen**
5. **Add: Wöchentliche Zusammenfassung (weekly_point_goals)**
6. **Add: Bonus für Konsistenz (X Tage in Folge >= 90%)**

---

Erstellt: 26.11.2025
Letzte Aktualisierung: 26.11.2025
Version: 1.0
