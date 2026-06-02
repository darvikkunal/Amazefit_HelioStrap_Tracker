# 📋 Node-by-Node Configuration Reference

Every node in the Kunal Health Tracker n8n workflow, with exact configuration JSON.

---

## Node 1 — Schedule Trigger

**Type:** `n8n-nodes-base.scheduleTrigger`  
**Purpose:** Fires the workflow every day at **6 AM**

```json
{
  "parameters": {
    "rule": {
      "interval": [
        {
          "triggerAtHour": 6
        }
      ]
    }
  },
  "name": "Schedule Trigger (Every Hour)",
  "type": "n8n-nodes-base.scheduleTrigger",
  "typeVersion": 1.1
}
```

---

## Node 2 — Fetch Intervals Wellness

**Type:** `n8n-nodes-base.httpRequest`  
**Purpose:** GET yesterday's wellness data from Intervals.icu

```json
{
  "parameters": {
    "method": "GET",
    "url": "=https://intervals.icu/api/v1/athlete/i598416/wellness/{{ $now.minus({days: 1}).toFormat('yyyy-MM-dd') }}",
    "authentication": "genericCredentialType",
    "genericAuthType": "httpBasicAuth",
    "options": {}
  },
  "name": "Fetch Intervals Wellness",
  "type": "n8n-nodes-base.httpRequest",
  "typeVersion": 4.4,
  "credentials": {
    "httpBasicAuth": {
      "name": "Intervals.icu API"
    }
  }
}
```

**Credential setup:**
```json
{
  "type": "httpBasicAuth",
  "name": "Intervals.icu API",
  "data": {
    "user": "API_KEY",
    "password": "YOUR_INTERVALS_API_KEY"
  }
}
```

**Expected output (single object):**
```json
{
  "id": "2026-05-29",
  "restingHR": 59,
  "hrv": 52,
  "sleepSecs": 34380,
  "sleepScore": 82,
  "sleepQuality": 2,
  "steps": 3795,
  "weight": 62,
  "atl": 81.52657,
  "atlLoad": 154
}
```

---

## Node 3 — Fetch Intervals Activities

**Type:** `n8n-nodes-base.httpRequest`  
**Purpose:** GET yesterday's workout activities from Intervals.icu

```json
{
  "parameters": {
    "method": "GET",
    "url": "=https://intervals.icu/api/v1/athlete/i598416/activities?oldest={{ $now.minus({days: 1}).toFormat('yyyy-MM-dd') }}&newest={{ $now.minus({days: 1}).toFormat('yyyy-MM-dd') }}",
    "authentication": "genericCredentialType",
    "genericAuthType": "httpBasicAuth",
    "options": {}
  },
  "name": "Fetch Activities",
  "type": "n8n-nodes-base.httpRequest",
  "typeVersion": 4.4,
  "credentials": {
    "httpBasicAuth": {
      "name": "Intervals.icu API"
    }
  }
}
```

**Expected output (array of objects):**
```json
[
  {
    "id": "i152635473",
    "name": "Night Workout",
    "type": "Workout",
    "calories": 18,
    "average_heartrate": 115,
    "device_name": "Amazfit Helio Strap"
  },
  {
    "id": "i152635468",
    "name": "Afternoon Weight Training",
    "type": "WeightTraining",
    "calories": 566,
    "average_heartrate": 119
  }
]
```

---

## Node 4 — Merge

**Type:** `n8n-nodes-base.merge`  
**Purpose:** Append wellness (Input 0) and activities (Input 1) into one list

```json
{
  "parameters": {
    "mode": "append",
    "options": {}
  },
  "name": "Merge",
  "type": "n8n-nodes-base.merge",
  "typeVersion": 3.2
}
```

**Connection wiring:**
- Wellness node → **Input 0**
- Activities node → **Input 1**

**Expected output:** 5 items (1 wellness + 4 activities)

---

## Node 5 — Code in JavaScript (Map → Supabase Shape)

**Type:** `n8n-nodes-base.code`  
**Purpose:** Merge wellness + activities into one clean object for Supabase

