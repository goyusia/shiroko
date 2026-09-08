#!/usr/bin/env bash

set -ex

cd /home/maint/apps/shiroko

git pull
gleam export erlang-shipment

