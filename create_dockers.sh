#!/usr/bin/env bash

docker build --network host -t ros-image .
docker build --network host -t yolo-api -f ./ultra_api/Dockerfile ./ultra_api
