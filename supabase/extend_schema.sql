-- Extended columns for sleep_score, workout_count, etc.
-- Run this AFTER schema.sql to add columns that were added later

ALTER TABLE daily_health_metrics
  ADD COLUMN IF NOT EXISTS sleep_score    INTEGER,
  ADD COLUMN IF NOT EXISTS sleep_quality  INTEGER,
  ADD COLUMN IF NOT EXISTS weight         DECIMAL(5,1),
  ADD COLUMN IF NOT EXISTS workout_count  INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS workout_names  TEXT,
  ADD COLUMN IF NOT EXISTS workout_avg_hr INTEGER,
  ADD COLUMN IF NOT EXISTS atl            DECIMAL(8,5),
  ADD COLUMN IF NOT EXISTS atl_load       INTEGER;
