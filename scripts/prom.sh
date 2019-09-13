#!/usr/bin/env bash

if [ "$1" = "" ]; then
  echo "path to prometheus link required"
  exit 1
fi

LINK=$1


SUB_DIR=$(echo $LINK | grep -oP '\/pull\/(\w+)\/(\d+)\/(\w+.*\w\/\d+)')
INSTALL_DIR="${HOME}/prometheus/$SUB_DIR"

IP=$((1 + RANDOM % 253))

init () {
  mkdir -p $INSTALL_DIR
  cd $INSTALL_DIR
  mkdir prom-data
  curl -L $LINK | tar -xz -C prom-data --strip-components=1
  sudo chmod -R 777 prom-data
}

gen_config() {
  cat > $INSTALL_DIR/docker-compose.yml << EOF
version: '2'
services:

    prom1:
        image: prom/prometheus:v2.6.0
        restart: always
        ports:
            - 9090
        volumes:
          - ./prom-data/:/etc/prometheus/data/
        networks:
          prom_net:
            ipv4_address: 172.24.${IP}.10
networks:
  prom_net:
    driver: bridge
    driver_opts:
      com.docker.network.enable_ipv6: "false"
    ipam:
      driver: default
      config:
      - subnet: 172.24.${IP}.0/24
        gateway: 172.24.${IP}.1
EOF
}

start() {
  cd $INSTALL_DIR; docker-compose up -d
  echo "Now available via http://172.24.${IP}.10:9090"
}


init
gen_config
start
