# Next Steps for Issue Resolution

1. **Unify Points Navigation**
   - Align the Admin dashboard buttons (see `src/components/AdminDashboard.tsx`) with the side menu routes in `src/components/Layout.tsx`/`src/App.tsx` so both "Punkteverwaltung" and "Punkte" open the same `PointsManager` view.
   - Ensure the monthly overview entry points link to `MonthlyPointsOverview` consistently, avoiding duplicate menu labels.

2. **Complete Translation Coverage**
   - Run through all visible labels in `AdminDashboard`, `PointsManager`, and the menu sections in `Layout.tsx` to confirm every string uses `t(...)` with keys present in `src/locales/en.json`, `de.json`, and `km.json`.
   - Add missing keys for task summaries (e.g., "Aufgaben heute" vs. "Aufgaben gesamt") so both dashboard cards render localized text rather than fallbacks.

3. **Validate Task/Checklist Counts**
   - In `AdminDashboard.tsx`, verify the counters for daily tasks and checklists match the RPC responses and that both cards share the same date basis (current Cambodia day). If mismatched, adjust the calculation helpers in `src/lib/dateUtils.ts` or the RPC selection parameters.

4. **Standardize Alerts and Errors**
   - Review user-facing error and success messages in the points flows (`PointsManager.tsx`, `MonthlyPointsOverview.tsx`) and check-in flows (`CheckInOverview.tsx`, `CheckInHistory.tsx`) to ensure they are translated and use consistent styling (e.g., `alert-info`, `alert-error`). Centralize any repeated text in locale files.

5. **Re-test Hooks After Lint Fixes**
   - Re-run `npm run lint -- --max-warnings=0` and `npm run build` after the above fixes to confirm the memoized callbacks still satisfy exhaustive-deps and no new warnings appear from translation additions.

6. **Environment Readiness Check**
   - Populate `.env` with valid `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`, and VAPID/public key values (see `README.md`), then exercise the admin and points flows end-to-end to verify Supabase writes (check-ins, points updates) succeed with real data.
