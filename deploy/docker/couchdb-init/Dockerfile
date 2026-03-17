FROM alpine:3.20

RUN apk add --no-cache bash curl

COPY couchdb-init.sh /usr/local/bin/couchdb-init.sh
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY curl /usr/local/bin/curl
RUN chmod +x /usr/local/bin/couchdb-init.sh
RUN chmod +x /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/curl

ENTRYPOINT ["bash", "/usr/local/bin/entrypoint.sh"]
