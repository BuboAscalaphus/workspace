#!/usr/bin/env bash

rm -rf src
vcs import src < your.repos
vcs pull --recursive src


