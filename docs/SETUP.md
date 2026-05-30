# 🔧 Setup Guide — Kunal Health Tracker

Complete end-to-end configuration guide. Follow every section in order.

---

## Table of Contents

1. [Hardware Setup](#1-hardware-setup)
2. [Intervals.icu Setup](#2-intervalsicu-setup)
3. [Get API Credentials](#3-get-api-credentials)
4. [Supabase Setup](#4-supabase-setup)
5. [Gemini API Setup](#5-gemini-api-setup)
6. [Telegram Bot Setup](#6-telegram-bot-setup)
7. [n8n Setup](#7-n8n-setup)
8. [Import & Configure Workflow](#8-import--configure-workflow)
9. [Test Each Node](#9-test-each-node)
10. [Activate & Verify](#10-activate--verify)

---

## 1. Hardware Setup

### Device
- **Amazfit Helio Strap** (or any Amazfit/Zepp compatible device)
- Ensure device is fully set up and syncing to the Zepp app

### Zepp App
1. Download **Zepp** app on iOS or Android
2. Sign in / create account
3. Pair your Amazfit device via Bluetooth
4. Enable auto-sync (Settings → Device → Auto Sync)
5. Wear the device — data will sync automatically

### Verify sync is working
- Open Zepp app → Home tab
- You should see: steps, heart rate, sleep data for today/yesterday
- If data shows — sync is working ✅

---

## 2. Intervals.icu Setup

### Create Account
1. Go to [intervals.icu](https://intervals.icu)
2. Sign up for a free account
3. Complete athlete profile setup

### Connect Zepp/Amazfit
1. Go to **Settings** (gear icon) → **Connections**
2. Find **Zepp** in the list
3. Click **Connect**
4. Authorize via Zepp OAuth popup
5. Enable these options:
   - ✅ Download activities
   - ✅ Download wellness
   - ✅ HRV (rMSSD)

### Verify sync
1. Go to Intervals.icu calendar
2. You should see wellness data (steps, sleep, HR) for recent days
3. If data shows — Zepp → Intervals sync is working ✅

### Get your Athlete ID
1. Go to **Settings** → scroll to bottom
2. Find **Developer Settings**
3. Note your **Athlete ID** (format: `i{numbers}`)
   - Example: `i598416`

---

## 3. Get API Credentials

### Intervals.icu API Key
1. Go to **Settings** → **Developer Settings**
2. Click **Generate** next to API Key
3. Copy and save the key securely
4. **Test it:**
```bash
curl -s -u "API_KEY:YOUR_API_KEY" \
  "https://intervals.icu/api/v1/athlete/YOUR_ATHLETE_ID" | python3 -m json.tool
```
You should see your athlete profile JSON.

5. **Test wellness:**
```bash
curl -s -u "API_KEY:YOUR_API_KEY" \
  "https://intervals.icu/api/v1/athlete/YOUR_ATHLETE_ID/wellness/YYYY-MM-DD" | python3 -m json.tool
```
Replace `YYYY-MM-DD` with yesterday's date.

> ⚠️ Important: The username is literally `API_KEY` (not your email). The password is your API key value.

---

## 4. Supabase Setup

### Create Project
1. Go to [supabase.com](https://supabase.com)
2. Sign up / log in
3. Click **New Project**
4. Choose organization, name it `kunal-health-tracker`
5. Set a strong database password (save it!)
6. Choose region closest to you
7. Wait ~2 minutes for project to provision

### Get Credentials
1. Go to **Settings** → **API**
2. Copy:
   - **Project URL** (format: `https://xxx.supabase.co`)
   - **anon public key** (long JWT string)

### Create Database Schema
1. Go to **SQL Editor** → **New query**
2. Paste the contents of `supabase/schema.sql`
3. Click **Run**
4. You should see: `Success. No rows returned`

### Add Extended Columns
1. Open another SQL query tab
2. Paste the contents of `supabase/extend_schema.sql`
3. Click **Run**
4. You should see: `Success. No rows returned`

### Verify
```sql
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'daily_health_metrics'
ORDER BY ordinal_position;
```
You should see all 26 columns listed.

---

## 5. Gemini API Setup

### Get API Key
1. Go to [Google AI Studio](https://aistudio.google.com)
2. Sign in with your Google account
3. Click **Get API Key** → **Create API key**
4. Copy the key

### Test it
```bash
curl -X POST \
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=YOUR_KEY" \
  -H "Content-Type: application/json" \
  -d '{"contents":[{"parts":[{"text":"Say hello in one sentence"}]}]}'
```

You should get a JSON response with text content.

### Free tier limits
- 15 requests per minute
- 1 million tokens per minute
- More than enough for 1 daily report

---

## 6. Telegram Bot Setup

### Create Bot
1. Open Telegram → search **@BotFather**
2. Send: `/newbot`
3. Enter bot name: `Your Health Bot` (display name)
4. Enter username: `yourusername_health_bot` (must end in `_bot`)
5. BotFather sends you a **token** like: `1234567890:AABBcc...`
6. Save this token

### Get Your Chat ID
1. Search for your new bot in Telegram
2. Click **Start**
3. Send any message (e.g. "hello")
4. Open in browser:
```
https://api.telegram.org/bot{YOUR_TOKEN}/getUpdates
```
5. Find `"chat":{"id":` in the response
6. That number is your **Chat ID**

### Test it
```bash
curl "https://api.telegram.org/bot{TOKEN}/sendMessage?chat_id={CHAT_ID}&text=Hello+from+Health+Tracker"
```
You should receive a Telegram message.

---

## 7. n8n Setup

### Option A — Self-hosted (recommended)
```bash
# Using Docker
docker run -it --rm \
  --name n8n \
  -p 5678:5678 \
  -v ~/.n8n:/home/node/.n8n \
  n8nio/n8n
```
Access at: `http://localhost:5678`

### Option B — n8n Cloud
1. Go to [n8n.io](https://n8n.io)
2. Sign up for free trial
3. No installation needed

### Initial Setup
1. Create your n8n account
2. Complete the onboarding
3. You'll land on the workflow canvas

---

## 8. Import & Configure Workflow

### Import
1. In n8n, click **⋯** (top right menu)
2. Click **Import from file**
3. Select `n8n/workflow.json`
4. The workflow will appear on the canvas

### Configure Credentials

#### Intervals.icu (HTTP Basic Auth)
1. Click on **Fetch Intervals Wellness** node
2. Under Authentication → **Generic Credential Type** → **HTTP Basic Auth**
3. Click **Create new credential**
4. Set:
   - **User:** `API_KEY`
   - **Password:** `your_intervals_api_key`
5. Click **Save**
6. Apply same credential to **Fetch Intervals Activities** node

#### Supabase
1. Click on **Save to Supabase** node
2. Click on the credential dropdown → **Create new**
3. Set:
   - **Host:** your Supabase project URL
   - **Service Role Secret:** your anon key
4. Save

#### Gmail
1. Click on **Send Gmail Report** node
2. Click credential → **Create new**
3. Follow OAuth flow to connect Gmail
4. Grant required permissions

#### Telegram
The Telegram node uses a plain HTTP GET — no credential needed. The token is in the URL directly.

### Update Variables
In the workflow, update these values if different from defaults:

| Node | Field | Value |
|---|---|---|
| Fetch Wellness | URL | Replace `i598416` with your athlete ID |
| Fetch Activities | URL | Replace `i598416` with your athlete ID |
| HTTP Request (Gemini) | URL | Replace API key in URL |
| Send Gmail | sendTo | Your email address |
| Send Telegram | chat_id query param | Your chat ID |
| Send Telegram | URL | Replace bot token |

---

## 9. Test Each Node

Test nodes **in order** by clicking each node → **Execute step**:

### Step 1 — Fetch Intervals Wellness
**Expected output:**
```json
{
  "id": "2026-05-29",
  "restingHR": 59,
  "hrv": 52,
  "sleepSecs": 34380,
  "steps": 3795,
  ...
}
```

### Step 2 — Fetch Intervals Activities
**Expected output:** Array of workout objects
```json
[
  { "name": "Morning Workout", "calories": 16, ... },
  { "name": "Afternoon Weight Training", "calories": 566, ... }
]
```

### Step 3 — Merge
**Expected:** 5 items (1 wellness + 4 activities)

### Step 4 — Code in JavaScript
**Expected output:**
```json
{
  "report_date": "2026-05-29",
  "steps": 3795,
  "resting_hr": 59,
  "calories": 660,
  "sleep_hours": 9.55,
  "workout_count": 4,
  ...
}
```

### Step 5 — Save to Supabase
**Expected:** Row upserted, output shows saved record with `id`

### Step 6 — Build Gemini Prompt
**Expected:** Output contains `prompt` field with formatted health data

### Step 7 — HTTP Request (Gemini)
**Expected:** `finishReason: "STOP"` (not MAX_TOKENS)

### Step 8 — Format Email + WhatsApp
**Expected:** `htmlEmail` and `whatsappMsg` fields populated

### Step 9 — Send Gmail
**Expected:** Email arrives in inbox within 30 seconds

### Step 10 — Send Telegram
**Expected:** Message arrives in Telegram within 5 seconds

---

## 10. Activate & Verify

### Activate
1. Click **Publish** button (top right)
2. Confirm in the dialog
3. Status shows **Published** — workflow is now live

### Verify tomorrow
1. At 9 AM the next day, check your Gmail and Telegram
2. You should receive the health report automatically
3. Check Supabase → Table Editor → `daily_health_metrics` to see the new row

### Check execution logs
1. In n8n → click **Executions** tab
2. You'll see each run with status (success/error)
3. Click any execution to see node-by-node output

---

## ✅ Setup Complete Checklist

- [ ] Amazfit device syncing to Zepp app
- [ ] Zepp connected to Intervals.icu
- [ ] Intervals.icu API key generated and tested
- [ ] Supabase project created
- [ ] Schema + extended columns created in Supabase
- [ ] Gemini API key obtained and tested
- [ ] Telegram bot created and chat ID obtained
- [ ] n8n workflow imported
- [ ] All credentials configured in n8n
- [ ] All nodes tested individually (green ticks)
- [ ] Test email received in Gmail
- [ ] Test message received in Telegram
- [ ] Workflow published/activated