```json
{
  "parameters": {
    "mode": "runOnceForAllItems",
    "jsCode": "const all = $input.all();\nconst wellness = all[0].json;\nconst activities = all.slice(1).map(i => i.json);\n\nlet totalCalories = 0;\nlet avgHRSum = 0;\nlet avgHRCount = 0;\nconst workoutNames = [];\n\nfor (const act of activities) {\n  if (act.calories)          totalCalories += act.calories;\n  if (act.average_heartrate) {\n    avgHRSum   += act.average_heartrate;\n    avgHRCount += 1;\n  }\n  if (act.name) workoutNames.push(`${act.name} (${act.type})`);\n}\n\nconst sleepHours = wellness.sleepSecs\n  ? Math.round((wellness.sleepSecs / 3600) * 100) / 100\n  : null;\n\nreturn [{\n  json: {\n    report_date:     wellness.id,\n    steps:           wellness.steps        ?? null,\n    resting_hr:      wellness.restingHR    ?? null,\n    hrv_avg:         wellness.hrv          ?? null,\n    hrv_min:         null,\n    hrv_max:         null,\n    spo2_avg:        wellness.spO2         ?? null,\n    spo2_min:        null,\n    sleep_hours:     sleepHours,\n    sleep_deep_min:  null,\n    sleep_rem_min:   null,\n    sleep_light_min: null,\n    sleep_awake_min: null,\n    calories:        totalCalories         || null,\n    distance_km:     null,\n    resp_rate:       wellness.respiration  ?? null,\n    sleep_score:     wellness.sleepScore   ?? null,\n    sleep_quality:   wellness.sleepQuality ?? null,\n    weight:          wellness.weight       ?? null,\n    workout_count:   activities.length,\n    workout_names:   workoutNames.join(', ') || 'Rest day',\n    workout_avg_hr:  avgHRCount > 0\n                       ? Math.round(avgHRSum / avgHRCount)\n                       : null,\n    atl:             wellness.atl          ?? null,\n    atl_load:        wellness.atlLoad      ?? null,\n  }\n}];"
  },
  "name": "Code in JavaScript",
  "type": "n8n-nodes-base.code",
  "typeVersion": 2
}
```

**JavaScript (readable):**
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

**Expected output (1 item):**
```json
{
  "report_date": "2026-05-29",
  "steps": 3795,
  "resting_hr": 59,
  "hrv_avg": 52,
  "sleep_hours": 9.55,
  "sleep_score": 82,
  "sleep_quality": 2,
  "calories": 660,
  "weight": 62,
  "workout_count": 4,
  "workout_names": "Night Workout (Workout), Evening Workout (Workout), Afternoon Weight Training (WeightTraining), Morning Workout (Workout)",
  "workout_avg_hr": 116,
  "atl": 81.52657,
  "atl_load": 154
}
```

---

## Node 6 — Save to Supabase (via Postgres)

**Type:** `n8n-nodes-base.postgres`  
**Purpose:** Upsert daily metrics into Supabase on `report_date` (uses Postgres node)

```json
{
  "parameters": {
    "operation": "upsert",
    "schema": {
      "mode": "list",
      "value": "public"
    },
    "table": {
      "mode": "list",
      "value": "daily_health_metrics"
    },
    "columns": {
      "mappingMode": "defineBelow",
      "value": {
        "report_date":    "={{ $json.report_date }}",
        "steps":          "={{ $json.steps }}",
        "resting_hr":     "={{ $json.resting_hr }}",
        "hrv_avg":        "={{ $json.hrv_avg }}",
        "hrv_min":        "={{ $json.hrv_min }}",
        "hrv_max":        "={{ $json.hrv_max }}",
        "spo2_avg":       "={{ $json.spo2_avg }}",
        "spo2_min":       "={{ $json.spo2_min }}",
        "sleep_hours":    "={{ $json.sleep_hours }}",
        "sleep_deep_min": "={{ $json.sleep_deep_min }}",
        "sleep_rem_min":  "={{ $json.sleep_rem_min }}",
        "sleep_light_min":"={{ $json.sleep_light_min }}",
        "sleep_awake_min":"={{ $json.sleep_awake_min }}",
        "calories":       "={{ $json.calories }}",
        "distance_km":    "={{ $json.distance_km }}",
        "resp_rate":      "={{ $json.resp_rate }}",
        "sleep_score":    "={{ $json.sleep_score }}",
        "sleep_quality":  "={{ $json.sleep_quality }}",
        "weight":         "={{ $json.weight }}",
        "workout_count":  "={{ $json.workout_count }}",
        "workout_names":  "={{ $json.workout_names }}",
        "workout_avg_hr": "={{ $json.workout_avg_hr }}",
        "atl":            "={{ $json.atl }}",
        "atl_load":       "={{ $json.atl_load }}"
      },
      "matchingColumns": ["report_date"]
    }
  },
  "name": "Save to Supabase",
  "type": "n8n-nodes-base.postgres",
  "typeVersion": 2.5
}
```

