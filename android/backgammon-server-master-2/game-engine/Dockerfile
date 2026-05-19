FROM python:3.11-slim

RUN apt-get update && \
    apt-get install -y gnubg && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /

COPY . .

RUN pip install --no-cache-dir -r /requirements.txt || true

ENV PATH="/usr/games:${PATH}"

EXPOSE 5000

CMD ["python","-u", "/app/app.py"]