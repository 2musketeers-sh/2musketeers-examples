#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SCRIPT=`basename "$0"`
CONTAINER_PREFIX=`basename ${DIR}`

# Speed up mvn builds
DOCKER_RUN_OPTS="-v ${HOME}/.m2:${HOME}/.m2"
DOCKER_BUILD_OPTS="-q"

source "${DIR}/2musketeers.sh"

bash "$@"