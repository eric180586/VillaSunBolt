# Push-Benachrichtigungen Setup - Vollständige Anleitung

## ✅ Was bereits implementiert ist

1. **Service Worker** (`public/service-worker.js`) - ✅ Vollständig
2. **Frontend Push-Logik** (`src/lib/pushNotifications.ts`) - ✅ Vollständig
3. **Auto-Subscribe beim Login** (`src/contexts/AuthContext.tsx` Zeile 51-70) - ✅ Vollständig
4. **Edge Function** (`supabase/functions/send-push-notification/index.ts`) - ✅ Vollständig
5. **Database Trigger** (Notifications → Push) - ✅ Vollständig

## ❌ Was noch fehlt: VAPID Keys in Supabase

Die Push-Benachrichtigungen funktionieren nicht weil die **VAPID Keys** in Supabase fehlen!

---

## 🔧 Setup-Anleitung (5 Minuten)

### Schritt 1: VAPID Keys generieren

Öffne ein Terminal und führe aus:

```bash
npx web-push generate-vapid-keys
```

Du bekommst diese Ausgabe:

```
=======================================
Public Key:
BMFVUPTc2DCiM9h6IJ86atYNioxCCMJlJYqE9IeRd6yWHnIYAe67tEhKz11oJHmyuh9azuZwNsdDZublyo7Y2eM

Private Key:
abc123xyz456def789ghi012jkl345mno678pqr901stu234vwx567yza890bcd
=======================================
```

### Schritt 2: Keys in Supabase Dashboard eintragen

1. Öffne dein **Supabase Dashboard**: https://supabase.com/dashboard
2. Wähle dein Projekt aus
3. Gehe zu **Project Settings** (linke Sidebar ganz unten)
4. Klicke auf **Edge Functions** (in der Settings-Sidebar)
5. Scrolle zu **Secrets** und klicke auf **Add Secret**

**Füge diese 3 Secrets hinzu:**

| Secret Name | Value | Notizen |
|-------------|-------|---------|
| `VAPID_PUBLIC_KEY` | (Der Public Key von oben) | Bereits in .env vorhanden |
| `VAPID_PRIVATE_KEY` | (Der Private Key von oben) | ⚠️ WICHTIG: Niemals committen! |
| `VAPID_EMAIL` | `mailto:admin@villasun.com` | Oder deine echte Email |

### Schritt 3: Edge Function neu deployen (Optional)

Die Edge Function lädt die Secrets automatisch. Aber falls Probleme auftreten:

1. Gehe zu **Edge Functions** im Supabase Dashboard
2. Finde `send-push-notification`
3. Klicke auf **Redeploy**

---

## 🧪 Testing

### Test 1: Service Worker prüfen

1. Öffne die App im Browser
2. Drücke **F12** für DevTools
3. Gehe zu **Application** → **Service Workers**
4. Du solltest sehen: `service-worker.js` mit Status "activated"

### Test 2: Push-Permission prüfen

1. Logge dich ein
2. Nach 10 Sekunden sollte automatisch ein Popup erscheinen:
   - "VillaSun möchte dir Benachrichtigungen senden"
3. Klicke auf **Zulassen**

### Test 3: Push-Subscription prüfen

Öffne die Browser Console (F12) und führe aus:

```javascript
navigator.serviceWorker.ready.then(reg => {
  reg.pushManager.getSubscription().then(sub => {
    console.log('Push subscription:', sub);
  });
});
```

Du solltest ein Objekt mit `endpoint`, `keys.p256dh` und `keys.auth` sehen.

### Test 4: Test-Notification senden

1. Logge dich als **Admin** ein
2. Öffne die Browser Console
3. Führe aus:

```javascript
const { data, error } = await supabase.functions.invoke('send-push-notification', {
  body: {
    role: 'staff',
    title: 'Test Notification',
    body: 'This is a test push notification!',
  }
});
console.log('Result:', data, error);
```

4. Alle Staff sollten jetzt eine Push-Notification bekommen!

### Test 5: Push bei geschlossener App

1. **Schließe** den Browser komplett
2. Lasse einen Admin eine Notification senden (z.B. Task Assignment)
3. Du solltest eine **Desktop-Notification** sehen auch wenn Browser geschlossen ist!

---

