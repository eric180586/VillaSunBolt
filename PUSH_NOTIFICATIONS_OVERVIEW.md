# Push-Benachrichtigungen Übersicht

## 🔔 Aktive Push-Benachrichtigungen im System

### 1. **Check-In System** ✅

#### Check-In Erfolg/Verspätung
- **Trigger**: Bei jedem Check-In (Funktion `process_check_in`)
- **Empfänger**:
  - **User**: Bestätigung mit Punkten
  - **Alle Admins**: Benachrichtigung über Check-In
- **Inhalt**:
  - Pünktlich: "You checked in on time! Points awarded: +5"
  - Verspätet: "You checked in X minutes late. Points: -Y"

#### Check-In Ablehnung
- **Trigger**: Admin lehnt Check-In ab (`reject_check_in`)
- **Empfänger**: Betroffener User
- **Inhalt**: "Dein Check-In wurde abgelehnt. Grund: [Reason]"

---

### 2. **Task Management** ✅

#### Neue Aufgabe zugewiesen
- **Trigger**: Neue Task erstellt mit `assigned_to` (`notify_task_assignment`)
- **Empfänger**: Zugewiesener Mitarbeiter
- **Inhalt**: "You have been assigned: [Task Title]"

#### Task genehmigt
- **Trigger**: Admin genehmigt Task (`approve_task_with_quality`)
- **Empfänger**:
  - **Assigned User**: Hauptpunkte
  - **Helper** (falls vorhanden): 50% Punkte
- **Inhalt**:
  - "Task Approved! [Quality Text] - [Title] (+X points)"
  - Mehrsprachig (DE/EN/KM)

#### Task zur Überarbeitung
- **Trigger**: Admin öffnet Task wieder (`reopen_task_with_penalty`)
- **Empfänger**: Zugewiesener Mitarbeiter
- **Inhalt**: "Bitte überarbeite: [Task Title]. [Admin Notes]"

---

### 3. **Departure Requests (Früh Gehen)** ✅

#### Neue Departure Request
- **Trigger**: Mitarbeiter stellt Antrag (`notify_admin_departure_request`)
- **Empfänger**: **Alle Admins**
- **Inhalt**: "[Staff Name] requests to leave early: [Reason]"

#### Departure genehmigt
- **Trigger**: Admin genehmigt Antrag (`notify_departure_approved`)
- **Empfänger**: Antragsteller
- **Inhalt**: "Go Go - Dtow Dtow :)"

---

### 4. **Team Chat** ✅

#### Neue Chat-Nachricht
- **Trigger**: Nachricht im Team Chat (`notify_chat_message`)
- **Empfänger**: **Alle anderen Mitarbeiter** (außer Sender)
- **Inhalt**: "[Sender Name] sent a message: [Message Preview]"

---

### 5. **Reception Notes** ✅

#### Wichtige Rezeptionsnotiz
- **Trigger**: Admin erstellt wichtige Notiz (`notify_reception_note`)
- **Empfänger**: **Alle Staff-Mitglieder**
- **Inhalt**: "Important Reception Note: [Note Preview]"

---

### 6. **Schedule/Dienstplan** ✅

#### Dienstplan veröffentlicht
- **Trigger**: Admin veröffentlicht Wochenplan (`notify_schedule_published`)
- **Empfänger**: Alle betroffenen Mitarbeiter
- **Inhalt**: "Your schedule for Week [Date] is now available"

#### Dienstplan geändert
- **Trigger**: Admin ändert Schichtzeiten (`notify_schedule_changed`)
- **Empfänger**: Betroffener Mitarbeiter
- **Inhalt**: "Your schedule was changed from [Old Time] to [New Time]"

---

### 7. **Bonus-Punkte / Glücksrad** ✅

#### Bonus-Punkte erhalten
- **Trigger**: Admin gibt Bonus ODER Glücksrad (`add_bonus_points`)
- **Empfänger**:
  - **User**: "You received X bonus points! Reason: [Reason]"
  - **Alle Admins**:
    - Glücksrad: "[Name] won X points from Fortune Wheel!"
    - Manuell: "Admin added X bonus points to [Name]"

---

### 8. **Patrol Rounds** ⚠️ (Aktuell KEINE Push)

#### Fehlende Patrol Round
- **Trigger**: Cron-Job prüft verpasste Rounds (`check_missed_patrol_rounds`)
- **Empfänger**: Zugewiesener Mitarbeiter
- **Inhalt**: "You missed patrol round at [Locations]. -1 point penalty"
- ⚠️ **Hinweis**: Aktuell nur In-App, KEIN Push!

---

## 📊 Statistik der Push-Benachrichtigungen

### Notification Types in der Datenbank:
- `check_in` - 36 Benachrichtigungen
- `task_assigned` - 4 Benachrichtigungen
- `task_approved` - 9 Benachrichtigungen
- `task_reopened` - 1 Benachrichtigung
- `schedule` - 44 Benachrichtigungen
- `info` - 2 Benachrichtigungen

---

## 🔧 Technische Details

### Push-Funktion:
- **Main Function**: `send_push_via_edge_function()`
- **Edge Function**: `/supabase/functions/send-push-notification`
- **Notification Trigger**: Automatischer Trigger bei INSERT in `notifications` Tabelle

### Sprachen:
Viele Notifications sind mehrsprachig:
- 🇩🇪 Deutsch (DE)
- 🇬🇧 Englisch (EN)
- 🇰🇭 Khmer (KM)

### Empfänger-Typen:
1. **Einzelne User** - Direkte Benachrichtigung
2. **Alle Admins** - Bei Departure Requests, Fortune Wheel, Check-Ins
3. **Alle Staff** - Bei Reception Notes, Chat Messages
4. **Betroffene User** - Bei Schedule Changes

---

## ⚠️ Fehlende Push-Benachrichtigungen

Diese Ereignisse haben aktuell KEINE Push-Benachrichtigungen:

1. **Patrol Rounds**:
   - Verpasste Patrol Runde
   - Patrol Round abgeschlossen
   - Patrol Scan erfolgreich

2. **Checklisten**:
   - Neue Checklist zugewiesen
   - Checklist genehmigt/abgelehnt
   - Checklist überfällig

3. **Checkout**:
   - Admin checked User aus
   - Automatischer Checkout

4. **Punkte-Updates**:
   - Tägliche Punkte-Zusammenfassung
   - Leaderboard Position geändert
   - Monatsziel erreicht

---

## 🎯 Empfehlungen

Falls du weitere Push-Benachrichtigungen hinzufügen möchtest, lass es mich wissen!

Priorität sollten haben:
1. ✅ Patrol Rounds (verpasst/abgeschlossen)
2. ✅ Checklist-Updates
3. ✅ Tägliche Zusammenfassungen
