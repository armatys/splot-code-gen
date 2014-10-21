#!/bin/bash

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SRC_DIR="${DIR}/src"

LUA_PATH="${SRC_DIR}/?.lua;;" tlc -o "${SRC_DIR}/codetree.lua" "${SRC_DIR}/codetree.tl"
LUA_PATH="${SRC_DIR}/?.lua;;" tlc -o "${SRC_DIR}/javatree.lua" "${SRC_DIR}/javatree.tl"

busted --cwd="${DIR}/" --pattern="test_" "${SRC_DIR}"
