FROM couchdb:3.4

RUN apt-get update && \
    apt-get install -y cron jq curl gzip && \
    rm -rf /var/lib/apt/lists/*

COPY backup/backup.sh /usr/local/bin/backup.sh
COPY backup/restore.sh /usr/local/bin/restore.sh
COPY backup/backup-cron /etc/cron.d/backup-cron
COPY backup/cron-entrypoint.sh /cron-entrypoint.sh
RUN chmod +x /usr/local/bin/backup.sh /usr/local/bin/restore.sh /cron-entrypoint.sh && \
    touch /var/log/cron.log && \
    crontab /etc/cron.d/backup-cron

ENTRYPOINT ["/cron-entrypoint.sh"]
