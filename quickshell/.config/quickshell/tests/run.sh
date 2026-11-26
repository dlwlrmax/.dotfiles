#!/bin/bash
# Run the JS unit tests (needs node), the launcher script tests and the
# stow-configs tests.  Usage: tests/run.sh
here="$(dirname "$0")"
node "$here/run.mjs" "$@" || exit 1
bash "$here/scripts.sh" || exit 1
bash "$here/stow-configs.sh" || exit 1
python3 "$here/../scripts/palette.py" --self-test
