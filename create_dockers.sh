#!/usr/bin/env bash

docker build --network host -t ros-image-vizionsdk-25-12 .
docker build --network host -t yolo-api -f ./ultra_api/Dockerfile ./ultra_api
