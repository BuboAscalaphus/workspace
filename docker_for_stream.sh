docker run --rm --name mediamtx   -p 8554:8554   -e MTX_READTIMEOUT=1000s   -e MTX_WRITETIMEOUT=100s   bluenviron/mediamtx:latest
