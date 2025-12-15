docker run --rm --name mediamtx \
  --network host \
  -e MTX_READTIMEOUT=1000s \
  -e MTX_WRITETIMEOUT=100s \
  bluenviron/mediamtx:latest

