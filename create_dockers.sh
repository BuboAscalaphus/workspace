#!/usr/bin/env bash

docker build -t ros-image .
docker build -t yolo-api -f ./ultra-api/Dockerfile ./ultra-api
