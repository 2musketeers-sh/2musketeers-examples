#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SCRIPT=`basename "$0"`
CONTAINER_PREFIX=`basename ${DIR}`

source "${DIR}/2musketeers.sh"

./mvnw verify 