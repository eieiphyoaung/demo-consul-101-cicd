# DNS Forwarding Logic in docker-compose.yaml

## Overview

This document explains how DNS resolution and forwarding works in the current docker-compose.yaml configuration.

---

## Current Configuration

```yaml
services:
  consul:
    command: agent -dev -client=0.0.0.0 -recursor=8.8.8.8
    networks:
      consul-net:
        ipv4_address: 172.20.0.10

  counting:
    networks:
      consul-net:
        aliases:
          - counting

  dashboard:
    environment:
      - COUNTING_SERVICE_URL=http://counting:9003
    networks:
      - consul-net

networks:
  consul-net:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16
```

---

## DNS Resolution Flow

### Step 1: Dashboard Queries "counting:9003"

When the dashboard application makes a request to `http://counting:9003`:

```
Dashboard Application
    ↓
Needs to resolve: "counting"
    ↓
Checks: /etc/resolv.conf
```

---

### Step 2: Container's DNS Configuration

Inside the dashboard container, `/etc/resolv.conf` looks like:

```
nameserver 127.0.0.11      # Docker's embedded DNS server
search service.consul       # Search domain (if configured)
options ndots:0
```

**Key Point**: `127.0.0.11` is Docker's **embedded DNS resolver** that exists in every container.

---

### Step 3: Docker Embedded DNS (127.0.0.11)

Docker's embedded DNS server handles the query:

```
Query: counting
    ↓
Docker DNS Checks:
  1. Is "counting" a container name? → Check
  2. Is "counting" a service name? → Check
  3. Is "counting" a network alias? → ✅ YES!
    ↓
Found network alias "counting" on consul-net
    ↓
Queries: What IPs have this alias?
    ↓
Returns ALL container IPs with alias "counting"
```

**Result:**
```
counting → 172.20.0.2 (demo-consul-101-cicd-counting-1)
counting → 172.20.0.3 (demo-consul-101-cicd-counting-2)
counting → 172.20.0.4 (demo-consul-101-cicd-counting-3)
```

---

### Step 4: Round-Robin Load Balancing

Docker DNS provides **built-in round-robin load balancing**:

```
Request 1: counting → 172.20.0.2
Request 2: counting → 172.20.0.3
Request 3: counting → 172.20.0.4
Request 4: counting → 172.20.0.2  (cycles back)
```

The application receives **one IP at a time** in rotating order.

---

## DNS Forwarding Logic Breakdown

### Scenario 1: Service Name Resolution (counting)

```
┌─────────────────────────────────────────────────────────────┐
│ Dashboard Container                                         │
│   Query: counting:9003                                      │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ↓
┌─────────────────────────────────────────────────────────────┐
│ /etc/resolv.conf                                            │
│   nameserver 127.0.0.11  ← Docker's embedded DNS           │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ↓
┌─────────────────────────────────────────────────────────────┐
│ Docker Embedded DNS (127.0.0.11)                           │
│                                                             │
│ 1. Check container names in consul-net                     │
│    ├─ demo-consul-101-cicd-counting-1 ✓                    │
│    ├─ demo-consul-101-cicd-counting-2 ✓                    │
│    └─ demo-consul-101-cicd-counting-3 ✓                    │
│                                                             │
│ 2. Check network aliases in consul-net                     │
│    └─ "counting" alias → 3 containers ✅                    │
│                                                             │
│ 3. Return all IPs with "counting" alias                    │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ↓
┌─────────────────────────────────────────────────────────────┐
│ DNS Response                                                │
│   counting = 172.20.0.2, 172.20.0.3, 172.20.0.4           │
│   (Round-robin order)                                       │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ↓
┌─────────────────────────────────────────────────────────────┐
│ Dashboard connects to one IP                                │
│   HTTP GET http://172.20.0.2:9003                          │
└─────────────────────────────────────────────────────────────┘
```

**No forwarding needed!** Docker DNS resolves it internally.

---

### Scenario 2: External Domain Resolution (google.com)

