#!/bin/bash

set -euo pipefail

mkdir -p External
wget https://github.com/meilisearch/meilisearch/releases/download/v1.22.1/meilisearch-macos-apple-silicon -O External/meilisearch

chmod +x External/meilisearch

./External/meilisearch --version

