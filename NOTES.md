# In your dashboard-counting-docker directory:
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


docker build -f Dockerfile.counting -t ei2000/counting:latest .
docker build -f Dockerfile.dashboard -t ei2000/dashboard:latest .

docker images

docker tag ei2000/counting:latest ei2000/counting:0.0.1
docker tag ei2000/dashboard:latest ei2000/dashboard:0.0.1

docker push ei2000/counting:0.0.1
docker push ei2000/dashboard:0.0.1

docker push ei2000/counting:latest
docker push ei2000/dashboard:latest

# Run containers using your own images
docker run --rm -p 9003:9003 --name counting ei2000/counting:latest


docker run --dns=172.17.0.1 --rm -p 9003:9003 --name counting4 ei2000/counting:latest

docker run --rm -p 9002:9002 --name dashboard \
  -e COUNTING_SERVICE_URL=http://host.docker.internal:9003 \
  ei2000/dashboard:latest


docker network create mynet
docker run --rm -p 9003:9003 --name counting --network mynet ei2000/counting:latest
docker run --rm -p 9002:9002 --name dashboard --network mynet \
  -e COUNTING_SERVICE_URL=http://counting:9003 \
  ei2000/dashboard:latest


## another way to with dockercompose

docker compose up --build

## delete docker images and docker ps

docker rm -f $(docker ps -aq)
docker rmi -f $(docker images -q)