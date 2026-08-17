FROM python:3.12-slim

WORKDIR /app

COPY app.py .

RUN pip install --no-cache-dir flask requests

EXPOSE 8000

CMD ["python", "app.py"]
