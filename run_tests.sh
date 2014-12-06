#!/bin/bash

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SRC_DIR="${DIR}/src"

LUA_PATH="${SRC_DIR}/?.lua;;" tlc -o "${SRC_DIR}/node.lua" "${SRC_DIR}/node.tl"
LUA_PATH="${SRC_DIR}/?.lua;;" tlc -o "${SRC_DIR}/javautils.lua" "${SRC_DIR}/javautils.tl"
LUA_PATH="${SRC_DIR}/?.lua;;" tlc -o "${SRC_DIR}/javanode.lua" "${SRC_DIR}/javanode.tl"
LUA_PATH="${SRC_DIR}/?.lua;;" tlc -o "${SRC_DIR}/java.lua" "${SRC_DIR}/java.tl"

busted --cwd="${DIR}/" --pattern="test_" "${SRC_DIR}"
