# Architecture Overview

## Complete System Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                         External Access                           │
└──────────────────────────────────────────────────────────────────┘
                                  │
                    ┌─────────────┼─────────────┐
                    │                           │
            http://localhost:8080      http://localhost:8500
                    │                           │
                    ↓                           ↓
            ┌───────────────┐          ┌──────────────┐
            │  Nginx Load   │          │   Consul UI  │
            │   Balancer    │          │              │
            │   (Port 80)   │          │  (Port 8500) │
            └───────────────┘          └──────────────┘
                    │                           │
                    │                           │
┌───────────────────┼───────────────────────────┼──────────────────┐
│                   │     consul-net network    │                  │
│                   │                           │                  │
│       ┌───────────┴───────────┐               │                  │
│       │  Load Balancing       │               │                  │
│       │  (Least Connections)  │               │                  │
│       └───────────┬───────────┘               │                  │
│                   │                           │                  │
│      ┌────────────┼────────────┐              │                  │
│      │            │            │              │                  │
│      ↓            ↓            ↓              ↓                  │
│ ┌──────────┐ ┌──────────┐ ┌──────────┐  ┌─────────────┐        │
│ │Dashboard │ │Dashboard │ │Dashboard │  │   Consul    │        │
│ │    -1    │ │    -2    │ │    -3    │  │   Server    │        │
│ │:9002     │ │:9002     │ │:9002     │  │  (Registry) │        │
│ └──────────┘ └──────────┘ └──────────┘  └─────────────┘        │
│      │            │            │              ↑                  │
│      └────────────┼────────────┘              │                  │
│                   │                           │                  │
│                   │ Consul DNS Resolution     │                  │
│                   │ (counting.service.consul) │                  │
│                   ↓                           │                  │
│           ┌──────────────┐                    │                  │
│           │ Counting Svc │                    │ Service          │
│           │  Discovery   │                    │ Registration     │
│           └──────────────┘                    │ & Health         │
│                   │                           │ Checks           │
│      ┌────────────┼────────────┐              │                  │
│      │            │            │              │                  │
│      ↓            ↓            ↓              │                  │
│ ┌──────────┐ ┌──────────┐ ┌──────────┐      │                  │
│ │Counting  │ │Counting  │ │Counting  │      │                  │
│ │   -1     │ │   -2     │ │   -3     │      │                  │
│ │:9003     │ │:9003     │ │:9003     │      │                  │
│ └──────────┘ └──────────┘ └──────────┘      │                  │
│      │            │            │             │                  │
│      └────────────┴────────────┴─────────────┘                  │
│                                                                  │
│              ┌────────────────────┐                             │
│              │  Consul Register   │                             │
│              │  (Auto Registration)│                            │
│              └────────────────────┘                             │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

## Traffic Flow

### 1. External User Access (via Load Balancer)
```
User Browser → http://localhost:8080
               ↓
         Nginx Load Balancer (nginx-lb)
               ↓ (distributes using least_conn)
         Dashboard-1, Dashboard-2, or Dashboard-3
               ↓ (uses Consul DNS)
         counting.service.consul
               ↓ (Consul resolves to)
         Counting-1, Counting-2, or Counting-3
```

### 2. Service Registration Flow
```
1. docker compose up --scale counting=3 --scale dashboard=3
   ↓
2. All containers start (consul, counting×3, dashboard×3, nginx, consul-register)
   ↓
3. Consul Register script detects all running containers
   ↓
4. For each container:
   - Extract container name and IP
   - Generate service definition with health check
   - Register with Consul via HTTP API
   ↓
5. Consul monitors health endpoints:
   - Counting: http://<ip>:9003/health
   - Dashboard: http://<ip>:9002/health
```

### 3. Service Discovery Flow (Internal)
```
Dashboard needs to call Counting service:
1. Dashboard queries Consul DNS: counting.service.consul
   ↓
2. Consul returns all healthy Counting instance IPs
   ↓
3. Dashboard connects to one of the healthy instances
   ↓
4. If instance fails health check, Consul stops returning its IP
```

## Component Details

### Nginx Load Balancer
- **Purpose**: External HTTP entry point for dashboard services
- **Algorithm**: Least connections (distributes to instance with fewest active connections)
- **Port**: 8080 (external) → 80 (internal)
- **Features**:
  - HTTP/1.1 with WebSocket support
  - Connection upgrade handling
  - Health check endpoint at `/health`
  - Proxy headers for real IP forwarding

### Consul
- **Purpose**: Service registry and health monitoring
- **Modes**:
  - Service discovery (DNS on port 8600)
  - Service registry (HTTP API on port 8500)
  - Health checking (HTTP GET to /health)
- **Services Registered**:
  - counting-1, counting-2, counting-3
  - dashboard-1, dashboard-2, dashboard-3

### Dashboard Service
- **Purpose**: Frontend UI
- **Scaling**: 3 instances (horizontal scaling)
- **Access**: Via Nginx load balancer only
- **Dependencies**: 
  - Counting service (via Consul DNS resolution)
  - Consul (for service discovery)

### Counting Service
- **Purpose**: Backend API
- **Scaling**: 3 instances (horizontal scaling)
- **Access**: Internal only (via Consul DNS)
- **No external access needed**

## Why This Architecture?

### 1. **Nginx Load Balancer is Essential**
   - ✅ Provides single entry point (localhost:8080)
   - ✅ Distributes traffic across dashboard instances
   - ✅ Handles WebSocket connections properly
   - ✅ No need to expose ports on individual dashboard containers

### 2. **Consul for Internal Service Discovery**
   - ✅ Dashboard discovers Counting instances automatically
   - ✅ Health monitoring ensures only healthy instances receive traffic
   - ✅ DNS-based service discovery (no hard-coded IPs)
   - ✅ Automatic failover if instances die

### 3. **Separation of Concerns**
   - **External traffic**: Nginx handles HTTP load balancing
   - **Internal traffic**: Consul handles service discovery
   - **Result**: Clean separation, easier to scale and maintain

## Scaling Examples

### Scale to 5 Dashboard Instances
```bash
# 1. Update nginx.conf to add dashboard-4 and dashboard-5
# 2. Scale up
docker compose up -d --scale dashboard=5
# 3. Reload Nginx
docker exec nginx-lb nginx -s reload
```

### Scale to 10 Counting Instances
```bash
# No nginx changes needed - Consul DNS handles it automatically
docker compose up -d --scale counting=10
# Consul will automatically register all 10 instances
```

## Health Monitoring

All services are monitored:
```
┌─────────────┐
│   Consul    │
│  (Monitor)  │
└──────┬──────┘
       │
       ├─→ GET http://counting-1:9003/health   (every 10s)
       ├─→ GET http://counting-2:9003/health   (every 10s)
       ├─→ GET http://counting-3:9003/health   (every 10s)
       ├─→ GET http://dashboard-1:9002/health  (every 10s)
       ├─→ GET http://dashboard-2:9002/health  (every 10s)
       └─→ GET http://dashboard-3:9002/health  (every 10s)
```

If any health check fails:
- Consul marks service as unhealthy
- Service removed from DNS queries
- Traffic automatically routes to healthy instances

## Summary

**Yes, you NEED Nginx load balancer** because:
1. Dashboard containers don't expose ports directly
2. You need a single entry point (localhost:8080)
3. You need load distribution across multiple dashboard instances
4. You need WebSocket support for real-time features

**Consul complements Nginx** by:
1. Handling internal service-to-service discovery
2. Monitoring health of all instances
3. Providing DNS resolution for internal services
4. Enabling automatic failover

Both work together to provide a robust, scalable microservices architecture! 🚀
