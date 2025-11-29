/*
  # Remove Duplicate schedules Table
  
  1. Changes
    - Drop unused schedules table
    - weekly_schedules is the active table in use
    - schedules table is empty and not referenced by frontend
*/

DROP TABLE IF EXISTS schedules CASCADE;
