#!/bin/bash
set -e

case "$1" in
  shell|bash|sh)
    shift
    exec bash "$@"
    ;;
esac
 
# Fordward flags at startup
exec freenet "$@"
 
