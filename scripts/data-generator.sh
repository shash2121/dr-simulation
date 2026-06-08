#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────
# DR Simulation - Random Data Generator
#
# Pushes random events to the app's /send-to-sqs endpoint.
# The app sends the message to SQS, then a background poller
# reads SQS and writes to PostgreSQL.
#
# If SQS is not configured (local dev), the app falls back
# to writing directly to PostgreSQL.
#
# Usage:
#   ./data-generator.sh <app-url> [interval-seconds]
#
# Examples:
#   ./data-generator.sh http://localhost:8080
#   ./data-generator.sh http://my-alb-123.us-east-1.elb.amazonaws.com 5
#   ./data-generator.sh http://localhost:8080 3 &
# ─────────────────────────────────────────────────────────

APP_URL="${1:?Usage: $0 <app-url> [interval-seconds]}"
INTERVAL="${2:-3}"

PRODUCTS=(
  "iPhone 16 Pro" "MacBook Air M4" "iPad Pro" "AirPods Max"
  "Apple Watch Ultra" "Vision Pro" "iMac" "Mac Mini" "HomePod"
)

ACTIONS=(
  "purchased" "returned" "viewed" "wishlisted" "abandoned"
  "shipped" "delivered" "canceled" "refunded" "reviewed"
)

USERS=(
  "alice" "bob" "carol" "dave" "eve" "frank" "grace"
  "henry" "iris" "jack" "kate" "leo" "maria" "nick" "olivia"
)

generate_body() {
  local product="${PRODUCTS[$((RANDOM % ${#PRODUCTS[@]}))]}"
  local action="${ACTIONS[$((RANDOM % ${#ACTIONS[@]}))]}"
  local user="${USERS[$((RANDOM % ${#USERS[@]}))]}"
  local amount=$((RANDOM % 5000 + 10))

  echo "{\"data\": \"$user $action $product for \$$amount\"}"
}

echo "=== DR Sim Data Generator ==="
echo "Target: $APP_URL/send-to-sqs"
echo "Interval: ${INTERVAL}s"
echo "Press Ctrl+C to stop"
echo ""

COUNT=0
while true; do
  BODY=$(generate_body)
  RESP=$(curl -s -X POST "$APP_URL/send-to-sqs" \
    -H "Content-Type: application/json" \
    -d "$BODY" 2>/dev/null || echo '{"status":"failed"}')

  STATUS=$(echo "$RESP" | jq -r '.status // "failed"')
  MSG_ID=$(echo "$RESP" | jq -r '.message_id // "—"')
  REGION=$(echo "$RESP" | jq -r '.region // "unknown"')

  COUNT=$((COUNT + 1))
  echo "[$(date +%H:%M:%S)] #$COUNT $STATUS | region=$REGION | msg=$MSG_ID | $(echo "$BODY" | jq -r '.data')"
  sleep "$INTERVAL"
done
