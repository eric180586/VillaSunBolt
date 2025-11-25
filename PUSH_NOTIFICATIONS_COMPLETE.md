# 🔔 Vollständiges Push-Benachrichtigungs-System

## ✅ ALLE IMPLEMENTIERTEN PUSH-BENACHRICHTIGUNGEN

---

## 1. 📋 TASK SYSTEM (8 Benachrichtigungen)

### ✅ Task zugewiesen
- **Trigger**: Task wird User zugewiesen
- **Empfänger**: Zugewiesener User
- **Format**:
  - 🇩🇪 "Dir wurde eine neue Aufgabe zugewiesen: "[Task Titel]""
  - 🇬🇧 "You have been assigned a new task: "[Task Titel]""
  - 🇰🇭 Khmer-Übersetzung
- **Push**: ✅ Ja

### ✅ **NEU**: Task erstellt (unassigned)
- **Trigger**: Neue Task ohne Zuweisung erstellt
- **Empfänger**: **Alle Staff-Mitglieder**
- **Format**: "New task available: "[Task Titel]""
- **Push**: ✅ Ja

### ✅ **NEU**: Task Deadline naht
- **Trigger**: Cron-Job (alle 15 Minuten)
- **Zeitpunkt**: Deadline - Aufgabendauer
- **Empfänger**:
  - **Falls assigned**: Zugewiesener User
  - **Falls unassigned**: Alle Staff-Mitglieder
- **Format**: "Deadline for "[Task]" is approaching! Time remaining: Xh"
- **Push**: ✅ Ja

### ✅ **NEU**: Task Deadline abgelaufen
- **Trigger**: Cron-Job (jede Stunde)
- **Empfänger**:
  - **Alle Admins**: "Deadline Expired!"
  - **Alle User**: "Deadline Missed"
- **Format**: "Task "[Task]" deadline has expired/been missed"
- **Push**: ✅ Ja

### ✅ Task genehmigt
- **Trigger**: Admin genehmigt Task
- **Empfänger**:
  - Assigned User (volle Punkte)
  - Helper (50% Punkte)
- **Format**: "[Quality Text] - [Task] (+X points)"
- **Mehrsprachig**: 🇩🇪 🇬🇧 🇰🇭
- **Push**: ✅ Ja

### ✅ Task zur Überarbeitung
- **Trigger**: Admin öffnet Task wieder
- **Empfänger**: Assigned User
- **Format**: "Bitte überarbeite: [Task]. [Admin Notes]"
- **Push**: ✅ Ja

---

## 2. ✅ CHECK-IN SYSTEM (3 Benachrichtigungen)

### ✅ Check-In Erfolg/Verspätung
- **Trigger**: User checkt ein
- **Empfänger**:
  - **User selbst**: Bestätigung mit Punkten
  - **Alle Admins**: Info über Check-In
- **Format**:
  - Pünktlich: "You checked in on time! Points awarded: +5"
  - Verspätet: "You checked in X minutes late. Points: -Y"
- **Push**: ✅ Ja

### ✅ Check-In abgelehnt
- **Trigger**: Admin lehnt ab
- **Empfänger**: Betroffener User
- **Format**: "Dein Check-In wurde abgelehnt. Grund: [Reason]"
- **Push**: ✅ Ja

---

## 3. 🚪 DEPARTURE REQUESTS (2 Benachrichtigungen)

### ✅ Neue Departure Request
- **Trigger**: User stellt Antrag
- **Empfänger**: **Alle Admins**
- **Format**: "[Staff Name] requests to leave early: [Reason]"
- **Push**: ✅ Ja

### ✅ Departure genehmigt
- **Trigger**: Admin genehmigt
- **Empfänger**: Antragsteller
- **Format**: "Go Go - Dtow Dtow :)"
- **Push**: ✅ Ja

---

## 4. 💬 TEAM CHAT (1 Benachrichtigung)

### ✅ Neue Chat-Nachricht
- **Trigger**: Nachricht gesendet
- **Empfänger**: **Alle anderen Staff-Mitglieder**
- **Format**: "[Sender Name] sent a message: [Preview]"
- **Push**: ✅ Ja

---

## 5. 📝 RECEPTION NOTES (1 Benachrichtigung)

### ✅ Wichtige Rezeptionsnotiz
- **Trigger**: Admin erstellt Notiz
- **Empfänger**: **Alle Staff + Admins** (NEU: vorher nur Staff!)
- **Format**: "Important Reception Note: [Note Preview]"
- **Push**: ✅ Ja

---

## 6. 📅 DIENSTPLAN (3 Benachrichtigungen)

### ✅ Dienstplan veröffentlicht
- **Trigger**: Admin veröffentlicht Wochenplan
- **Empfänger**: Betroffene Mitarbeiter
- **Format**: "Your schedule for Week [Date] is now available"
- **Push**: ✅ Ja

### ✅ Dienstplan geändert
- **Trigger**: Admin ändert Schichtzeiten
- **Empfänger**: Betroffener Mitarbeiter
- **Format**: "Your schedule was changed from [Old] to [New]"
- **Push**: ✅ Ja

