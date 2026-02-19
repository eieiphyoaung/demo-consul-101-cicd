#!/bin/bash

# Script to register 3 counting and 3 dashboard services to Consul

echo "Registering counting services to Consul..."

# Get container names and IPs for counting services
# COUNTING_DATA=($(docker ps --format "{{.Names}}" | grep "counting" | sort | xargs -I {} sh -c 'echo "{}:$(docker inspect -f "{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}" {})"'))
COUNTING_DATA=($(docker ps --filter "label=com.docker.compose.service=counting" --format "{{.Names}}" | sort | xargs -I {} sh -c 'echo "{}:$(docker inspect -f "{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}" {})"'))
# Register counting services
for i in {0..2}; do
  SERVICE_ID="counting-$((i+1))"
  DATA="${COUNTING_DATA[$i]}"
  CONTAINER_NAME=$(echo "$DATA" | cut -d: -f1)
  IP=$(echo "$DATA" | cut -d: -f2)
  PORT=9003
  
  if [ -n "$IP" ] && [ "$IP" != "" ]; then
    cat > /tmp/${SERVICE_ID}.json <<EOF
{
  "service": {
    "name": "counting",
    "id": "${SERVICE_ID}",
    "address": "${IP}",
    "port": ${PORT},
    "check": {
      "id": "${SERVICE_ID}-check",
      "http": "http://${IP}:${PORT}/health",
      "method": "GET",
      "interval": "10s",
      "timeout": "1s"
    }
  }
}
EOF
    consul services register /tmp/${SERVICE_ID}.json
    echo "Registered ${SERVICE_ID} (${CONTAINER_NAME}) at ${IP}:${PORT}"
  else
    echo "Warning: Could not find IP for counting service $((i+1))"
  fi
done

echo ""
echo "Registering dashboard services to Consul..."

# Get container names and IPs for dashboard services
# DASHBOARD_DATA=($(docker ps --format "{{.Names}}" | grep "dashboard" | sort | xargs -I {} sh -c 'echo "{}:$(docker inspect -f "{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}" {})"'))
DASHBOARD_DATA=($(docker ps --filter "label=com.docker.compose.service=dashboard" --format "{{.Names}}" | sort | xargs -I {} sh -c 'echo "{}:$(docker inspect -f "{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}" {})"'))
# Register dashboard services
for i in {0..2}; do
  SERVICE_ID="dashboard-$((i+1))"
  DATA="${DASHBOARD_DATA[$i]}"
  CONTAINER_NAME=$(echo "$DATA" | cut -d: -f1)
  IP=$(echo "$DATA" | cut -d: -f2)
  PORT=9002
  
  if [ -n "$IP" ] && [ "$IP" != "" ]; then
    cat > /tmp/${SERVICE_ID}.json <<EOF
{
  "service": {
    "name": "dashboard",
    "id": "${SERVICE_ID}",
    "address": "${IP}",
    "port": ${PORT},
    "check": {
      "id": "${SERVICE_ID}-check",
      "http": "http://${IP}:${PORT}/health",
      "method": "GET",
      "interval": "10s",
      "timeout": "1s"
    }
  }
}
EOF
    consul services register /tmp/${SERVICE_ID}.json
    echo "Registered ${SERVICE_ID} (${CONTAINER_NAME}) at ${IP}:${PORT}"
  else
    echo "Warning: Could not find IP for dashboard service $((i+1))"
  fi
done

echo ""
echo "All services registered successfully!"
echo ""
echo "Verify with: consul catalog services"
echo "Check health: consul catalog service counting"
echo "Check health: consul catalog service dashboard"