**Credential setup:** Uses a Postgres credential pointing to your Supabase project's connection string.

---

## Node 7 — Build Gemini Prompt (Advanced)

**Type:** `n8n-nodes-base.code`  
**Purpose:** Format health data + workout plan into a 7-section AI coaching prompt

The prompt includes:
- PPL A/B workout split for each day of the week
- HRV-based recovery flagging (FATIGUED / MODERATE / RECOVERED)
- Sleep quality flagging (POOR / AVERAGE / GOOD)
- Kunal's approved YouTube creators library for daily video recommendations
- 7 structured sections: Yesterday Recap, Win of the Day, One Thing to Fix, Today's Targets, Watch This Today, Recovery Intelligence, Tonight's Sleep Target

```json
{
  "parameters": {
    "mode": "runOnceForAllItems",
    "jsCode": "// See node file n8n/nodes/07_build_gemini_prompt.json for full code"
  },
  "name": "Build Gemini Prompt",
  "type": "n8n-nodes-base.code",
  "typeVersion": 2
}
```

**Key variables in prompt:**
- `workoutSplit` — maps each day to PPL A/B exercises with drop set finishers
- `todayWorkout` — today's scheduled session
- `hrvFlag` — "RECOVERED — go all out" / "MODERATE — train but pace yourself" / "FATIGUED — reduce volume"
- `sleepFlag` — "GOOD — fully ready" / "AVERAGE — normal training ok" / "POOR — flag recovery"
- `creatorsLibrary` — 18 approved YouTube creators organized by category

---

## Node 8 — HTTP Request (OpenRouter API)

**Type:** `n8n-nodes-base.httpRequest`  
**Purpose:** Call OpenRouter API (routes to best available free model)

```json
{
  "parameters": {
    "method": "POST",
    "url": "https://openrouter.ai/api/v1/chat/completions",
    "sendHeaders": true,
    "headerParameters": {
      "parameters": [
        {
          "name": "Authorization",
          "value": "Bearer YOUR_OPENROUTER_API_KEY"
        },
        {
          "name": "HTTP-Referer",
          "value": "https://your-n8n-instance.com"
        },
        {
          "name": "X-Title",
          "value": "Kunal Health Coach"
        }
      ]
    },
    "sendBody": true,
    "specifyBody": "json",
    "jsonBody": "={\n  \"model\": \"openrouter/free\",\n  \"messages\": [\n    { \"role\": \"user\", \"content\": \"={{ $json.prompt }}\" }\n  ],\n  \"max_tokens\": 2048,\n  \"transforms\": [\"middle-out\"],\n  \"route\": \"fallback\"\n}",
    "options": {}
  },
  "name": "HTTP Request",
  "type": "n8n-nodes-base.httpRequest",
  "typeVersion": 4.4,
  "retryOnFail": true,
  "waitBetweenTries": 5000
}
```

**Request headers:**
- `Authorization: Bearer {key}` — OpenRouter API key
- `HTTP-Referer` — your n8n instance URL (for OpenRouter rankings)
- `X-Title: Kunal Health Coach` — identifies your app in OpenRouter logs

**Request body features:**
- `model: openrouter/free` — uses the best available free model
- `transforms: ["middle-out"]` — model router pattern
- `route: "fallback"` — falls through providers on failure
- `max_tokens: 2048` — prevents response cutoff

**Expected output:**
```json
{
  "choices": [
    {
      "message": {
        "content": "1. 🌅 YESTERDAY RECAP...",
        "reasoning": "..."
      }
    }
  ]
}
```

---

## Node 9 — Format Email + WhatsApp Message (Advanced)

**Type:** `n8n-nodes-base.code`  
**Purpose:** Extract AI text, filter reasoning tokens, build HTML email and Telegram message

```json
{
  "parameters": {
    "mode": "runOnceForAllItems",
    "jsCode": "// See node file n8n/nodes/09_format_email_telegram.json for full code"
  },
  "name": "Format Email + WhatsApp Message",
  "type": "n8n-nodes-base.code",
  "typeVersion": 2
}
```

