#!/usr/bin/env bash

# Test Clash sidecar proxy connection
# This script tests if the proxy at localhost:8888 can successfully access Google

echo "Testing proxy connection to Google.com..."
echo "Proxy: localhost:8888"
echo "---"

# Test with curl using the proxy
curl -x http://localhost:8888 -I -L --connect-timeout 10 https://www.google.com

echo "---"
echo "Test completed."
