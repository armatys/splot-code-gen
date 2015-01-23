#!/bin/bash

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
DIST_DIR="${DIR}/dist"

tup upd
echo -e "\n\nRunning tests...\n\n"
busted --cwd="${DIR}/" --pattern="test_" --lpath="${DIST_DIR}/?.lua;${DIST_DIR}/?/init.lua" "${DIST_DIR}"
