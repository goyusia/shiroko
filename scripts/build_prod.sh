#!/usr/bin/env bash

set -ex

cd /home/maint/apps/shiroko

git pull
gleam build
# gleam export erlang-shipment
