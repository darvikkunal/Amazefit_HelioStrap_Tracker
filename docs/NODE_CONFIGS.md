# 📋 Node-by-Node Configuration Reference

Every node in the Kunal Health Tracker n8n workflow, with exact configuration JSON.

---

## Node 1 — Schedule Trigger

**Type:** `n8n-nodes-base.scheduleTrigger`  
**Purpose:** Fires the workflow every day at 9 AM

```json
{
  "parameters": {
    "rule": {
      "interval": [
        {
          "triggerAtHour": 9
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
    "device_name": " Amazfit Helio Strap"
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
  "typeVersion": 3
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

## Node 6 — Save to Supabase

**Type:** `n8n-nodes-base.supabase`  
**Purpose:** Upsert daily metrics into Supabase on `report_date`

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
  "type": "n8n-nodes-base.supabase",
  "typeVersion": 1
}
```

---

## Node 7 — Build Gemini Prompt

**Type:** `n8n-nodes-base.code`  
**Purpose:** Format all health data into a structured AI prompt

```json
{
  "parameters": {
    "mode": "runOnceForAllItems",
    "jsCode": "const d = $input.first().json;\nconst reportDate = d.report_date ? d.report_date.toString().substring(0, 10) : 'N/A';\nconst sleepQualityMap = { 1: 'Excellent', 2: 'Good', 3: 'Fair', 4: 'Poor', 5: 'Very Poor' };\nconst sleepQualityLabel = d.sleep_quality ? (sleepQualityMap[d.sleep_quality] ?? d.sleep_quality) : 'N/A';\nconst prompt = `...`;\nreturn [{ json: { prompt, ...d } }];"
  },
  "name": "Build Gemini Prompt",
  "type": "n8n-nodes-base.code",
  "typeVersion": 2
}
```

**JavaScript (readable):**
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

const prompt = `You are Kunal's personal health coach. Analyze today's biometric data from his Amazfit Helio Strap and provide an intelligent daily health summary.

📅 Date: ${reportDate}

📊 TODAY'S METRICS:
- Steps: ${d.steps ?? 'N/A'}
- Calories burned: ${d.calories ?? 'N/A'} kcal
- Resting Heart Rate: ${d.resting_hr ?? 'N/A'} bpm
- Avg Workout HR: ${d.workout_avg_hr ?? 'N/A'} bpm
- HRV (RMSSD): ${d.hrv_avg ?? 'N/A'} ms
- SpO₂: ${d.spo2_avg ?? 'N/A'}%
- Weight: ${d.weight ?? 'N/A'} kg
- Training Load (ATL): ${d.atl ? Math.round(d.atl) : 'N/A'}

🏋️ WORKOUTS TODAY (${d.workout_count ?? 0} sessions):
${d.workout_names ?? 'Rest day'}

😴 SLEEP LAST NIGHT:
- Total sleep: ${d.sleep_hours ?? 'N/A'} hours
- Sleep score: ${d.sleep_score ?? 'N/A'}/100
- Sleep quality: ${sleepQualityLabel}

Provide a friendly, concise health summary in exactly this structure:

1. 🌅 OVERALL STATUS (2 sentences — how is Kunal doing today overall)
2. 💪 WHAT'S GOOD (1-2 specific positive observations from the data)
3. ⚠️ WATCH OUT (1 thing that needs attention, if any — be honest but kind)
4. 🎯 ACTION FOR TODAY (1 clear, specific, actionable recommendation)
5. 💤 SLEEP INSIGHT (brief comment on sleep quality and score)

Keep total response under 200 words. Use the exact emojis shown. Be specific with numbers. Speak directly to Kunal.`;

