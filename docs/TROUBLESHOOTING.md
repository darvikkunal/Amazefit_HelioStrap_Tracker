# 🐛 Troubleshooting Guide

Common issues encountered during setup and how to fix them.

---

## Intervals.icu API Issues

### `403 Host not in allowlist`
**When:** Calling from a browser widget or certain server environments  
**Cause:** Intervals.icu blocks requests from non-whitelisted origins  
**Fix:** Always call from n8n HTTP Request nodes or your local terminal — never from browser-side JavaScript

### `403 Access denied`
**When:** Auth header is wrong  
**Cause:** Incorrect Basic Auth format  
**Fix:** Username must be literally `API_KEY` (all caps), password is your key value
```bash
# Correct
curl -u "API_KEY:1an2euw5ng67dpexsy4tuv1g7" https://intervals.icu/api/v1/athlete/i598416

# Wrong
curl -u "i598416:1an2euw5ng67dpexsy4tuv1g7" ...
curl -u "1an2euw5ng67dpexsy4tuv1g7:" ...
```

### Empty wellness response `{}`
**When:** Querying a date with no data  
**Cause:** Zepp hasn't synced that day, or date is in the future  
**Fix:** Use yesterday's date. Wait for Zepp sync (can take up to 1 hour after midnight)

### Activities returns `[]`
**When:** No workouts logged that day  
**Cause:** Rest day — completely normal  
**Fix:** Code handles this gracefully. `workout_count` will be `0`, `workout_names` will be `'Rest day'`

---

## n8n Code Node Issues

### `fetch is not defined`
**When:** Using `fetch()` in Code node  
**Cause:** n8n 2.22.5 task runner sandbox blocks native `fetch`  
**Fix:** Don't make HTTP calls inside Code nodes. Use separate HTTP Request nodes instead

### `$http is not defined`
**When:** Using `$http.request()` in Code node  
**Cause:** Same sandbox restriction  
**Fix:** Same — use HTTP Request nodes, not inline calls in Code nodes

### Code node spinning / timeout
**When:** Code node runs for >2 minutes without completing  
**Cause:** Usually infinite loop or waiting on blocked network call  
**Fix:** Cancel, check for any `fetch`/`$http` calls, remove them

### AI reasoning text appearing in output
**When:** Telegram/email shows "Let me analyze..." or "I need to..." before actual content  
**Cause:** OpenRouter/LLM returns reasoning text in `message.content`  
**Fix:** The Format Email node has regex filter to strip these lines. If new patterns appear, add them to the `.replace()` chain.

### `$input.all()` returns wrong order
**When:** Wellness item is not at index 0  
**Cause:** Merge node inputs are connected in wrong order  
**Fix:** In Merge node, ensure Wellness node → Input 0, Activities node → Input 1

---

## OpenRouter API Issues

