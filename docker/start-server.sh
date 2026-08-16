#!/usr/bin/env bash
set -Eeuo pipefail

if [ "${NODE_ENV:-development}" = "production" ]; then
  exec npm run --prefix server start:prod
fi

exec npm run --prefix server start:dev