```
┌─────────────────────────────────────────────────────────────┐
│ Container                                                   │
│   Query: google.com                                         │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ↓
┌─────────────────────────────────────────────────────────────┐
│ Docker Embedded DNS (127.0.0.11)                           │
│                                                             │
│ 1. Not a container name ✗                                  │
│ 2. Not a service name ✗                                    │
│ 3. Not a network alias ✗                                   │
│                                                             │
│ 4. Forward to upstream DNS servers                         │
│    (Docker daemon's configured DNS)                         │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ↓
┌─────────────────────────────────────────────────────────────┐
│ Host's DNS Resolvers                                        │
│   - 8.8.8.8 (Google DNS)                                   │
│   - 1.1.1.1 (Cloudflare DNS)                               │
│   - Or corporate DNS                                        │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ↓
┌─────────────────────────────────────────────────────────────┐
│ Internet DNS Resolution                                     │
│   google.com → 142.250.185.46                              │
└─────────────────────────────────────────────────────────────┘
```

**Forwarding happens automatically** for non-Docker names.

---

### Scenario 3: Consul DNS Query (.consul domain)

**Problem**: If dashboard tries to query `counting.service.consul`:

```
┌─────────────────────────────────────────────────────────────┐
│ Dashboard Container                                         │
│   Query: counting.service.consul:9003                       │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ↓
┌─────────────────────────────────────────────────────────────┐
│ Docker Embedded DNS (127.0.0.11)                           │
│                                                             │
│ 1. Not a container name ✗                                  │
│ 2. Not a service name ✗                                    │
│ 3. Not a network alias ✗                                   │
│                                                             │
│ 4. Forward to upstream DNS (host's DNS)                    │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ↓
┌─────────────────────────────────────────────────────────────┐
│ Host's DNS (8.8.8.8)                                        │
│                                                             │
│ "consul" is not a valid TLD                                │
│ NXDOMAIN (Name not found) ✗                                │
└─────────────────────────────────────────────────────────────┘
```

**Result**: ❌ FAILS because Docker DNS doesn't know to forward `.consul` queries to Consul DNS server.

---

## How Consul DNS Works (Port 8600)

Consul has its own DNS server listening on port 8600:

```yaml
consul:
  ports:
    - "8600:8600/udp"  # Consul DNS port
```

### Consul DNS Capabilities

```
Query: counting.service.consul
    ↓
Consul DNS Server (172.20.0.10:8600)
    ↓
Checks Consul Service Catalog
    ↓
Filters: Only HEALTHY instances
    ↓
Returns: IPs of healthy counting services
```

### Consul Recursor Configuration

```yaml
consul:
  command: agent -dev -client=0.0.0.0 -recursor=8.8.8.8
```

**What `-recursor=8.8.8.8` does:**

```
Query to Consul DNS: google.com
    ↓
Consul DNS checks: Not a .consul domain
    ↓
Forwards to: 8.8.8.8 (recursor)
    ↓
8.8.8.8 resolves: google.com → 142.250.185.46
    ↓
Consul DNS returns result to client
```

**Purpose**: Allows Consul DNS to handle both:
- Consul service queries (`.consul` domains)
- External queries (everything else)

---

## Network Configuration

### Subnet Configuration

```yaml
networks:
  consul-net:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16
```

**What this does:**
- Creates isolated network with IP range: `172.20.0.0/16`
- Allows 65,534 IP addresses (172.20.0.1 - 172.20.255.254)
- Containers get IPs automatically from this range
- DNS resolution works only within this network

### Fixed IP for Consul

```yaml
consul:
  networks:
    consul-net:
      ipv4_address: 172.20.0.10
```

**Why fixed IP?**
- Consul always has same IP (172.20.0.10)
- Makes it easier to configure DNS forwarding
- Allows services to hardcode Consul location
- Prevents IP conflicts during restarts

---

## Network Aliases in Detail

### How Aliases Work

```yaml
counting:
  networks:
    consul-net:
      aliases:
        - counting
```

**Effect:**
1. Each counting container gets:
   - Its own unique IP (e.g., 172.20.0.2)
   - Its full name (demo-consul-101-cicd-counting-1)
   - The alias name (`counting`)

2. Docker DNS maps the alias to **all containers** with that alias:
   ```
   counting → 172.20.0.2 (counting-1)
   counting → 172.20.0.3 (counting-2)  
   counting → 172.20.0.4 (counting-3)
   ```

3. When queried, Docker DNS returns **all IPs** in round-robin order

