# PHASE 2 - FUNKTIONALE ANPASSUNGEN

## PROBLEM ANALYSE

### 1. Übersetzungen - UMFANGREICH
**Betroffene Dateien:** 50+ Components  
**Hardcoded Strings gefunden:**
- AdminDashboard.tsx: ~15 deutsche Strings
- CheckInApproval.tsx: ~10 deutsche Strings
- Viele weitere Components

**2 OPTIONEN:**
- **Option A (Schnell):** Nur kritische Admin-Components fixen
- **Option B (Vollständig):** Alle Components durchgehen (3-4 Stunden Arbeit)

---

### 2. Patrol Rounds - LOGIK ÄNDERUNG ⚠️
**Aktuell:**
- Nur zugewiesene Person kann Patrol machen
- Penalty nur für zugewiesene Person

**Gewünscht:**
- JEDER Staff kann Patrol machen
- Bei Verpassen: ALLE in der Schicht -1 Punkt pro QR Code

**Betroffen:**
- PatrolRounds.tsx (Frontend)
- Database Functions (Backend)
- Mehrere Migrations

---

### 3. Help Me Button
**Einfach:** Button-Visibility ändern

---

## EMPFEHLUNG

**KOMPRIMIERTER ANSATZ für Phase 2:**

1. **AdminDashboard Übersetzungen** (15 Min)
   - Nur die wichtigsten Strings
   
2. **Patrol Rounds Rewrite** (45 Min)
   - Datenbank Logik neu
   - Frontend anpassen
   
3. **Help Me Button für alle** (10 Min)
   - Einfache Conditional-Änderung

**Dann direkt zu PHASE 3:**
- Task Buttons größer/prominenter
- Items direkt abhakbar

**Übersetzungen vollständig später** als separater Task wenn gewünscht.

---

## IHRE ENTSCHEIDUNG

**Option 1:** Komprimierter Ansatz (schnell, fokussiert)
**Option 2:** Alle Übersetzungen jetzt fixen (vollständig, zeitaufwändig)
**Option 3:** Etwas anderes priorisieren

Was bevorzugen Sie?

