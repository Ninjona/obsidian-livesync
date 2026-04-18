#!/bin/bash
if [[ -z "$hostname" ]]; then
    echo "ERROR: Hostname missing"
    exit 1
fi
if [[ -z "$admin_username" ]]; then
    echo "ERROR: admin_username missing"
    exit 1
fi

if [[ -z "$admin_password" ]]; then
    echo "ERROR: admin_password missing"
    exit 1
fi
if [[ -z "$node" ]]; then
    echo "INFO: defaulting to _local"
    node=_local
fi

echo "-- Configuring CouchDB by REST APIs... -->"

until (curl -X POST "${hostname}/_cluster_setup" -H "Content-Type: application/json" -d "{\"action\":\"enable_single_node\",\"username\":\"${admin_username}\",\"password\":\"${admin_password}\",\"bind_address\":\"0.0.0.0\",\"port\":5984,\"singlenode\":true}" --user "${admin_username}:${admin_password}"); do sleep 5; done
until (curl -X PUT "${hostname}/_node/${node}/_config/chttpd/require_valid_user" -H "Content-Type: application/json" -d '"true"' --user "${admin_username}:${admin_password}"); do sleep 5; done
until (curl -X PUT "${hostname}/_node/${node}/_config/chttpd_auth/require_valid_user" -H "Content-Type: application/json" -d '"true"' --user "${admin_username}:${admin_password}"); do sleep 5; done
until (curl -X PUT "${hostname}/_node/${node}/_config/httpd/WWW-Authenticate" -H "Content-Type: application/json" -d '"Basic realm=\"couchdb\""' --user "${admin_username}:${admin_password}"); do sleep 5; done
until (curl -X PUT "${hostname}/_node/${node}/_config/httpd/enable_cors" -H "Content-Type: application/json" -d '"true"' --user "${admin_username}:${admin_password}"); do sleep 5; done
until (curl -X PUT "${hostname}/_node/${node}/_config/chttpd/enable_cors" -H "Content-Type: application/json" -d '"true"' --user "${admin_username}:${admin_password}"); do sleep 5; done
until (curl -X PUT "${hostname}/_node/${node}/_config/chttpd/max_http_request_size" -H "Content-Type: application/json" -d '"4294967296"' --user "${admin_username}:${admin_password}"); do sleep 5; done
until (curl -X PUT "${hostname}/_node/${node}/_config/couchdb/max_document_size" -H "Content-Type: application/json" -d '"50000000"' --user "${admin_username}:${admin_password}"); do sleep 5; done
until (curl -X PUT "${hostname}/_node/${node}/_config/cors/credentials" -H "Content-Type: application/json" -d '"true"' --user "${admin_username}:${admin_password}"); do sleep 5; done
until (curl -X PUT "${hostname}/_node/${node}/_config/cors/origins" -H "Content-Type: application/json" -d '"app://obsidian.md,capacitor://localhost,http://localhost"' --user "${admin_username}:${admin_password}"); do sleep 5; done
until (curl -X PUT "${hostname}/_node/${node}/_config/cors/methods" -H "Content-Type: application/json" -d '"GET, PUT, POST, HEAD, DELETE, OPTIONS"' --user "${admin_username}:${admin_password}"); do sleep 5; done
until (curl -X PUT "${hostname}/_node/${node}/_config/cors/headers" -H "Content-Type: application/json" -d '"accept, authorization, content-type, origin, referer, x-requested-with"' --user "${admin_username}:${admin_password}"); do sleep 5; done

echo "<-- Configuring CouchDB by REST APIs Done!"
