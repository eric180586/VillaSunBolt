# Push Notifications Setup - VAPID Keys konfigurieren

## Problem
Push Notifications funktionieren nicht, weil die VAPID Keys nicht als Supabase Secrets konfiguriert sind.

## Lösung - VAPID Keys als Supabase Secrets hinzufügen

### Schritt 1: Supabase Dashboard öffnen
1. Gehe zu https://supabase.com/dashboard
2. Wähle dein Projekt "VillaSun" aus
3. Gehe zu **Settings** → **Edge Functions** (oder **Project Settings** → **Edge Functions**)

### Schritt 2: Secrets hinzufügen
Klicke auf "Manage secrets" oder "Add secret" und füge folgende 3 Secrets hinzu:

#### Secret 1: VAPID_PUBLIC_KEY
```
Name: VAPID_PUBLIC_KEY
Value: BMFVUPTc2DCiM9h6IJ86atYNioxCCMJlJYqE9IeRd6yWHnIYAe67tEhKz11oJHmyuh9azuZwNsdDZublyo7Y2eM
```

#### Secret 2: VAPID_PRIVATE_KEY
```
Name: VAPID_PRIVATE_KEY
Value: yE0Q9d5k25-kMSiGenzT4igBdRWSR9bZYL1-IIyy80Y
```

#### Secret 3: VAPID_EMAIL
```
Name: VAPID_EMAIL
Value: mailto:admin@villasun.com
```

### Schritt 3: Edge Functions neu starten
Nach dem Hinzufügen der Secrets:
1. Gehe zu **Edge Functions**
2. Finde die Function "send-push-notification"
3. Klicke auf "Redeploy" oder warte 1-2 Minuten

### Schritt 4: Testen
1. Führe einen Check-in durch
2. Du solltest jetzt eine Push-Notification erhalten!

## Frontend - Public Key aktualisieren

Die Web-App benötigt auch den Public Key. Dieser muss in der `.env` Datei sein:

```env
VITE_VAPID_PUBLIC_KEY=BMFVUPTc2DCiM9h6IJ86atYNioxCCMJlJYqE9IeRd6yWHnIYAe67tEhKz11oJHmyuh9azuZwNsdDZublyo7Y2eM
```

Nach dem Ändern der `.env`:
```bash
npm run build
```

## Verifikation

Nach der Konfiguration sollten Push Notifications funktionieren bei:
- ✅ Check-in (für User und Admins)
- ✅ Task Approval/Rejection
- ✅ Departure Request Approval
- ✅ Neue Tasks/Assignments
- ✅ Alle anderen Notifications

## Troubleshooting

Falls es immer noch nicht funktioniert:

1. **Browser Console checken** (F12)
   - Suche nach Push-Subscription Fehlern
   - Prüfe ob Service Worker registriert ist

2. **Supabase Edge Function Logs**
   - Gehe zu Edge Functions → send-push-notification
   - Checke die Logs für Fehler

3. **Notifications Permission**
   - Browser muss Notifications erlauben
   - Checke in Browser Settings

4. **Service Worker**
   - Muss registriert sein
   - Öffne Chrome DevTools → Application → Service Workers
