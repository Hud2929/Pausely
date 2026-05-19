#!/bin/bash

# Test script for the waitlist signup edge function
# Usage: ./test-waitlist.sh your@email.com

EMAIL=${1:-"test@example.com"}
PROJECT_REF=${2:-"YOUR_PROJECT_REF"}

if [ "$PROJECT_REF" = "YOUR_PROJECT_REF" ]; then
    echo "Usage: ./test-waitlist.sh your@email.com your-project-ref"
    echo ""
    echo "Your project ref is in your Supabase URL:"
    echo "https://your-project-ref.supabase.co"
    echo ""
    exit 1
fi

FUNCTION_URL="https://${PROJECT_REF}.supabase.co/functions/v1/waitlist-signup"

echo "Testing waitlist signup with email: $EMAIL"
echo "URL: $FUNCTION_URL"
echo ""

RESPONSE=$(curl -s -X POST "$FUNCTION_URL" \
    -H "Content-Type: application/json" \
    -d "{\"email\": \"$EMAIL\", \"source\": \"test\"}")

echo "Response:"
echo "$RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$RESPONSE"

echo ""
if echo "$RESPONSE" | grep -q '"success":true'; then
    echo "Test PASSED"
else
    echo "Test FAILED - check the response above"
fi
