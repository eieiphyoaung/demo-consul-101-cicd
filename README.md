## Quick Start

### 1. Prepare Binaries
Download the Linux ARM64 binaries for both services:

```sh
curl -LO https://github.com/hashicorp/demo-consul-101/releases/download/v0.0.5/counting-service_linux_arm64.zip
unzip counting-service_linux_arm64.zip
mv counting-service_linux_arm64 counting-service
chmod +x counting-service
rm counting-service_linux_arm64.zip

curl -LO https://github.com/hashicorp/demo-consul-101/releases/download/v0.0.5/dashboard-service_linux_arm64.zip
unzip dashboard-service_linux_arm64.zip
mv dashboard-service_linux_arm64 dashboard-service
chmod +x dashboard-service
rm dashboard-service_linux_arm64.zip
```

### 2. Build Images

```sh
docker build -f Dockerfile.counting -t <your-dockerhub-username>/counting:latest .
docker build -f Dockerfile.dashboard -t <your-dockerhub-username>/dashboard:latest .
```

### 3. Run with Docker Compose

```sh
docker compose up --build
```

### 4. Run Individually (with custom network)

```sh
docker network create mynet

docker run -d --rm --name counting --network mynet -p 9003:9003 <your-dockerhub-username>/counting:latest

docker run -d --rm --name dashboard --network mynet -p 9002:9002 \
  -e COUNTING_SERVICE_URL=http://counting:9003 \
  <your-dockerhub-username>/dashboard:latest
```

## File Structure

```
.
├── Dockerfile.counting
├── Dockerfile.dashboard
├── dashboard-service
├── counting-service
├── docker-compose.yaml
└── README.md
```
