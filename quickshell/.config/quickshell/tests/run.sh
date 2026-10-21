#!/bin/bash
# Run the JS unit tests (needs node).  Usage: tests/run.sh
here="$(dirname "$0")"
node "$here/run.mjs" "$@" || exit 1
python3 "$here/../scripts/palette.py" --self-test
