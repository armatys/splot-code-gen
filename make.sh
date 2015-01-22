#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
"${DIR}"/compile.sh
"${DIR}"/run_tests.sh
