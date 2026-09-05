#!/usr/bin/env bash

set -ex

ERL_FLAGS="-sname shiroko -setcookie my-secret" gleam dev