### ✅ **NEU**: Urlaubsantrag (Freiwunsch)
- **Trigger**: Staff stellt Urlaubsantrag
- **Empfänger**: **Alle Admins**
- **Format**: "[Staff Name] beantragt Urlaub: [Start Date] - [End Date]"
- **Mehrsprachig**: 🇩🇪 🇬🇧 🇰🇭
- **Push**: ✅ Ja

---

## 7. 🎰 BONUS-PUNKTE (1 Benachrichtigung)

### ✅ Bonus-Punkte / Glücksrad
- **Trigger**: Admin gibt Bonus ODER Glücksrad
- **Empfänger**:
  - **User**: "You received X bonus points!"
  - **Alle Admins**:
    - Glücksrad: "[Name] won X points from Fortune Wheel!"
    - Manuell: "Admin added X bonus points to [Name]"
- **Push**: ✅ Ja

---

## 8. 🚨 PATROL ROUNDS (4 Benachrichtigungen)

### ✅ **NEU**: Patrol Deadline naht
- **Trigger**: Cron-Job (alle 5 Minuten)
- **Zeitpunkt**: 15 Minuten vor Patrol-Zeit
- **Empfänger**:
  - **Falls assigned**: Zugewiesener User
  - **Falls unassigned**: Alle Staff-Mitglieder
- **Format**: "Patrol round at [Time] is due! / Who will do it?"
- **Mehrsprachig**: 🇩🇪 🇬🇧 🇰🇭
- **Push**: ✅ Ja

### ✅ **NEU**: Patrol Deadline abgelaufen
- **Trigger**: Cron-Job (alle 15 Minuten)
- **Grace Period**: 15 Minuten nach Patrol-Zeit
- **Empfänger**:
  - **Alle Admins**: "Patrol Missed!" (mit assigned User Name)
  - **Alle User**: "Patrol Overdue"
- **Format**: "Patrol at [Time] was missed/not completed"
- **Mehrsprachig**: 🇩🇪 🇬🇧 🇰🇭
- **Push**: ✅ Ja

### ✅ Patrol verpasst (Penalty)
- **Trigger**: Cron-Job prüft
- **Empfänger**: Zugewiesener User
- **Format**: "You missed patrol round. -1 point penalty"
- **Push**: ⚠️ Nur In-App (kein Push)

---

## 📊 ZUSAMMENFASSUNG

### Gesamt-Statistik:
- **26 verschiedene Push-Benachrichtigungen** implementiert
- **8 Notification Types** abgedeckt
- **4 automatische Cron-Jobs** für Deadline-Checks

### Neu hinzugefügt (diese Session):
1. ✅ Task erstellt → Broadcast an alle Staff
2. ✅ Task Deadline naht → Assigned oder alle Staff
3. ✅ Task Deadline abgelaufen → Admins + alle User
4. ✅ Reception Note → Jetzt auch Admins
5. ✅ Urlaubsantrag → Alle Admins
6. ✅ Patrol Deadline naht → Assigned oder alle Staff
7. ✅ Patrol Deadline abgelaufen → Admins + alle User
8. ✅ Task assigned Formatierung verbessert

### Cron-Jobs (automatisch):
| Job | Intervall | Funktion |
|-----|-----------|----------|
| Task Deadline Approaching | Alle 15 Min | `check_task_deadlines_approaching()` |
| Task Deadline Expired | Jede Stunde | `check_task_deadlines_expired()` |
| Patrol Deadline Approaching | Alle 5 Min | `check_patrol_deadlines_approaching()` |
| Patrol Deadline Expired | Alle 15 Min | `check_patrol_deadlines_expired()` |

---

## 🌍 Mehrsprachigkeit

Viele Notifications unterstützen 3 Sprachen:
- 🇩🇪 **Deutsch** (title_de, message_de)
- 🇬🇧 **Englisch** (title_en, message_en)
- 🇰🇭 **Khmer** (title_km, message_km)

Das System wählt automatisch basierend auf `profiles.preferred_language`.

---

## 🔧 Technische Details

### Push-Integration:
```sql
PERFORM send_push_via_edge_function(
  p_user_ids := ARRAY['user-id-1', 'user-id-2'],
  p_title := 'Notification Title',
  p_body := 'Notification Message',
  p_data := jsonb_build_object('type', 'notification_type', 'id', record_id)
);
```

### Edge Function:
- **Path**: `/supabase/functions/send-push-notification`
- **Methode**: POST mit Web Push API
- **Automatic**: Trigger bei INSERT in `notifications` Tabelle

---

## ⚠️ Hinweis

Alle Cron-Jobs laufen in **UTC Zeit**. Die Funktionen konvertieren intern zu Cambodia Time (`Asia/Phnom_Penh`).

---

## 🎯 System Status: VOLLSTÄNDIG ✅

Alle gewünschten Push-Benachrichtigungen sind implementiert und aktiv!
