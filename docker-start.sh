#!/bin/sh
DOUBTFIRE_DOCKER_MACHINE_IP=$(docker-machine ip doubtfire)

echo Creating services...
DOUBTFIRE_DOCKER_MACHINE_IP=$DOUBTFIRE_DOCKER_MACHINE_IP docker-compose -p doubtfire build

echo Starting Database...
DOUBTFIRE_DOCKER_MACHINE_IP=$DOUBTFIRE_DOCKER_MACHINE_IP docker-compose -p doubtfire start db

echo Populating database with test data...
DOUBTFIRE_DOCKER_MACHINE_IP=$DOUBTFIRE_DOCKER_MACHINE_IP docker-compose -p doubtfire run api rake db:populate

echo Starting Doubtfire API and Web...
DOUBTFIRE_DOCKER_MACHINE_IP=$DOUBTFIRE_DOCKER_MACHINE_IP docker-compose -p doubtfire up -d

echo Done!

echo
echo To stop Doubtfire, run stop.sh
echo
echo Doubtfire is hosted locally at:
echo "\tDoubtfire API: http://$DOUBTFIRE_DOCKER_MACHINE_IP:3000/api/docs/"
echo "\tDoubtfire Web: http://$DOUBTFIRE_DOCKER_MACHINE_IP:8000/"
