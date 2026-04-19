FROM debian:bookworm-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        cron \
        curl \
        jq \
        gzip \
        ca-certificates && \
    rm -rf /var/lib/apt/lists/*

COPY backup.sh /usr/local/bin/backup.sh
COPY restore.sh /usr/local/bin/restore.sh
COPY cron-entrypoint.sh /cron-entrypoint.sh
RUN chmod +x /usr/local/bin/backup.sh /usr/local/bin/restore.sh /cron-entrypoint.sh && \
    touch /var/log/cron.log

ENTRYPOINT ["/cron-entrypoint.sh"]
