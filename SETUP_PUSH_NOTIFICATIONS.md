# Push-Benachrichtigungen Setup - Finale Schritte

## Status
✅ VAPID Keys generiert
✅ Public Key in .env hinzugefügt
⚠️ Private Key muss noch zu Supabase hinzugefügt werden

## VAPID Keys

**Public Key (bereits in .env):**
```
BEo0RqAi1-FSfeRK0bFYscOc9ovfsLhONF25veK5J5f29Z9awBSkEF3Pj9RCxGxhgy9J2viCo38THSvmv-g5Haw
```

**Private Key (für Supabase Secrets):**
```
KjLuKyMtzq-w0HSi0WOAAlm5hsTfFrcloguE2yUN438
```

## Nächste Schritte

### 1. Private Key zu Supabase hinzufügen

Gehe zu: https://supabase.com/dashboard/project/vmfvvjzgzmmkigpxynii/settings/vault/secrets

Füge ein neues Secret hinzu:
- Name: `VAPID_PRIVATE_KEY`
- Value: `KjLuKyMtzq-w0HSi0WOAAlm5hsTfFrcloguE2yUN438`

### 2. Fehlende SQL-Funktionen anwenden

Gehe zu: https://supabase.com/dashboard/project/vmfvvjzgzmmkigpxynii/sql/new

Kopiere und führe den Inhalt von `/tmp/apply_missing_functions.sql` aus (269 Zeilen).

Das fügt hinzu:
- `approve_task_with_points` - Tasks genehmigen
- `reopen_task_with_penalty` - Tasks ablehnen
- `approve_checklist_instance` - Checklisten genehmigen
- `reject_checklist_instance` - Checklisten ablehnen
- `approve_check_in` - Check-ins genehmigen
- `reject_check_in` - Check-ins ablehnen
- `reset_all_points` - Punkte zurücksetzen

### 3. Fertig!

Danach ist alles komplett und die App ist produktionsbereit inklusive Push-Benachrichtigungen.

## Was Push-Benachrichtigungen bewirken

Die App sendet automatisch Benachrichtigungen für:
- 🔔 Neue Task-Zuweisungen
- ⏰ Check-in Erinnerungen (8:45 Uhr & 14:45 Uhr)
- ✅ Admin-Genehmigungen (Tasks, Checklists, Check-ins)
- ❌ Ablehnungen mit Feedback
- 💬 Neue Chat-Nachrichten
- 📝 Neue Notizen
- 🚶 Patrol-Erinnerungen
- 🎯 Ende-des-Tages Requests

Alle Benachrichtigungen funktionieren auf dem Handy und Desktop!
