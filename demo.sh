#\!/bin/bash

echo "🎵 ZimSync File Transfer Demo"
echo "============================"
echo ""

# Kill any existing server
pkill -f "zimsync-cli serve" || true

# Start server in background
echo "🚀 Starting ZimSync server..."
swift run zimsync-cli serve --directory test-files --port 8080 > server.log 2>&1 &
SERVER_PID=$\!

# Give server time to start
sleep 3

echo "   Server PID: $SERVER_PID"
echo "   Sharing files from: test-files/"
echo "   Available files:"
ls -la test-files/
echo ""

# Test discovery
echo "🔍 Testing discovery..."
timeout 5 swift run zimsync-cli discover --timeout 3 || echo "   No devices found (expected if no other ZimSync devices)"
echo ""

# Test basic UDP connection
echo "📡 Testing UDP connection..."
echo "Hello ZimSync Protocol\!" | nc -u -w2 localhost 8080 || echo "   Server not responding to text"
echo ""

# Test protocol packets
echo "🧪 Testing ZimSync protocol..."
swift run zimsync-cli send test.txt localhost || echo "   Protocol test may have issues"
echo ""

# Show server logs
echo "📋 Server logs:"
echo "=================="
cat server.log | head -20
echo ""

# Cleanup
echo "🧹 Cleaning up..."
kill $SERVER_PID 2>/dev/null || true
sleep 1

echo "✅ Demo complete\!"
EOF < /dev/null