## 🔍 Troubleshooting

### Problem: "VAPID keys not configured"

**Lösung:** VAPID Keys in Supabase Edge Functions Secrets eintragen (siehe Schritt 2)

### Problem: Keine Permission-Popup

**Lösung:**
- Prüfe ob Browser Push unterstützt (Chrome, Firefox, Edge = ✅)
- Safari unterstützt erst ab Version 16
- Prüfe ob Service Worker aktiviert ist

### Problem: "Registration failed"

**Lösung:**
```javascript
// Browser Console:
navigator.serviceWorker.getRegistrations().then(regs => {
  regs.forEach(reg => reg.unregister());
});
// Dann Seite neu laden
```

### Problem: Push kommt nicht an

**Checklist:**
1. ✅ VAPID Keys in Supabase gesetzt?
2. ✅ Notification Permission erteilt?
3. ✅ Push-Subscription in Datenbank vorhanden?
   ```sql
   SELECT * FROM push_subscriptions WHERE user_id = '<deine-user-id>';
   ```
4. ✅ Edge Function Logs prüfen:
   - Supabase Dashboard → Edge Functions → send-push-notification → Logs

---

## 📊 Wie es funktioniert

### Flow Diagram:

```
1. User Login
   ↓
2. AuthContext: Auto-subscribe nach 10 Sekunden
   ↓
3. Browser fragt: "Notifications erlauben?"
   ↓
4. User klickt "Zulassen"
   ↓
5. Push-Subscription wird erstellt
   ↓
6. Subscription wird in DB gespeichert (push_subscriptions Tabelle)
   ↓
7. Admin erstellt Task / Check-in wird genehmigt / etc.
   ↓
8. Database Trigger erstellt Notification
   ↓
9. Trigger ruft Edge Function auf: send-push-notification
   ↓
10. Edge Function sendet Push an alle betroffenen User
   ↓
11. Service Worker empfängt Push
   ↓
12. Browser zeigt Notification (auch bei geschlossener App!)
```

### Welche Events triggern Push-Notifications?

- ✅ Task Assignment (neue Task zugewiesen)
- ✅ Task Approval (Task genehmigt)
- ✅ Task Reopened (Task wieder geöffnet)
- ✅ Check-in Approved (Check-in genehmigt)
- ✅ Check-in Needs Approval (Admin Notification)
- ✅ Time-off Request (Freiwunsch eingereicht)
- ✅ Departure Request (Feierabend-Request)
- ✅ Note Added (Neue Notiz für Staff)
- ✅ Patrol Round Reminder
- ✅ Task Deadline Reminder

---

## 🎯 Nächste Schritte

1. **VAPID Keys generieren** (siehe Schritt 1)
2. **Keys in Supabase eintragen** (siehe Schritt 2)
3. **App neu laden und testen**
4. **Fertig!** 🎉

---

## 🔐 Sicherheit

⚠️ **WICHTIG:**
- Niemals VAPID Private Key in Git committen!
- Nur in Supabase Edge Functions Secrets speichern
- Public Key kann öffentlich sein (ist bereits in .env)

---

## 📱 Browser-Kompatibilität

| Browser | Support | Notizen |
|---------|---------|---------|
| Chrome | ✅ | Vollständig |
| Firefox | ✅ | Vollständig |
| Edge | ✅ | Vollständig |
| Safari | ⚠️ | Ab Version 16 |
| Opera | ✅ | Vollständig |
| Mobile Chrome | ✅ | Android only |
| Mobile Safari | ❌ | iOS unterstützt kein Web Push |

---

## 💡 Zusätzliche Features (Optional)

### Admin: Test Push senden

Füge in AdminDashboard einen Button hinzu:

```typescript
const testPush = async () => {
  const { error } = await supabase.functions.invoke('send-push-notification', {
    body: {
      role: 'staff',
      title: 'Test Notification',
      body: 'Dies ist eine Test-Benachrichtigung!',
    }
  });
  if (error) alert('Error: ' + error.message);
  else alert('Push sent to all staff!');
};
```

### User: Push-Einstellungen

Füge in Profile/Settings einen Toggle hinzu um Push zu aktivieren/deaktivieren.

---

**Das System ist vollständig implementiert und wartet nur auf die VAPID Keys!** 🚀
