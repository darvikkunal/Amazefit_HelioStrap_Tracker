# 🚀 Future Improvements & Roadmap

---

## 🔜 Near-term (Easy wins)

### 7-Day Trend Analysis in Gemini Prompt
Query Supabase for the last 7 days and include the trend in the AI prompt.
```sql
SELECT report_date, steps, resting_hr, hrv_avg, sleep_hours
FROM daily_health_metrics
ORDER BY report_date DESC
LIMIT 7;
```
Pass this as a table to Gemini — it can then say things like "your HRV has been dropping for 3 days."

### Delay Trigger if Data Not Ready
Sometimes Zepp → Intervals sync is slow. Add a check:
- If `wellness.steps` is null or 0, wait 30 minutes and retry
- n8n has a Wait node for this

### Weekly Summary Report
Every Sunday, generate a weekly recap:
- Best sleep day
- Highest step day
- Total calories burned
- Average HRV trend
- Workout consistency

---

## 📊 Medium-term (More depth)

### Supabase Dashboard
Build a simple dashboard using Supabase's built-in chart views or connect to:
- **Metabase** (free, self-hosted)
- **Grafana** (free, powerful)
- **Retool** (free tier)

### HRV Trend Alerts
If today's HRV is >20% below your 7-day average — send an alert.
Indicates overtraining, illness, or poor recovery.

### Sleep Stage Data
Currently sleep stages (deep/REM/light) come back as null from Intervals.
- Monitor if Zepp starts exposing this via Intervals API
- Alternatively check if Zepp Health API exposes it directly

### Weight Trend Tracking
Current weight comes from Intervals (synced from Zepp scale if connected).
Build a weekly weight trend chart and include in the email.

### VO2 Max Tracking
Amazfit devices estimate VO2 Max. When this becomes available in Intervals:
- Track monthly trends
- Include in Gemini analysis

---

## 🏗️ Long-term (Big features)

### Full Web Dashboard
Build a React/Next.js dashboard that reads from Supabase:
- Calendar heatmap of daily steps
- HRV trend line chart
- Sleep consistency chart
- Workout frequency chart
- AI coach chat interface

### Historical Backfill
Populate all historical data from before the pipeline started:
- Use Intervals.icu wellness range endpoint
- Loop through dates back to account creation
- Batch insert into Supabase

### Multi-Device Support
Currently hardcoded for one athlete. Make it multi-user:
- Store `athlete_id` per user in Supabase
- Each user gets their own report

### Anomaly Detection
Use Gemini to detect health anomalies:
- Sudden HR spike
- Sleep score drop for 3+ consecutive days
- Zero step days (did device die?)
- Send immediate alert, not just daily report

### WhatsApp via Twilio
Replace CallMeBot with official Twilio WhatsApp API:
- More reliable
- Supports rich media
- Small monthly cost (~$0.005/message)

### Apple Health / Google Fit Integration
If moving away from Amazfit:
- Intervals.icu supports Apple Health via Health Auto Export app
- Google Fit via Health Connect
- Pipeline stays the same, just different sync source

---

## 🐛 Known Limitations

| Limitation | Impact | Potential Fix |
|---|---|---|
| No sleep stages (deep/REM/light) | Gemini can't analyze sleep structure | Wait for Zepp/Intervals to expose it |
| No distance data | Can't calculate pace or distance | Available in activities endpoint for GPS workouts |
| Zepp sync delay | Data may not be ready at exactly 9 AM | Delay trigger to 10 AM or add retry logic |
| Single user | Can only track one athlete | Add multi-user support |
| No historical data before setup date | Can't analyze long-term trends | Backfill script |
| Gemini has no memory | Each report is independent | Pass 7-day history in prompt |

---

*Last updated: June 2, 2026*
