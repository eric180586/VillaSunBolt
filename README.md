# Villa Sun Staff Management App

Vollständige Staff Management Lösung mit Task-System, Punktesystem, Check-In/Out, Patrol Rounds und mehr.

## Status: ✅ Produktionsbereit

### Letzte Updates (2025-11-12)
- Task System vollständig funktionsfähig
- Notifications implementiert
- Automatische Task-Archivierung aktiv
- Photo-Felder zur Tasks Tabelle hinzugefügt
- Build erfolgreich

## Wichtige Dokumente

- **VOLLSTAENDIGE_LOESUNG.md** - Kompletter Status aller Fixes
- **SETUP_PUSH_NOTIFICATIONS.md** - Push Notification Setup

## Technologie Stack

- **Frontend:** React + TypeScript + Vite + Tailwind CSS
- **Backend:** Supabase (PostgreSQL + Auth + Storage + Edge Functions)
- **Features:** Realtime Updates, PWA, i18n (DE/EN/KM)

## Installation

```bash
npm install
npm run dev
```

Create a `.env` based on `.env.example` and provide your Supabase credentials plus VAPID keys for push notifications before running the app locally.

## Build

```bash
npm run build
```

## Hauptfunktionen

- ✅ Task Management mit Templates
- ✅ Punktesystem mit Gamification
- ✅ Check-In/Check-Out System
- ✅ Patrol Rounds mit QR-Codes
- ✅ Team Chat mit Photo-Upload
- ✅ Shopping Liste
- ✅ Notizen System
- ✅ Departure Requests
- ✅ Push Notifications ebenfalls automatisch übersetzt
- ✅ Mehrsprachigkeit (DE/EN/KM)

