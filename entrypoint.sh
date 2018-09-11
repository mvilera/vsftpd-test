#!/bin/bash

set -e
cp /etc/ssl/private/clients/pems/* /pems

exec "$@"
