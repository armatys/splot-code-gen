#!/bin/bash

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
pushd "${DIR}/src"

tlc -o codetree.lua codetree.tl
tlc -o javatree.lua javatree.tl

busted test_codetree.lua
busted test_javatree.lua

popd
