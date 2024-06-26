# syntax=docker/dockerfile:1.8

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

FROM sandreas/tone:v0.1.5 AS tone

FROM node:20-alpine
ENV NODE_ENV=production
RUN set -ex && \
    apk add --no-cache --update \
        curl \
        tzdata \
        ffmpeg \
        bash \
        jq \
        shadow \
        su-exec \
        dumb-init && \
    usermod --shell /bin/bash node && \
    rm -rf /var/cache/apk/*
COPY --from=tone /usr/local/bin/tone /usr/local/bin/
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
COPY --chmod=755 entrypoint.sh /entrypoint.sh
ENTRYPOINT [ "/entrypoint.sh" ]
CMD ["node", "index.js"]
EXPOSE 80