return [{ json: { prompt, ...d } }];
```

---

## Node 8 — HTTP Request (Gemini API)

**Type:** `n8n-nodes-base.httpRequest`  
**Purpose:** Call Google Gemini 2.5 Flash to generate AI health summary

```json
{
  "parameters": {
    "method": "POST",
    "url": "=https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=YOUR_GEMINI_API_KEY",
    "sendBody": true,
    "specifyBody": "json",
    "jsonBody": "={{\n{\n  contents: [\n    {\n      parts: [\n        {\n          text: $json.prompt\n        }\n      ]\n    }\n  ],\n  generationConfig: {\n    temperature: 0.7,\n    maxOutputTokens: 2048\n  }\n}\n}}",
    "options": {}
  },
  "name": "HTTP Request",
  "type": "n8n-nodes-base.httpRequest",
  "typeVersion": 4.4
}
```

**Request body (readable):**
```json
{
  "contents": [
    {
      "parts": [
        {
          "text": "{{ $json.prompt }}"
        }
      ]
    }
  ],
  "generationConfig": {
    "temperature": 0.7,
    "maxOutputTokens": 2048
  }
}
```

**Expected output:**
```json
{
  "candidates": [
    {
      "content": {
        "parts": [
          {
            "text": "Hello Kunal! Here's your daily health summary:\n\n1. 🌅 OVERALL STATUS..."
          }
        ]
      },
      "finishReason": "STOP"
    }
  ]
}
```

> ⚠️ If `finishReason` is `MAX_TOKENS` instead of `STOP`, increase `maxOutputTokens` to `4096`.

---

## Node 9 — Format Email + WhatsApp Message

**Type:** `n8n-nodes-base.code`  
**Purpose:** Extract Gemini text, build HTML email and Telegram message

```json
{
  "parameters": {
    "mode": "runOnceForAllItems",
    "jsCode": "// See readable version below"
  },
  "name": "Format Email + WhatsApp Message",
  "type": "n8n-nodes-base.code",
  "typeVersion": 2
}
```

**JavaScript (readable):**
```javascript
const geminiRaw = $input.first().json;
const prevData = $('Build Gemini Prompt').first().json;

const aiText = geminiRaw?.candidates?.[0]?.content?.parts?.[0]?.text
  ?? 'No summary available';
const d = prevData;
const reportDate = d.report_date
  ? d.report_date.toString().substring(0, 10)
  : 'N/A';

const sleepQualityMap = {
  1: 'Excellent', 2: 'Good', 3: 'Fair',
  4: 'Poor', 5: 'Very Poor'
};
const sleepQualityLabel = d.sleep_quality
  ? (sleepQualityMap[d.sleep_quality] ?? d.sleep_quality)
  : '—';

