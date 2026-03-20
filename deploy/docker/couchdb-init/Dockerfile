FROM alpine:3.20

RUN apk add --no-cache bash curl nodejs npm

# Install the encryption helper used by LiveSync setup URI generation.
RUN mkdir -p /opt/setupuri \
    && cd /opt/setupuri \
    && npm init -y >/dev/null 2>&1 \
    && npm install --omit=dev octagonal-wheels@0.1.30 >/dev/null 2>&1

COPY couchdb-init.sh /usr/local/bin/couchdb-init.sh
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY curl /usr/local/bin/curl
COPY generate-setupuri.mjs /opt/setupuri/generate-setupuri.mjs
RUN chmod +x /usr/local/bin/couchdb-init.sh
RUN chmod +x /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/curl

ENTRYPOINT ["bash", "/usr/local/bin/entrypoint.sh"]
