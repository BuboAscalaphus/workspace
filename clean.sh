#!/usr/bin/env bash

rm -rf build install log

find src -mindepth 1 -maxdepth 1 \
  ! -name owl_bags \
  ! -name owl_weights \
  -exec rm -rf {} +





