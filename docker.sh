#!/bin/sh

#
# Doubtfire Docker Script
# =======================
#
# Provides commands to run Doubtfire via Docker without
# actually needing to know Docker commands (hopefully)
#

#
# Resets the color
#
msg_reset () {
  RESET='\033[0m'
  printf "${RESET}\n"
}

#
# Log an error
#
error () {
  RED_FORE='\033[0;31m'
  printf "${RED_FORE}ERROR: $1"
  msg_reset
}

#
# Log verbose message
#
verbose () {
  if [ $VERBOSE_OUTPUT -eq 1 ]; then
    return
  fi
  CYAN_FORE='\033[0;36m'
  printf "${CYAN_FORE}INFO: $1"
  msg_reset
}

#
# Log message
#
msg () {
  printf "$1\n"
}

#
# Try and get the docker machine IP
# Returns the IP or else exits the script
#
get_docker_machine_ip () {
  DOUBTFIRE_DOCKER_MACHINE_IP=$(docker-machine ip doubtfire)

  if [ $? -ne 0 ]; then
    verbose "Docker machine is not running. Attempting to start..."
    docker-machine start doubtfire
    if [ $? -ne 0 ]; then
      error "Could not start Doubtfire docker machine!"
      msg "Ensure you have created the docker machine first:"
      msg "  docker-machine create --driver virtualbox doubtfire"
      exit 1
    fi
  fi

  verbose "Running Docker daemon..."
  eval "$(docker-machine env doubtfire)"
}

#
# Returns whether or not the provided service is running
#
is_service_running () {
  verbose "Checking if $1 is running..."
  DOUBTFIRE_DOCKER_MACHINE_IP=$DOUBTFIRE_DOCKER_MACHINE_IP docker-compose -p doubtfire ps $1 | grep 'Up' &> /dev/null
  if [ $? -ne 0 ]; then
    verbose "Service $1 is not running!"
    return 1
  fi
  verbose "Service $1 is running"
  return 0
}

#
# Returns whether or not all services are running
#
is_doubtfire_running () {
  verbose "Checking if doubtfire is running..."
  if is_service_running "db" && is_service_running "api" && is_service_running "db" ; then
    verbose "Doubtfire is up and running"
    return 0
  fi
  verbose "Doubtfire is not running!"
  return 1
}

#
# Tries and restores a previous instance of the docker
#
restore_doubtfire_services () {
  msg "Attempting to restore Doubtfire services..."
  DOUBTFIRE_DOCKER_MACHINE_IP=$DOUBTFIRE_DOCKER_MACHINE_IP docker-compose -p doubtfire up -d
  if [ $? -ne 0 ]; then
    verbose "Failed to restore Doubtfire."
    return 1
  fi
  verbose "Restored Doubtfire"
  return 0
}

#
# Tries and restores a previous instance of the docker
#
build_doubtfire_images () {
  case $1 in
    'api'|'web'|'db')
      ;;
    '')
      msg "Building all Doubtfire images. This may take a while..."
      ;;
    *)
      msg "Invalid image provided. Please provide one of api, web or db."
      return 1
      ;;
  esac
  DOUBTFIRE_DOCKER_MACHINE_IP=$DOUBTFIRE_DOCKER_MACHINE_IP docker-compose -p doubtfire build $1
  if [ $? -ne 0 ]; then
    error "Failed to build Doubtfire. Refer to logs above."
    return 1
  fi
  verbose "Built Doubtfire"
  return 0
}

#
# Tries to create Doubtfire services
#
create_doubtfire_services () {
  verbose "Attempting to create Doubtfire services..."
  DOUBTFIRE_DOCKER_MACHINE_IP=$DOUBTFIRE_DOCKER_MACHINE_IP docker-compose -p doubtfire create
  if [ $? -ne 0 ]; then
    error "Failed to create services! Refer to docker-compose output above."
    return 1
  fi
  verbose "Created Doubtfire services"
  return 0
}

#
# Starts the doubtfire database
#
start_doubtfire_database () {
  verbose "Attempting to start Doubtfire database container..."
  DOUBTFIRE_DOCKER_MACHINE_IP=$DOUBTFIRE_DOCKER_MACHINE_IP docker-compose -p doubtfire start db
  if [ $? -ne 0 ]; then
    error "Failed to start Doubtfire database! Refer to docker-compose output above."
    return 1
  fi
  verbose "Started Doubtfire Database"
  return 0
}

#
# Tries a direct connect to the DF postgresql database
#
is_postgres_running () {
  IS_RUNNING=$(DOUBTFIRE_DOCKER_MACHINE_IP=$DOUBTFIRE_DOCKER_MACHINE_IP docker-compose -p doubtfire run db bash -c "PGPASSWORD=d872\\\$dh psql -h db -U itig -c \"select 'It is running'\" 2>/dev/null | grep -c \"It is running\"")
  if [[ $IS_RUNNING == *"1"* ]]; then
    return 0
  else
    return 1
  fi
}

#
# Populates doubtfire database
#
populate_doubtfire_database () {
  msg "Ensuring database is running..."
  # Check if database is running. If not start it
  if ! is_service_running "db" && ! start_doubtfire_database; then
    error "Cannot populate as service isn't running"
    return 1
  fi
  # Ensure we can actually connect to the DB before we ask to write to it
  while ! is_postgres_running; do
    verbose "Postgres not yet running... sleep 1"
    sleep 1
  done
  msg "Populating database with test data..."
  DOUBTFIRE_DOCKER_MACHINE_IP=$DOUBTFIRE_DOCKER_MACHINE_IP docker-compose -p doubtfire run api rake db:populate
  if [ $? -ne 0 ]; then
    error "Failed to populate Doubtfire database! Refer to error above."
    return 1
  fi
  msg "Database populated!"
  return 0
}

