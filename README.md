# Demo Consul 101 - CICD

A demonstration project showcasing Consul service discovery and health checking with Docker Compose, featuring automated service registration for counting and dashboard microservices.

## Architecture

The project consists of:
- **Consul Server**: Service registry and health checker
- **Counting Service**: Backend API service (3 instances)
- **Dashboard Service**: Frontend UI service (3 instances)
- **Consul Register**: Automated service registration container

All services run on a custom Docker bridge network (`consul-net`) for isolated communication.

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
- Launch 3 counting service instances
- Launch 3 dashboard service instances
- Automatically register all services with Consul

### 3. Access Services

- **Consul UI**: http://localhost:8500

### 4. View Container Startup Logs

Monitor service containers as they start:

```sh
# View all services logs
docker compose logs -f

# View specific service logs
docker logs -f demo-consul-101-cicd-counting-1
docker logs -f demo-consul-101-cicd-dashboard-1
docker logs -f demo-consul-101-cicd-counting-2
docker logs -f consul
```

**Example Startup Output:**

```
counting-1  | Serving at http://localhost:9003
counting-1  | (Pass as PORT environment variable)
counting-2  | Serving at http://localhost:9003
counting-2  | (Pass as PORT environment variable)
counting-3  | Serving at http://localhost:9003
counting-3  | (Pass as PORT environment variable)

dashboard-1  | Starting server on http://0.0.0.0:9002
dashboard-1  | (Pass as PORT environment variable)
dashboard-1  | Using counting service at http://counting:9003
dashboard-1  | (Pass as COUNTING_SERVICE_URL environment variable)
dashboard-1  | Starting websocket server...
dashboard-2  | Starting server on http://0.0.0.0:9002
dashboard-2  | (Pass as PORT environment variable)
dashboard-2  | Using counting service at http://counting:9003
dashboard-2  | (Pass as COUNTING_SERVICE_URL environment variable)
dashboard-2  | Starting websocket server...
```

### 5. View Service Registration Logs

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

Check registered services:

```sh
# List all services
consul catalog services
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