### Response is empty or truncated
**When:** AI summary ends abruptly or is blank  
**Cause:** `max_tokens` too low or rate limited  
**Fix:** Set `max_tokens: 2048` in the OpenRouter request body. Check [openrouter.ai/activity](https://openrouter.ai/activity) for rate limits.

### `401 Unauthorized`
**When:** OpenRouter returns auth error  
**Cause:** Wrong or missing API key  
**Fix:** Verify your API key at [openrouter.ai/keys](https://openrouter.ai/keys). Ensure `Bearer` prefix is included in Authorization header.

### `fetch is not defined` or `$http is not defined`
**When:** Using fetch() or $http in Code node  
**Cause:** n8n 2.22.5 task runner sandbox blocks native fetch  
**Fix:** Don't make HTTP calls inside Code nodes. OpenRouter is called via a separate HTTP Request node.

### Model unavailability
**When:** OpenRouter returns error about model not found  
**Cause:** `openrouter/free` routes to available free models — some may be temporarily down  
**Fix:** The `route: "fallback"` setting handles this automatically. If persistent, try a specific model like `google/gemini-2.5-flash` or `anthropic/claude-3-5-haiku`.

### OpenRouter fallback retries
**When:** Node shows retries before success  
**Cause:** The workflow has `retryOnFail: true` with `waitBetweenTries: 5000` (5 seconds)  
**Fix:** This is intentional — transient failures are retried automatically.

---

## Supabase / Postgres Issues

### Column doesn't exist error
**When:** Postgres upsert fails  
**Cause:** New columns (`sleep_score`, `workout_count`, etc.) not added to table  
**Fix:** Run `supabase/extend_schema.sql` in Supabase SQL editor

### Can't connect to Supabase via Postgres node
**When:** Postgres node shows connection error  
**Cause:** Wrong host, port, or password  
**Fix:** Use Supabase connection pooler: `aws-0-xxx.pooler.supabase.com:6543` with `postgres` user and database password (not anon key). Enable SSL.

### `report_date` shows as timestamp `2026-05-29T00:00:00.000Z`
**When:** Date appears with time component  
**Cause:** Supabase/Postgres returns DATE as ISO string  
**Fix:** Use `.toString().substring(0, 10)` to extract just `YYYY-MM-DD`

### Duplicate key violation
**When:** Trying to insert a date that already exists  
**Cause:** Upsert not configured correctly  
**Fix:** Ensure Postgres node Operation is **Upsert**, and `report_date` is in **Columns to match on**

---

## Telegram Issues

### `getUpdates` returns `{"ok":true,"result":[]}`
**When:** Trying to get chat ID  
**Cause:** Haven't started the bot yet  
**Fix:** Find your bot in Telegram, click **Start**, send a message, then refresh getUpdates

### Markdown not rendering in Telegram
**When:** Telegram shows raw `*bold*` or `_italic_` instead of formatting  
**Cause:** `parse_mode` parameter not set  
**Fix:** Ensure the HTTP Request node has `parse_mode: Markdown` in the query parameters

### Message gets cut off
**When:** Telegram message ends with `...`  
**Cause:** Using `.substring(0, 300)` in Format node  
**Fix:** Remove the substring limit — use `${aiText}` directly

### `sendQuery` vs `sendQueryParameters`
**When:** Telegram parameters not being sent correctly  
**Cause:** n8n version difference — some use `sendQueryParameters`, others use `sendQuery`  
**Fix:** The live workflow uses `sendQuery: true`. If importing into older n8n, try `sendQueryParameters: true` instead.

### CallMeBot not working
**When:** WhatsApp delivery via CallMeBot fails  
**Cause:** CallMeBot is an unreliable third-party service  
**Fix:** Use Telegram instead (more reliable, free, official API)

---

## Gmail Issues

### OAuth authorization fails
**When:** Setting up Gmail credential  
**Cause:** Google OAuth scope issue  
**Fix:** Ensure you grant all requested Gmail permissions during OAuth flow

### Email not received
**When:** Node shows success but no email arrives  
**Cause:** Check spam folder  
**Fix:** Whitelist the sender address. Also verify `sendTo` field has correct email

---

## Data Issues

### Steps in Intervals much lower than Zepp shows
**When:** Comparing Intervals data to Zepp app  
**Cause:** Health Connect ZIP export was incomplete (this was the original problem)  
**Fix:** This is resolved — we now use Intervals.icu API directly which pulls from Zepp OAuth, giving accurate data

### Yesterday's data not available at 9 AM
**When:** Workflow runs but wellness data is empty/stale  
**Cause:** Zepp → Intervals sync hasn't completed yet  
**Fix:** Either delay trigger to 10 AM, or add a 30-minute retry logic. Alternatively, check Intervals.icu calendar to see when your data typically appears

### `sleep_hours` shows wrong value
**When:** Sleep hours seem too high or too low  
**Cause:** `sleepSecs` includes naps if device detects them  
**Fix:** This is expected behavior — Intervals aggregates all sleep detected by the device for that calendar day
