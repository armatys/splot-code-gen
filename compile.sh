#!/bin/bash

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SRC_DIR="${DIR}/src"
DIST_DIR="${DIR}/dist"
: ${TLC:="tlc"}
: ${TLC_MODULES:=""}

rm -rf "${DIST_DIR}"
mkdir -p "${DIST_DIR}"

LUA_PATH="${TLC_MODULES}${SRC_DIR}/?.lua;;" ${TLC} -o "${DIST_DIR}/node.lua" "${SRC_DIR}/node.tl"
LUA_PATH="${TLC_MODULES}${SRC_DIR}/?.lua;;" ${TLC} -o "${DIST_DIR}/javautils.lua" "${SRC_DIR}/javautils.tl"
LUA_PATH="${TLC_MODULES}${SRC_DIR}/?.lua;;" ${TLC} -o "${DIST_DIR}/javanode.lua" "${SRC_DIR}/javanode.tl"
LUA_PATH="${TLC_MODULES}${SRC_DIR}/?.lua;;" ${TLC} -o "${DIST_DIR}/java.lua" "${SRC_DIR}/java.tl"
LUA_PATH="${TLC_MODULES}${SRC_DIR}/?.lua;;" ${TLC} -o "${DIST_DIR}/swiftnode.lua" "${SRC_DIR}/swiftnode.tl"
LUA_PATH="${TLC_MODULES}${SRC_DIR}/?.lua;;" ${TLC} -o "${DIST_DIR}/swift.lua" "${SRC_DIR}/swift.tl"
LUA_PATH="${TLC_MODULES}${SRC_DIR}/?.lua;;" ${TLC} -o "${DIST_DIR}/main.lua" "${SRC_DIR}/main.tl"

cp "${SRC_DIR}"/*.lua "${DIST_DIR}/"
