#!/bin/bash

# Test UDP server with nc (netcat)
echo "Testing UDP server on port 8080..."
echo "Hello ZimSync!" | nc -u -w1 localhost 8080

# Also test with socat if available
if command -v socat &> /dev/null; then
    echo "Testing with socat..."
    echo "Hello from socat!" | socat - UDP:localhost:8080
fi