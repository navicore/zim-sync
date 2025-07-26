#!/bin/bash

PORT=8080
HOST=localhost

echo "🧪 Testing ZimSync UDP echo server on $HOST:$PORT"
echo ""

# Test 1: Using nc (netcat) with timeout
echo "Test 1: Using nc (netcat)"
echo -n "Sending: 'Hello ZimSync!' ... "
RESPONSE=$(echo "Hello ZimSync!" | nc -u -w1 $HOST $PORT)
if [ -n "$RESPONSE" ]; then
    echo "✅ Received: $RESPONSE"
else
    echo "❌ No response received"
fi

echo ""

# Test 2: Using socat if available
if command -v socat &> /dev/null; then
    echo "Test 2: Using socat"
    echo -n "Sending: 'Testing with socat' ... "
    RESPONSE=$(echo "Testing with socat" | socat -t1 - UDP:$HOST:$PORT)
    if [ -n "$RESPONSE" ]; then
        echo "✅ Received: $RESPONSE"
    else
        echo "❌ No response received"
    fi
else
    echo "Test 2: Socat not installed (brew install socat)"
fi

echo ""

# Test 3: Multiple messages
echo "Test 3: Multiple messages"
for i in {1..3}; do
    MSG="Message $i"
    echo -n "Sending: '$MSG' ... "
    RESPONSE=$(echo "$MSG" | nc -u -w1 $HOST $PORT)
    if [ -n "$RESPONSE" ]; then
        echo "✅ Received: $RESPONSE"
    else
        echo "❌ No response received"
    fi
    sleep 0.1
done