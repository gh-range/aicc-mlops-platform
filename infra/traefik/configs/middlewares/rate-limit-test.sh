#!/bin/bash
for i in {1..120}; do
  curl -o /dev/null -s -w "%{http_code}\n" -k https://traefik.aicc.local/dashboard/ &
done
wait
