# Frontend Audit Report - Villa Sun App

## CRITICAL ISSUES FOUND

### 1. **MISSING DATABASE TYPE DEFINITIONS** 🔴 CRITICAL
**Problem:** Only `tasks` table has TypeScript types. 24 other tables have NO types!

**Missing Types:**
- chat_messages
- check_ins
- checklist_instances
- checklist_items
- checklists
- daily_point_goals
- departure_requests
- fortune_wheel_spins
- how_to_documents
- how_to_steps
- humor_modules
- notes
- notifications
- patrol_locations
- patrol_rounds
- patrol_scans
- patrol_schedules
- points_history
- profiles
- quiz_highscores
- read_receipts
- schedules
- shopping_items
- tutorial_slides

**Impact:** 100+ TypeScript errors, no type safety, queries fail silently

**Fix:** Generate complete database.types.ts from actual schema

---

### 2. **CHECKLISTS TABLE - FIELD MISMATCH** 🔴 CRITICAL

**Database has:**
```sql
- photo_requirement (text) -- Values: 'always', 'sometimes', 'never'
- photo_explanation (jsonb or text)
```

**Frontend tries to write:**
```typescript
- photo_required (boolean) ❌ DOES NOT EXIST
- photo_required_sometimes (boolean) ❌ DOES NOT EXIST
- photo_explanation_text (text) ❌ DOES NOT EXIST
```

**Files affected:**
- Checklists.tsx (lines 55, 175, 205, 238, 265, 585-617)

**Impact:** Data is NOT being saved to database!

**Fix Required:**
1. Either add columns to DB: `photo_required`, `photo_required_sometimes`, `photo_explanation_text`
2. OR change frontend to use: `photo_requirement` (text with values 'always'/'sometimes'/'never')

---

### 3. **TASKS TABLE - POSSIBLE PHOTO FIELD ISSUES** 🟡 WARNING

**Database has:**
```sql
- photo_url (text) -- Single photo
- photo_urls (jsonb) -- Multiple photos
- photo_explanation_text (text) ✅
- description_photo (jsonb) ✅
- admin_photos (jsonb) ✅
```

**Frontend may reference:**
- photo_proof_required (needs verification)
- photo_required_sometimes (needs verification)

**Status:** Needs deeper audit

---

### 4. **UNUSED IMPORTS** 🟡 WARNING

**Files with unused imports (from typecheck):**
- App.tsx: CheckInApproval
- AdminDashboard.tsx: CheckInOverview, color, createTask, addPoints, staffProfiles, completedTasks
- Chat.tsx: (complex insert issues)
- CheckInHistory.tsx: Download
- DepartureRequestAdmin.tsx: All imports unused
- EmployeeManagement.tsx: Mail
- EndOfDayRequest.tsx: isSameDay, schedules, error
- FortuneWheel.tsx: selectRandomSegment
- HumorModuleSettings.tsx: ArrowLeft, onBack
- Leaderboard.tsx: TrendingUp
- Many more...

**Impact:** Slower build times, confusion

---

### 5. **UNUSED STATE VARIABLES** 🟡 WARNING

Examples from typecheck:
- Dashboard.tsx: tasks, schedules
- PerformanceMetrics.tsx: teamEstimatedTime, staffProfiles, estimatedTimeMinutes
- PhotoRequirementDice.tsx: Camera
- And many more...

**Impact:** Wasted memory, confusion

---

### 6. **INCONSISTENT FIELD NAMING** 🟡 WARNING

**Pattern Issues:**
- Some use `_photo` (singular)
- Some use `_photos` (plural jsonb array)
- Some use `photo_` prefix
- Some use `_photo_` infix

**Recommendation:** Standardize naming:
- Single photo: `{field}_photo_url` (text)
- Multiple photos: `{field}_photos` (jsonb array)
- Example text: `photo_explanation_text` (text)

---

## FIXES COMPLETED ✅

1. ✅ Removed duplicate `explanation_photo` and `photo_explanation` from tasks table
2. ✅ Cleaned up Tasks.tsx - removed non-existent explanation_photo upload
3. ✅ Fixed Checklists.tsx - removed descriptionPhoto state
4. ✅ Fixed PerformanceMetrics.tsx - removed explanation_photo from query
5. ✅ PatrolRounds.tsx already correct with photo_explanation

---

## RECOMMENDED ACTION PLAN

### Phase 1: Database Type Generation (HIGH PRIORITY)
1. Generate complete database.types.ts for all 25 tables
2. Use Supabase CLI or manual schema extraction
3. Replace current minimal database.types.ts

### Phase 2: Fix Checklists Schema Mismatch (HIGH PRIORITY)
**Option A - Add DB columns (RECOMMENDED):**
```sql
ALTER TABLE checklists
ADD COLUMN photo_required boolean DEFAULT false,
ADD COLUMN photo_required_sometimes boolean DEFAULT false,
ADD COLUMN photo_explanation_text text;
```

**Option B - Update Frontend:**
Change Checklists.tsx to use:
```typescript
photo_requirement: 'always' | 'sometimes' | 'never'
```

### Phase 3: Remove Unused Code (MEDIUM PRIORITY)
1. Remove all unused imports (50+ instances)
2. Remove all unused state variables (30+ instances)
3. Remove unused functions

### Phase 4: Type Safety Enforcement (MEDIUM PRIORITY)
1. Fix all TypeScript errors (100+)
2. Enable strict mode
3. Add proper null checks

### Phase 5: Code Consolidation (LOW PRIORITY)
1. Extract duplicate utility functions
2. Standardize field naming conventions
3. Create shared types/interfaces

---

## ESTIMATED EFFORT

- **Phase 1:** 2-3 hours (automated + manual review)
- **Phase 2:** 30 minutes (choose option + implement)
- **Phase 3:** 3-4 hours (manual cleanup)
- **Phase 4:** 4-5 hours (fix errors)
- **Phase 5:** 2-3 hours (refactoring)

**Total:** ~12-15 hours

---

## IMMEDIATE NEXT STEPS

1. **DECIDE:** Checklists schema - add columns to DB or change frontend?
2. **GENERATE:** Complete database.types.ts
3. **FIX:** TypeScript errors blocking builds
4. **TEST:** Ensure all features work after fixes

