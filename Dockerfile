# syntax=docker/dockerfile:1.18
ARG NUSQLITE3_DIR="/usr/local/lib/nusqlite3"
ARG NUSQLITE3_PATH="${NUSQLITE3_DIR}/libnusqlite3.so"

FROM node:22-alpine AS prepare
ARG AUDIOBOOKSHELF_VERSION
RUN set -ex && apk add git jq curl
RUN set -ex && \
    git clone -b ${AUDIOBOOKSHELF_VERSION} https://github.com/advplyr/audiobookshelf.git /prepare

FROM node:22-alpine AS build-client
WORKDIR /client
COPY --from=prepare /prepare/client /client
RUN set -ex && npm ci && npm cache clean --force
RUN set -ex && npm run generate

FROM node:22-alpine AS build-server

ARG NUSQLITE3_DIR
ARG TARGETPLATFORM

ENV NODE_ENV=production

RUN apk add --no-cache --update \
    curl \
    make \
    python3 \
    g++ \
    unzip

WORKDIR /server
COPY --from=prepare /prepare/index.js /server
COPY --from=prepare /prepare/package* /server
COPY --from=prepare /prepare/server /server/server

RUN case "$TARGETPLATFORM" in \
    "linux/amd64") \
    curl -L -o /tmp/library.zip "https://github.com/mikiher/nunicode-sqlite/releases/download/v1.2/libnusqlite3-linux-musl-x64.zip" ;; \
    "linux/arm64") \
    curl -L -o /tmp/library.zip "https://github.com/mikiher/nunicode-sqlite/releases/download/v1.2/libnusqlite3-linux-musl-arm64.zip" ;; \
    *) echo "Unsupported platform: $TARGETPLATFORM" && exit 1 ;; \
    esac && \
    unzip /tmp/library.zip -d $NUSQLITE3_DIR && \
    rm /tmp/library.zip

RUN npm ci --only=production

FROM node:22-alpine

ARG NUSQLITE3_DIR
ARG NUSQLITE3_PATH

RUN set -ex && \
    apk add --no-cache --update \
    tzdata \
    ffmpeg \
    bash \
    jq \
    shadow \
    su-exec \
    unzip \
    dumb-init && \
    usermod --shell /bin/bash node && \
    rm -rf /var/cache/apk/*

COPY --from=build-client /client/dist /app/client/dist
COPY --from=build-server /server /app
COPY --from=build-server /usr/local/lib/nusqlite3 /usr/local/lib/nusqlite3

ENV PORT=80 \
    CONFIG_PATH="/config" \
    METADATA_PATH="/metadata" \
    SOURCE="docker" \
    NUSQLITE3_DIR=${NUSQLITE3_DIR} \
    NUSQLITE3_PATH=${NUSQLITE3_PATH} \
    NODE_ENV=production

COPY --chmod=755 entrypoint.sh /entrypoint.sh

ENTRYPOINT [ "/entrypoint.sh" ]

CMD ["node", "index.js"]

EXPOSE 80
