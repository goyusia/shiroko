#!/usr/bin/env bash

set -ex

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <branch-or-commit-id>" >&2
  exit 1
fi

cd /home/maint/apps/shiroko

git fetch
git checkout "$1"

cd shiroko && gleam build
# gleam export erlang-shipment