**AI Text Extraction:**
- Reads `choices[0].message.content` (OpenRouter format)
- Falls back to `choices[0].message.reasoning` if content is empty/short
- Strips `<think>` reasoning tags
- Removes meta-text lines (e.g. "Let me draft...", "Section 1...", "Must include...")
- Normalizes excessive newlines

**HTML Email Features:**
- Dark header with "Kunal's Daily Health Brief" branding
- Today's session banner (e.g. "Monday → Chest & Triceps")
- Color-coded metrics grid (green/amber/red based on targets):
  - Steps (goal: 9,000) — red <5k, amber 5k-8k, green >8k
  - Calories, Resting HR, HRV (color-coded), Sleep hours, Sleep score, Workout HR, Weight, Sessions
- Steps progress bar toward 9,000 goal
- Workout names banner (if applicable)
- AI coach brief with formatted sections
- Pipeline footer

**Telegram Message Features:**
- Markdown-formatted (bold headers, italic footer)
- Yesterday's numbers with emoji indicators (✅⚠️❌)
- Full AI coach text (stripped of markdown formatting for safety)

---

## Node 10 — Send Gmail Report

**Type:** `n8n-nodes-base.gmail`  
**Purpose:** Send HTML email to Gmail

```json
{
  "parameters": {
    "sendTo": "darvikkunal@gmail.com",
    "subject": "=🏃 Daily Health Report — {{ $json.report_date }}",
    "message": "={{ $json.htmlEmail }}",
    "options": {}
  },
  "name": "Send Gmail Report",
  "type": "n8n-nodes-base.gmail",
  "typeVersion": 2.1,
  "credentials": {
    "gmailOAuth2": {
      "name": "Gmail account"
    }
  }
}
```

---

## Node 11 — Send Telegram

**Type:** `n8n-nodes-base.httpRequest`  
**Purpose:** Send health summary to Telegram bot with Markdown formatting

```json
{
  "parameters": {
    "method": "GET",
    "url": "https://api.telegram.org/botYOUR_BOT_TOKEN/sendMessage",
    "sendQuery": true,
    "queryParameters": {
      "parameters": [
        {
          "name": "chat_id",
          "value": "YOUR_CHAT_ID"
        },
        {
          "name": "text",
          "value": "={{ $json.whatsappMsg }}"
        },
        {
          "name": "parse_mode",
          "value": "Markdown"
        }
      ]
    },
    "options": {}
  },
  "name": "Send Telegram via kunalhealth_bot",
  "type": "n8n-nodes-base.httpRequest",
  "typeVersion": 4.2
}
```

**Expected output:**
```json
{
  "ok": true,
  "result": {
    "message_id": 4,
    "chat": {
      "id": "YOUR_CHAT_ID",
      "first_name": "Kunal"
    },
    "text": "💪 *Kunal's Health Brief — 2026-05-29*..."
  }
}
```

---

## Connection Map

```
Schedule Trigger (6 AM)
    ├──→ Fetch Intervals Wellness  → Merge (Input 0)
    └──→ Fetch Intervals Activities → Merge (Input 1)
                                        ↓
                                  Code in JavaScript
                                        ↓
                              Save to Supabase (Postgres)
                                        ↓
                              Build Gemini Prompt (Advanced)
                                        ↓
                              HTTP Request (OpenRouter API)
                                        ↓
                              Format Email + WhatsApp (Advanced)
                                   ↙        ↘
                            Send Gmail    Send Telegram
```

---

## Key Differences from Earlier Version

| Aspect | Previous | Current (Live) |
|---|---|---|
| Schedule | 9 AM | **6 AM** |
| DB Node | Supabase | **Postgres** (connecting to Supabase) |
| AI Provider | Gemini 2.5 Flash | **OpenRouter** (openrouter/free) |
| AI Response Path | `candidates[0].content.parts[0].text` | **`choices[0].message.content`** |
| Prompt | Simple 5-section | **Advanced 7-section with workout splits** |
| Email Template | 9-metric grid | **Color-coded grid + session banner + progress bar** |
| Telegram Params | `sendQueryParameters` | **`sendQuery`** |
| Telegram Mode | None | **`parse_mode: Markdown`** |
| Reasoning Filter | None | **Strips `<think>` tags + meta-text** |
| Retry on Fail | None | **Enabled with 5s wait** |
