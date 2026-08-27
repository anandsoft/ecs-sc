#!/bin/sh
set -eu
envsubst '${CATALOG_HOST} ${CATALOG_PORT} ${SALES_HOST} ${SALES_PORT}' \
  < /etc/nginx/templates/default.conf.template \
  > /etc/nginx/conf.d/default.conf
exec nginx -g 'daemon off;'
