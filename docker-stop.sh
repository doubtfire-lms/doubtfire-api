#!/bin/sh
DOUBTFIRE_DOCKER_MACHINE_IP=$(docker-machine ip doubtfire)

echo "Stopping doubtfire..."
DOUBTFIRE_DOCKER_MACHINE_IP=$DOUBTFIRE_DOCKER_MACHINE_IP docker-compose -p doubtfire down

if [ $? -ne 0 ]; then
    echo "Failed to stop Doubtfire! Either it isn't running or something went wrong."
    exit 3
fi

echo "Done!"
echo
echo "Doubtfire is no longer running"
echo "To start Doubtfire, run docker-start.sh"
