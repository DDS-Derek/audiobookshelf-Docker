# syntax=docker/dockerfile:1.13

FROM node:20-alpine AS prepare
ARG AUDIOBOOKSHELF_VERSION
RUN set -ex && apk add git jq curl
RUN set -ex && \
    git clone -b ${AUDIOBOOKSHELF_VERSION} https://github.com/advplyr/audiobookshelf.git /prepare

FROM node:20-alpine AS build
WORKDIR /client
COPY --from=prepare /prepare/client /client
RUN set -ex && npm ci && npm cache clean --force
RUN set -ex && npm run generate

FROM node:20-alpine AS integrate
COPY --from=build /client/dist /app/client/dist
COPY --from=prepare /prepare/index.js /app
COPY --from=prepare /prepare/package* /app
COPY --from=prepare /prepare/server /app/server

FROM node:20-alpine
ENV NODE_ENV=production
ENV NUSQLITE3_DIR="/usr/local/lib/nusqlite3"
ENV NUSQLITE3_PATH="${NUSQLITE3_DIR}/libnusqlite3.so"
ARG TARGETPLATFORM
RUN set -ex && \
    apk add --no-cache --update \
        curl \
        tzdata \
        ffmpeg \
        bash \
        jq \
        shadow \
        su-exec \
        unzip \
        dumb-init && \
    usermod --shell /bin/bash node && \
    case "$TARGETPLATFORM" in \
    "linux/amd64") \
    curl -L -o /tmp/library.zip "https://github.com/mikiher/nunicode-sqlite/releases/download/v1.2/libnusqlite3-linux-musl-x64.zip" ;; \
    "linux/arm64") \
    curl -L -o /tmp/library.zip "https://github.com/mikiher/nunicode-sqlite/releases/download/v1.2/libnusqlite3-linux-musl-arm64.zip" ;; \
    *) echo "Unsupported platform: $TARGETPLATFORM" && exit 1 ;; \
    esac && \
    unzip /tmp/library.zip -d $NUSQLITE3_DIR && \
    rm -rf /tmp/library.zip /var/cache/apk/*
COPY --from=integrate /app /app
RUN set -ex && \
    cd /app && \
    apk add --no-cache --update --virtual .build-deps \
        make \
        python3 \
        g++ && \
    npm ci --only=production && \
    apk del --purge .build-deps \
    rm -rf /var/cache/apk/*
ENV PORT=80 \
    CONFIG_PATH="/config" \
    METADATA_PATH="/metadata" \
    SOURCE="docker"
COPY --chmod=755 entrypoint.sh /entrypoint.sh
ENTRYPOINT [ "/entrypoint.sh" ]
CMD ["node", "index.js"]
EXPOSE 80