#
# Shows DF is running message
#
show_running_message () {
  msg "Doubtfire is now running at:"
  msg "  Doubtfire API: http://$DOUBTFIRE_DOCKER_MACHINE_IP:3000/api/docs/"
  msg "  Doubtfire Web: http://$DOUBTFIRE_DOCKER_MACHINE_IP:8000/"
  msg "It may take several moments for the URLs above to become active"
}

#
# Starts doubtfire
#
start_doubtfire () (
  try_build_df_again () {
    verbose "Attempting to recover by re-building Doubtfire images..."
    if ! build_doubtfire_images; then
      error "Cannot build Doubtfire images"
      return 1
    fi
  }
  get_docker_machine_ip
  msg "Starting doubtfire ..."
  if is_doubtfire_running; then
    msg "No need to start Doubtfire. It is already running."
    show_running_message
    return 0
  fi
  # First, try to see if the services have already been created
  # and if not create them
  if ! restore_doubtfire_services && ! create_doubtfire_services; then
    verbose "Problem creating services. Trying to rebuild images..."
    if ! try_build_df_again; then
      error "Failed to start Doubtfire - cannot create services"
      return 1
    fi
  fi
  # Repopulate database
  if ! populate_doubtfire_database; then
    verbose "Problem populating. Trying to rebuild images..."
    if ! try_build_df_again || ! restore_doubtfire_services; then
      error "Failed to start Doubtfire - could not populate data and restore"
      return 1
    fi
  fi
  show_running_message
)

#
# Stop doubtfire
#
stop_doubtfire () {
  get_docker_machine_ip

  if ! is_doubtfire_running; then
    msg "No need to stop Doubtfire. It is already stopped."
    return 1
  fi

  msg "Stopping doubtfire ..."
  DOUBTFIRE_DOCKER_MACHINE_IP=$DOUBTFIRE_DOCKER_MACHINE_IP docker-compose -p doubtfire down

  if [ $? -ne 0 ]; then
    error "Failed to stop Doubtfire! Check logs above"
    return 1
  fi

  msg "Doubtfire is no longer running"
}

#
# Restart doubtfire
#
restart_doubtfire () {
  get_docker_machine_ip

  if ! is_doubtfire_running; then
    msg "Cannot restart Doubtfire. It is not running"
    return 1
  fi

  msg "Restarting doubtfire ..."
  DOUBTFIRE_DOCKER_MACHINE_IP=$DOUBTFIRE_DOCKER_MACHINE_IP docker-compose -p doubtfire restart

  if [ $? -ne 0 ]; then
    error "Failed to restart Doubtfire! Check logs above"
    return 1
  fi

  msg "Doubtfire was restarted."
  show_running_message
}

#
# Attach to container
#
attach_to () {
  get_docker_machine_ip

  case $1 in
    'api'|'web'|'db')
      ;;
    *)
      msg "Invalid container provided. Please provide one of api, web or db."
      return 1
      ;;
  esac

  if ! is_doubtfire_running; then
    msg "Cannot attach or ssh into to Doubtfire container. Doubtfire is not running"
    return 1
  fi

  msg "Attaching to $1. Use ctrl+c to detach."
  docker attach --sig-proxy=false doubtfire-$1
  msg "\nDeattached from $1."
}

#
# Show help
#
show_help () {
  msg "Run Doubtfire using Docker."
  msg
  msg "Usage:"
  msg "./docker.sh [COMMAND] [ARGS...]"
  msg "./docker.sh -h"
  msg
  msg "Options:"
  msg "  -v  Show more output"
  msg "  -h  Display help"
  msg
  msg "Commands:"
  msg "  start      Start Doubtfire docker services"
  msg "  stop       Stop Doubtfire docker services"
  msg "  restart    Restart Doubtfire docker services"
  msg "  build      (Re)build Doubtfire docker image(s)"
  msg "  populate   Populate the API with test data"
  msg "  attach     Attach to one of the api, web or db containers"
  return 0
}

#
# Handle options
#
handle_options () {
  COMMAND=$1
  VERBOSE_OUTPUT=1
  shift 1
  # Not a switch?
  if [[ $1 != "-"* ]]; then
    ARG_1=$1
    shift 1
  fi
  while getopts ":vh" OPT; do
    case $OPT in
      v)
        VERBOSE_OUTPUT=0
        ;;
      h)
        show_help
        return $?
        ;;
      \?)
        error "Invalid option: -$OPTARG" >&2
        ;;
    esac
  done
  case $COMMAND in
    "start")
      start_doubtfire
      return $?
      ;;
    "stop")
      stop_doubtfire
      return $?
      ;;
    "restart")
      restart_doubtfire
      return $?
      ;;
    "populate")
      populate_doubtfire_database
      return $?
      ;;
    "build")
      build_doubtfire_images $ARG_1
      return $?
      ;;
    "attach")
      attach_to $ARG_1
      return $?
      ;;
    "")
      show_help
      return $?
      ;;
    *)
      msg "Invalid command provided"
      return 1
      ;;
  esac
}

handle_options $*
