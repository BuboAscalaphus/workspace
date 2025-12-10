#!/usr/bin/env bash

docker build -t ros-image .
docker build -t yolo-api -f ./ultra_api/Dockerfile ./ultra_api
