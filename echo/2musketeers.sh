#!/bin/bash
##################################################################
#
# This script is a pattern and is designed to customised per use.
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
# When CONTAINER_PREFIX is set to SCRIPT, a new build container will be built for 
# each calling script. Although Docker will cache shared layers, lots of image
# names will be created. 
# Setting this to something of a broader "scope", such as the apps checkout 
# directory name, will produce 1 build container for all scripts.
##
: ${CONTAINER_PREFIX:=${SCRIPT}}

##
# Function to detect if we are running in a container.
# Credit: a bunch of different stackoverflow posts and others. Eg https://tuhrig.de/how-to-know-you-are-inside-a-docker-container/ and https://stackoverflow.com/questions/23513045/how-to-check-if-a-process-is-running-inside-docker-container
##
function is_container () {
  grep -qE '/docker/|/lxc/' /proc/1/cgroup
  echo "$?"
}

##
# Detect whether we are running in an interactive shell. This affects whether we
# add the docker run '-t' option.
#    - https://www.gnu.org/software/bash/manual/html_node/Is-this-Shell-Interactive_003f.html
##
case "$-" in
*i*)	DOCKER_RUN_OPTS="${DOCKER_RUN_OPTS} -t " ;;
esac


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

  ##
  # create a temporary Dockerfile with....
  ##
  local t_dockerfile=$(mktemp /tmp/Dockerfile.XXXXXXXXX)
  cat <<-EOF > "${t_dockerfile}"

    ##
    # Set the base image
    ##
    FROM ${DOCKER_RUN_IMAGE}

    ###
    # Add any dependencies necessary to run your tests, build, or deploy.
    ##
    #RUN export  DEBIAN_FRONTEND=noninteractive ;  apt-get update && \
    # apt-get install -y \
    #	jq  \
    #	build-essential  \
    #	--no-install-recommends \
    # --no-install-suggests \
    # && apt-get -y clean
    #	&& rm -rf /root/.cache /tmp/* /var/lib/apt/lists/* /var/tmp/*
    ##


    ##
    # This next section create all the necessary groups and users with the correct uid and gids
    #  NOTE: The commands run may be base image dependent! (eg useradd vs adduser)
    ##
    RUN addgroup --gid ${LOCAL_GID} ${LOCAL_USERNAME}
    RUN useradd --create-home -g ${LOCAL_GID} -u ${LOCAL_UID} ${LOCAL_USERNAME}

    ##
    # Run the container as the same calling user
    ##
    USER ${LOCAL_USERNAME}
EOF

    ##
    # Build the container. Remember, Docker is smart about caching layers so the above will likely only be built once!
    # NOTE: Output is only shown on error, OR if it's taking longer than 2 seconds to complete the build
    #
    # The sleep
    ##
    echo -n '' >.docker-build-output
    (docker build -t "${CONTAINER_PREFIX}_2musketeers:latest"  -f "${t_dockerfile}" .  &>>.docker-build-output || \
      { ERRCODE=$?; kill $loggerpid ; cat .docker-build-output ; exit ${ERRCODE}; }) & #show output on failure
    dockerbuild_pid=$!
    ( sleep 2; tail --pid=$dockerbuild_pid --lines=+0 -f .docker-build-output ) & #wait 5 secs then start showing the docker build output
    loggerpid=$!
    wait $dockerbuild_pid
    kill $loggerpid && wait $loggerpid 2>/dev/null #Cancel showing the docker build output (only when docker build was quicker)

    
    ##
    # Run docker and call the parent script..
    ##
    exec docker run --init -i \
      -v "${DIR}:${DIR}" \
      ${DOCKER_RUN_OPTS} \
      --env-file <( env| cut -f1 -d= | grep -vwF -e JAVA_HOME -e HOME -e PATH -e TEMP -e TMP -e TMPDIR) \
      --workdir "${PWD}" \
      "${CONTAINER_PREFIX}_2musketeers:latest" \
      "${DIR}/${SCRIPT}" \
      "$@"
}

##
# If we are not in a container, and we have been ask to run in local mode,
# run the calling script in docker
##
if [[ "x${RUN_LOCAL}" = "xfalse" ]] && [[ "x$(is_container)" = "x1" ]]; then
  docker_run "$@"
fi