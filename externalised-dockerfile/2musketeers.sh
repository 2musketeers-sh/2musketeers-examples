#!/bin/bash
##################################################################
#
# This script is a patern and is designed to customised per use.
#    see - https://2musketeers.sh
#
##################################################################

##
# Allow the parent script to run as is. This, assumes that the current environment has all the necessary dependencies
##
: ${RUN_LOCAL:="false"}
##
# The base Docker image to wrap the script with
##
: ${DOCKER_RUN_IMAGE:="debian:jessie-slim"}

##
# Use a Dockerfile instead of specifying an inline one. This allows it to be customised per calling script
##
: ${DOCKER_BUILD_FILE:="Dockerfile.build"}
##
# Hide the docker build output unless there is an error
##
: ${DOCKER_BUILD_VERBOSE:="false"}

##
# When CONTAINER_PREFIX is set to SCRIPT, a new build container will be built for 
# each calling script. Although Docker will cache shared layers, lots of image
# names will be created. 
# Setting this to something of a broader "scope", such as the apps checkout 
# directory name, will produce 1 build container for all scripts.
##
: ${CONTAINER_PREFIX:=`basename ${DIR}`}

##
# Function to detect if we are running in a container.
# Credit: a bunch of different stackoverflow posts and others. Eg https://tuhrig.de/how-to-know-you-are-inside-a-docker-container/ and https://stackoverflow.com/questions/23513045/how-to-check-if-a-process-is-running-inside-docker-container
##
function is_container () {
  grep -qE '/docker/|/lxc/' /proc/1/cgroup
  echo "$?"
}

##
# Magic time:
# * capture the current running context. In this example we capture the docker GID so we can run docker inside the container. (this is not docker-in-docker though).
# * build a docker image with:
# ** any necessary dependencies,
# ** user, groups and home directory that matches the parent runtime.
# * runs Docker:
# ** passing in all environment variables,
# ** mapping the current working directory into the container at the same location
# * replace the current running program using `exec`.
#
# The uid and gid setup ensure that any files written outside of the container are created with the correct uid & gid.
#  see - https://medium.com/redbubble/running-a-docker-container-as-a-non-root-user-7d2e00f8ee15
#
##
function docker_run () {

  ##
  # Capture the current uid, gid, username and docker gid.
  ##
  local LOCAL_UID=$(id -u)
  local LOCAL_GID=$(id -g)
  local LOCAL_USERNAME="${USER}"
  local DOCKER_GID=$(getent group docker | cut -d: -f3)

    ##
    # Build the container. Remember, Docker is smart about caching layers so the above will likely only be built once!
    #
    # NOTE: This example "scopes" the container to the calling script name. This could easily be changed to APP_NAME or the
    # calling directory name to prevent a new container being created for each shell script
    ##
    DOCKER_BUILD_OUT=$(docker build -t "${CONTAINER_PREFIX}_docker:latest"  \
      --build-arg DOCKER_RUN_IMAGE="${DOCKER_RUN_IMAGE}" \
      --build-arg LOCAL_UID="${LOCAL_UID}" \
      --build-arg LOCAL_GID="${LOCAL_GID}" \
      --build-arg LOCAL_USERNAME="${LOCAL_USERNAME}" \
      --build-arg DOCKER_GID="${DOCKER_GID}" \
      -f "${DOCKER_BUILD_FILE}" . 2>&1) || \
     { ERRCODE=$?; echo "${DOCKER_BUILD_OUT}"; exit $ERRCODE; }
        ##
    # Show the output if needed
    ##
    [ "x${DOCKER_BUILD_VERBOSE}" != "xfalse" ] && echo "${DOCKER_BUILD_OUT}"

    ##
    # Run docker and call the parent script..
    ##
    exec docker run -it \
      -v "${DIR}:${DIR}" \
      --env-file <( env| cut -f1 -d= ) \
      --workdir "${PWD}" \
      "${CONTAINER_PREFIX}_docker:latest" \
      "${DIR}/${SCRIPT}" \
      "$@"
}

##
# If we are not in a container, and we have been ask to run in local mode,
# run the calling script in docker
##
if [ "x${RUN_LOCAL}" = "xfalse" ] && [ "x$(is_container)" = "x1" ]; then
  docker_run "$@"
fi