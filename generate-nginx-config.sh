#!/bin/sh
# generate-nginx-config.sh
# Generates nginx.conf dynamically based on running dashboard containers

echo "Generating Nginx configuration..."

# Count dashboard instances
DASHBOARD_COUNT=${DASHBOARD_COUNT:-3}

cat > nginx.conf <<'HEADER'
events {
    worker_connections 1024;
}

http {
    upstream dashboard_backend {
        least_conn;
        
HEADER

# Add dashboard servers
for i in $(seq 1 $DASHBOARD_COUNT); do
    echo "        server demo-consul-101-cicd-dashboard-${i}:9002;" >> nginx.conf
done

cat >> nginx.conf <<'FOOTER'
    }

    server {
        listen 80;
        server_name localhost;

        location / {
            proxy_pass http://dashboard_backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            
            # WebSocket support
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            
            # Timeouts
            proxy_connect_timeout 60s;
            proxy_send_timeout 60s;
            proxy_read_timeout 60s;
        }

        location /health {
            access_log off;
            return 200 "healthy\n";
            add_header Content-Type text/plain;
        }
        
        location /nginx-status {
            stub_status on;
            access_log off;
        }
    }
}
FOOTER

echo "Nginx configuration generated successfully!"
echo "Dashboard instances configured: $DASHBOARD_COUNT"
cat nginx.conf
