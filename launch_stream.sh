ffmpeg -re -stream_loop -1 -i ./output.mp4   -vf scale=1280:720   -c:v libx264 -preset ultrafast -tune zerolatency -pix_fmt yuv420p   -f rtsp -rtsp_transport tcp rtsp://localhost:8554/cam1
