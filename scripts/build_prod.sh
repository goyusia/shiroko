#!/usr/bin/env bash

set -ex

cd /home/maint/apps/shiroko

git pull

cd shiroko && gleam build
# gleam export erlang-shipment
