FROM ultralytics/ultralytics:latest-jetson-jetpack6
# Optionally: RUN pip install "ultralytics==8.3.0"

RUN pip install --no-cache-dir fastapi "uvicorn[standard]" pydantic

WORKDIR /app
COPY app.py /app/app.py
EXPOSE 8000
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]
