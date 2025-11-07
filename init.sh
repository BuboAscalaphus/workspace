#!/usr/bin/env bash

sudo apt install python3-vcstool
vcs import src < my.repos
sed -i 's|^WS=${WS:-$HOME/ros2_ws}|WS=${WS:-$HOME/workspace}|' "./src/owl_tools/config.sh"

