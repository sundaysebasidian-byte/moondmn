#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
commit=1e349176e5ae689d924a2a2c7a8df25c220d8b07
if [ -d .tck ]; then
  test "$(git -C .tck rev-parse HEAD)" = "$commit"
  test -z "$(git -C .tck status --porcelain)"
  exit 0
fi
git clone --no-checkout https://github.com/dmn-tck/tck.git .tck
git -C .tck checkout --detach "$commit"
