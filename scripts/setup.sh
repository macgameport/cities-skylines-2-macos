#!/bin/bash
# Compatibility forwarder. Cities: Skylines II's setup now lives at cities-skylines-2/scripts/setup.sh:
# this repository became one folder per game in 2026-11. Older clones and older instructions run
# `bash scripts/setup.sh` from the repo root, and this keeps them working. Arguments pass through.
exec bash "$(cd "$(dirname "$0")/.." && pwd)/cities-skylines-2/scripts/setup.sh" "$@"