### Without Aliases (What Would Happen)

If we removed the alias:

```yaml
counting:
  networks:
    - consul-net  # No alias
```

Then:
- ❌ `counting` would NOT resolve
- ✅ `demo-consul-101-cicd-counting-1` would resolve
- ✅ `counting` (service name) might work in some cases

**Problem**: Full container names are unpredictable and break when scaling.

---

## DNS Flow Comparison

### Current Setup (Working)

```
Dashboard → counting:9003
    ↓
Docker DNS (127.0.0.11)
    ↓
Resolves via network alias
    ↓
Returns: 172.20.0.2, 172.20.0.3, 172.20.0.4
    ↓
Dashboard connects (round-robin)
    ↓
✅ SUCCESS
```

### If Using .service.consul (Without Config)

```
Dashboard → counting.service.consul:9003
    ↓
Docker DNS (127.0.0.11)
    ↓
Not found, forward to host DNS
    ↓
Host DNS: "consul" TLD doesn't exist
    ↓
❌ NXDOMAIN - FAILS
```

### If Configured to Use Consul DNS

```yaml
dashboard:
  dns:
    - 172.20.0.10  # Consul DNS
    - 8.8.8.8      # Fallback
```

Then:

```
Dashboard → counting.service.consul:9003
    ↓
Consul DNS (172.20.0.10:53)
    ↓
Queries Consul service catalog
    ↓
Returns: Healthy counting IPs
    ↓
Dashboard connects
    ↓
✅ SUCCESS
```

---

## Key Takeaways

### 1. **Docker Embedded DNS (127.0.0.11)**
- Present in every container
- Resolves container names, service names, and aliases
- Forwards unknown queries to upstream DNS
- Provides automatic round-robin load balancing

### 2. **Network Aliases**
- Enable short, friendly service names
- Map multiple containers to one name
- Critical for service discovery
- Make scaling transparent

### 3. **Consul DNS (Port 8600)**
- Separate DNS server for `.consul` domains
- Queries Consul's service catalog
- Filters by health status
- Has recursor for external queries

### 4. **No DNS Forwarding Between Docker DNS and Consul DNS**
- Docker DNS doesn't automatically forward to Consul
- Requires explicit `dns:` configuration
- Current setup uses Docker DNS only (simpler)
- Consul still used for health monitoring

### 5. **Why Current Setup Works**
- Uses Docker's native DNS capabilities
- Network aliases provide service discovery
- No complex DNS forwarding needed
- Consul monitors health without DNS integration
- Simple, reliable, production-ready

---

## Visual Summary

```
┌──────────────────────────────────────────────────────────┐
│  Container (dashboard-1)                                 │
│  ┌─────────────────────────────────────────────────┐    │
│  │ Application: http://counting:9003               │    │
│  └─────────────────┬───────────────────────────────┘    │
│                    │                                     │
│  ┌─────────────────▼───────────────────────────────┐    │
│  │ /etc/resolv.conf                                │    │
│  │   nameserver 127.0.0.11                         │    │
│  └─────────────────┬───────────────────────────────┘    │
└────────────────────┼──────────────────────────────────┘
                     │
                     ▼
     ┌───────────────────────────────────────┐
     │  Docker Embedded DNS (127.0.0.11)     │
     │                                        │
     │  Resolution order:                    │
     │  1. Container names                   │
     │  2. Service names                     │
     │  3. Network aliases ← counting ✓      │
     │  4. Forward to upstream DNS           │
     └───────────────┬───────────────────────┘
                     │
        ┌────────────┴────────────┐
        │                         │
        ▼                         ▼
  [Found: counting]        [Not found: google.com]
        │                         │
        │                         ↓
        │                  Forward to 8.8.8.8
        │                         │
        ↓                         ↓
  Return IPs:            Return external IP
  172.20.0.2
  172.20.0.3
  172.20.0.4
```

---

## Conclusion

Your docker-compose.yaml uses **Docker's native DNS** with **network aliases** for service discovery. There's **no explicit DNS forwarding** to Consul DNS - Docker DNS handles everything internally. Consul is used for **health monitoring and service registration**, not for DNS resolution in this setup.

This is a **simple, reliable, and production-ready** approach! 🎉
