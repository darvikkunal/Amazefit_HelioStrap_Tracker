-- Create the daily_health_metrics table
CREATE TABLE IF NOT EXISTS daily_health_metrics (
  report_date    DATE PRIMARY KEY,
  steps          INTEGER,
  resting_hr     INTEGER,
  hrv_avg        DECIMAL(5,1),
  hrv_min        INTEGER,
  hrv_max        INTEGER,
  spo2_avg       DECIMAL(4,1),
  spo2_min       INTEGER,
  sleep_hours    DECIMAL(4,2),
  sleep_deep_min INTEGER,
  sleep_rem_min  INTEGER,
  sleep_light_min INTEGER,
  sleep_awake_min INTEGER,
  calories       INTEGER,
  distance_km    DECIMAL(6,2),
  resp_rate      DECIMAL(4,1),
  sleep_score    INTEGER,
  sleep_quality  INTEGER,
  weight         DECIMAL(5,1),
  workout_count  INTEGER DEFAULT 0,
  workout_names  TEXT,
  workout_avg_hr INTEGER,
  atl            DECIMAL(8,5),
  atl_load       INTEGER,
  created_at     TIMESTAMPTZ DEFAULT NOW()
);

-- Add index for fast date queries
CREATE INDEX IF NOT EXISTS idx_daily_health_metrics_date ON daily_health_metrics (report_date DESC);
