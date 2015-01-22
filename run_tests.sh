#!/bin/bash

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SRC_DIR="${DIR}/src"
DIST_DIR="${DIR}/dist"

# ${DIR}/compile.sh

cp "${SRC_DIR}"/*.lua "${DIST_DIR}/"
busted --cwd="${DIR}/" --pattern="test_" --lpath="${DIST_DIR}/?.lua;${DIST_DIR}/?/init.lua" "${DIST_DIR}"
