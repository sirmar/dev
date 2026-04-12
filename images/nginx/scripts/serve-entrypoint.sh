#!/bin/sh
if [ -f /etc/nginx/conf.d/default.conf.template ]; then
	envsubst "$(env | cut -d= -f1 | sed 's/^/$/g' | tr '\n' ' ')" </etc/nginx/conf.d/default.conf.template >/etc/nginx/conf.d/default.conf
fi
exec nginx -g "daemon off;"
