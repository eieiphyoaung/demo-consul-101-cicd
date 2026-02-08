# Demo Consul 101 - CICD

A demonstration project showcasing Consul service discovery and health checking with Docker Compose, featuring automated service registration for counting and dashboard microservices.

## Architecture

The project consists of:
- **Consul Server**: Service registry and health checker
- **Counting Service**: Backend API service (3 instances)
- **Dashboard Service**: Frontend UI service (3 instances)
- **Nginx Load Balancer**: Distributes traffic across dashboard instances
- **Consul Register**: Automated service registration container

All services run on a custom Docker bridge network (`consul-net`) for isolated communication.

## Key Features

- ✅ **Service Discovery**: Consul DNS resolves `.service.consul` domains with health-aware routing
- ✅ **Load Balancing**: Nginx distributes traffic across dashboard instances
- ✅ **Health Monitoring**: Consul monitors all service health and filters unhealthy instances
- ✅ **Auto Registration**: Services automatically register with Consul
- ✅ **Scalability**: Easily scale services up or down
- ✅ **Resilience**: Automatic failover when services become unhealthy

## Prerequisites

- Docker 20.10 or higher
- Docker Compose v2 or higher
- 8GB RAM recommended for running all services

## Quick Start

### 1. Start All Services

```sh
docker compose up --scale counting=3 --scale dashboard=3
```

This command will:
- Start Consul server on port 8500
- Start Nginx load balancer on port 8080
- Launch 3 counting service instances
- Launch 3 dashboard service instances
- Automatically register all services with Consul

### 2. Access Services

- **Dashboard (via Load Balancer)**: http://localhost:8080
- **Consul UI**: http://localhost:8500

### 3. Test Load Balancing

Verify that Nginx is distributing traffic across dashboard instances:

```sh
# Check Nginx status
docker logs nginx-lb

# Access dashboard multiple times and check which instance responds
curl -I http://localhost:8080

# Monitor dashboard logs to see which instance handles requests
docker compose logs -f dashboard
```

### 4. View Service Registration Logs

Monitor the automated service registration process:

```sh
# View registration container logs
docker logs consul-register
```

**Example Registration Output:**

```
consul-register  | OK: 46.5 MiB in 32 packages
consul-register  | Registering counting services to Consul...
consul-register  | Registered counting-1 (demo-consul-101-cicd-counting-1) at 172.20.0.3:9003
consul-register  | Registered counting-2 (demo-consul-101-cicd-counting-2) at 172.20.0.4:9003
consul-register  | Registered counting-3 (demo-consul-101-cicd-counting-3) at 172.20.0.2:9003
consul-register  | 
consul-register  | Registering dashboard services to Consul...
consul-register  | Registered dashboard-1 (demo-consul-101-cicd-dashboard-1) at 172.20.0.7:9002
consul-register  | Registered dashboard-2 (demo-consul-101-cicd-dashboard-2) at 172.20.0.5:9002
consul-register  | Registered dashboard-3 (demo-consul-101-cicd-dashboard-3) at 172.20.0.6:9002
consul-register  | 
consul-register  | All services registered successfully!
consul-register  | 
consul-register  | Verify with: consul catalog services
consul-register  | Check health: consul catalog service counting
consul-register  | Check health: consul catalog service dashboard
consul-register exited with code 0
```

## Service Details

### Nginx Load Balancer
- **Image**: `nginx:alpine`
- **Port**: 8080 (external) → 80 (internal)
- **Load Balancing**: Least connections algorithm
- **Backend**: All dashboard service instances
- **Health Check**: `/health` endpoint
- **Features**:
  - WebSocket support for real-time updates
  - Automatic request distribution
  - Connection upgrade handling
  - Custom headers for proxy forwarding

### Counting Service
- **Image**: `ei2000/counting:latest`
- **Port**: 9003
- **Instances**: 3 (scalable)
- **Health Check**: HTTP GET to `/health`
- **Purpose**: Backend API providing counting functionality

### Dashboard Service
- **Image**: `ei2000/dashboard:latest`
- **Port**: 9002
- **Instances**: 3 (scalable)
- **Health Check**: HTTP GET to `/health`
- **Upstream**: Connects to counting service via Consul DNS (`http://counting.service.consul:9003`)
- **Access**: Via Nginx load balancer on port 8080

### Consul
- **Image**: `hashicorp/consul:latest`
- **Mode**: Development (-dev)
- **UI Port**: 8500
- **DNS Port**: 8600
- **Purpose**: Service registry and health checking

## How Service Discovery Works

Dashboard connects to Counting service using Consul DNS:

```
Dashboard Container
    ↓ Query: counting.service.consul:9003
    ↓
Docker DNS (127.0.0.11)
    ↓ Forwards .consul domain to host DNS
    ↓
Host DNS (or Docker daemon's DNS)
    ↓ Not found locally
    ↓
Consul DNS Server (172.20.0.10:8600)
    ↓ Queries Consul service catalog
    ↓ Filters only HEALTHY instances
    ↓
Returns: [172.20.0.3, 172.20.0.4, 172.20.0.2]
    ↓ Round-robin load balancing
    ↓
Counting Service Instance
```


## Checking Container IPs

To view the IP addresses of running containers in the Docker network:

```sh
docker ps --format "{{.Names}}" | grep -E "counting|dashboard" | xargs -I {} sh -c 'echo "{}: $(docker inspect -f "{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}" {})"'
```

**Example Output:**
```
demo-consul-101-cicd-counting-1: 172.20.0.3
demo-consul-101-cicd-counting-2: 172.20.0.4
demo-consul-101-cicd-counting-3: 172.20.0.2
demo-consul-101-cicd-dashboard-1: 172.20.0.7
demo-consul-101-cicd-dashboard-2: 172.20.0.5
demo-consul-101-cicd-dashboard-3: 172.20.0.6
```

