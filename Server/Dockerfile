FROM node:24-bookworm-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends chromium ffmpeg fonts-wqy-zenhei \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY package.json ./
COPY src ./src
COPY scripts ./scripts

ENV PORT=3216 \
    OUTPUT_DIR=/data/output \
    CHROMIUM_BIN=/usr/bin/chromium \
    FFMPEG_BIN=/usr/bin/ffmpeg

EXPOSE 3216
CMD ["node", "src/server.js"]
