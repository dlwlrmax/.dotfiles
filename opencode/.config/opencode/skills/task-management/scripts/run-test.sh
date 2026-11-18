#!/usr/bin/env bash
# Temporary helper: runs a command in the langmaster project root.
# Used by TestEngineer to execute phpunit/pint when no shell tool is exposed.
set -e
cd /home/kienct/gitlab/langmaster.edu.vn
exec "$@"
