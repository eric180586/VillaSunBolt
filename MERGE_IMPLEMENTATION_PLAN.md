# Tasks & Checklists Merge - Vollständiger Implementierungsplan

## IST-ZUSTAND (Was wurde gemacht)
✅ Database: checklist_instances + checklists Tabellen wurden gelöscht
✅ Database: Daten wurden in tasks Tabelle migriert
✅ Database: Point calculation functions verwenden nur tasks
✅ useChecklists Hook: Liest Templates aus tasks
✅ Checklists.tsx: Erstellt Templates in tasks Tabelle

## FEHLT NOCH (Kritisch)

### 1. Tasks.tsx - Vereinheitlichtes UI
**Problem:** Code zeigt noch separaten checklist_instances Code
**Lösung:**
- Tasks mit `items !== null && items.length > 0` sind Checklists
- Beim Klick "Me Do Already" auf Task mit items → Modal mit Items-Liste öffnen
- User kann Items abhaken
- Bei Completion → Helper-Popup zeigen
- Nach Helper-Auswahl → complete_task_with_helper() RPC aufrufen

### 2. Task Completion Modal - Items Support
**Problem:** showCompleteModal zeigt keine items
**Lösung:**
- In TaskCompletionModal items anzeigen
- Items abhakbar machen
- Nur wenn alle items completed → "Complete" Button aktivieren

### 3. Helper Popup
**Problem:** Erscheint nie
**Lösung:**
- Nach items completion → Popup "Hattest du Hilfe?"
- Ja → Mitarbeiter-Liste zeigen
- Nein → Direkt complete
- Complete mit helper_id → complete_task_with_helper(task_id, helper_id)

### 4. Admin - Template Management
**Problem:** Admin kann Templates nicht öffnen/löschen
**Lösung:**
- In Tasks view: Templates mit Badge "Template" markieren
- Click auf Template → Edit Modal (wie bei Checklists.tsx)
- Delete Button → tasks.delete()

### 5. Task Display Logic
**Problem:** UI unterscheidet nicht zwischen Task/Checklist
**Lösung:**
```typescript
const isChecklist = (task) => task.items && task.items.length > 0;
const isTemplate = (task) => task.is_template === true;
```

## GEPLANTE ÄNDERUNGEN

### Tasks.tsx
1. Remove: Alle checklist_instances Code
2. Add: `isChecklist()` helper function
3. Change: "Me Do Already" button logic
   - If isChecklist → open items modal
   - Else → existing logic
4. Add: Items completion modal
5. Add: Helper selection popup
6. Add: Template editing support

### TaskCompletionModal.tsx (oder inline)
1. Show items if task has items
2. Allow checking items
3. Disable complete until all checked
4. After complete → show helper popup

### Helper Selection Component
1. New component: HelperSelectionModal
2. Shows all staff members
3. "No Helper" option
4. Calls complete_task_with_helper

## IMPLEMENTIERUNGS-REIHENFOLGE
1. Helper Selection Modal (neu)
2. Task Completion mit Items Support
3. Tasks.tsx cleanup (remove checklist code)
4. Template editing support
5. Testing

## TESTING CHECKLIST
- [ ] Staff kann Task mit items öffnen
- [ ] Staff kann items abhaken
- [ ] Staff kann Task mit items completen
- [ ] Helper Popup erscheint
- [ ] Points werden korrekt gesplittet bei Helper
- [ ] Admin kann Templates öffnen
- [ ] Admin kann Templates bearbeiten
- [ ] Admin kann Templates löschen
- [ ] Admin kann Tasks mit items reviewen
- [ ] "Again and Again" template generiert täglich neue Instanzen
