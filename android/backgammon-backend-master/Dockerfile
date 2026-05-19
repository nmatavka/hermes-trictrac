FROM ubuntu:resolute

RUN apt-get update && apt-get install -y --no-install-recommends \
    openjdk-25-jre-headless \
    gnubg \
    && rm -rf /var/lib/apt/lists/*

# 2. Setup App Directory
WORKDIR /app

# 3. Copy the pre-built JAR
# We assume the jar is in the same folder as this Dockerfile
COPY . .

# 4. Run it
ENV PORT=8080
EXPOSE 8080
ENTRYPOINT ["bash", "./bin/kotlin-backend"]