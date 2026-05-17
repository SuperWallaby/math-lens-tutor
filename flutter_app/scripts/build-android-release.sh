#!/usr/bin/env bash
# Android만 — 전체 릴리스는 ./release.sh 사용 권장
exec "$(dirname "$0")/release.sh" android "$@"