const htmlEmail = `<!DOCTYPE html><html><body style="font-family:-apple-system,Arial,sans-serif;background:#f5f5f5;padding:20px;margin:0">
<div style="max-width:600px;margin:0 auto;background:white;border-radius:12px;overflow:hidden;box-shadow:0 2px 8px rgba(0,0,0,.1)">
  <div style="background:linear-gradient(135deg,#1a1a2e,#16213e);color:white;padding:24px;text-align:center">
    <h2 style="margin:0;font-size:22px">🏃 Daily Health Report</h2>
    <p style="margin:4px 0 0;opacity:.7;font-size:13px">${reportDate} · Helio → Zepp → Intervals.icu → Gemini</p>
  </div>
  <div style="display:grid;grid-template-columns:1fr 1fr 1fr;gap:10px;padding:20px">
    <div style="background:#f8f9fa;border-radius:8px;padding:12px;text-align:center">
      <div style="font-size:22px;font-weight:700;color:#1a1a2e">${d.steps ?? '—'}</div>
      <div style="font-size:10px;color:#888;margin-top:3px">STEPS</div>
    </div>
    <div style="background:#f8f9fa;border-radius:8px;padding:12px;text-align:center">
      <div style="font-size:22px;font-weight:700;color:#1a1a2e">${d.calories ?? '—'}</div>
      <div style="font-size:10px;color:#888;margin-top:3px">CALORIES</div>
    </div>
    <div style="background:#f8f9fa;border-radius:8px;padding:12px;text-align:center">
      <div style="font-size:22px;font-weight:700;color:#e63946">${d.resting_hr ?? '—'}</div>
      <div style="font-size:10px;color:#888;margin-top:3px">RESTING HR</div>
    </div>
    <div style="background:#f8f9fa;border-radius:8px;padding:12px;text-align:center">
      <div style="font-size:22px;font-weight:700;color:#4361ee">${d.hrv_avg ?? '—'}</div>
      <div style="font-size:10px;color:#888;margin-top:3px">HRV (ms)</div>
    </div>
    <div style="background:#f8f9fa;border-radius:8px;padding:12px;text-align:center">
      <div style="font-size:22px;font-weight:700;color:#2a9d8f">${d.sleep_hours ?? '—'}</div>
      <div style="font-size:10px;color:#888;margin-top:3px">SLEEP HRS</div>
    </div>
    <div style="background:#f8f9fa;border-radius:8px;padding:12px;text-align:center">
      <div style="font-size:22px;font-weight:700;color:#f4a261">${d.sleep_score ?? '—'}</div>
      <div style="font-size:10px;color:#888;margin-top:3px">SLEEP SCORE</div>
    </div>
    <div style="background:#f8f9fa;border-radius:8px;padding:12px;text-align:center">
      <div style="font-size:22px;font-weight:700;color:#1a1a2e">${d.workout_count ?? 0}</div>
      <div style="font-size:10px;color:#888;margin-top:3px">WORKOUTS</div>
    </div>
    <div style="background:#f8f9fa;border-radius:8px;padding:12px;text-align:center">
      <div style="font-size:22px;font-weight:700;color:#1a1a2e">${d.workout_avg_hr ?? '—'}</div>
      <div style="font-size:10px;color:#888;margin-top:3px">AVG HR</div>
    </div>
    <div style="background:#f8f9fa;border-radius:8px;padding:12px;text-align:center">
      <div style="font-size:22px;font-weight:700;color:#1a1a2e">${d.weight ?? '—'}</div>
      <div style="font-size:10px;color:#888;margin-top:3px">WEIGHT kg</div>
    </div>
  </div>
  ${d.workout_names ? `<div style="padding:0 20px 12px">
    <div style="background:#fff8e7;border-left:3px solid #f4a261;padding:10px 14px;border-radius:0 6px 6px 0;font-size:13px;color:#555">
      🏋️ <strong>Workouts:</strong> ${d.workout_names}
    </div>
  </div>` : ''}
  <div style="padding:0 20px 20px">
    <div style="background:#f0f4ff;border-left:4px solid #4361ee;padding:16px;border-radius:0 8px 8px 0;font-size:14px;line-height:1.7;color:#333;white-space:pre-wrap">${aiText}</div>
  </div>
  <div style="background:#f8f9fa;padding:12px;text-align:center;font-size:11px;color:#aaa">
    Amazfit Helio Strap → Zepp → Intervals.icu → n8n → Gemini → You
  </div>
</div></body></html>`;

const whatsappMsg = `🏃 Health Report — ${reportDate}\n\n👟 Steps: ${d.steps ?? 'N/A'}\n🔥 Calories: ${d.calories ?? 'N/A'} kcal\n❤️ Resting HR: ${d.resting_hr ?? 'N/A'} bpm\n🧠 HRV: ${d.hrv_avg ?? 'N/A'} ms\n💤 Sleep: ${d.sleep_hours ?? 'N/A'}h (Score: ${d.sleep_score ?? 'N/A'}/100)\n🏋️ Workouts: ${d.workout_count ?? 0} sessions\n\n${aiText}`;

return [{ json: { htmlEmail, whatsappMsg, report_date: reportDate } }];
```

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
**Purpose:** Send health summary to Telegram bot

```json
{
  "parameters": {
    "method": "GET",
    "url": "https://api.telegram.org/bot8977658056:AAGG0fKLdsLNn1ofaUyVHB865qR_bbEJz9w/sendMessage",
    "sendQueryParameters": true,
    "queryParameters": {
      "parameters": [
        {
          "name": "chat_id",
          "value": "7608056243"
        },
        {
          "name": "text",
          "value": "={{ $json.whatsappMsg }}"
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
      "id": 7608056243,
      "first_name": "Kunal"
    },
    "text": "🏃 Health Report — 2026-05-29..."
  }
}
```

---

## Connection Map

```
Schedule Trigger
    ├──→ Fetch Intervals Wellness  → Merge (Input 0)
    └──→ Fetch Intervals Activities → Merge (Input 1)
                                        ↓
                                  Code in JavaScript
                                        ↓
                                  Save to Supabase
                                        ↓
                                  Build Gemini Prompt
                                        ↓
                                  HTTP Request (Gemini)
                                        ↓
                                  Format Email + WhatsApp
                                     ↙        ↘
                            Send Gmail    Send Telegram
```
