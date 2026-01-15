#! /bin/bash

export OBOT_SERVER_TOOL_REGISTRIES="github.com/obot-platform/tools,test-tools"
export GPTSCRIPT_TOOL_REMAP="test-tools=./tests/integration/tools/"
export GPTSCRIPT_INTERNAL_OPENAI_STREAMING=false

echo "Starting obot server..."

# Debug: Verify OBOT_SERVER_DSN is set
if [[ -z "$OBOT_SERVER_DSN" ]]; then
  echo "⚠️  WARNING: OBOT_SERVER_DSN not set, using default PostgreSQL connection"
  export OBOT_SERVER_DSN="postgres://testuser:testpass@localhost:5432/testdb?sslmode=disable"
else
  echo "✅ Using OBOT_SERVER_DSN from environment"
fi

# Sanitize for display (remove password)
DISPLAY_DSN=$(echo "$OBOT_SERVER_DSN" | sed 's/:\/\/[^:]*:[^@]*@/:\/\/***:***@/')
echo "Database connection: $DISPLAY_DSN"

./bin/obot server --dev-mode --gateway-debug > ./obot.log 2>&1 &

URL="http://localhost:8080/api/healthz"
TIMEOUT=300
INTERVAL=5
MAX_RETRIES=$((TIMEOUT / INTERVAL))

echo "Waiting for $URL to return OK..."

for ((i=1; i<=MAX_RETRIES; i++)); do
  response=$(curl -s -o /dev/null -w "%{http_code}" "$URL" 2>/dev/null)
  
  if [ "$response" = "200" ]; then
    health_content=$(curl -s "$URL")
    if [[ "$health_content" == *"ok"* ]]; then
      echo "✅ Health check passed! Response: $health_content"
      go test ./tests/integration/... -v
      exit 0
    else
      echo "⚠️  Got HTTP 200 but unexpected response: $health_content"
    fi
  fi

  echo "Attempt $i/$MAX_RETRIES: Service not ready (HTTP $response). Retrying in $INTERVAL seconds..."
  sleep "$INTERVAL"
done

echo "❌ Timeout reached! Service at $URL did not return OK within $TIMEOUT seconds"
echo "=== Last 200 lines of obot.log ==="
tail -n 200 ./obot.log
exit 1

