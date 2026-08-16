#!/usr/bin/env bash
set -Eeuo pipefail

if [ "${NODE_ENV:-development}" = "production" ]; then
  exec npm run --prefix frontend start -- --mode=production
fi

exec npm run --prefix frontend start
