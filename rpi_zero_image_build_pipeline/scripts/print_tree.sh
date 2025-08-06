#!/usr/bin/env bash
set -e
echo "Repository tree preview:"
find ../sa-image -maxdepth 3 -type f -printf "%p\n" | sed 's#^../##'
