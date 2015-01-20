#!/bin/bash

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SRC_DIR="${DIR}/src"
DIST_DIR="${DIR}/dist"

rm -rf "${DIST_DIR}"
mkdir -p "${DIST_DIR}"

LUA_PATH="${SRC_DIR}/?.lua;;" tlc -o "${DIST_DIR}/node.lua" "${SRC_DIR}/node.tl"
LUA_PATH="${SRC_DIR}/?.lua;;" tlc -o "${DIST_DIR}/javautils.lua" "${SRC_DIR}/javautils.tl"
LUA_PATH="${SRC_DIR}/?.lua;;" tlc -o "${DIST_DIR}/javanode.lua" "${SRC_DIR}/javanode.tl"
LUA_PATH="${SRC_DIR}/?.lua;;" tlc -o "${DIST_DIR}/java.lua" "${SRC_DIR}/java.tl"
LUA_PATH="${SRC_DIR}/?.lua;;" tlc -o "${DIST_DIR}/swiftnode.lua" "${SRC_DIR}/swiftnode.tl"
LUA_PATH="${SRC_DIR}/?.lua;;" tlc -o "${DIST_DIR}/swift.lua" "${SRC_DIR}/swift.tl"

cp "${SRC_DIR}"/*.lua "${DIST_DIR}/"
