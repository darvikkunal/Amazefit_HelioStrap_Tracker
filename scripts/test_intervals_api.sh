#!/bin/bash
# Test Intervals.icu API connectivity and data retrieval
#
# Usage:
#   ./scripts/test_intervals_api.sh YOUR_API_KEY YOUR_ATHLETE_ID YYYY-MM-DD
#
# Example:
#   ./scripts/test_intervals_api.sh 1an2euw5ng67dpexsy4tuv1g7 i598416 2026-05-29

set -euo pipefail

if [ $# -ne 3 ]; then
  echo "Usage: $0 API_KEY ATHLETE_ID DATE"
  echo ""
  echo "Arguments:"
  echo "  API_KEY      Your Intervals.icu API key"
  echo "  ATHLETE_ID   Your athlete ID (e.g. i598416)"
  echo "  DATE         Date in YYYY-MM-DD format (e.g. 2026-05-29)"
  echo ""
  echo "Example:"
  echo "  $0 1an2euw5ng67dpexsy4tuv1g7 i598416 2026-05-29"
  exit 1
fi

API_KEY="$1"
ATHLETE_ID="$2"
DATE="$3"
BASE_URL="https://intervals.icu/api/v1/athlete/${ATHLETE_ID}"

echo "=========================================="
echo "  Kunal Health Tracker - API Test"
echo "=========================================="
echo ""

# Test 1: Athlete profile
echo "--- Test 1: Athlete Profile ---"
echo "GET ${BASE_URL}"
echo ""
RESULT=$(curl -s -o /dev/null -w "%{http_code}" -u "API_KEY:${API_KEY}" "${BASE_URL}")
if [ "$RESULT" = "200" ]; then
  echo "  ✅ PASS (HTTP $RESULT)"
else
  echo "  ❌ FAIL (HTTP $RESULT)"
  echo "  Check your API key and athlete ID."
fi
echo ""

# Test 2: Wellness data
echo "--- Test 2: Wellness Data for ${DATE} ---"
echo "GET ${BASE_URL}/wellness/${DATE}"
echo ""
WELLNESS=$(curl -s -u "API_KEY:${API_KEY}" "${BASE_URL}/wellness/${DATE}")
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -u "API_KEY:${API_KEY}" "${BASE_URL}/wellness/${DATE}")

if [ "$HTTP_CODE" = "200" ]; then
  echo "  ✅ PASS (HTTP $HTTP_CODE)"
  echo ""
  echo "  Response:"
  echo "$WELLNESS" | python3 -m json.tool 2>/dev/null || echo "$WELLNESS"
  echo ""

  # Extract key metrics
  STEPS=$(echo "$WELLNESS" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('steps','N/A'))" 2>/dev/null || echo "N/A")
  RESTING_HR=$(echo "$WELLNESS" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('restingHR','N/A'))" 2>/dev/null || echo "N/A")
  HRV=$(echo "$WELLNESS" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('hrv','N/A'))" 2>/dev/null || echo "N/A")
  SLEEP=$(echo "$WELLNESS" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('sleepSecs','N/A'))" 2>/dev/null || echo "N/A")

  echo "  Summary:"
  echo "    Steps:      $STEPS"
  echo "    Resting HR: $RESTING_HR bpm"
  echo "    HRV:        $HRV ms"
  echo "    Sleep:      $SLEEP secs"
else
  echo "  ❌ FAIL (HTTP $HTTP_CODE)"
  echo "  Response: $WELLNESS"
fi
echo ""

# Test 3: Activities data
echo "--- Test 3: Activities for ${DATE} ---"
echo "GET ${BASE_URL}/activities?oldest=${DATE}&newest=${DATE}"
echo ""
ACTIVITIES=$(curl -s -u "API_KEY:${API_KEY}" "${BASE_URL}/activities?oldest=${DATE}&newest=${DATE}")
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -u "API_KEY:${API_KEY}" "${BASE_URL}/activities?oldest=${DATE}&newest=${DATE}")

if [ "$HTTP_CODE" = "200" ]; then
  COUNT=$(echo "$ACTIVITIES" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")
  echo "  ✅ PASS (HTTP $HTTP_CODE, $COUNT activities)"
  echo ""
  echo "  Response:"
  echo "$ACTIVITIES" | python3 -m json.tool 2>/dev/null || echo "$ACTIVITIES"
else
  echo "  ❌ FAIL (HTTP $HTTP_CODE)"
  echo "  Response: $ACTIVITIES"
fi
echo ""
echo "=========================================="
echo "  Done."
echo "=========================================="
