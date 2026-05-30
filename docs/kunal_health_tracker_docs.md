# 🏃 Kunal Health Tracker — Project Documentation

> Fully automated personal health intelligence pipeline. No manual exports. No uploads. Just wake up and read your report.

---

## 📋 Table of Contents

1. [Project Overview](#overview)
2. [Architecture](#architecture)
3. [Tech Stack](#tech-stack)
4. [Data Sources](#data-sources)
5. [Pipeline Walkthrough](#pipeline)
6. [API Reference](#api-reference)
7. [Supabase Schema](#supabase-schema)
8. [n8n Workflow](#n8n-workflow)
9. [Node Configurations](#node-configs)
10. [Gemini Prompt](#gemini-prompt)
11. [Output Formats](#output-formats)
12. [Credentials & Keys](#credentials)
13. [Troubleshooting](#troubleshooting)
14. [Future Improvements](#future)

---

## 🎯 Project Overview {#overview}

**Goal:** Build a fully automated daily health report pipeline that collects biometric data from an Amazfit Helio Strap, processes it through AI, and delivers a personalized health summary every morning.

**Trigger:** Every day at **9 AM** the workflow fetches the previous day's complete data.

**Deliverables:**
- 📧 HTML email report to Gmail
- 📱 Summary message to Telegram

**What makes this different:**
- Zero manual intervention — data flows automatically from wrist to inbox
- AI-generated personalized insights (not just raw numbers)
- Historical data stored in Supabase for trend analysis
- Accurate data source — Intervals.icu syncs directly from Zepp

---

## 🏗️ Architecture {#architecture}

```
Amazfit Helio Strap
        ↓ (auto BLE sync)
     Zepp App
        ↓ (OAuth integration)
   Intervals.icu
        ↓ (REST API)
       n8n
    ↙        ↘
Wellness    Activities
API call    API call
    ↘        ↙
      Merge
        ↓
  Code Node (JS)
  Field mapping
        ↓
    Supabase
  daily_health_metrics
        ↓
  Build Gemini Prompt
        ↓
  Gemini 2.5 Flash
        ↓
  Format Email + Telegram
        ↓              ↓
    Gmail           Telegram
  HTML Report      Text Summary
```

---

## 🛠️ Tech Stack {#tech-stack}

| Component | Tool | Purpose |
|---|---|---|
| Wearable | Amazfit Helio Strap | Heart rate, HRV, sleep, steps |
| Mobile App | Zepp (Huami) | Device sync + data aggregation |
| Health Platform | Intervals.icu | Data hub + REST API |
| Automation | n8n (self-hosted) | Workflow orchestration |
| Database | Supabase (PostgreSQL) | Historical data storage |
| AI | Google Gemini 2.5 Flash | Health summary generation |
| Email | Gmail (OAuth) | HTML report delivery |
| Messaging | Telegram Bot API | Daily summary delivery |

---

## 📊 Data Sources {#data-sources}

### Wellness Endpoint
```
GET /api/v1/athlete/i598416/wellness/{date}
```
Returns daily aggregated wellness metrics:

| Field | Description |
|---|---|
| `steps` | Total steps for the day |
| `restingHR` | Resting heart rate (bpm) |
| `hrv` | HRV RMSSD (ms) |
| `sleepSecs` | Total sleep in seconds |
| `sleepScore` | Sleep score 0-100 |
| `sleepQuality` | 1=Excellent → 5=Very Poor |
| `spO2` | Blood oxygen % |
| `respiration` | Breathing rate |
| `weight` | Body weight (kg) |
| `atl` | Acute Training Load |
| `atlLoad` | Training load value |

### Activities Endpoint
```
GET /api/v1/athlete/i598416/activities?oldest={date}&newest={date}
```
Returns array of individual workout sessions:

| Field | Description |
|---|---|
| `name` | Workout name (e.g. "Morning Workout") |
| `type` | Type (Workout, WeightTraining, etc.) |
| `calories` | Calories burned |
| `average_heartrate` | Avg HR during workout |
| `icu_distance` | Distance in meters |
| `icu_training_load` | Session training load |
| `device_name` | "Amazfit Helio Strap" |

---

## 🔄 Pipeline Walkthrough {#pipeline}

### Step 1 — Schedule Trigger
- Fires every day at **9 AM**
- Fetches data for **yesterday** (`$now.minus({days: 1})`)
- Reason: yesterday's data is complete (sleep finished, workouts synced)

### Step 2 — Fetch Intervals Wellness
- HTTP GET to Intervals.icu wellness endpoint
- Auth: Basic Auth (`API_KEY` / api_key_value)
- Returns single wellness object

### Step 3 — Fetch Intervals Activities
- HTTP GET to Intervals.icu activities endpoint
- Same auth as wellness
- Returns array of workout objects for the day

### Step 4 — Merge (Append)
- Mode: **Append** (not Combine)
- Wellness = item[0]
- Activities = items[1..N]
- Output: 1 wellness + N activity items

### Step 5 — Code Node (Map → Supabase Shape)
- Takes all items from Merge
- `item[0]` = wellness data
- `items.slice(1)` = activity array
- Sums calories across all activities
- Averages heart rate across all workouts
- Converts `sleepSecs` → `sleep_hours`
- Outputs single clean mapped object

### Step 6 — Save to Supabase
- Operation: **Upsert** on `report_date`
- If row exists for that date → update
- If not → insert
- Preserves historical data

### Step 7 — Build Gemini Prompt
- Formats all health data into a structured prompt
- Includes sleep quality label mapping (1=Excellent, 2=Good, etc.)
- Cleans `report_date` to `YYYY-MM-DD` format

### Step 8 — HTTP Request (Gemini API)
- POST to Gemini 2.5 Flash
- `maxOutputTokens: 2048` (prevents cutoff)
- `temperature: 0.7`
- Returns AI-generated health summary

### Step 9 — Format Email + Telegram
- Extracts AI text from Gemini response
- Builds HTML email with 9-metric grid
- Builds Telegram message with key stats + full AI summary

### Step 10 — Send Gmail
- Sends HTML email to `darvikkunal@gmail.com`
- Subject: `🏃 Daily Health Report — {date}`

### Step 11 — Send Telegram
- GET to Telegram Bot API
- `chat_id`: 7608056243
- `text`: full health summary message

---

## 🌐 API Reference {#api-reference}

### Intervals.icu Authentication
```
Type: HTTP Basic Auth
Username: API_KEY
Password: {your_api_key}
```

Base64 encoded header:
```
Authorization: Basic QVBJX0tFWTo...
```

### Intervals.icu Endpoints Used

```bash
# Athlete profile
GET https://intervals.icu/api/v1/athlete/i598416

# Single day wellness
GET https://intervals.icu/api/v1/athlete/i598416/wellness/2026-05-29

# Date range wellness
GET https://intervals.icu/api/v1/athlete/i598416/wellness?oldest=2026-05-20&newest=2026-05-30

# Activities for a day
GET https://intervals.icu/api/v1/athlete/i598416/activities?oldest=2026-05-29&newest=2026-05-29
```

### Gemini API
```
POST https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key={API_KEY}

Body:
{
  "contents": [{"parts": [{"text": "{prompt}"}]}],
  "generationConfig": {
    "temperature": 0.7,
    "maxOutputTokens": 2048
  }
}
```

### Telegram Bot API
```
GET https://api.telegram.org/bot{TOKEN}/sendMessage?chat_id={CHAT_ID}&text={MESSAGE}
```

---

## 🗄️ Supabase Schema {#supabase-schema}

### Table: `daily_health_metrics`

```sql
CREATE TABLE IF NOT EXISTS daily_health_metrics (
  id                SERIAL PRIMARY KEY,
  report_date       DATE UNIQUE NOT NULL,

  -- Activity
  steps             INTEGER,
  distance_km       NUMERIC(6,2),
  calories          INTEGER,

  -- Heart
  resting_hr        INTEGER,
  hrv_avg           NUMERIC(6,1),
  hrv_min           NUMERIC(6,1),
  hrv_max           NUMERIC(6,1),

  -- Oxygen & Breathing
  spo2_avg          NUMERIC(5,1),
  spo2_min          NUMERIC(5,1),
  resp_rate         NUMERIC(5,1),

  -- Sleep
  sleep_hours       NUMERIC(4,1),
  sleep_score       NUMERIC,
  sleep_quality     INTEGER,
  sleep_deep_min    INTEGER,
  sleep_rem_min     INTEGER,
  sleep_light_min   INTEGER,
  sleep_awake_min   INTEGER,

  -- Body
  weight            NUMERIC,

  -- Workouts
  workout_count     INTEGER,
  workout_names     TEXT,
  workout_avg_hr    INTEGER,

  -- Training Load
  atl               NUMERIC,
  atl_load          NUMERIC,

  -- Metadata
  created_at        TIMESTAMPTZ DEFAULT NOW(),
  updated_at        TIMESTAMPTZ DEFAULT NOW()
);
```

### Upsert Key
```
report_date (UNIQUE) — one row per day
```

### Indexes
```sql
CREATE INDEX IF NOT EXISTS idx_health_date
  ON daily_health_metrics (report_date DESC);
```

---

## ⚙️ n8n Workflow {#n8n-workflow}

**Workflow name:** Kunal Health Tracker  
**Status:** Published / Active  
**Schedule:** Daily at 9:00 AM  
**n8n version:** 2.22.5 (Self Hosted)

### Node List

| # | Node | Type | Purpose |
|---|---|---|---|
| 1 | Schedule Trigger | scheduleTrigger | Fires at 9 AM daily |
| 2 | Fetch Intervals Wellness | httpRequest | GET wellness data |
| 3 | Fetch Intervals Activities | httpRequest | GET activity data |
| 4 | Merge | merge | Append both inputs |
| 5 | Code in JavaScript | code | Map + transform fields |
| 6 | Save to Supabase | supabase | Upsert daily metrics |
| 7 | Build Gemini Prompt | code | Format AI prompt |
| 8 | HTTP Request (Gemini) | httpRequest | Call Gemini API |
| 9 | Format Email + WhatsApp | code | Build HTML + message |
| 10 | Send Gmail Report | gmail | Deliver HTML email |
| 11 | Send Telegram | httpRequest | Deliver Telegram message |

---

## 🔧 Node Configurations {#node-configs}

### Fetch Intervals Wellness
```json
{
  "method": "GET",
  "url": "https://intervals.icu/api/v1/athlete/i598416/wellness/{{ $now.minus({days: 1}).toFormat('yyyy-MM-dd') }}",
  "authentication": "genericCredentialType",
  "genericAuthType": "httpBasicAuth"
}
```

### Fetch Intervals Activities
```json
{
  "method": "GET",
  "url": "https://intervals.icu/api/v1/athlete/i598416/activities?oldest={{ $now.minus({days: 1}).toFormat('yyyy-MM-dd') }}&newest={{ $now.minus({days: 1}).toFormat('yyyy-MM-dd') }}",
  "authentication": "genericCredentialType",
  "genericAuthType": "httpBasicAuth"
}
```

### Merge Node
```
Mode: Append
— Output items of each input, one after the other
— Item 0 = Wellness
— Items 1..N = Activities
```

### Code Node — Map → Supabase Shape
```javascript
const all = $input.all();
const wellness = all[0].json;
const activities = all.slice(1).map(i => i.json);

let totalCalories = 0;
let avgHRSum = 0;
let avgHRCount = 0;
const workoutNames = [];

for (const act of activities) {
  if (act.calories)          totalCalories += act.calories;
  if (act.average_heartrate) {
    avgHRSum   += act.average_heartrate;
    avgHRCount += 1;
  }
  if (act.name) workoutNames.push(`${act.name} (${act.type})`);
}

const sleepHours = wellness.sleepSecs
  ? Math.round((wellness.sleepSecs / 3600) * 100) / 100
  : null;

return [{
  json: {
    report_date:     wellness.id,
    steps:           wellness.steps        ?? null,
    resting_hr:      wellness.restingHR    ?? null,
    hrv_avg:         wellness.hrv          ?? null,
    hrv_min:         null,
    hrv_max:         null,
    spo2_avg:        wellness.spO2         ?? null,
    spo2_min:        null,
    sleep_hours:     sleepHours,
    sleep_deep_min:  null,
    sleep_rem_min:   null,
    sleep_light_min: null,
    sleep_awake_min: null,
    calories:        totalCalories         || null,
    distance_km:     null,
    resp_rate:       wellness.respiration  ?? null,
    sleep_score:     wellness.sleepScore   ?? null,
    sleep_quality:   wellness.sleepQuality ?? null,
    weight:          wellness.weight       ?? null,
    workout_count:   activities.length,
    workout_names:   workoutNames.join(', ') || 'Rest day',
    workout_avg_hr:  avgHRCount > 0
                       ? Math.round(avgHRSum / avgHRCount)
                       : null,
    atl:             wellness.atl          ?? null,
    atl_load:        wellness.atlLoad      ?? null,
  }
}];
```

---

## 🤖 Gemini Prompt {#gemini-prompt}

```javascript
const d = $input.first().json;
const reportDate = d.report_date
  ? d.report_date.toString().substring(0, 10)
  : 'N/A';

const sleepQualityMap = {
  1: 'Excellent', 2: 'Good', 3: 'Fair',
  4: 'Poor', 5: 'Very Poor'
};
const sleepQualityLabel = d.sleep_quality
  ? (sleepQualityMap[d.sleep_quality] ?? d.sleep_quality)
  : 'N/A';

const prompt = `You are Kunal's personal health coach...
📅 Date: ${reportDate}
📊 TODAY'S METRICS:
- Steps, Calories, HR, HRV, Sleep, Workouts...

Output structure:
1. 🌅 OVERALL STATUS
2. 💪 WHAT'S GOOD
3. ⚠️ WATCH OUT
4. 🎯 ACTION FOR TODAY
5. 💤 SLEEP INSIGHT

Under 200 words. Speak directly to Kunal.`;
```

---

## 📤 Output Formats {#output-formats}

### Gmail HTML Email
- Dark gradient header with date
- 9-metric card grid (Steps, Calories, Resting HR, HRV, Sleep Hours, Sleep Score, Workouts, Avg HR, Weight)
- Workout names banner (amber accent)
- AI summary in blue accent box
- Footer: pipeline attribution

### Telegram Message
```
🏃 Health Report — 2026-05-29

👟 Steps: 3795
🔥 Calories: 660 kcal
❤️ Resting HR: 59 bpm
🧠 HRV: 52.0 ms
💤 Sleep: 9.6h (Score: 82/100)
🏋️ Workouts: 4 sessions

{Full Gemini AI Summary}
```

---

## 🔑 Credentials & Keys {#credentials}

| Service | Credential Type | Notes |
|---|---|---|
| Intervals.icu | HTTP Basic Auth | Username: `API_KEY`, Password: api key |
| Supabase | Supabase API | Project URL + anon key |
| Gmail | OAuth2 | `eops70FmdqVZXlEw` |
| Gemini | API Key in URL | Passed as query param |
| Telegram | Bot Token in URL | No n8n credential needed |

### Key IDs
```
Athlete ID:     i598416
Telegram Chat:  7608056243
Telegram Bot:   kunalhealth_bot
```

> ⚠️ Never commit API keys to version control. Rotate the Intervals.icu key if compromised via Settings → Developer Settings.

---

## 🐛 Troubleshooting {#troubleshooting}

### CORS errors from browser
**Cause:** Intervals.icu blocks browser-origin requests  
**Fix:** Always call the API from n8n nodes or terminal — never from browser widgets

### `fetch is not defined` in Code node
**Cause:** n8n 2.22.5 task runner sandbox blocks `fetch` and `$http`  
**Fix:** Use separate HTTP Request nodes, not inline API calls in Code nodes

### Gemini response truncated (`finishReason: MAX_TOKENS`)
**Cause:** `maxOutputTokens` too low  
**Fix:** Set `maxOutputTokens: 2048` in Gemini request body

### Activities endpoint returns empty array
**Cause:** Rest day — no workouts logged  
**Fix:** Code handles this gracefully — `workout_count: 0`, `workout_names: 'Rest day'`

### Merge node producing wrong order
**Cause:** Wellness not on Input 0  
**Fix:** Ensure Wellness node connects to Input 0, Activities to Input 1 of Merge

### `report_date` shows as timestamp
**Cause:** Supabase returns `DATE` as ISO string with time  
**Fix:** Use `.toString().substring(0, 10)` to extract `YYYY-MM-DD`

---

## 🚀 Future Improvements {#future}

- [ ] **7-day trend analysis** — query Supabase for last 7 days and include in Gemini prompt
- [ ] **Weekly summary report** — Sunday recap of the full week
- [ ] **HRV trend alerts** — notify if HRV drops significantly vs 7-day average
- [ ] **Sleep stage data** — if Zepp exposes deep/REM/light via Intervals
- [ ] **Weight trend** — track weight changes over time
- [ ] **VO2 Max tracking** — when available from device
- [ ] **Dashboard** — Supabase + Metabase or Grafana visualization
- [ ] **WhatsApp** — replace Telegram if CallMeBot becomes reliable or use Twilio
- [ ] **Backfill script** — populate historical data before May 2026

---

## 📅 Project Timeline

| Date | Milestone |
|---|---|
| May 30, 2026 | Health Connect ZIP approach attempted — data mismatch discovered |
| May 30, 2026 | Intervals.icu API discovered and tested |
| May 30, 2026 | Wellness + Activities endpoints verified via curl |
| May 30, 2026 | n8n workflow rebuilt with parallel API calls |
| May 30, 2026 | Supabase schema extended with 8 new columns |
| May 30, 2026 | Gemini integration working — full AI summary |
| May 30, 2026 | Gmail HTML report delivered ✅ |
| May 30, 2026 | Telegram bot set up and delivering ✅ |
| May 30, 2026 | Workflow published and active ✅ |

---

*Built by Kunal Banda · Powered by Intervals.icu + n8n + Gemini · Last updated May 30, 2026*
