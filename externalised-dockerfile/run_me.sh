#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SCRIPT=`basename "$0"`

source "${DIR}/2musketeers.sh"

echo "I'm in docker! I am $(whoami)"% 