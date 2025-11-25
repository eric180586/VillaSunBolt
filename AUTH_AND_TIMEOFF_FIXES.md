# Auth & Time-Off Request Fixes

## 🔧 Probleme behoben:

### 1. **Auth Refresh Token Error** ✅
**Problem**:
```
AuthApiError: Invalid Refresh Token: Refresh Token Not Found
```

**Lösung**:
- ✅ Verbesserte Auth State Handling in `AuthContext.tsx`
- ✅ Automatischer Logout bei ungültigem Token
- ✅ Bessere Event-Behandlung (TOKEN_REFRESHED, SIGNED_OUT)
- ✅ Global Auth Handler in `supabase.ts` hinzugefügt
- ✅ Automatische Weiterleitung zur Login-Seite bei Session-Ablauf

**Code-Änderungen**:
```typescript
// supabase.ts - Global Auth Handler
supabase.auth.onAuthStateChange((event, session) => {
  if (event === 'SIGNED_OUT' || !session) {
    if (window.location.pathname !== '/') {
      localStorage.clear();
      sessionStorage.clear();
      window.location.href = '/';
    }
  }
});
```

---

### 2. **Time-Off Requests 400 Error** ✅
**Problem**:
```
Failed to load resource: the server responded with a status of 400
Error submitting time-off request
```

**Root Cause**:
- Tabelle hatte `staff_id`, `request_date` (einzelnes Datum)
- Neue Notification-Funktion erwartete `user_id`, `start_date`, `end_date`
- Frontend versuchte mit alter Struktur zu arbeiten

**Lösung**:
- ✅ `start_date` und `end_date` Spalten zur Tabelle hinzugefügt
- ✅ `notify_time_off_request()` Funktion updated → verwendet jetzt `staff_id`
- ✅ Frontend `Schedules.tsx` Component updated:
  - Interface `TimeOffRequest` mit neuen Feldern
  - INSERT verwendet jetzt `start_date`, `end_date`
  - Query updated für Datums-Bereich
  - Display-Logik angepasst
- ✅ Neue Spalte `request_type` für bessere Kategorisierung (vacation, sick_leave, personal, other)
- ✅ RLS Policies überprüft und gesichert

**Neue Tabellenstruktur**:
```sql
time_off_requests:
  - id (uuid)
  - staff_id (uuid) ← Verwendet von Frontend
  - start_date (date) ← NEU
  - end_date (date) ← NEU
  - request_date (date) ← Legacy, für Kompatibilität
  - request_type (text) ← NEU: vacation/sick_leave/personal/other
  - reason (text)
  - status (pending/approved/rejected)
  - admin_response (text)
  - reviewed_by (uuid)
  - reviewed_at (timestamptz)
```

---

## 📋 Alle RLS Policies für time_off_requests:

1. ✅ **Staff can view own requests** - SELECT auf eigene staff_id
2. ✅ **Staff can create own requests** - INSERT mit eigener staff_id
3. ✅ **Admins can view all requests** - SELECT für Admins
4. ✅ **Admins can update all requests** - UPDATE für Admins

---

## 🔔 Notification Integration:

Die neue `notify_time_off_request()` Trigger-Funktion:
- ✅ Trigger bei INSERT in `time_off_requests`
- ✅ Benachrichtigt **alle Admins**
- ✅ Mehrsprachig (DE/EN/KM)
- ✅ Mit Push-Benachrichtigung
- ✅ Zeigt Mitarbeiter-Name und Datums-Bereich an

---

## ✅ Status: ALLE FEHLER BEHOBEN

- Auth Token-Fehler wird nun gracefully behandelt
- Time-Off Requests funktionieren vollständig
- Alle Notifications werden korrekt versendet
- Build erfolgreich ohne Fehler

---

## 💡 Für den User:

**Falls der Auth-Fehler wieder auftritt:**
1. Einfach ausloggen
2. Neu einloggen
3. Das System räumt automatisch die Session auf

**Time-Off Requests jetzt:**
- Können einzelne Tage ODER Zeiträume sein
- Start- und Enddatum werden gespeichert
- Admins bekommen sofort Push-Benachrichtigung
- Mehrsprachige Benachrichtigungen
