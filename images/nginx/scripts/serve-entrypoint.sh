#!/bin/sh
if [ -f /etc/nginx/conf.d/default.conf.template ]; then
	envsubst </etc/nginx/conf.d/default.conf.template >/etc/nginx/conf.d/default.conf
fi
exec nginx -g "daemon off;"
