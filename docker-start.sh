#!/bin/sh
DOUBTFIRE_DOCKER_MACHINE_IP=$(docker-machine ip doubtfire)

if [ $? -ne 0 ]; then
  echo "Docker machine is not running. Attempting to start..."
  docker-machine start doubtfire
  if [ $? -ne 0 ]; then
    echo "Could not start Doubtfire docker machine!"
    echo "Ensure you have created the docker machine first:"
    echo "\tdocker-machine create --driver virtualbox doubtfire"
    exit 1
  fi
  eval "$(docker-machine env doubtfire)"
fi

echo "Trying to restore previous Doubtfire service..."
DOUBTFIRE_DOCKER_MACHINE_IP=$DOUBTFIRE_DOCKER_MACHINE_IP docker-compose -p doubtfire up -d

if [ $? -ne 0 ]; then
  echo "No previous Doubtfire service has been created. Creating services..."
  DOUBTFIRE_DOCKER_MACHINE_IP=$DOUBTFIRE_DOCKER_MACHINE_IP docker-compose -p doubtfire create

  if [ $? -ne 0 ]; then
    echo "Failed to create services! Refer to docker-compose output above."
    exit 2
  fi

  echo "Starting Database..."
  DOUBTFIRE_DOCKER_MACHINE_IP=$DOUBTFIRE_DOCKER_MACHINE_IP docker-compose -p doubtfire start db

  if [ $? -ne 0 ]; then
    echo "Failed to start the database! Refer to docker-compose output above."
    exit 3
  fi

  echo "Starting Doubtfire API and Web..."
  DOUBTFIRE_DOCKER_MACHINE_IP=$DOUBTFIRE_DOCKER_MACHINE_IP docker-compose -p doubtfire up -d

  if [ $? -ne 0 ]; then
    echo "Failed to start the API and Web interfaces! Refer to docker-compose output above."
    exit 4
  fi
fi

echo "Populating database with test data..."
DOUBTFIRE_DOCKER_MACHINE_IP=$DOUBTFIRE_DOCKER_MACHINE_IP docker-compose -p doubtfire run api rake db:populate

if [ $? -ne 0 ]; then
  echo "Failed to populate the database! Refer to docker-compose output above."
  exit 5
fi

echo "Done!"

echo
echo "To stop Doubtfire, run docker-stop.sh"
echo
echo "Doubtfire is hosted locally at:"
echo "\tDoubtfire API: http://$DOUBTFIRE_DOCKER_MACHINE_IP:3000/api/docs/"
echo "\tDoubtfire Web: http://$DOUBTFIRE_DOCKER_MACHINE_IP:8000/"
