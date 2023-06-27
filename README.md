# audiobookshelf-Docker

## Install

```bash
docker run -d \
  -p 13378:80 \
  -v </path/to/config>:/config \
  -v </path/to/metadata>:/metadata \
  -v </path/to/audiobooks>:/audiobooks \
  -v </path/to/podcasts>:/podcasts \
  -e PUID=1000 \
  -e PGID=1000 \
  -e UMASK=022 \
  -e TZ=Asia/Shanghai \
  --health-cmd="curl -f http://127.0.0.1/healthcheck || exit 1" \
  --health-interval=30s \
  --health-timeout=3s \
  --health-start-period=10s \
  --name audiobookshelf \
  ddsderek/audiobookshelf:latest
```

```yaml
version: '3.3'
services:
    audiobookshelf:
        ports:
            - '13378:80'
        volumes:
            - '</path/to/config>:/config'
            - '</path/to/metadata>:/metadata'
            - '</path/to/audiobooks>:/audiobooks'
            - '</path/to/podcasts>:/podcasts'
        environment:
            - PUID=1000
            - PGID=1000
            - UMASK=022
            - TZ=Asia/Shanghai
        healthcheck:
            test: ["CMD", "curl", "-f", "http://127.0.0.1/healthcheck"]
            interval: 30s
            timeout: 3s
            start_period: 10s
        container_name: audiobookshelf
        image: 'ddsderek/audiobookshelf:latest'
```