## Service Registration

Services are automatically registered with Consul using the `register-services.sh` script

### Manual Registration

If you need to manually register services:

```sh
./register-services.sh
```

### Verify Registration

Check registered services in Consul:

```sh
# List all services
docker exec consul consul catalog services

# Check counting service details
docker exec consul consul catalog service counting

# Check dashboard service details
docker exec consul consul catalog service dashboard

# Check health status
curl http://localhost:8500/v1/health/service/counting
```

## Testing Service Discovery

Test that dashboard can reach counting service via Consul DNS:

```sh
# Test Consul DNS resolution for .service.consul domain
docker exec demo-consul-101-cicd-dashboard-1 nslookup counting.service.consul

# Test HTTP connection using Consul DNS
docker exec demo-consul-101-cicd-dashboard-1 wget -qO- http://counting.service.consul:9003

# Test Docker DNS resolution (fallback)
docker exec demo-consul-101-cicd-dashboard-1 nslookup counting

# Test HTTP connection using Docker DNS
docker exec demo-consul-101-cicd-dashboard-1 wget -qO- http://counting:9003

# Test end-to-end via Nginx
curl http://localhost:8080

# Verify services are registered in Consul
docker exec consul consul catalog service counting
curl http://localhost:8500/v1/health/service/counting
```

## Scaling Services

You can adjust the number of instances for each service:

```sh
# Scale to 5 counting and 2 dashboard instances
docker compose up --scale counting=5 --scale dashboard=2

# Scale down to 1 instance each
docker compose up --scale counting=1 --scale dashboard=1
```

## Stopping and Cleanup

### Stop All Services

```sh
docker compose down
```

### Remove All Data and Networks

```sh
docker compose down -v
```

### Clean Docker Resources

```sh
# Remove all containers
docker rm -f $(docker ps -aq)

# Remove all images
docker rmi -f $(docker images -q)
```

**Note**: This is a development setup. For production deployments, use Consul in cluster mode with proper security configurations.

## Architecture Diagram

```
External Client (Browser)
         ↓
    http://localhost:8080
         ↓
  ┌──────────────────┐
  │  Nginx Load      │
  │  Balancer        │
  │  (Port 8080)     │
  └────────┬─────────┘
           │
    ┌──────┼──────┐
    ↓      ↓      ↓
┌─────┐ ┌─────┐ ┌─────┐
│Dash │ │Dash │ │Dash │
│  1  │ │  2  │ │  3  │
└──┬──┘ └──┬──┘ └──┬──┘
   │       │       │
   └───────┼───────┘
           │
    Docker DNS: counting:9003
           │
    ┌──────┼──────┐
    ↓      ↓      ↓
┌─────┐ ┌─────┐ ┌─────┐
│Count│ │Count│ │Count│
│  1  │ │  2  │ │  3  │
└──┬──┘ └──┬──┘ └──┬──┘
   │       │       │
   └───────┼───────┘
           │
    ┌──────────────┐
    │   Consul     │
    │  Registry &  │
    │   Health     │
    │  Monitoring  │
    └──────────────┘
```

## Quick Reference

### Common Commands

```sh
# Start all services with scaling
docker compose up --scale counting=3 --scale dashboard=3

# Start in detached mode
docker compose up -d --scale counting=3 --scale dashboard=3

# View logs
docker compose logs -f
docker logs nginx-lb
docker logs consul

# Check Nginx configuration
docker exec nginx-lb nginx -t

# Reload Nginx
docker exec nginx-lb nginx -s reload

# Test load balancer
curl http://localhost:8080
curl http://localhost:8080/health

# Check Consul services
docker exec consul consul catalog services

# Stop all services
docker compose down
```

### Useful URLs

- **Dashboard (Load Balanced)**: http://localhost:8080
- **Consul UI**: http://localhost:8500
- **Nginx Health Check**: http://localhost:8080/health

## Troubleshooting

### Dashboard Can't Connect to Counting Service

```sh
# Check if services are running
docker ps | grep demo-consul-101-cicd

# Test DNS resolution
docker exec demo-consul-101-cicd-dashboard-1 nslookup counting

# Test direct connection
docker exec demo-consul-101-cicd-dashboard-1 wget -qO- http://counting:9003

# Check dashboard logs
docker logs demo-consul-101-cicd-dashboard-1

# Check counting logs
docker logs demo-consul-101-cicd-counting-1
```

### Services Not Registering in Consul

```sh
# Check consul-register logs
docker logs consul-register

# Manually run registration
./register-services.sh

# Check Consul connectivity
docker exec demo-consul-101-cicd-dashboard-1 wget -qO- http://consul:8500/v1/catalog/services
```

### Nginx Not Load Balancing

```sh
# Check Nginx logs
docker logs nginx-lb

# Test Nginx configuration
docker exec nginx-lb nginx -t

# Reload Nginx
docker exec nginx-lb nginx -s reload

# Verify backend connectivity
docker exec nginx-lb wget -qO- http://demo-consul-101-cicd-dashboard-1:9002
```

### Full Reset

```sh
# Stop and remove everything
docker compose down -v

# Remove all containers and networks
docker rm -f $(docker ps -aq)
docker network prune -f

# Start fresh
docker compose up --scale counting=3 --scale dashboard=3
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License.

## Resources

- [HashiCorp Consul Documentation](https://www.consul.io/docs)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Nginx Documentation](https://nginx.org/en/docs/)

---

**Built with ❤️ for learning Consul service discovery and load balancing**
