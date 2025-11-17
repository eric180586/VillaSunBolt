# Timezone Handling in VillaSun App

**Cambodia Timezone: Asia/Phnom_Penh (UTC+7)**

## ✅ CORRECT Approach

### Database Functions
```sql
-- CORRECT: Store actual UTC time
v_check_in_time := NOW();  -- Stores UTC

-- CORRECT: Convert to Cambodia timezone only for calculations
v_cambodia_time := v_check_in_time AT TIME ZONE 'Asia/Phnom_Penh';
v_check_in_date := DATE(v_cambodia_time);
v_actual_check_in_time := v_cambodia_time::time;

-- CORRECT: Store UTC time in database
INSERT INTO check_ins (check_in_time) VALUES (v_check_in_time);  -- UTC
```

### Frontend Display
```typescript
// CORRECT: Use toLocaleTimeString with timeZone option
{new Date(checkIn.check_in_time).toLocaleTimeString('de-DE', {
  timeZone: 'Asia/Phnom_Penh',
  hour: '2-digit',
  minute: '2-digit'
})}

// CORRECT: Use helper functions from dateUtils.ts
import { toLocaleTimeStringCambodia } from '../lib/dateUtils';
{toLocaleTimeStringCambodia(checkIn.check_in_time, 'de-DE')}
```

## ❌ WRONG Approach

### Database Functions
```sql
-- WRONG: Converts UTC to Cambodia time, then stores as UTC
v_check_in_time := now() AT TIME ZONE 'Asia/Phnom_Penh';
-- Result: 13:08 Cambodia → stored as 13:08 UTC → displays as 20:08 Cambodia
```

### Frontend Display
```typescript
// WRONG: Uses browser's local timezone
{new Date(checkIn.check_in_time).toLocaleTimeString('de-DE')}
// Will display different times based on user's browser timezone
```

## Status of Current Implementation

### ✅ VERIFIED CORRECT
1. **process_check_in** function - Stores UTC, converts for calculations ✅
2. **approve_check_in** function - Converts UTC to Cambodia for calculations ✅
3. **CheckIn.tsx** - Uses timeZone: 'Asia/Phnom_Penh' ✅
4. **CheckInOverview.tsx** - Uses timeZone: 'Asia/Phnom_Penh' ✅
5. **CheckInApproval.tsx** - Uses toLocaleTimeStringCambodia helper ✅
6. **dateUtils.ts** - All helper functions use Asia/Phnom_Penh ✅

### ⚠️ LESS CRITICAL (Non-Check-In times)
These components display `created_at` timestamps which are less critical:
- DepartureRequestAdmin
- EmployeeManagement
- Notifications
- Notes
- Profile
- Schedules

**Note:** These are not time-sensitive for business logic, but could be improved for consistency.

## Testing

To verify timezone is correct:
```sql
-- Check current DB time
SELECT
  NOW() as utc_time,
  NOW() AT TIME ZONE 'Asia/Phnom_Penh' as cambodia_time;

-- Check a specific check-in
SELECT
  check_in_time,
  check_in_time AT TIME ZONE 'Asia/Phnom_Penh' as cambodia_display
FROM check_ins
WHERE id = 'xxx';
```

Expected result at 13:08 Cambodia time:
- `utc_time`: 2025-11-17 06:08:00+00
- `cambodia_time`: 2025-11-17 13:08:00

## Migration Applied
- **20251117062000_fix_checkin_timezone_correct_storage.sql** - Fixed process_check_in to store UTC time correctly

## Summary
✅ **Check-In system is NOW CORRECT**
- Database stores UTC time
- Calculations use Cambodia timezone
- Frontend displays Cambodia timezone
- All new check-ins will have correct times
