#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SCRIPT=`basename "$0"`

# Speed up mvn builds
DOCKER_RUN_OPTS="-v ${HOME}/.m2:${HOME}/.m2 -v ${HOME}/.gradle:${HOME}/.gradle"

source "${DIR}/2musketeers.sh"

bash "$@"