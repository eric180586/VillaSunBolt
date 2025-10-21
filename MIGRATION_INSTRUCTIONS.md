# 🗄️ Migrations-Anleitung für Villa Sun App

## ✅ Was bereits erledigt ist

- ✅ **140 bereinigte Migrations-Dateien** (von ursprünglich 152, Duplikate entfernt)
- ✅ **Basis-Schema deployed** (9 Haupt-Tabellen: profiles, tasks, checklists, schedules, etc.)
- ✅ **RLS aktiviert** auf allen Tabellen
- ✅ **Frontend-Code** komplett kopiert aus ZIP
- ✅ **Edge Functions** bereit zum Deployment

## 📊 Aktuelle Datenbank

**Vorhandene Tabellen:**
1. profiles
2. schedules
3. tasks
4. checklists
5. checklist_items
6. checklist_instances
7. notes
8. points_history
9. notifications

## 🔄 Verbleibende Migrationen

**Insgesamt: 137 Migrationen** müssen noch angewendet werden.

Diese befinden sich in: `/supabase/migrations/`

### Wichtige Migrations (Priorität):

1. **Check-in System** (20251011140532_create_checkin_system.sql)
2. **Punktesystem** (20251017120000_FINAL_APPROVED_points_calculation_system.sql)
3. **Patrol Rounds** (20251012023157_create_patrol_rounds_system.sql)
4. **Fortune Wheel** (20251013003610_create_fortune_wheel_system.sql)
5. **Tutorial System** (20251017140000_create_tutorial_slides_system.sql)

## 🚀 Optionen zum Anwenden der Migrationen

### Option 1: Automatisches Batch-Script (EMPFOHLEN)

Ich habe ein Python-Script vorbereitet das alle Migrationen listet:

\`\`\`bash
python3 apply_all_migrations.py
\`\`\`

Für die tatsächliche Anwendung müssten wir entweder:
- Ein Supabase CLI script verwenden
- Die Migrationen manuell im Supabase Dashboard SQL Editor ausführen
- Ein custom Script schreiben das das MCP Tool nutzt

### Option 2: Manuelle Anwendung im Supabase Dashboard

1. Gehe zu deinem Supabase Dashboard
2. SQL Editor öffnen
3. Kopiere den Inhalt von `/supabase/migrations/[filename].sql`
4. Führe aus
5. Wiederhole für alle 137 Dateien (zeitaufwändig!)

### Option 3: Supabase CLI (Lokal)

\`\`\`bash
# Erst Supabase CLI installieren
npm install -g supabase

# Mit deinem Projekt verbinden
supabase link --project-ref YOUR_PROJECT_REF

# Alle Migrationen anwenden
supabase db push
\`\`\`

## ⚠️ Bekannte Probleme

### 1. Viele Punkt-Berechnungs-Fixes

Es gibt **26 Migrationen** die das Punktesystem fixen/ändern. Diese sind redundant und könnten zu einer konsolidiert werden.

### 2. Migration-Dependencies

Einige Migrationen hängen von vorherigen ab. Sie **müssen in chronologischer Reihenfolge** angewendet werden!

### 3. npm Install Problem

Aktuell blockiert ein Netzwerkproblem npm install. Das muss behoben werden bevor die App gebaut werden kann.

## 📋 Empfohlenes Vorgehen

### Sofort (Heute):

1. **npm Problem beheben**
   - Evtl. npm cache löschen: `npm cache clean --force`
   - Oder: Dependencies manuell von ZIP kopieren

2. **Kritische Migrationen anwenden**
   - Check-in System
   - Punktesystem (FINAL APPROVED Version)
   - Patrol Rounds

### Mittelfristig (Diese Woche):

3. **Restliche Migrationen konsolidieren**
   - Ähnliche Fixes zu einer Migration zusammenfassen
   - Reduzierung von 137 auf ~30-40 Migrationen

4. **Alle Migrationen anwenden**
   - Via Batch-Script oder manuell
   - Fehler dokumentieren und beheben

### Langfristig:

5. **Migration-Strategie etablieren**
   - Keine direkten Production-Deployments mehr
   - Erst in Staging testen
   - Rollback-Scripts erstellen

## 🎯 Nächste Schritte für mich

1. Fix npm install issue
2. Test frontend build
3. Deploy Edge Functions
4. Create migration batch script

## 📞 Bei Fragen

Sag Bescheid welche Option du bevorzugst und ich helfe dir beim Setup!
