#!/bin/sh
DOUBTFIRE_DOCKER_MACHINE_IP=$(docker-machine ip doubtfire)

echo Stopping doubtfire...
DOUBTFIRE_DOCKER_MACHINE_IP=$DOUBTFIRE_DOCKER_MACHINE_IP docker-compose -p doubtfire down
